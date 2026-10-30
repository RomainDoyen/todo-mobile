import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/src/app_model.dart';
import 'package:todo_mobile/src/models.dart';
import 'package:todo_mobile/src/scope.dart';
import 'package:todo_mobile/theme.dart';
import 'package:todo_mobile/ui/task_detail_page.dart';
import 'package:todo_mobile/ui/task_images.dart';

void main() {
  testWidgets('detail page spreads fields across the screen width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final model = AppModel()
      ..phase = SessionPhase.ready
      ..tasks = [
        const Task(
          id: 'task-1',
          profileId: 'profile-1',
          title: 'Acheter le cadeau',
          description: 'Passer en magasin avant samedi.',
          status: TaskStatus.todo,
          priority: TaskPriority.high,
          dueAt: '2026-10-31T08:00:00.000Z',
          categoryId: null,
          pinned: false,
          position: 0,
          createdAt: '2026-10-20T08:00:00.000Z',
          updatedAt: '2026-10-24T08:00:00.000Z',
          completedAt: null,
          tags: [],
          subtasks: [
            Subtask(id: 'sub-1', taskId: 'task-1', title: 'Choisir le papier', done: false, position: 0),
          ],
        ),
      ];

    await tester.pumpWidget(
      AppScope(
        model: model,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const TaskDetailPage(taskId: 'task-1'),
        ),
      ),
    );
    await tester.pump();

    final priority = tester.getRect(find.text('Priorité'));
    final due = tester.getRect(find.text('Échéance'));
    expect(priority.top, closeTo(due.top, 1));
    expect(due.left, greaterThan(priority.right));
    expect(due.left, greaterThan(180));

    final created = tester.getRect(find.text('CRÉÉE'));
    final updated = tester.getRect(find.text('MODIFIÉE'));
    expect(created.top, closeTo(updated.top, 1));
    expect(updated.left, greaterThan(created.right));

    final tiles = tester.widgetList<SizedBox>(
      find.descendant(
        of: find.byType(TaskImageGallery),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width != null && widget.height == widget.width,
        ),
      ),
    );
    expect(tiles.any((tile) => tile.width! > 100), isTrue);
  });
}
