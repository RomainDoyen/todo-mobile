import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todo_mobile/src/local_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('a cloud update keeps images already saved on the phone', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) => applyLocalSchema(db),
      ),
    );
    const profileId = 'profile-1';
    const taskId = 'task-1';
    await db.insert('profiles', {
      'id': profileId,
      'name': 'Perso',
      'color': '#0F766E',
      'created_at': '2026-10-31T09:00:00.000Z',
    });
    await db.insert('tasks', {
      'id': taskId,
      'profile_id': profileId,
      'title': 'Club auto Longtemps',
      'description': 'Bois Blanc',
      'status': 'todo',
      'priority': 'medium',
      'due_at': '2026-11-29T08:00:00.000Z',
      'category_id': null,
      'pinned': 0,
      'position': 1,
      'created_at': '2026-10-31T09:00:00.000Z',
      'updated_at': '2026-10-31T09:00:00.000Z',
      'completed_at': null,
    });
    await db.insert('task_images', {
      'id': 'image-1',
      'task_id': taskId,
      'file_name': 'image-1.jpg',
      'created_at': '2026-10-31T10:00:00.000Z',
      'position': 0,
    });

    final store = LocalStore(db);
    await store.applyCloudDocuments({
      'profiles': [
        {
          'id': profileId,
          'name': 'Perso',
          'color': '#0F766E',
          'createdAt': '2026-10-31T09:00:00.000Z',
          'updatedAt': '2026-10-31T11:00:00.000Z',
        },
      ],
      'tasks': [
        {
          'id': taskId,
          'profileId': profileId,
          'title': 'Club auto Longtemps',
          'description': 'Bois Blanc, site de la source',
          'status': 'todo',
          'priority': 'medium',
          'dueAt': '2026-11-29T08:00:00.000Z',
          'pinned': 0,
          'position': 1,
          'createdAt': '2026-10-31T09:00:00.000Z',
          'updatedAt': '2026-10-31T11:00:00.000Z',
        },
      ],
    });

    final images = await db.query('task_images', where: 'task_id = ?', whereArgs: [taskId]);
    final tasks = await db.query('tasks', where: 'id = ?', whereArgs: [taskId]);
    expect(images, hasLength(1));
    expect(images.single['file_name'], 'image-1.jpg');
    expect(tasks.single['description'], 'Bois Blanc, site de la source');
    await db.close();
  });
}
