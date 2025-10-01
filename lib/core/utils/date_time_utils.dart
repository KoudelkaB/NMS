import 'package:timezone/timezone.dart' as tz;

/// Utility class for timezone-aware DateTime operations
class DateTimeUtils {
  DateTimeUtils._();

  /// Gets the current DateTime in Prague timezone (Europe/Prague)
  static DateTime get nowInPrague {
    try {
      final prague = tz.getLocation('Europe/Prague');
      final nowInPrague = tz.TZDateTime.now(prague);
      // Convert to local DateTime (removes timezone info but keeps the correct time)
      return DateTime(
        nowInPrague.year,
        nowInPrague.month,
        nowInPrague.day,
        nowInPrague.hour,
        nowInPrague.minute,
        nowInPrague.second,
        nowInPrague.millisecond,
        nowInPrague.microsecond,
      );
    } catch (e) {
      // Fallback to system time if timezone is not available
      return DateTime.now();
    }
  }
}
