import 'package:myvault/data/reminder_date.dart';
import 'package:myvault/data/vault_item.dart';

/// Phone notifications for secure notes. The vault file stays the source of the date.
abstract class NoteReminders {
  Future<bool> ensurePermission();

  /// Schedules, shows, or clears the notification for one saved note.
  Future<void> apply(VaultItem item, {DateTime? now});

  /// Restores future reminders after login. A reminder that already fired stays quiet.
  Future<void> sync(List<VaultItem> items, {DateTime? now});

  Future<void> cancel(String id);

  Future<void> cancelAll();
}

class NoopNoteReminders implements NoteReminders {
  const NoopNoteReminders();

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> apply(VaultItem item, {DateTime? now}) async {}

  @override
  Future<void> sync(List<VaultItem> items, {DateTime? now}) async {}

  @override
  Future<void> cancel(String id) async {}

  @override
  Future<void> cancelAll() async {}
}

class MemoryNoteReminders implements NoteReminders {
  MemoryNoteReminders({this.allow = true, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  bool allow;
  final DateTime Function() clock;
  final List<String> shown = [];
  final Map<String, DateTime> scheduled = {};
  final List<String> cancelled = [];
  var clearedAll = false;

  @override
  Future<bool> ensurePermission() async => allow;

  @override
  Future<void> apply(VaultItem item, {DateTime? now}) async {
    await cancel(item.id);
    final plan = planReminder(
      item.reminderDate,
      now ?? clock(),
      includeImmediate: true,
    );
    switch (plan) {
      case null:
        return;
      case ShowReminderNow():
        shown.add(item.id);
      case ScheduleReminder(:final fireAt):
        scheduled[item.id] = fireAt;
    }
  }

  @override
  Future<void> sync(List<VaultItem> items, {DateTime? now}) async {
    await cancelAll();
    final clockNow = now ?? clock();
    for (final item in items) {
      if (item.type != VaultItemType.secret) continue;
      final plan = planReminder(
        item.reminderDate,
        clockNow,
        includeImmediate: false,
      );
      if (plan is ScheduleReminder) scheduled[item.id] = plan.fireAt;
    }
  }

  @override
  Future<void> cancel(String id) async {
    scheduled.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
    clearedAll = true;
  }
}
