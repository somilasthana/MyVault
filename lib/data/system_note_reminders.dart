import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:myvault/data/note_reminders.dart';
import 'package:myvault/data/reminder_date.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _channelId = 'secure-note-reminders';
const _channelName = 'Secure note reminders';
const _channelDescription = 'Reminders for secure notes at 10:00 AM';

/// One phone notification per secure note, at 10:00 AM local time.
class SystemNoteReminders implements NoteReminders {
  SystemNoteReminders({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  var _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: 'MyVault',
          appUserModelId: 'Com.MyVault.MyVault',
          guid: 'c3a1d5e7-4b28-4f6a-9d0c-7e2b8a1f64d3',
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> ensurePermission() async {
    try {
      await init();
    } catch (_) {
      return false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      if (granted == false) return false;
      final exact = await android.canScheduleExactNotifications();
      if (exact != true) await android.requestExactAlarmsPermission();
      return true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, sound: true);
      return granted ?? false;
    }
    final mac = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (mac != null) {
      final granted = await mac.requestPermissions(alert: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  @override
  Future<void> apply(VaultItem item, {DateTime? now}) async {
    await cancel(item.id);
    final plan = planReminder(
      item.reminderDate,
      now ?? DateTime.now(),
      includeImmediate: true,
    );
    switch (plan) {
      case null:
        return;
      case ShowReminderNow():
        await _show(item);
      case ScheduleReminder(:final fireAt):
        await _schedule(item, fireAt);
    }
  }

  @override
  Future<void> sync(List<VaultItem> items, {DateTime? now}) async {
    await cancelAll();
    final clock = now ?? DateTime.now();
    for (final item in items) {
      if (item.type != VaultItemType.secret) continue;
      final plan = planReminder(
        item.reminderDate,
        clock,
        includeImmediate: false,
      );
      if (plan is ScheduleReminder) await _schedule(item, plan.fireAt);
    }
  }

  @override
  Future<void> cancel(String id) async {
    if (!_ready) return;
    await _plugin.cancel(id: reminderNotificationId(id));
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  Future<void> _show(VaultItem item) {
    return _plugin.show(
      id: reminderNotificationId(item.id),
      title: item.title,
      body: 'Reminder',
      notificationDetails: _details,
    );
  }

  Future<void> _schedule(VaultItem item, DateTime fireAt) async {
    final when = tz.TZDateTime(
      tz.local,
      fireAt.year,
      fireAt.month,
      fireAt.day,
      fireAt.hour,
      fireAt.minute,
    );
    final mode = await _scheduleMode();
    try {
      await _plugin.zonedSchedule(
        id: reminderNotificationId(item.id),
        title: item.title,
        body: 'Reminder',
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: mode,
      );
    } catch (_) {
      if (mode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
      await _plugin.zonedSchedule(
        id: reminderNotificationId(item.id),
        title: item.title,
        body: 'Reminder',
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications();
    if (exact == true) return AndroidScheduleMode.exactAllowWhileIdle;
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }
}

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  macOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
);
