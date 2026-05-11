import 'dart:io';

class WindowsPrintersService {
  const WindowsPrintersService._();

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

\$font = New-Object System.Drawing.Font('Consolas', 11, [System.Drawing.FontStyle]::Regular)

\$doc.add_PrintPage({
  param(\$sender, \$e)
  \$brush = [System.Drawing.Brushes]::Black
  \$x = 0
  \$y = 0
  \$e.Graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit
  \$e.Graphics.DrawString(\$text, \$font, \$brush, \$x, \$y)
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
