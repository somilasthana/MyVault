const reminderMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Calendar day as `yyyy-MM-dd`. The clock time is not stored.
String reminderDateKey(DateTime day) {
  final year = day.year.toString().padLeft(4, '0');
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '$year-$month-$date';
}

DateTime? parseReminderDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final date = int.parse(match[3]!);
  final day = DateTime(year, month, date);
  if (day.year != year || day.month != month || day.day != date) return null;
  return day;
}

/// `DD/MM/YYYY` for the line under the reminder slider.
String formatReminderDate(DateTime day) {
  final date = day.day.toString().padLeft(2, '0');
  final month = day.month.toString().padLeft(2, '0');
  return '$date/$month/${day.year}';
}

String reminderTriggerLine(DateTime day) {
  return 'This note will be triggered on ${formatReminderDate(day)}';
}

String reminderMonthTitle(DateTime month) {
  return '${reminderMonthNames[month.month - 1]} ${month.year}';
}

DateTime reminderInstant(DateTime day) {
  return DateTime(day.year, day.month, day.day, 10);
}

bool reminderDayEnabled(DateTime day, DateTime today) {
  final target = DateTime(day.year, day.month, day.day);
  final start = DateTime(today.year, today.month, today.day);
  return !target.isBefore(start);
}

bool reminderIsToday(DateTime day, DateTime now) {
  return day.year == now.year && day.month == now.month && day.day == now.day;
}

bool reminderStillPending(DateTime day, DateTime now) {
  return reminderInstant(day).isAfter(now);
}

/// What the phone should do with one saved reminder.
///
/// A future 10:00 AM is scheduled. Today after 10:00 AM can show at once.
/// A day that has already passed stays on the note and does not notify again.
sealed class ReminderPlan {
  const ReminderPlan();
}

class ScheduleReminder extends ReminderPlan {
  const ScheduleReminder(this.fireAt);

  final DateTime fireAt;
}

class ShowReminderNow extends ReminderPlan {
  const ShowReminderNow();
}

ReminderPlan? planReminder(
  String? reminderDate,
  DateTime now, {
  required bool includeImmediate,
}) {
  final day = parseReminderDate(reminderDate);
  if (day == null) return null;
  if (reminderStillPending(day, now)) {
    return ScheduleReminder(reminderInstant(day));
  }
  if (includeImmediate && reminderIsToday(day, now)) {
    return const ShowReminderNow();
  }
  return null;
}

int reminderNotificationId(String id) {
  var hash = 17;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
