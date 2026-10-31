import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/src/merge.dart';
import 'package:todo_mobile/src/models.dart';
import 'package:todo_mobile/src/sync_engine.dart';
import 'package:todo_mobile/src/time.dart';

Task _task({
  String? dueAt,
  TaskPriority priority = TaskPriority.medium,
  TaskStatus status = TaskStatus.todo,
  String title = 'Titre',
}) {
  return Task(
    id: 't',
    profileId: 'p',
    title: title,
    description: 'notes',
    status: status,
    priority: priority,
    dueAt: dueAt,
    categoryId: null,
    pinned: false,
    position: 1,
    createdAt: '2026-10-24T08:00:00.000Z',
    updatedAt: '2026-10-24T08:00:00.000Z',
    completedAt: null,
    tags: const [],
    subtasks: const [],
  );
}

void main() {
  test('cloud document newer than local is applied', () {
    expect(
      shouldApplyCloud(
        localUpdatedAt: '2026-10-24T08:00:00.000Z',
        updatedAt: '2026-10-24T09:00:00.000Z',
        deletedAt: null,
      ),
      CloudAction.apply,
    );
  });

  test('newer local change skips an older cloud document', () {
    expect(
      shouldApplyCloud(
        localUpdatedAt: '2026-10-24T10:00:00.000Z',
        updatedAt: '2026-10-24T09:00:00.000Z',
        deletedAt: null,
      ),
      CloudAction.skip,
    );
  });

  test('a cloud tombstone deletes the local row', () {
    expect(
      shouldApplyCloud(
        localUpdatedAt: '2026-10-24T08:00:00.000Z',
        updatedAt: '2026-10-24T09:00:00.000Z',
        deletedAt: '2026-10-24T09:00:00.000Z',
      ),
      CloudAction.delete,
    );
  });

  test('urgent filter keeps open urgent tasks', () {
    final now = DateTime(2026, 10, 24, 15);
    final tasks = [
      _task(priority: TaskPriority.urgent),
      _task(priority: TaskPriority.urgent, status: TaskStatus.done),
      _task(),
    ];
    final visible = filterTasks(tasks, filter: QuickFilter.urgent, now: now);
    expect(visible, hasLength(1));
  });

  test('sync cursor follows the newest document and ignores the clock', () {
    expect(nextSyncCursor(null, const []), '1970-01-01T00:00:00.000Z');
    expect(
      nextSyncCursor('2026-10-31T09:38:14.673Z', const [
        '2026-10-31T09:38:14.673Z',
        '2026-10-31T09:44:57.817Z',
      ]),
      '2026-10-31T09:44:57.817Z',
    );
    expect(
      nextSyncCursor('2026-10-31T09:38:14.673Z', const []),
      '2026-10-31T09:38:14.673Z',
    );
  });

  test('search matches title and description', () {
    final visible = filterTasks([_task(title: 'Courses')], search: 'cours');
    expect(visible, hasLength(1));
    expect(filterTasks([_task()], search: 'absent'), isEmpty);
  });
}
