/// Sot = gjendja e hapur. Dje = gjendja e fundit e mbyllur.
class OperationalPeriod {
  const OperationalPeriod({
    this.openShiftId,
    this.lastClosedShiftId,
    this.openStartedAt,
    this.lastClosedOpenedAt,
    this.lastClosedClosedAt,
  });

  final int? openShiftId;
  final int? lastClosedShiftId;
  final DateTime? openStartedAt;
  final DateTime? lastClosedOpenedAt;
  final DateTime? lastClosedClosedAt;

  bool isSot({int? shiftId, DateTime? at}) {
    if (openShiftId != null && shiftId != null) {
      return shiftId == openShiftId;
    }
    final t = at ?? DateTime.now();
    final start = openStartedAt ?? DateTime(t.year, t.month, t.day);
    return !t.isBefore(start);
  }

  bool isDje({int? shiftId, DateTime? at}) {
    if (lastClosedShiftId != null && shiftId != null) {
      return shiftId == lastClosedShiftId;
    }
    final from = lastClosedOpenedAt;
    final to = lastClosedClosedAt;
    if (at == null || from == null || to == null) return false;
    return !at.isBefore(from) && !at.isAfter(to);
  }
}
