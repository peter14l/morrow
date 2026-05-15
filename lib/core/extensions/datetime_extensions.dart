import 'package:timeago/timeago.dart' as timeago;

/// Common DateTime extensions for formatting and comparison.
extension DateTimeX on DateTime {
  /// Check if this date is today.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if this date is yesterday.
  bool get isYesterday {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Check if this date is in the future.
  bool get isFuture => isAfter(DateTime.now());

  /// Check if this date is in the past.
  bool get isPast => isBefore(DateTime.now());

  /// Format as short date (e.g., "Jan 15, 2024").
  String get toShortDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[month - 1]} $day, $year';
  }

  /// Format as full date time (e.g., "Jan 15, 2024 3:30 PM").
  String get toFullDateTime {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = hour12 == 0 ? 12 : hour12;
    final period = this.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '${months[month - 1]} $day, $year $hour:$minuteStr $period';
  }

  /// Format as time only (e.g., "3:30 PM").
  String get toTimeOnly {
    final hour = this.hour == 0
        ? 12
        : (this.hour > 12 ? this.hour - 12 : this.hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    final period = this.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minuteStr $period';
  }

  /// Get relative time string (e.g., "2 hours ago", "just now").
  String get toRelativeString {
    return timeago.format(this);
  }

  /// Check if same day as another date.
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Strip time component (set to midnight UTC).
  DateTime get dateOnly => DateTime(year, month, day);

  /// 12-hour format hour.
  int get hour12 => hour % 12;
}
