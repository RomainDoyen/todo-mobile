import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'ids.dart';
import 'merge.dart';
import 'models.dart';
import 'time.dart';

const _schema = '''
CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY NOT NULL,
  profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  emoji TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tags (
  id TEXT PRIMARY KEY NOT NULL,
  profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY NOT NULL,
  profile_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL CHECK(status IN ('todo', 'done')),
  priority TEXT NOT NULL CHECK(priority IN ('low', 'medium', 'high', 'urgent')),
  due_at TEXT,
  category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
  pinned INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT
);
CREATE TABLE IF NOT EXISTS task_tags (
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, tag_id)
);
CREATE TABLE IF NOT EXISTS subtasks (
  id TEXT PRIMARY KEY NOT NULL,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS outbox (
  id TEXT PRIMARY KEY NOT NULL,
  entity TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tasks_profile ON tasks(profile_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_at);
CREATE INDEX IF NOT EXISTS idx_categories_profile ON categories(profile_id);
CREATE INDEX IF NOT EXISTS idx_tags_profile ON tags(profile_id);
CREATE INDEX IF NOT EXISTS idx_subtasks_task ON subtasks(task_id);
CREATE TABLE IF NOT EXISTS task_images (
  id TEXT PRIMARY KEY NOT NULL,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_task_images_task ON task_images(task_id);
''';

Future<String> userDatabasePath(String userId) async {
  final dir = await getApplicationDocumentsDirectory();
  final safe = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  return p.join(dir.path, 'mes_taches_$safe.sqlite');
}

Future<Database> openUserDatabase(String userId) async {
  final path = await userDatabasePath(userId);
  return openDatabase(
    path,
    version: 2,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
    onCreate: (db, version) async {
      await _applySchema(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) await _applySchema(db);
    },
  );
}

Future<void> _applySchema(Database db) async {
  for (final statement in _schema.split(';')) {
    final sql = statement.trim();
    if (sql.isNotEmpty) await db.execute(sql);
  }
}

/// Applies the local schema. Used by tests that open their own database.
Future<void> applyLocalSchema(Database db) => _applySchema(db);

const _mergeTables = [
  'profiles',
  'categories',
  'tags',
  'tasks',
  'task_tags',
  'subtasks',
  'task_images',
  'outbox',
  'meta',
];

/// Moves a database created while the server was down onto the real account id.
Future<void> migrateUserDatabase(String fromId, String toId) async {
  if (fromId == toId) return;
  final from = await userDatabasePath(fromId);
  final to = await userDatabasePath(toId);
  final source = File(from);
  if (!await source.exists()) return;

  final target = File(to);
  if (!await target.exists()) {
    try {
      await source.rename(to);
    } catch (_) {
      await source.copy(to);
      await source.delete();
    }
    await _deleteSidecars(from);
    return;
  }

  final dest = await openUserDatabase(toId);
  try {
    await dest.execute('PRAGMA foreign_keys = OFF');
    await dest.execute('ATTACH DATABASE ? AS src', [from]);
    for (final table in _mergeTables) {
      final present = await dest.rawQuery(
        "SELECT 1 FROM src.sqlite_master WHERE type = 'table' AND name = ?",
        [table],
      );
      if (present.isEmpty) continue;
      await dest.execute('INSERT OR REPLACE INTO $table SELECT * FROM src.$table');
    }
    await dest.execute('DETACH DATABASE src');
  } finally {
    await dest.close();
  }
  await source.delete();
  await _deleteSidecars(from);
}

