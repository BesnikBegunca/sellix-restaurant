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
      final cmd = "Get-Content -LiteralPath '$escapedPath' -Raw | Out-Printer -Name '$escapedPrinter'";

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
