import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import '../audit_log_service.dart';
import '../receipt_text.dart';
import '../windows_printers_service.dart';
import 'escpos_receipt_builder.dart';
import 'printer_profile.dart';

// ── Print job ─────────────────────────────────────────────────────────────────

class _PrintJob {
  _PrintJob({
    required this.jobId,
    required this.printerName,
    required this.escPosBytes,
    required this.fallbackText,
    this.retryCount = 0,
  });

  final String jobId;
  final String printerName;
  final Uint8List escPosBytes;
  final String fallbackText;
  final int retryCount;

  _PrintJob withRetry() => _PrintJob(
    jobId: jobId,
    printerName: printerName,
    escPosBytes: escPosBytes,
    fallbackText: fallbackText,
    retryCount: retryCount + 1,
  );
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Production-grade ESC/POS thermal printer service.
///
/// Features:
/// - Raw ESC/POS bytes sent via Win32 winspool.drv (PowerShell P/Invoke)
/// - One automatic retry on first failure
/// - Silent text-mode fallback when ESC/POS fails after retry
/// - FIFO print queue — duplicate job IDs are dropped
/// - Non-blocking: [enqueue] returns immediately; jobs process in the background
/// - Cash drawer kick via ESC p
/// - Audit log on fallback / failure
///
/// Future extension points (not implemented):
/// - Android USB OTG: swap [_sendRawBytes] backend
/// - Bluetooth ESC/POS: swap [_sendRawBytes] backend
/// - Network/LAN: swap [_sendRawBytes] backend
/// - Sunmi internal printer: call Sunmi SDK via platform channel
class EscPosPrinterService {
  EscPosPrinterService._();
  static final EscPosPrinterService instance = EscPosPrinterService._();

  final Queue<_PrintJob> _queue = Queue();
  final Set<String> _queued = {};   // de-duplication set
  bool _processing = false;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Enqueue a kitchen-order or payment receipt for background printing.
  ///
  /// [jobId] should be unique per receipt (e.g. 'kitchen-<orderNumber>').
  /// If an identical [jobId] is already in the queue the new job is dropped,
  /// preventing double-print on rapid payment taps.
  void enqueue({
    required String jobId,
    required String printerName,
    required Uint8List escPosBytes,
    required String fallbackText,
  }) {
    if (_queued.contains(jobId)) return;
    _queued.add(jobId);
    _queue.add(_PrintJob(
      jobId: jobId,
      printerName: printerName,
      escPosBytes: escPosBytes,
      fallbackText: fallbackText,
    ));
    _processQueue();
  }

  /// Synchronously print (awaitable) — used when the caller needs to know the
  /// result before proceeding (e.g. payment confirmation flow).
  Future<bool> printNow({
    required String printerName,
    required Uint8List escPosBytes,
    required String fallbackText,
  }) => _executeJob(_PrintJob(
    jobId: 'immediate-${DateTime.now().millisecondsSinceEpoch}',
    printerName: printerName,
    escPosBytes: escPosBytes,
    fallbackText: fallbackText,
  ));

  /// Build and print a test page immediately.
  Future<bool> printTestPage({
    required String printerName,
    required String companyName,
    required PrinterProfile profile,
  }) {
    final bytes = EscPosReceiptBuilder.buildTestReceipt(
      profile: profile,
      companyName: companyName,
    );
    final fallback = '=== TEST PRINT ===\n$companyName\nProfile: ${profile.name}\n'
        'Paper: ${profile.paperWidthMm}mm  Cut: ${profile.supportsCut}  Drawer: ${profile.supportsDrawer}\n';
    return printNow(
      printerName: printerName,
      escPosBytes: bytes,
      fallbackText: fallback,
    );
  }

  /// Send a cash-drawer kick command.
  ///
  /// Always fire-and-forget; errors are silently discarded to avoid
  /// blocking the payment flow.
  Future<void> openCashDrawer(String printerName) async {
    if (printerName.trim().isEmpty) return;
    try {
      // Drawer kick only — 5 bytes: ESC p 0 t1 t2
      final bytes = Uint8List.fromList([0x1B, 0x70, 0x00, 0x19, 0xFA]);
      await _sendRawBytes(printerName: printerName, bytes: bytes);
    } catch (_) {
      // Non-fatal: cash drawer failure never blocks payment.
    }
  }

  /// Detect the printer profile from its Windows name.
  PrinterProfile profileFor(String printerName, {int paperWidthMm = 80}) {
    final detected = PrinterProfile.detectFromName(printerName);
    return paperWidthMm != detected.paperWidthMm
        ? detected.withPaperWidth(paperWidthMm)
        : detected;
  }

  // ── Queue processing ──────────────────────────────────────────────────────

  void _processQueue() {
    if (_processing || _queue.isEmpty) return;
    _processing = true;
    _runNext();
  }

  Future<void> _runNext() async {
    while (_queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _queued.remove(job.jobId);
      await _executeJob(job);
    }
    _processing = false;
  }