Future<void> _deleteSidecars(String path) async {
  for (final suffix in ['-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.delete();
  }
}

class LocalStore {
  LocalStore(this.db);

  final Database db;

  Future<void> close() async {
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {}
    await db.close();
  }

  Future<String?> meta(String key) async {
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) {
    return db.insert('meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Profile>> listProfiles() async {
    final rows = await db.query('profiles', orderBy: 'created_at ASC');
    return rows.map(_profile).toList();
  }

  Future<Profile> createProfile(String name, String color) async {
    final profile = Profile(
      id: createId(),
      name: name.trim(),
      color: color,
      createdAt: nowIso(),
    );
    await db.transaction((txn) async {
      await txn.insert('profiles', {
        'id': profile.id,
        'name': profile.name,
        'color': profile.color,
        'created_at': profile.createdAt,
      });
      await _enqueue(txn, entity: 'profiles', entityId: profile.id, op: 'upsert', payload: {
        'id': profile.id,
        'name': profile.name,
        'color': profile.color,
        'createdAt': profile.createdAt,
      }, updatedAt: profile.createdAt);
    });
    return profile;
  }

  Future<void> updateProfile(String id, {String? name, String? color}) async {
    final existing = await _profileById(id);
    if (existing == null) return;
    final next = Profile(
      id: existing.id,
      name: name?.trim().isNotEmpty == true ? name!.trim() : existing.name,
      color: color ?? existing.color,
      createdAt: existing.createdAt,
    );
    final updatedAt = nowIso();
    await db.transaction((txn) async {
      await txn.update(
        'profiles',
        {'name': next.name, 'color': next.color},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueue(txn, entity: 'profiles', entityId: id, op: 'upsert', payload: {
        'id': next.id,
        'name': next.name,
        'color': next.color,
        'createdAt': next.createdAt,
      }, updatedAt: updatedAt);
    });
  }

  Future<void> deleteProfile(String id) async {
    final profiles = await listProfiles();
    if (profiles.length <= 1) {
      throw StateError('Impossible de supprimer le dernier profil');
    }
    final updatedAt = nowIso();
    await db.transaction((txn) async {
      await txn.delete('profiles', where: 'id = ?', whereArgs: [id]);
      await _enqueue(txn,
          entity: 'profiles', entityId: id, op: 'delete', payload: {}, updatedAt: updatedAt);
    });
  }

  Future<bool> ensureDefaultProfile() async {
    final profiles = await listProfiles();
    if (profiles.isNotEmpty) return false;
    await createProfile('Perso', '#0F766E');
    return true;
  }

  Future<List<Category>> listCategories(String profileId) async {
    final rows = await db.query(
      'categories',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_category).toList();
  }

  Future<Category> createCategory(
    String profileId, {
    required String name,
    required String color,
    String? emoji,
  }) async {
    final category = Category(
      id: createId(),
      profileId: profileId,
      name: name.trim(),
      color: color,
      emoji: emoji,
      createdAt: nowIso(),
    );
    await db.transaction((txn) async {
      await txn.insert('categories', {
        'id': category.id,
        'profile_id': category.profileId,
        'name': category.name,
        'color': category.color,
        'emoji': category.emoji,
        'created_at': category.createdAt,
      });
      await _enqueue(txn, entity: 'categories', entityId: category.id, op: 'upsert', payload: {
        'id': category.id,
        'profileId': category.profileId,
        'name': category.name,
        'color': category.color,
        'emoji': category.emoji,
        'createdAt': category.createdAt,
      }, updatedAt: category.createdAt);
    });
    return category;
  }

  Future<void> deleteCategory(String id) async {
    final updatedAt = nowIso();
    await db.transaction((txn) async {
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
      await _enqueue(txn,
          entity: 'categories', entityId: id, op: 'delete', payload: {}, updatedAt: updatedAt);
    });
  }

  Future<List<Tag>> listTags(String profileId) async {
    final rows = await db.query(
      'tags',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_tag).toList();
  }

  Future<Tag> createTag(String profileId, {required String name, required String color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('Le nom du tag est requis');
    final existing = await listTags(profileId);
    if (existing.any((tag) => tag.name.toLowerCase() == trimmed.toLowerCase())) {
      throw StateError('Un tag avec ce nom existe déjà');
    }
    final tag = Tag(
      id: createId(),
      profileId: profileId,
      name: trimmed,
      color: color,
      createdAt: nowIso(),
    );
    await db.transaction((txn) async {
      await txn.insert('tags', {
        'id': tag.id,
        'profile_id': tag.profileId,
        'name': tag.name,
        'color': tag.color,
        'created_at': tag.createdAt,
      });
      await _enqueue(txn, entity: 'tags', entityId: tag.id, op: 'upsert', payload: {
        'id': tag.id,
        'profileId': tag.profileId,
        'name': tag.name,
        'color': tag.color,
        'createdAt': tag.createdAt,
      }, updatedAt: tag.createdAt);
    });
    return tag;
  }

  Future<void> updateTag(String id, {String? name, String? color}) async {
    final rows = await db.query('tags', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final existing = _tag(rows.first);
    final nextName = name?.trim().isNotEmpty == true ? name!.trim() : existing.name;
    final siblings = await listTags(existing.profileId);
    if (siblings.any(
      (tag) => tag.id != id && tag.name.toLowerCase() == nextName.toLowerCase(),
    )) {
      throw StateError('Un tag avec ce nom existe déjà');
    }
    final updatedAt = nowIso();
    await db.transaction((txn) async {
      await txn.update(
        'tags',
        {'name': nextName, 'color': color ?? existing.color},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueue(txn, entity: 'tags', entityId: id, op: 'upsert', payload: {
        'id': existing.id,
        'profileId': existing.profileId,
        'name': nextName,
        'color': color ?? existing.color,
        'createdAt': existing.createdAt,
      }, updatedAt: updatedAt);
    });
  }

  Future<void> deleteTag(String id) async {
    final links = await db.query('task_tags', where: 'tag_id = ?', whereArgs: [id]);
    final updatedAt = nowIso();
    await db.transaction((txn) async {
      await txn.delete('task_tags', where: 'tag_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
      for (final link in links) {
        final taskId = link['task_id'] as String;
        await _enqueue(txn,
            entity: 'task_tags',
            entityId: taskTagEntityId(taskId, id),
            op: 'delete',
            payload: {'taskId': taskId, 'tagId': id},
            updatedAt: updatedAt);
      }
      await _enqueue(txn, entity: 'tags', entityId: id, op: 'delete', payload: {}, updatedAt: updatedAt);
    });
  }

  Future<List<({String id, String title, String? dueAt})>> listOpenDueTasks() async {
    final rows = await db.query(
      'tasks',
      columns: ['id', 'title', 'due_at'],
      where: "status = 'todo' AND due_at IS NOT NULL AND due_at != ''",
    );
    return [
      for (final row in rows)
        (
          id: row['id']! as String,
          title: row['title']! as String,
          dueAt: row['due_at'] as String?,
        ),
    ];
  }

  Future<List<Task>> listTasks(String profileId) async {
    final rows = await db.query(
      'tasks',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'pinned DESC, created_at DESC, position DESC',
    );
    final tasks = <Task>[];
    for (final row in rows) {
      tasks.add(await _hydrateTask(row));
    }
    return tasks;
  }

  Future<Task?> getTask(String id) async {
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _hydrateTask(rows.first);
  }

  Future<Task> createTask(String profileId, TaskDraft draft) async {
    final title = draft.title.trim();
    if (title.isEmpty) throw StateError('Le titre est requis');
    final id = createId();
    final ts = nowIso();
    final maxRows = await db.rawQuery(
      'SELECT MAX(position) AS m FROM tasks WHERE profile_id = ?',
      [profileId],
    );
    final position = ((maxRows.first['m'] as int?) ?? 0) + 1;
    await db.transaction((txn) async {
      await txn.insert('tasks', {
        'id': id,
        'profile_id': profileId,
        'title': title,
        'description': _blankToNull(draft.description),
        'status': draft.status.name,
        'priority': draft.priority.name,
        'due_at': draft.dueAt,
        'category_id': draft.categoryId,
        'pinned': draft.pinned ? 1 : 0,
        'position': position,
        'created_at': ts,
        'updated_at': ts,
        'completed_at': draft.status == TaskStatus.done ? ts : null,
      });
      await _setTags(txn, id, draft.tagIds, ts);
      await _replaceSubtasks(txn, id, draft.subtasks, ts);
      final task = await _taskPayload(txn, id);
      await _enqueue(txn,
          entity: 'tasks', entityId: id, op: 'upsert', payload: task, updatedAt: ts);
    });
    for (final path in draft.imagePaths) {
      await addTaskImage(id, path);
    }
    return (await getTask(id))!;
  }

  Future<Task?> updateTask(String id, TaskDraft draft) async {
    final existing = await getTask(id);
    if (existing == null) return null;
    final title = draft.title.trim().isEmpty ? existing.title : draft.title.trim();
    final ts = nowIso();
    final completedAt = draft.status == TaskStatus.done
        ? (existing.completedAt ?? ts)
        : null;
    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        {
          'title': title,
          'description': _blankToNull(draft.description),
          'status': draft.status.name,
          'priority': draft.priority.name,
          'due_at': draft.dueAt,
          'category_id': draft.categoryId,
          'pinned': draft.pinned ? 1 : 0,
          'updated_at': ts,
          'completed_at': completedAt,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _setTags(txn, id, draft.tagIds, ts);
      await _replaceSubtasks(txn, id, draft.subtasks, ts);
      final task = await _taskPayload(txn, id);
      await _enqueue(txn,
          entity: 'tasks', entityId: id, op: 'upsert', payload: task, updatedAt: ts);
    });
    for (final path in draft.imagePaths) {
      await addTaskImage(id, path);
    }
    return getTask(id);
  }

  Future<void> toggleDone(String id) async {
    final existing = await getTask(id);
    if (existing == null) return;
    final next = existing.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done;
    final ts = nowIso();
    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        {
          'status': next.name,
          'updated_at': ts,
          'completed_at': next == TaskStatus.done ? (existing.completedAt ?? ts) : null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueue(txn,
          entity: 'tasks',
          entityId: id,
          op: 'upsert',
          payload: await _taskPayload(txn, id),
          updatedAt: ts);
    });
  }

  Future<void> togglePin(String id) async {
    final existing = await getTask(id);
    if (existing == null) return;
    final ts = nowIso();
    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        {'pinned': existing.pinned ? 0 : 1, 'updated_at': ts},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueue(txn,
          entity: 'tasks',
          entityId: id,
          op: 'upsert',
          payload: await _taskPayload(txn, id),
          updatedAt: ts);
    });
  }

  Future<void> toggleSubtask(String id) async {
    final rows = await db.query('subtasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final done = (rows.first['done'] as int) == 0;
    final ts = nowIso();
    await db.transaction((txn) async {
      await txn.update('subtasks', {'done': done ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
      final next = await txn.query('subtasks', where: 'id = ?', whereArgs: [id], limit: 1);
      final row = next.first;
      await _enqueue(txn, entity: 'subtasks', entityId: id, op: 'upsert', payload: {
        'id': id,
        'taskId': row['task_id'],
        'title': row['title'],
        'done': done,
        'position': row['position'],
      }, updatedAt: ts);
    });
  }

  Future<void> deleteTask(String id) async {
    final existing = await getTask(id);
    final images = await db.query('task_images', where: 'task_id = ?', whereArgs: [id]);
    final ts = nowIso();
    await db.transaction((txn) async {
      if (existing != null) {
        for (final tag in existing.tags) {
          await _enqueue(txn,
              entity: 'task_tags',
              entityId: taskTagEntityId(id, tag.id),
              op: 'delete',
              payload: {'taskId': id, 'tagId': tag.id},
              updatedAt: ts);
        }
        for (final sub in existing.subtasks) {
          await _enqueue(txn,
              entity: 'subtasks', entityId: sub.id, op: 'delete', payload: {}, updatedAt: ts);
        }
      }
      await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
      await _enqueue(txn, entity: 'tasks', entityId: id, op: 'delete', payload: {}, updatedAt: ts);
    });
    await _deleteImageFiles(images);
  }

  Future<void> addTaskImage(String taskId, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return;
    var ext = p.extension(sourcePath).toLowerCase();
    if (!RegExp(r'^\.(jpe?g|png|webp|gif|heic|heif)$').hasMatch(ext)) ext = '.jpg';
    final id = createId();
    final name = '$id$ext';
    final dir = await _imageDirPath();
    await source.copy(p.join(dir, name));
    final maxRows = await db.rawQuery(
      'SELECT MAX(position) AS m FROM task_images WHERE task_id = ?',
      [taskId],
    );
    final position = ((maxRows.first['m'] as int?) ?? -1) + 1;
    await db.insert('task_images', {
      'id': id,
      'task_id': taskId,
      'file_name': name,
      'created_at': nowIso(),
      'position': position,
    });
  }

  Future<void> removeTaskImage(String id) async {
    final rows = await db.query('task_images', where: 'id = ?', whereArgs: [id], limit: 1);
    await db.delete('task_images', where: 'id = ?', whereArgs: [id]);
    await _deleteImageFiles(rows);
  }

  String? _imageDir;

  Future<String> _imageDirPath() async {
    final cached = _imageDir;
    if (cached != null) return cached;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'task_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _imageDir = dir.path;
    return dir.path;
  }

  Future<void> _deleteImageFiles(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final dir = await _imageDirPath();
    for (final row in rows) {
      final file = File(p.join(dir, row['file_name'] as String));
      if (await file.exists()) await file.delete();
    }
  }

  Future<List<OutboxEntry>> listOutbox() async {
    final rows = await db.query('outbox', orderBy: 'rowid ASC');
    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String);
      return OutboxEntry(
        id: row['id'] as String,
        entity: row['entity'] as String,
        entityId: row['entity_id'] as String,
        op: row['op'] as String,
        payload: payload is Map ? Map<String, dynamic>.from(payload) : {},
        updatedAt: row['updated_at'] as String,
      );
    }).toList();
  }

  Future<void> removeOutbox(List<String> ids) async {
    if (ids.isEmpty) return;
    final marks = List.filled(ids.length, '?').join(',');
    await db.delete('outbox', where: 'id IN ($marks)', whereArgs: ids);
  }

  Future<void> seedRelationsOnce() async {
    const key = 'sync:relationsSeeded:v2';
    if (await meta(key) != null) return;
    final ts = nowIso();
    await db.transaction((txn) async {
      await txn.delete(
        'outbox',
        where: "entity = 'task_tags' AND entity_id NOT GLOB '[a-zA-Z0-9]*'",
      );
      final links = await txn.query('task_tags');
      for (final link in links) {
        final taskId = link['task_id'] as String;
        final tagId = link['tag_id'] as String;
        final entityId = taskTagEntityId(taskId, tagId);
        if (!_validAppwriteUid(entityId)) continue;
        await _enqueue(txn,
            entity: 'task_tags',
            entityId: entityId,
            op: 'upsert',
            payload: {'taskId': taskId, 'tagId': tagId},
            updatedAt: ts);
      }
      final subs = await txn.query('subtasks');
      for (final row in subs) {
        await _enqueue(txn, entity: 'subtasks', entityId: row['id'] as String, op: 'upsert', payload: {
          'id': row['id'],
          'taskId': row['task_id'],
          'title': row['title'],
          'done': (row['done'] as int) != 0,
          'position': row['position'],
        }, updatedAt: ts);
      }
      await txn.insert('meta', {'key': key, 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> applyCloudDocuments(Map<String, List<Map<String, dynamic>>> documents) async {
    await db.transaction((txn) async {
      for (final entity in syncEntities) {
        for (final doc in documents[entity] ?? const []) {
          await _applyDocument(txn, entity, doc);
        }
      }
    });
  }

  Future<void> _applyDocument(
    DatabaseExecutor txn,
    String entity,
    Map<String, dynamic> doc,
  ) async {
    final id = (doc['id'] ?? doc['\$id'] ?? '').toString();
    final updatedAt = (doc['updatedAt'] ?? '').toString();
    final deletedRaw = doc['deletedAt'];
    final deletedAt = deletedRaw == null || deletedRaw == '' ? null : deletedRaw.toString();
    final local = await _localStamp(txn, entity, id);
    final action = shouldApplyCloud(
      localUpdatedAt: local,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
    if (action == CloudAction.skip) return;
    if (action == CloudAction.delete) {
      await _deleteCloud(txn, entity, id, doc);
      return;
    }
    await _upsertCloud(txn, entity, id, doc);
  }

  Future<String?> _localStamp(DatabaseExecutor txn, String entity, String id) async {
    switch (entity) {
      case 'profiles':
        return _one(txn, 'SELECT created_at AS v FROM profiles WHERE id = ?', [id]);
      case 'categories':
        return _one(txn, 'SELECT created_at AS v FROM categories WHERE id = ?', [id]);
      case 'tags':
        return _one(txn, 'SELECT created_at AS v FROM tags WHERE id = ?', [id]);
      case 'tasks':
        return _one(txn, 'SELECT updated_at AS v FROM tasks WHERE id = ?', [id]);
      default:
        return null;
    }
  }

  Future<void> _upsertById(
    DatabaseExecutor txn,
    String table,
    Map<String, Object?> row,
  ) async {
    final updated = await txn.update(
      table,
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    if (updated == 0) await txn.insert(table, row);
  }

  Future<void> _upsertCloud(
    DatabaseExecutor txn,
    String entity,
    String id,
    Map<String, dynamic> doc,
  ) async {
    switch (entity) {
      case 'profiles':
        await _upsertById(txn, 'profiles', {
          'id': id,
          'name': _str(doc, 'name', 'name'),
          'color': _str(doc, 'color', 'color'),
          'created_at': _str(doc, 'createdAt', 'created_at'),
        });
      case 'categories':
        await _upsertById(txn, 'categories', {
          'id': id,
          'profile_id': _str(doc, 'profileId', 'profile_id'),
          'name': _str(doc, 'name', 'name'),
          'color': _str(doc, 'color', 'color'),
          'emoji': _strOrNull(doc, 'emoji', 'emoji'),
          'created_at': _str(doc, 'createdAt', 'created_at'),
        });
      case 'tags':
        await _upsertById(txn, 'tags', {
          'id': id,
          'profile_id': _str(doc, 'profileId', 'profile_id'),
          'name': _str(doc, 'name', 'name'),
          'color': _str(doc, 'color', 'color'),
          'created_at': _str(doc, 'createdAt', 'created_at'),
        });
      case 'tasks':
        await _upsertById(txn, 'tasks', {
          'id': id,
          'profile_id': _str(doc, 'profileId', 'profile_id'),
          'title': _str(doc, 'title', 'title'),
          'description': _strOrNull(doc, 'description', 'description'),
          'status': _str(doc, 'status', 'status'),
          'priority': _str(doc, 'priority', 'priority'),
          'due_at': _strOrNull(doc, 'dueAt', 'due_at'),
          'category_id': _strOrNull(doc, 'categoryId', 'category_id'),
          'pinned': _boolInt(doc, 'pinned', 'pinned'),
          'position': _num(doc, 'position', 'position'),
          'created_at': _str(doc, 'createdAt', 'created_at'),
          'updated_at': _str(doc, 'updatedAt', 'updated_at'),
          'completed_at': _strOrNull(doc, 'completedAt', 'completed_at'),
        });
        final tagIds = doc['tagIds'] ?? doc['tag_ids'];
        if (tagIds is List) {
          await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [id]);
          for (final tagId in tagIds) {
            await txn.insert('task_tags', {
              'task_id': id,
              'tag_id': tagId.toString(),
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      case 'task_tags':
        await txn.insert('task_tags', {
          'task_id': _str(doc, 'taskId', 'task_id'),
          'tag_id': _str(doc, 'tagId', 'tag_id'),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      case 'subtasks':
        await _upsertById(txn, 'subtasks', {
          'id': id,
          'task_id': _str(doc, 'taskId', 'task_id'),
          'title': _str(doc, 'title', 'title'),
          'done': _boolInt(doc, 'done', 'done'),
          'position': _num(doc, 'position', 'position'),
        });
    }
  }

  Future<void> _deleteCloud(
    DatabaseExecutor txn,
    String entity,
    String id,
    Map<String, dynamic> doc,
  ) async {
    switch (entity) {
      case 'profiles':
        await txn.delete('profiles', where: 'id = ?', whereArgs: [id]);
      case 'categories':
        await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
      case 'tags':
        await txn.delete('task_tags', where: 'tag_id = ?', whereArgs: [id]);
        await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
      case 'tasks':
        await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [id]);
        await txn.delete('subtasks', where: 'task_id = ?', whereArgs: [id]);
        await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
      case 'task_tags':
        await txn.delete(
          'task_tags',
          where: 'task_id = ? AND tag_id = ?',
          whereArgs: [_str(doc, 'taskId', 'task_id'), _str(doc, 'tagId', 'tag_id')],
        );
      case 'subtasks':
        await txn.delete('subtasks', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> _setTags(DatabaseExecutor txn, String taskId, List<String> tagIds, String ts) async {
    final previous = await txn.query('task_tags', where: 'task_id = ?', whereArgs: [taskId]);
    final prevIds = previous.map((row) => row['tag_id'] as String).toSet();
    final nextIds = tagIds.toSet();
    await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [taskId]);
    for (final tagId in nextIds) {
      await txn.insert('task_tags', {'task_id': taskId, 'tag_id': tagId});
    }
    for (final tagId in prevIds.difference(nextIds)) {
      await _enqueue(txn,
          entity: 'task_tags',
          entityId: taskTagEntityId(taskId, tagId),
          op: 'delete',
          payload: {'taskId': taskId, 'tagId': tagId},
          updatedAt: ts);
    }
    for (final tagId in nextIds) {
      await _enqueue(txn,
          entity: 'task_tags',
          entityId: taskTagEntityId(taskId, tagId),
          op: 'upsert',
          payload: {'taskId': taskId, 'tagId': tagId},
          updatedAt: ts);
    }
  }

  Future<void> _replaceSubtasks(
    DatabaseExecutor txn,
    String taskId,
    List<({String title, bool done})> items,
    String ts,
  ) async {
    final previous = await txn.query('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
    await txn.delete('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
    for (final row in previous) {
      await _enqueue(txn,
          entity: 'subtasks',
          entityId: row['id'] as String,
          op: 'delete',
          payload: {},
          updatedAt: ts);
    }
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final title = item.title.trim();
      if (title.isEmpty) continue;
      final subId = createId();
      await txn.insert('subtasks', {
        'id': subId,
        'task_id': taskId,
        'title': title,
        'done': item.done ? 1 : 0,
        'position': index,
      });
      await _enqueue(txn, entity: 'subtasks', entityId: subId, op: 'upsert', payload: {
        'id': subId,
        'taskId': taskId,
        'title': title,
        'done': item.done,
        'position': index,
      }, updatedAt: ts);
    }
  }

  Future<Map<String, dynamic>> _taskPayload(DatabaseExecutor txn, String id) async {
    final rows = await txn.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    final row = rows.first;
    return {
      'id': row['id'],
      'profileId': row['profile_id'],
      'title': row['title'],
      'description': row['description'],
      'status': row['status'],
      'priority': row['priority'],
      'dueAt': row['due_at'],
      'categoryId': row['category_id'],
      'pinned': (row['pinned'] as int) != 0,
      'position': row['position'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'completedAt': row['completed_at'],
    };
  }

  Future<Task> _hydrateTask(Map<String, Object?> row) async {
    final id = row['id'] as String;
    final tagRows = await db.rawQuery(
      '''SELECT t.* FROM tags t
         INNER JOIN task_tags tt ON tt.tag_id = t.id
         WHERE tt.task_id = ?
         ORDER BY t.name COLLATE NOCASE ASC''',
      [id],
    );
    final subRows = await db.query(
      'subtasks',
      where: 'task_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    final imageRows = await db.query(
      'task_images',
      where: 'task_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    final imageDir = await _imageDirPath();
    return Task(
      id: id,
      profileId: row['profile_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      status: parseStatus(row['status'] as String),
      priority: parsePriority(row['priority'] as String),
      dueAt: row['due_at'] as String?,
      categoryId: row['category_id'] as String?,
      pinned: (row['pinned'] as int) != 0,
      position: row['position'] as int,
      createdAt: row['created_at'] as String,
      updatedAt: row['updated_at'] as String,
      completedAt: row['completed_at'] as String?,
      tags: tagRows.map(_tag).toList(),
      subtasks: subRows.map(_subtask).toList(),
      images: [
        for (final image in imageRows)
          TaskImage(
            id: image['id'] as String,
            taskId: id,
            path: p.join(imageDir, image['file_name'] as String),
            createdAt: image['created_at'] as String,
          ),
      ],
    );
  }

  Future<Profile?> _profileById(String id) async {
    final rows = await db.query('profiles', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _profile(rows.first);
  }

  Future<void> _enqueue(
    DatabaseExecutor txn, {
    required String entity,
    required String entityId,
    required String op,
    required Map<String, dynamic> payload,
    required String updatedAt,
  }) {
    return txn.insert('outbox', {
      'id': createId(),
      'entity': entity,
      'entity_id': entityId,
      'op': op,
      'payload': jsonEncode(payload),
      'updated_at': updatedAt,
    });
  }
}

bool _validAppwriteUid(String id) {
  return id.length <= 36 && RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_]{0,35}$').hasMatch(id);
}

Future<String?> _one(DatabaseExecutor txn, String sql, List<Object?> args) async {
  final rows = await txn.rawQuery(sql, args);
  if (rows.isEmpty) return null;
  final value = rows.first['v'];
  return value?.toString();
}

Object? _pick(Map<String, dynamic> doc, String camel, String snake) {
  if (doc.containsKey(camel)) return doc[camel];
  return doc[snake];
}

String _str(Map<String, dynamic> doc, String camel, String snake) {
  final value = _pick(doc, camel, snake);
  return value == null ? '' : value.toString();
}

String? _strOrNull(Map<String, dynamic> doc, String camel, String snake) {
  final value = _pick(doc, camel, snake);
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int _boolInt(Map<String, dynamic> doc, String camel, String snake) {
  final value = _pick(doc, camel, snake);
  if (value == true || value == 1 || value == '1') return 1;
  return 0;
}

int _num(Map<String, dynamic> doc, String camel, String snake) {
  final value = _pick(doc, camel, snake);
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _blankToNull(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

Profile _profile(Map<String, Object?> row) {
  return Profile(
    id: row['id'] as String,
    name: row['name'] as String,
    color: row['color'] as String,
    createdAt: row['created_at'] as String,
  );
}

Category _category(Map<String, Object?> row) {
  return Category(
    id: row['id'] as String,
    profileId: row['profile_id'] as String,
    name: row['name'] as String,
    color: row['color'] as String,
    emoji: row['emoji'] as String?,
    createdAt: row['created_at'] as String,
  );
}

Tag _tag(Map<String, Object?> row) {
  return Tag(
    id: row['id'] as String,
    profileId: row['profile_id'] as String,
    name: row['name'] as String,
    color: row['color'] as String,
    createdAt: row['created_at'] as String,
  );
}

Subtask _subtask(Map<String, Object?> row) {
  return Subtask(
    id: row['id'] as String,
    taskId: row['task_id'] as String,
    title: row['title'] as String,
    done: (row['done'] as int) != 0,
    position: row['position'] as int,
  );
}
