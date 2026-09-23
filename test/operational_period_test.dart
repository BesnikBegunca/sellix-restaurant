import 'package:flutter_test/flutter_test.dart';
import 'package:pos_system/features/dashboard/operational_period.dart';

void main() {
  final opened = DateTime(2026, 9, 22, 10);
  final closed = DateTime(2026, 9, 23, 2);
  final nextOpen = DateTime(2026, 9, 23, 2);

  const period = OperationalPeriod(
    openShiftId: 2,
    lastClosedShiftId: 1,
    openStartedAt: null,
    lastClosedOpenedAt: null,
    lastClosedClosedAt: null,
  );

  test('closed shift sales move to Dje, not Sot', () {
    expect(period.isSot(shiftId: 1), isFalse);
    expect(period.isDje(shiftId: 1), isTrue);
    expect(period.isSot(shiftId: 2), isTrue);
    expect(period.isDje(shiftId: 2), isFalse);
  });

  test('fallback uses last closed interval when sale has no shiftId', () {
    final byTime = OperationalPeriod(
      lastClosedOpenedAt: opened,
      lastClosedClosedAt: closed,
      openStartedAt: nextOpen,
    );
    expect(byTime.isDje(at: DateTime(2026, 9, 22, 23)), isTrue);
    expect(byTime.isDje(at: DateTime(2026, 9, 23, 3)), isFalse);
    expect(byTime.isSot(at: DateTime(2026, 9, 23, 3)), isTrue);
  });
}
