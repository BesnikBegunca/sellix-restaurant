import 'dart:typed_data';

/// Low-level ESC/POS byte builder.
///
/// Chain calls to compose a receipt, then call [build] to get the final
/// byte array ready to be sent to the printer as a RAW print job.
///
/// ESC/POS standard references: Epson TM-series, STAR, XPrinter, generic POS80.
class EscPosBytes {
  EscPosBytes({this.paperWidthMm = 80});

  final int paperWidthMm;
  final List<int> _buf = [];

  // ── ESC/POS byte constants ───────────────────────────────────────────────

  static const _esc = 0x1B;
  static const _gs  = 0x1D;
  static const _lf  = 0x0A;

  // ── Printer control ──────────────────────────────────────────────────────

  /// ESC @ — Initialize printer (clear buffer, reset all modes).
  EscPosBytes reset() {
    _buf.addAll([_esc, 0x40]);
    return this;
  }

  // ── Text alignment ───────────────────────────────────────────────────────

  /// ESC a 0 — Left align.
  EscPosBytes alignLeft() {
    _buf.addAll([_esc, 0x61, 0x00]);
    return this;
  }

  /// ESC a 1 — Center align.
  EscPosBytes alignCenter() {
    _buf.addAll([_esc, 0x61, 0x01]);
    return this;
  }

  /// ESC a 2 — Right align.
  EscPosBytes alignRight() {
    _buf.addAll([_esc, 0x61, 0x02]);
    return this;
  }

  // ── Text style ───────────────────────────────────────────────────────────

  /// ESC E 1 — Bold on.
  EscPosBytes boldOn() {
    _buf.addAll([_esc, 0x45, 0x01]);
    return this;
  }

  /// ESC E 0 — Bold off.
  EscPosBytes boldOff() {
    _buf.addAll([_esc, 0x45, 0x00]);
    return this;
  }

  /// ESC ! n — Double height + width when [on] is true.
  EscPosBytes doubleSize(bool on) {
    _buf.addAll([_esc, 0x21, on ? 0x30 : 0x00]);
    return this;
  }

  // ── Text output ──────────────────────────────────────────────────────────

  /// Print a raw string (no newline).
  EscPosBytes text(String s) {
    _buf.addAll(_encode(s));
    return this;
  }

  /// Print a string followed by a line feed.
  EscPosBytes textLine(String s) => text(s).lf();

  /// Print a centered string followed by a line feed, then restore left align.
  EscPosBytes centeredLine(String s) =>
      alignCenter().textLine(s).alignLeft();

  /// Print a centered bold string followed by a line feed, then restore styles.
  EscPosBytes boldCenteredLine(String s) =>
      alignCenter().boldOn().textLine(s).boldOff().alignLeft();

  /// Centered, bold, double width/height (titull pagese).
  EscPosBytes boldCenteredDoubleLine(String s) => alignCenter()
      .boldOn()
      .doubleSize(true)
      .textLine(s)
      .doubleSize(false)
      .boldOff()
      .alignLeft();

  /// Print a line feed n times.
  EscPosBytes lf([int n = 1]) {
    for (var i = 0; i < n; i++) {
      _buf.add(_lf);
    }
    return this;
  }

  /// Print a full-width separator using dashes.
  EscPosBytes separator() => textLine('-' * lineWidth);

  /// Print a double-line separator using '='.
  EscPosBytes doubleSeparator() => textLine('=' * lineWidth);

  // ── Column helpers ───────────────────────────────────────────────────────

  /// Fixed-width left-padded column.
  String col(String s, int width, {bool rightAlign = false}) {
    if (s.length >= width) return s.substring(0, width);
    return rightAlign ? s.padLeft(width) : s.padRight(width);
  }

  /// Print a two-column row: left text + right text filling [lineWidth].
  EscPosBytes rowLR(String left, String right) {
    final w = lineWidth;
    final r = right.length;
    final l = w - r;
    final leftStr = left.length >= l ? left.substring(0, l) : left.padRight(l);
    return textLine('$leftStr$right');
  }

  // ── Hardware commands ────────────────────────────────────────────────────

  /// GS V 0 — Full paper cut.
  EscPosBytes fullCut() {
    _buf.addAll([_gs, 0x56, 0x00]);
    return this;
  }

  /// GS V 1 — Partial paper cut (leaves a thin strip).
  EscPosBytes partialCut() {
    _buf.addAll([_gs, 0x56, 0x01]);
    return this;
  }

  /// ESC p 0 t1 t2 — Cash drawer kick on pin 2.
  ///
  /// t1 = on-time in units of 2ms, t2 = off-time in units of 2ms.
  /// 0x19 (25 × 2ms = 50ms on) and 0xFA (250 × 2ms = 500ms off) are safe
  /// defaults for most 24V and 12V drawers.
  EscPosBytes drawerKick() {
    _buf.addAll([_esc, 0x70, 0x00, 0x19, 0xFA]);
    return this;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  Uint8List build() => Uint8List.fromList(_buf);

  // ── Paper geometry ───────────────────────────────────────────────────────

  /// Characters per line at standard 12 cpi (characters per inch).
  /// 80mm paper ≈ 48 chars, 58mm paper ≈ 32 chars.
  int get lineWidth => paperWidthMm <= 58 ? 32 : 48;

  // ── Encoding ─────────────────────────────────────────────────────────────

  /// Encode [s] to CP437-compatible bytes.
  ///
  /// Thermal printers default to CP437 or CP850. Albanian characters (ë, ç)
  /// and other extended Latin characters are transliterated to their ASCII
  /// base form so the receipt reads correctly without reprogramming the
  /// printer's code page.
  static List<int> _encode(String s) {
    const replacements = {
      'ë': 'e', 'Ë': 'E',
      'ç': 'c', 'Ç': 'C',
      'â': 'a', 'Â': 'A',
      'î': 'i', 'Î': 'I',
      'û': 'u', 'Û': 'U',
      'ô': 'o', 'Ô': 'O',
      'ê': 'e', 'Ê': 'E',
      'à': 'a', 'À': 'A',
      'è': 'e', 'È': 'E',
      'é': 'e', 'É': 'E',
      'ù': 'u', 'Ù': 'U',
      'ã': 'a', 'õ': 'o',
      'ñ': 'n', 'ü': 'u', 'Ü': 'U',
      'ö': 'o', 'Ö': 'O',
      'ä': 'a', 'Ä': 'A',
    };
    final sb = StringBuffer();
    for (final ch in s.runes.map(String.fromCharCode)) {
      sb.write(replacements[ch] ?? (ch.codeUnitAt(0) > 127 ? '?' : ch));
    }
    return sb.toString().codeUnits;
  }
}
