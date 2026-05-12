/// Capability profile for a thermal printer model.
///
/// Each profile stores hardware limits and feature flags so the receipt
/// builder can tailor its output without runtime capability negotiation.
class PrinterProfile {
  const PrinterProfile({
    required this.name,
    required this.paperWidthMm,
    required this.charWidth,
    required this.supportsCut,
    required this.supportsDrawer,
    this.encoding = 'CP437',
  });

  /// Human-readable model label shown in the admin UI.
  final String name;

  /// Physical paper roll width in millimetres (58 or 80).
  final int paperWidthMm;

  /// Characters per line at the printer's default pitch (typically 12 cpi).
  final int charWidth;

  /// Whether the printer supports paper-cut commands (GS V).
  final bool supportsCut;

  /// Whether the printer supports a cash-drawer kick (ESC p).
  final bool supportsDrawer;

  /// Default code page expected by this printer model.
  final String encoding;

  // ── Named profiles ───────────────────────────────────────────────────────

  static const genericPos80 = PrinterProfile(
    name: 'Generic POS80',
    paperWidthMm: 80,
    charWidth: 48,
    supportsCut: true,
    supportsDrawer: true,
  );

  static const epsonTm = PrinterProfile(
    name: 'Epson TM',
    paperWidthMm: 80,
    charWidth: 48,
    supportsCut: true,
    supportsDrawer: true,
  );

  static const xprinter = PrinterProfile(
    name: 'XPrinter',
    paperWidthMm: 80,
    charWidth: 48,
    supportsCut: true,
    supportsDrawer: true,
  );

  /// Sunmi printers have an internal printer; no drawer or external cut.
  static const sunmi = PrinterProfile(
    name: 'Sunmi',
    paperWidthMm: 80,
    charWidth: 48,
    supportsCut: false,
    supportsDrawer: false,
  );

  static const bixolon = PrinterProfile(
    name: 'Bixolon',
    paperWidthMm: 80,
    charWidth: 48,
    supportsCut: true,
    supportsDrawer: true,
  );

  static const star = PrinterProfile(
    name: 'STAR',
    paperWidthMm: 80,
    charWidth: 48,
    supportsCut: true,
    supportsDrawer: true,
  );

  static const narrowPos58 = PrinterProfile(
    name: 'Generic POS58',
    paperWidthMm: 58,
    charWidth: 32,
    supportsCut: true,
    supportsDrawer: false,
  );

  /// Fallback when the printer name matches nothing — safe conservative defaults.
  static const unknown = PrinterProfile(
    name: 'Unknown',
    paperWidthMm: 80,
    charWidth: 48,
    supportsCut: false,
    supportsDrawer: false,
  );

  // ── Auto-detect ──────────────────────────────────────────────────────────

  /// Infer the best profile from the installed Windows printer name.
  ///
  /// Matching is case-insensitive and uses keyword heuristics. When no
  /// keyword matches, [genericPos80] is returned (widest compatibility).
  static PrinterProfile detectFromName(String printerName) {
    final lower = printerName.toLowerCase();

    if (lower.contains('epson')) return epsonTm;
    if (lower.contains('xprinter') || lower.contains('xp-')) return xprinter;
    if (lower.contains('sunmi')) return sunmi;
    if (lower.contains('bixolon') || lower.contains('srp-')) return bixolon;
    if (lower.contains('star') || lower.contains('tsp')) return star;
    if (lower.contains('58mm') ||
        lower.contains('58 mm') ||
        lower.contains('pos58') ||
        lower.contains('pos-58')) return narrowPos58;

    // Any name with common thermal-printer keywords → generic 80mm.
    if (lower.contains('pos') ||
        lower.contains('thermal') ||
        lower.contains('receipt') ||
        lower.contains('80mm') ||
        lower.contains('80 mm')) return genericPos80;

    return genericPos80;
  }

  /// Override paper width while keeping other profile values.
  PrinterProfile withPaperWidth(int mm) => PrinterProfile(
    name: name,
    paperWidthMm: mm,
    charWidth: mm <= 58 ? 32 : 48,
    supportsCut: supportsCut,
    supportsDrawer: supportsDrawer,
    encoding: encoding,
  );

  @override
  String toString() =>
      '$name (${paperWidthMm}mm, cut:$supportsCut, drawer:$supportsDrawer)';
}
