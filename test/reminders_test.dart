import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/src/reminders.dart';
import 'package:todo_mobile/src/time.dart';

void main() {
  test('schedules 05:00 a week before and the day before', () {
    final planned = planReminders([
      (
        id: 'task-1',
        title: 'Courses',
        dueAt: dueIsoFromDate(DateTime(2026, 10, 31)),
      ),
    ], now: DateTime(2026, 10, 20, 8));

    expect(planned, hasLength(2));
    expect(planned[0].when, DateTime(2026, 10, 24, 5));
    expect(planned[0].title, 'Dans une semaine');
    expect(planned[0].body, 'Courses');
    expect(planned[1].when, DateTime(2026, 10, 30, 5));
    expect(planned[1].title, 'Demain');
    expect(planned[1].body, 'Courses');
    expect(planned[0].id, isNot(planned[1].id));
    expect(planned[0].id, reminderNotificationId('task-1', 'week'));
  });

  test('keeps a 05:00 reminder that is due exactly now', () {
    final planned = planReminders([
      (
        id: 'task-1',
        title: 'Courses',
        dueAt: dueIsoFromDate(DateTime(2026, 10, 31)),
      ),
    ], now: DateTime(2026, 10, 24, 5));

    expect(planned.map((reminder) => reminder.title), [
      'Dans une semaine',
      'Demain',
    ]);
    expect(planned[0].immediate, isTrue);
    expect(planned[1].immediate, isFalse);
    expect(planned[1].when, DateTime(2026, 10, 30, 5));
  });

  test('shows the eve reminder later the same day and drops an older one', () {
    final sameDay = planReminders([
      (
        id: 'task-1',
        title: 'Courses',
        dueAt: dueIsoFromDate(DateTime(2026, 10, 31)),
      ),
    ], now: DateTime(2026, 10, 30, 18));
    expect(sameDay, hasLength(1));
    expect(sameDay.single.title, 'Demain');
    expect(sameDay.single.immediate, isTrue);
    expect(sameDay.single.when, DateTime(2026, 10, 30, 5));

    final nextDay = planReminders([
      (
        id: 'task-1',
        title: 'Courses',
        dueAt: dueIsoFromDate(DateTime(2026, 10, 31)),
      ),
    ], now: DateTime(2026, 10, 25, 8));
    expect(nextDay.map((reminder) => reminder.title), ['Demain']);
    expect(nextDay.single.immediate, isFalse);
    expect(nextDay.single.when, DateTime(2026, 10, 30, 5));
  });

  test('skips a task without a due date and keeps the ids stable', () {
    final first = planReminders([
      (id: 'task-1', title: '  ', dueAt: dueIsoFromDate(DateTime(2026, 3, 1))),
      (id: 'task-2', title: 'Sans date', dueAt: null),
    ], now: DateTime(2026, 2, 1, 8));

    expect(first, hasLength(2));
    expect(first[0].when, DateTime(2026, 2, 22, 5));
    expect(first[1].when, DateTime(2026, 2, 28, 5));
    expect(first[0].body, 'Tâche');
    expect(first.map((reminder) => reminder.id), [
      reminderNotificationId('task-1', 'week'),
      reminderNotificationId('task-1', 'eve'),
    ]);
  });

  test(
    'the eve reminder uses the chosen time and the week reminder stays at 05:00',
    () {
      final planned = planReminders(
        [
          (
            id: 'task-1',
            title: 'Courses',
            dueAt: dueIsoFromDate(DateTime(2026, 10, 31)),
          ),
        ],
        now: DateTime(2026, 10, 20, 8),
        eveHour: 18,
        eveMinute: 30,
      );

      expect(planned[0].when, DateTime(2026, 10, 24, 5));
      expect(planned[1].when, DateTime(2026, 10, 30, 18, 30));
      expect(planned[1].title, 'Demain');
      expect(planned[1].immediate, isFalse);

      final later = planReminders(
        [
          (
            id: 'task-1',
            title: 'Courses',
            dueAt: dueIsoFromDate(DateTime(2026, 10, 31)),
          ),
        ],
        now: DateTime(2026, 10, 30, 19),
        eveHour: 18,
        eveMinute: 30,
      );
      expect(later.single.immediate, isTrue);
      expect(later.single.when, DateTime(2026, 10, 30, 18, 30));
    },
  );
}
