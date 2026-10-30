import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/src/app_model.dart';
import 'package:todo_mobile/src/models.dart';
import 'package:todo_mobile/src/scope.dart';
import 'package:todo_mobile/theme.dart';
import 'package:todo_mobile/ui/home_screen.dart';

void main() {
  testWidgets('home and calendar lists paginate three tasks at a time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final model = AppModel()
      ..phase = SessionPhase.ready
      ..tasks = [
        for (var index = 1; index <= 11; index++)
          Task(
            id: 'task-$index',
            profileId: 'profile-1',
            title: 'Tâche $index',
            description: null,
            status: TaskStatus.todo,
            priority: TaskPriority.medium,
            dueAt: '2026-01-${index.toString().padLeft(2, '0')}T08:00:00.000Z',
            categoryId: null,
            pinned: false,
            position: index,
            createdAt: '2026-01-01T08:00:00.000Z',
            updatedAt: '2026-01-01T08:00:00.000Z',
            completedAt: null,
            tags: const [],
            subtasks: const [],
          ),
      ];

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tâche 1'), findsOneWidget);
    expect(find.text('Tâche 4'), findsNothing);
    expect(find.text('Page 1 sur 4'), findsOneWidget);

    await tester.tap(find.byTooltip('Page suivante'));
    await tester.pump();

    expect(find.text('Tâche 1'), findsNothing);
    expect(find.text('Tâche 4'), findsOneWidget);
    expect(find.text('Page 2 sur 4'), findsOneWidget);
  });

  testWidgets('calendar shows a month grid and the selected day', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final tomorrow = todayDate.add(const Duration(days: 1));
    String dueOn(DateTime day) =>
        DateTime(day.year, day.month, day.day, 12).toUtc().toIso8601String();

    final model = AppModel()
      ..phase = SessionPhase.ready
      ..tasks = [
        for (var index = 1; index <= 4; index++)
          Task(
            id: 'today-$index',
            profileId: 'profile-1',
            title: 'Aujourd’hui $index',
            description: null,
            status: TaskStatus.todo,
            priority: TaskPriority.medium,
            dueAt: dueOn(todayDate),
            categoryId: null,
            pinned: false,
            position: index,
            createdAt: '2026-01-01T08:00:00.000Z',
            updatedAt: '2026-01-01T08:00:00.000Z',
            completedAt: null,
            tags: const [],
            subtasks: const [],
          ),
        Task(
          id: 'tomorrow',
          profileId: 'profile-1',
          title: 'Course demain',
          description: null,
          status: TaskStatus.todo,
          priority: TaskPriority.medium,
          dueAt: dueOn(tomorrow),
          categoryId: null,
          pinned: false,
          position: 5,
          createdAt: '2026-01-01T08:00:00.000Z',
          updatedAt: '2026-01-01T08:00:00.000Z',
          completedAt: null,
          tags: const [],
          subtasks: const [],
        ),
      ];

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Calendrier'));
    await tester.pump();

    expect(find.byTooltip('Mois précédent'), findsOneWidget);
    expect(find.byTooltip('Mois suivant'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('Aujourd’hui 1'), findsOneWidget);
    expect(find.text('Aujourd’hui 4'), findsNothing);
    expect(find.text('Page 1 sur 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Page suivante'));
    await tester.pump();
    expect(find.text('Aujourd’hui 4'), findsOneWidget);

    if (tomorrow.month != todayDate.month) {
      await tester.tap(find.byTooltip('Mois suivant'));
      await tester.pump();
    }
    await tester.tap(
      find.byKey(
        ValueKey('day-${tomorrow.year}-${tomorrow.month}-${tomorrow.day}'),
      ),
    );
    await tester.pump();

    expect(find.text('Course demain'), findsOneWidget);
    expect(find.text('Aujourd’hui 4'), findsNothing);
    expect(find.text('Page 1 sur 2'), findsNothing);
  });
}