  // ── Job execution: ESC/POS → retry → text fallback ───────────────────────

  Future<bool> _executeJob(_PrintJob job) async {
    // 1. First attempt — ESC/POS raw bytes.
    bool ok = await _sendRawBytes(
      printerName: job.printerName,
      bytes: job.escPosBytes,
    );
    if (ok) return true;

    // 2. Single retry.
    if (job.retryCount == 0) {
      ok = await _sendRawBytes(
        printerName: job.printerName,
        bytes: job.escPosBytes,
      );
      if (ok) return true;
    }

    // 3. Text fallback — never crash the payment flow.
    _logFallback(job.printerName);
    return _textFallback(printerName: job.printerName, text: job.fallbackText);
  }

  // ── Transport layer ───────────────────────────────────────────────────────

  /// Send raw bytes to a Windows printer via winspool.drv (P/Invoke).
  ///
  /// The PowerShell script uses [Add-Type] to compile a tiny C# shim that
  /// calls OpenPrinter / StartDocPrinter / WritePrinter / EndDocPrinter
  /// with data type "RAW" — bypassing GDI completely.
  Future<bool> _sendRawBytes({
    required String printerName,
    required Uint8List bytes,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!Platform.isWindows) return false;
    if (printerName.trim().isEmpty || bytes.isEmpty) return false;

    final tempDir = await Directory.systemTemp.createTemp('pos_escpos_');
    try {
      final binFile = File('${tempDir.path}\\receipt.bin');
      await binFile.writeAsBytes(bytes, flush: true);

      final safePath    = binFile.path.replaceAll("'", "''");
      final safePrinter = printerName.replaceAll("'", "''");

      final script = _rawPrintScript(safePrinter, safePath);

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      ).timeout(timeout, onTimeout: () => ProcessResult(-1, 1, '', 'timeout'));

      return result.exitCode == 0;
    } catch (_) {
      return false;
    } finally {
      await tempDir.delete(recursive: true).catchError((_) {});
    }
  }

  /// Fallback — identical to the original [WindowsPrintersService.printRawText].
  Future<bool> _textFallback({
    required String printerName,
    required String text,
  }) async {
    try {
      return await WindowsPrintersService.printRawText(
        printerName: printerName,
        text: '$text\n\n\n',
      );
    } catch (_) {
      return false;
    }
  }

  void _logFallback(String printerName) {
    AuditLogService.instance.log(
      actionType: AuditAction.settingChanged,
      entityType: 'printer',
      details: {
        'event': 'escpos_fallback',
        'printer': printerName,
        'reason': 'raw_bytes_failed',
      },
    );
  }

  // ── PowerShell / Win32 script ─────────────────────────────────────────────

  /// Builds a self-contained PowerShell script that:
  /// 1. Compiles a C# helper class (once per process, cached by .NET)
  /// 2. Reads the binary receipt file
  /// 3. Sends it to [printerName] as a RAW print job via winspool.drv
  static String _rawPrintScript(String printerName, String binPath) => r"""
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class EscPosRawPrint {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DOCINFO {
        [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPWStr)] public string pDataType;
    }
    [DllImport("winspool.Drv", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool OpenPrinter(string szPrinter, out IntPtr hPrinter, IntPtr pd);
    [DllImport("winspool.Drv", SetLastError = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);
    [DllImport("winspool.Drv", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern int StartDocPrinter(IntPtr hPrinter, int level, ref DOCINFO pDocInfo);
    [DllImport("winspool.Drv", SetLastError = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);
    [DllImport("winspool.Drv", SetLastError = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);
    [DllImport("winspool.Drv", SetLastError = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);
    [DllImport("winspool.Drv", SetLastError = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    public static bool Print(string printer, byte[] data) {
        IntPtr hPrinter = IntPtr.Zero;
        if (!OpenPrinter(printer, out hPrinter, IntPtr.Zero)) return false;
        try {
            var di = new DOCINFO {
                pDocName = "POS Receipt",
                pOutputFile = null,
                pDataType = "RAW"
            };
            if (StartDocPrinter(hPrinter, 1, ref di) == 0) return false;
            StartPagePrinter(hPrinter);
            IntPtr ptr = Marshal.AllocCoTaskMem(data.Length);
            try {
                Marshal.Copy(data, 0, ptr, data.Length);
                int written = 0;
                WritePrinter(hPrinter, ptr, data.Length, out written);
            } finally {
                Marshal.FreeCoTaskMem(ptr);
            }
            EndPagePrinter(hPrinter);
            EndDocPrinter(hPrinter);
            return true;
        } finally {
            ClosePrinter(hPrinter);
        }
    }
}
'@ -Language CSharp -ErrorAction Stop
""" +
      '''
\$bytes = [System.IO.File]::ReadAllBytes('$binPath')
if ([EscPosRawPrint]::Print('$printerName', \$bytes)) { exit 0 } else { exit 1 }
''';
}
