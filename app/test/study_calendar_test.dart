import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/study_calendar.dart';

void main() {
  test('account calendar handles positive and negative offsets at UTC midnight',
      () {
    final instant = DateTime.utc(2026, 9, 9, 0, 15);
    expect(StudyCalendar('America/Los_Angeles').day(instant),
        DateTime.utc(2026, 9, 8));
    expect(StudyCalendar('Asia/Tokyo').day(instant), DateTime.utc(2026, 9, 9));
    expect(StudyCalendar('invalid').day(instant), DateTime.utc(2026, 9, 9));
  });

  test(
      'Brussels spring and autumn changes are calendar days, not 24 hour steps',
      () {
    final calendar = StudyCalendar('Europe/Brussels');
    final spring = DateTime.utc(2026, 3, 29, 10);
    expect(
        calendar
            .startOfDay(spring, offsetDays: 1)
            .difference(calendar.startOfDay(spring))
            .inHours,
        23);
    expect(calendar.daysBetween(spring, DateTime.utc(2026, 3, 30, 8)), 1);
    final autumn = DateTime.utc(2026, 10, 25, 10);
    expect(
        calendar
            .startOfDay(autumn, offsetDays: 1)
            .difference(calendar.startOfDay(autumn))
            .inHours,
        25);
    expect(calendar.daysBetween(autumn, DateTime.utc(2026, 10, 26, 8)), 1);
  });
}
