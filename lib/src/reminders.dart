import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

typedef ReminderSource = ({String id, String title, String? dueAt});

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.taskId,
    required this.title,
    required this.body,
    required this.when,
    this.immediate = false,
  });

  final int id;
  final String taskId;
  final String title;
  final String body;
  final DateTime when;

  /// The 05:00 slot is already past, but it is still that calendar day.
  final bool immediate;
}

/// Stable notification id. Dart [String.hashCode] changes between runs.
int reminderNotificationId(String taskId, String kind) {
  var hash = 0x811c9dc5;
  for (final unit in '$kind:$taskId'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

/// One alarm a week before the due day at 05:00, and one the day before at [eveHour]:[eveMinute].
List<PlannedReminder> planReminders(
  Iterable<ReminderSource> tasks, {
  DateTime? now,
  int eveHour = 5,
  int eveMinute = 0,
}) {
  final clock = now ?? DateTime.now();
  final planned = <PlannedReminder>[];
  for (final task in tasks) {
    final dueAt = task.dueAt;
    if (dueAt == null || dueAt.isEmpty) continue;
    final due = DateTime.tryParse(dueAt)?.toLocal();
    if (due == null) continue;
    final dueDay = DateTime(due.year, due.month, due.day);
    final title = task.title.trim().isEmpty ? 'Tâche' : task.title.trim();
    _add(
      planned,
      taskId: task.id,
      kind: 'week',
      title: 'Dans une semaine',
      body: title,
      when: _atFive(dueDay.subtract(const Duration(days: 7))),
      now: clock,
    );
    final eveDay = dueDay.subtract(const Duration(days: 1));
    _add(
      planned,
      taskId: task.id,
      kind: 'eve',
      title: 'Demain',
      body: title,
      when: DateTime(
        eveDay.year,
        eveDay.month,
        eveDay.day,
        eveHour.clamp(0, 23),
        eveMinute.clamp(0, 59),
      ),
      now: clock,
    );
  }
  planned.sort((a, b) {
    final byTime = a.when.compareTo(b.when);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return planned;
}

DateTime _atFive(DateTime day) => DateTime(day.year, day.month, day.day, 5);

void _add(
  List<PlannedReminder> planned, {
  required String taskId,
  required String kind,
  required String title,
  required String body,
  required DateTime when,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final whenDay = DateTime(when.year, when.month, when.day);
  final upcoming = when.isAfter(now);
  if (!upcoming && whenDay != today) return;
  planned.add(
    PlannedReminder(
      id: reminderNotificationId(taskId, kind),
      taskId: taskId,
      title: title,
      body: body,
      when: when,
      immediate: !upcoming,
    ),
  );
}

class TaskReminders {
  TaskReminders({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void> _tail = Future<void>.value();
  var _ready = false;
  var _asked = false;

  Future<void> apply(
    List<ReminderSource> tasks, {
    int eveHour = 5,
    int eveMinute = 0,
  }) {
    final run = _tail.then(
      (_) => _apply(tasks, eveHour: eveHour, eveMinute: eveMinute),
    );
    _tail = run.catchError((Object _) {});
    return run;
  }

  Future<void> _apply(
    List<ReminderSource> tasks, {
    required int eveHour,
    required int eveMinute,
  }) async {
    if (!_supported) return;
    final planned = planReminders(
      tasks,
      eveHour: eveHour,
      eveMinute: eveMinute,
    );
    try {
      await _ensureReady();
      if (planned.isNotEmpty) await _askPermissions();
      await _plugin.cancelAllPendingNotifications();
      final mode = await _scheduleMode();
      final seen = await _catchupSeenToday();
      final marked = <String>{...seen};
      for (final reminder in planned) {
        final mark = _catchupMark(reminder);
        if (reminder.immediate) {
          if (mark != null && seen.contains(mark)) continue;
          await _plugin.show(
            id: reminder.id,
            title: reminder.title,
            body: reminder.body,
            notificationDetails: _details,
            payload: reminder.taskId,
          );
          if (mark != null) marked.add(mark);
          continue;
        }
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
          notificationDetails: _details,
          androidScheduleMode: mode,
          payload: reminder.taskId,
        );
        if (mark != null) marked.add(mark);
      }
      await _storeCatchup(marked);
    } catch (error, stack) {
      debugPrint('Rappels non programmés: $error\n$stack');
    }
  }

  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<void> _askPermissions() async {
    if (_asked) return;
    _asked = true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    final exact = await android?.canScheduleExactNotifications();
    if (exact != true) await android?.requestExactAlarmsPermission();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: false, sound: true);
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications();
    return exact == true
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static const _catchupKey = 'reminder_catchup';

  String? _catchupMark(PlannedReminder reminder) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final whenDay = DateTime(
      reminder.when.year,
      reminder.when.month,
      reminder.when.day,
    );
    if (whenDay != today) return null;
    final month = today.month.toString().padLeft(2, '0');
    final day = today.day.toString().padLeft(2, '0');
    return '${today.year}-$month-$day:${reminder.id}:${reminder.when.hour}:${reminder.when.minute}';
  }

  Future<Set<String>> _catchupSeenToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final month = today.month.toString().padLeft(2, '0');
    final day = today.day.toString().padLeft(2, '0');
    final prefix = '${today.year}-$month-$day:';
    return {
      for (final item in prefs.getStringList(_catchupKey) ?? const <String>[])
        if (item.startsWith(prefix)) item,
    };
  }

  Future<void> _storeCatchup(Set<String> marks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_catchupKey, marks.toList());
  }

  bool get _supported {
    if (kIsWeb || Platform.environment['FLUTTER_TEST'] == 'true') return false;
    return Platform.isAndroid || Platform.isIOS;
  }
}

const _details = NotificationDetails(
  android: AndroidNotificationDetails(
    'task_reminders',
    'Rappels',
    channelDescription:
        'Une semaine avant l’échéance à 5 h, puis la veille à l’heure choisie',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
    enableVibration: true,
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    presentBadge: false,
  ),
);
