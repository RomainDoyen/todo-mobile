import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class SavedConnection {
  const SavedConnection({
    required this.email,
    required this.password,
    required this.name,
    required this.mode,
    required this.apiBase,
    required this.user,
    required this.token,
    required this.pending,
  });

  final String email;
  final String? password;
  final String name;
  final String mode;
  final String apiBase;
  final AuthUser user;
  final String? token;
  final bool pending;
}

class ConnectionStore {
  ConnectionStore(this.db);

  final Database db;

  static Future<ConnectionStore> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      p.join(dir.path, 'connection.sqlite'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE connection (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            email TEXT NOT NULL,
            password TEXT,
            name TEXT NOT NULL,
            mode TEXT NOT NULL,
            api_base TEXT NOT NULL,
            user_json TEXT NOT NULL,
            token TEXT,
            pending INTEGER NOT NULL
          )
        ''');
        await _createAccounts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE accounts ADD COLUMN name TEXT NOT NULL DEFAULT ''");
          await db.execute('ALTER TABLE accounts ADD COLUMN password TEXT');
          await db.execute('ALTER TABLE accounts ADD COLUMN updated_at TEXT');
        }
      },
    );
    return ConnectionStore(db);
  }

  Future<SavedConnection?> read() async {
    final rows = await db.query('connection', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final user = AuthUser.fromJson(jsonDecode(row['user_json'] as String) as Map<String, dynamic>);
    final password = row['password'] as String?;
    final token = row['token'] as String?;
    return SavedConnection(
      email: row['email'] as String,
      password: password == null || password.isEmpty ? null : password,
      name: row['name'] as String,
      mode: row['mode'] as String,
      apiBase: row['api_base'] as String,
      user: user,
      token: token == null || token.isEmpty ? null : token,
      pending: (row['pending'] as int) != 0,
    );
  }

  Future<void> save(SavedConnection connection) {
    return db.insert(
      'connection',
      {
        'id': 1,
        'email': connection.email,
        'password': connection.password,
        'name': connection.name,
        'mode': connection.mode,
        'api_base': connection.apiBase,
        'user_json': jsonEncode(connection.user.toJson()),
        'token': connection.token,
        'pending': connection.pending ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clear() {
    return db.delete('connection', where: 'id = 1');
  }

  Future<String?> userIdForEmail(String email) async {
    final rows = await db.query(
      'accounts',
      columns: ['user_id'],
      where: 'email = ?',
      whereArgs: [_emailKey(email)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['user_id'] as String?;
  }

  Future<void> remember({
    required String email,
    required String userId,
    String name = '',
    String? password,
  }) async {
    final key = _emailKey(email);
    final existing = await db.query('accounts', where: 'email = ?', whereArgs: [key], limit: 1);
    final previousName = existing.isEmpty ? '' : (existing.first['name'] as String? ?? '');
    final previousPassword = existing.isEmpty ? null : existing.first['password'] as String?;
    final nextName = name.trim().isEmpty ? previousName : name.trim();
    final nextPassword = (password == null || password.isEmpty) ? previousPassword : password;
    await db.insert(
      'accounts',
      {
        'email': key,
        'user_id': userId,
        'name': nextName,
        'password': nextPassword,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({String email, String name, String? password})?> lastAccount() async {
    final rows = await db.query('accounts', orderBy: 'updated_at DESC', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final password = row['password'] as String?;
    return (
      email: row['email'] as String,
      name: (row['name'] as String?) ?? '',
      password: password == null || password.isEmpty ? null : password,
    );
  }
}

Future<void> _createAccounts(Database db) {
  return db.execute('''
    CREATE TABLE accounts (
      email TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL DEFAULT '',
      password TEXT,
      updated_at TEXT
    )
  ''');
}

String _emailKey(String email) => email.trim().toLowerCase();
