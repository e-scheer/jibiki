import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Calendar dates follow the account timezone on every device. UTC is also the
/// server fallback for missing or invalid preferences; timestamps remain UTC.
class StudyCalendar {
  StudyCalendar(String? timezone) {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    try {
      _location = tz.getLocation(timezone ?? 'UTC');
    } on tz.LocationNotFoundException {
      _location = tz.UTC;
    }
  }

  static bool _initialized = false;
  late final tz.Location _location;

  DateTime local(DateTime instant) => tz.TZDateTime.from(instant, _location);

  DateTime startOfDay(DateTime instant, {int offsetDays = 0}) {
    final date = local(instant);
    return tz.TZDateTime(
        _location, date.year, date.month, date.day + offsetDays);
  }

  // A date-only UTC value supports calendar arithmetic without DST hours.
  DateTime day(DateTime instant) {
    final date = local(instant);
    return DateTime.utc(date.year, date.month, date.day);
  }

  int daysBetween(DateTime from, DateTime to) =>
      day(to).difference(day(from)).inDays;
}
