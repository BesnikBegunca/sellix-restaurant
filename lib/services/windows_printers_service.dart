import 'dart:io';

class WindowsPrintersService {
  const WindowsPrintersService._();

  // ── Printer discovery ────────────────────────────────────────────────────

  /// Returns the name of the system default printer, or null if none is set
  /// or the platform is not Windows.
  static Future<String?> getDefaultPrinter() async {
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'(Get-Printer | Where-Object { $_.Default -eq $true } | Select-Object -First 1 -ExpandProperty Name)',
      ]).timeout(const Duration(seconds: 5), onTimeout: () => ProcessResult(-1, 1, '', ''));
      if (result.exitCode != 0) return null;
      final name = (result.stdout as String).trim();
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  /// Returns true when the named printer exists in the Windows spooler AND
  /// reports a status of "Normal" (i.e. online, no error).
  ///
  /// A return value of false means the printer is offline, paused, in an
  /// error state, or does not exist — the caller should warn the user before
  /// attempting to print.
  static Future<bool> isPrinterOnline(String printerName) async {
    if (!Platform.isWindows) return false;
    if (printerName.trim().isEmpty) return false;
    final escaped = printerName.replaceAll("'", "''");
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '''
try {
  \$p = Get-Printer -Name '$escaped' -ErrorAction Stop
  if (\$p.PrinterStatus -eq 'Normal') { exit 0 } else { exit 1 }
} catch { exit 2 }
''',
      ]).timeout(const Duration(seconds: 5), onTimeout: () => ProcessResult(-1, 1, '', ''));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<List<String>> listInstalledPrinters() async {
    if (!Platform.isWindows) return const [];

    final result = await Process.run('powershell', const [
      '-NoProfile',
      '-Command',
      'Get-Printer | Select-Object -ExpandProperty Name',
    ]);

    if (result.exitCode != 0) return const [];

    final output = (result.stdout as String?) ?? '';
    final names = output
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return names;
  }

  static Future<bool> printRawText({
    required String printerName,
    required String text,
  }) async {
    if (!Platform.isWindows) return false;
    if (printerName.trim().isEmpty) return false;

    final tempDir = await Directory.systemTemp.createTemp('pos_print_');
    try {
      final file = File('${tempDir.path}\\receipt.txt');
      await file.writeAsString(text, flush: true);

      final escapedPath = file.path.replaceAll("'", "''");
      final escapedPrinter = printerName.replaceAll("'", "''");
      final cmd = '''
\$printerName = '$escapedPrinter'
\$textPath = '$escapedPath'
\$text = Get-Content -LiteralPath \$textPath -Raw

Add-Type -AssemblyName System.Drawing

\$doc = New-Object System.Drawing.Printing.PrintDocument
\$doc.PrinterSettings.PrinterName = \$printerName
\$doc.PrintController = New-Object System.Drawing.Printing.StandardPrintController

# Use the printer's own paper profile (usually 80mm receipt on POS80 driver).
\$doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0, 0, 0, 0)

\$fontRegular = New-Object System.Drawing.Font('Consolas', 11, [System.Drawing.FontStyle]::Regular)
\$fontBold = New-Object System.Drawing.Font('Consolas', 11, [System.Drawing.FontStyle]::Bold)
\$lineHeight = \$fontRegular.GetHeight() + 2

\$doc.add_PrintPage({
  param(\$sender, \$e)
  \$brush = [System.Drawing.Brushes]::Black
  \$x = 0
  \$y = 0
  \$e.Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit
  \$lines = \$text -split \"`r?`n\"
  foreach (\$line in \$lines) {
    if (\$line.StartsWith('[[B]]') -and \$line.EndsWith('[[/B]]')) {
      \$clean = \$line.Substring(5, \$line.Length - 11)
      \$e.Graphics.DrawString(\$clean, \$fontBold, \$brush, \$x, \$y)
    } else {
      \$e.Graphics.DrawString(\$line, \$fontRegular, \$brush, \$x, \$y)
    }
    \$y += \$lineHeight
  }
  \$e.HasMorePages = \$false
})

\$doc.Print()
''';

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        cmd,
      ]);

      return result.exitCode == 0;
    } finally {
      await tempDir.delete(recursive: true).catchError((_) {});
    }
  }
}
