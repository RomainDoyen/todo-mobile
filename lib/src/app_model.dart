import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'connection_store.dart';
import 'ids.dart';
import 'local_store.dart';
import 'models.dart';
import 'reminders.dart';
import 'sync_engine.dart';
import 'time.dart';

const defaultApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://mes-taches-api.todo-extension.workers.dev',
);

const _mobileScheme = 'mestaches';

enum SessionPhase { booting, signedOut, ready, failed }

class AppModel extends ChangeNotifier {
  AppModel({FlutterSecureStorage? secure, TaskReminders? reminders})
    : _secure = secure ?? const FlutterSecureStorage(),
      _reminders = reminders ?? TaskReminders();

  final FlutterSecureStorage _secure;
  final TaskReminders _reminders;
  SharedPreferences? _prefs;
  ConnectionStore? _connection;
  LocalStore? _store;
  Timer? _syncTimer;

  SessionPhase phase = SessionPhase.booting;
  String? bootError;
  AppTheme theme = AppTheme.light;
  String apiBase = defaultApiBase;
  AuthUser? user;
  String? _token;
  bool pendingAuth = false;
  SyncStatus syncStatus = SyncStatus.synced;
  String? syncError;
  String? lastSyncAt;
  List<Profile> profiles = [];
  String? activeProfileId;
  List<Task> tasks = [];
  List<Tag> tags = [];
  List<Category> categories = [];
  QuickFilter filter = QuickFilter.all;
  String search = '';
  String? selectedTagId;
  bool syncing = false;

  List<Task> get visibleTasks =>
      filterTasks(tasks, filter: filter, search: search, tagId: selectedTagId);

  Profile? get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  int eveReminderHour = 5;
  int eveReminderMinute = 0;

  String get eveReminderLabel {
    final hour = eveReminderHour.toString().padLeft(2, '0');
    final minute = eveReminderMinute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int get openCount =>
      tasks.where((task) => task.status == TaskStatus.todo).length;

  ({int done, int total}) get today => dayProgress(tasks);

  ApiClient get _api => ApiClient(apiBase);

  Future<void> start() async {
    _prefs = await SharedPreferences.getInstance();
    theme = _prefs!.getString('theme') == 'dark'
        ? AppTheme.dark
        : AppTheme.light;
    apiBase = _prefs!.getString('api_base') ?? defaultApiBase;
    _readEveReminder(_prefs!.getString('reminder_eve_time'));
    _connection = await ConnectionStore.open();

    final saved = await _connection!.read();
    if (saved != null) {
      apiBase = saved.apiBase;
      await _prefs!.setString('api_base', apiBase);
      user = saved.user;
      _token = saved.token;
      pendingAuth = saved.pending;
      await _openSession();
      return;
    }

    final token = await _secure.read(key: 'auth_token');
    final rawUser = await _secure.read(key: 'auth_user');
    if (token == null || rawUser == null) {
      phase = SessionPhase.signedOut;
      notifyListeners();
      return;
    }
    try {
      user = AuthUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
    } catch (_) {
      phase = SessionPhase.signedOut;
      notifyListeners();
      return;
    }
    _token = token;
    pendingAuth = false;
    await _persistConnection(password: null, mode: 'login', pending: false);
    await _openSession();
  }

  Future<void> setApiBase(String value) async {
    final next = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (next.isEmpty) return;
    apiBase = next;
    await _prefs?.setString('api_base', next);
    notifyListeners();
  }

  Future<void> setEveReminderTime(int hour, int minute) async {
    eveReminderHour = hour.clamp(0, 23);
    eveReminderMinute = minute.clamp(0, 59);
    await _prefs?.setString('reminder_eve_time', eveReminderLabel);
    notifyListeners();
    final store = _store;
    if (store == null) return;
    try {
      final dueTasks = await store.listOpenDueTasks();
      await _reminders.apply(
        dueTasks,
        eveHour: eveReminderHour,
        eveMinute: eveReminderMinute,
      );
    } catch (_) {}
  }

  void _readEveReminder(String? raw) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw ?? '');
    if (match == null) return;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return;
    eveReminderHour = hour;
    eveReminderMinute = minute;
  }

  Future<void> toggleTheme() async {
    theme = theme == AppTheme.light ? AppTheme.dark : AppTheme.light;
    await _prefs?.setString('theme', theme.name);
    notifyListeners();
  }

  Future<({String email, String name, String? password})?> lastAccount() {
    final connection = _connection;
    if (connection == null) return Future.value(null);
    return connection.lastAccount();
  }

  Future<void> login(String email, String password) async {
    final trimmed = email.trim();
    try {
      final data = await _requestAuth(
        mode: 'login',
        email: trimmed,
        password: password,
        name: '',
      );
      await _acceptAuth(data);
      final current = user;
      if (current != null) {
        await _connection?.remember(
          email: current.email,
          userId: current.id,
          name: current.name,
          password: password,
        );
      }
    } on ApiException catch (error) {
      if (!error.serverDown) rethrow;
      await _enterOffline(
        email: trimmed,
        password: password,
        name: '',
        mode: 'login',
      );
    }
  }

  Future<void> register(String email, String password, String name) async {
    final trimmed = email.trim();
    final trimmedName = name.trim();
    try {
      final data = await _requestAuth(
        mode: 'register',
        email: trimmed,
        password: password,
        name: trimmedName,
      );
      await _acceptAuth(data);
      final current = user;
      if (current != null) {
        await _connection?.remember(
          email: current.email,
          userId: current.id,
          name: current.name.isEmpty ? trimmedName : current.name,
          password: password,
        );
      }
    } on ApiException catch (error) {
      if (!error.serverDown) rethrow;
      await _enterOffline(
        email: trimmed,
        password: password,
        name: trimmedName,
        mode: 'register',
      );
    }
  }

  Future<void> loginWithGoogle() async {
    final base = apiBase.replaceAll(RegExp(r'/+$'), '');
    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: '$base/auth/google?client=mobile',
        callbackUrlScheme: _mobileScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: true),
      );
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      if (code.contains('cancel')) return;
      throw ApiException(error.message ?? 'Connexion Google impossible', 0);
    }
    final uri = Uri.parse(result);
    if (uri.queryParameters['error'] == '1') {
      throw ApiException('La connexion Google a échoué', 401);
    }
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw ApiException('Code Google manquant', 400);
    }
    final data = await _api.post('/auth/exchange', body: {'code': code});
    await _acceptAuth(data);
  }

  Future<void> logout() async {
    final token = _token;
    _syncTimer?.cancel();
    if (token != null) {
      try {
        await _api.post('/auth/logout', token: token);
      } catch (_) {}
    }
    try {
      await _secure.delete(key: 'auth_token');
      await _secure.delete(key: 'auth_user');
    } catch (_) {}
    try {
      await _connection?.clear();
      await _store?.close();
    } catch (_) {}
    _store = null;
    _token = null;
    pendingAuth = false;
    user = null;
    unawaited(_reminders.apply(const []));
    profiles = [];
    tasks = [];
    tags = [];
    categories = [];
    activeProfileId = null;
    phase = SessionPhase.signedOut;
    syncStatus = SyncStatus.synced;
    syncError = null;
    notifyListeners();
  }

  void setFilter(QuickFilter value) {
    filter = value;
    notifyListeners();
  }

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void setSelectedTag(String? id) {
    selectedTagId = selectedTagId == id ? null : id;
    notifyListeners();
  }

  Future<void> selectProfile(String id) async {
    activeProfileId = id;
    await _prefs?.setString('active_profile:${user?.id}', id);
    await reload();
  }

  Future<void> createProfile(String name, String color) async {
    final store = _requireStore();
    final profile = await store.createProfile(name, color);
    await selectProfile(profile.id);
    _scheduleSync();
  }

  Future<void> deleteProfile(String id) async {
    final store = _requireStore();
    await store.deleteProfile(id);
    if (activeProfileId == id) {
      final remaining = await store.listProfiles();
      activeProfileId = remaining.first.id;
      await _prefs?.setString('active_profile:${user?.id}', activeProfileId!);
    }
    await reload();
    _scheduleSync();
  }

  Future<void> createTag(String name, String color) async {
    final profileId = _requireProfile();
    await _requireStore().createTag(profileId, name: name, color: color);
    await reload();
    _scheduleSync();
  }

  Future<void> updateTag(String id, {String? name, String? color}) async {
    await _requireStore().updateTag(id, name: name, color: color);
    await reload();
    _scheduleSync();
  }

  Future<void> deleteTag(String id) async {
    await _requireStore().deleteTag(id);
    if (selectedTagId == id) selectedTagId = null;
    await reload();
    _scheduleSync();
  }

  Future<Category> createCategory(String name, String color) async {
    final category = await _requireStore().createCategory(
      _requireProfile(),
      name: name,
      color: color,
    );
    await reload();
    _scheduleSync();
    return category;
  }

  Future<void> deleteCategory(String id) async {
    await _requireStore().deleteCategory(id);
    await reload();
    _scheduleSync();
  }

  Future<void> createTask(TaskDraft draft) async {
    await _requireStore().createTask(_requireProfile(), draft);
    await reload();
    _scheduleSync();
  }

  Future<void> updateTask(String id, TaskDraft draft) async {
    await _requireStore().updateTask(id, draft);
    await reload();
    _scheduleSync();
  }

  Future<void> toggleDone(String id) async {
    await _requireStore().toggleDone(id);
    await reload();
    _scheduleSync();
  }

  Future<void> togglePin(String id) async {
    await _requireStore().togglePin(id);
    await reload();
    _scheduleSync();
  }

  Future<void> toggleSubtask(String id) async {
    await _requireStore().toggleSubtask(id);
    await reload();
    _scheduleSync();
  }

  Future<void> deleteTask(String id) async {
    await _requireStore().deleteTask(id);
    await reload();
    _scheduleSync();
  }

  Future<void> addTaskImages(String taskId, List<String> paths) async {
    if (paths.isEmpty) return;
    final store = _requireStore();
    for (final path in paths) {
      await store.addTaskImage(taskId, path);
    }
    await reload();
  }

  Future<void> removeTaskImage(String id) async {
    await _requireStore().removeTaskImage(id);
    await reload();
  }

  Future<void> reload() async {
    final store = _store;
    final profileId = activeProfileId;
    if (store == null) return;
    profiles = await store.listProfiles();
    if (profileId == null) {
      tasks = [];
      tags = [];
      categories = [];
    } else {
      tasks = await store.listTasks(profileId);
      tags = await store.listTags(profileId);
      categories = await store.listCategories(profileId);
    }
    await _refreshSyncStatus();
    notifyListeners();
    if (!identical(_store, store)) return;
    try {
      final dueTasks = await store.listOpenDueTasks();
      if (!identical(_store, store)) return;
      unawaited(
        _reminders.apply(
          dueTasks,
          eveHour: eveReminderHour,
          eveMinute: eveReminderMinute,
        ),
      );
    } catch (_) {}
  }

  Future<void> syncNow() async {
    if (_store == null || user == null || syncing) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      if (pendingAuth) {
        final ready = await _flushPendingAuth();
        if (!ready) {
          if (syncStatus != SyncStatus.error) syncStatus = SyncStatus.offline;
          return;
        }
      }
      final token = _token;
      final store = _store;
      final userId = user?.id;
      if (token == null || store == null || userId == null) {
        syncStatus = SyncStatus.offline;
        return;
      }
      await SyncEngine(store, _api).sync(token: token, userId: userId);
      syncError = null;
      await reload();
    } on ApiException catch (error) {
      syncError = error.message;
      syncStatus = error.serverDown ? SyncStatus.offline : SyncStatus.error;
      if (error.status == 401) {
        await logout();
        bootError = 'Session expirée';
      }
      notifyListeners();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _acceptAuth(Map<String, dynamic> data) async {
    final token = data['token'] as String?;
    final rawUser = data['user'];
    if (token == null || rawUser is! Map) {
      throw ApiException('Réponse de connexion invalide', 500);
    }
    user = AuthUser.fromJson(Map<String, dynamic>.from(rawUser));
    _token = token;
    pendingAuth = false;
    await _secure.write(key: 'auth_token', value: token);
    await _secure.write(key: 'auth_user', value: jsonEncode(user!.toJson()));
    await _persistConnection(password: null, mode: 'login', pending: false);
    await _openSession();
  }

  Future<Map<String, dynamic>> _requestAuth({
    required String mode,
    required String email,
    required String password,
    required String name,
  }) {
    if (mode == 'register') {
      return _api.post(
        '/auth/register',
        body: {'email': email, 'password': password, 'name': name},
      );
    }
    return _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
  }

  Future<void> _enterOffline({
    required String email,
    required String password,
    required String name,
    required String mode,
  }) async {
    final known = await _connection?.userIdForEmail(email);
    final localUser = AuthUser(
      id: known ?? 'local${createId().replaceAll('-', '')}',
      email: email,
      name: name,
    );
    user = localUser;
    _token = null;
    pendingAuth = true;
    syncStatus = SyncStatus.offline;
    syncError = null;
    await _secure.delete(key: 'auth_token');
    await _secure.delete(key: 'auth_user');
    await _persistConnection(password: password, mode: mode, pending: true);
    await _openSession();
  }

  Future<bool> _flushPendingAuth() async {
    final saved = await _connection?.read();
    final password = saved?.password;
    if (saved == null || !saved.pending || password == null) {
      return _token != null;
    }
    try {
      final data = await _requestAuth(
        mode: saved.mode,
        email: saved.email,
        password: password,
        name: saved.name,
      );
      await _promote(saved, data);
      return true;
    } on ApiException catch (error) {
      if (saved.mode == 'register' && error.status == 409) {
        try {
          final data = await _requestAuth(
            mode: 'login',
            email: saved.email,
            password: password,
            name: saved.name,
          );
          await _promote(saved, data);
          return true;
        } on ApiException catch (loginError) {
          if (loginError.serverDown) return false;
          syncError = loginError.message;
          syncStatus = SyncStatus.error;
          return false;
        }
      }
      if (error.serverDown) return false;
      syncError = error.message;
      syncStatus = SyncStatus.error;
      return false;
    }
  }

  Future<void> _promote(
    SavedConnection saved,
    Map<String, dynamic> data,
  ) async {
    final token = data['token'] as String?;
    final rawUser = data['user'];
    if (token == null || rawUser is! Map) {
      throw ApiException('Réponse de connexion invalide', 500);
    }
    final remote = AuthUser.fromJson(Map<String, dynamic>.from(rawUser));
    final previousId = saved.user.id;
    await _store?.close();
    _store = null;
    try {
      if (previousId != remote.id) {
        await migrateUserDatabase(previousId, remote.id);
      }
      user = remote;
      _token = token;
      pendingAuth = false;
      await _secure.write(key: 'auth_token', value: token);
      await _secure.write(key: 'auth_user', value: jsonEncode(remote.toJson()));
      await _persistConnection(
        password: null,
        mode: saved.mode,
        pending: false,
      );
      _store = LocalStore(await openUserDatabase(remote.id));
    } catch (_) {
      user = saved.user;
      _token = null;
      pendingAuth = true;
      _store = LocalStore(await openUserDatabase(previousId));
      rethrow;
    }
  }

  Future<void> _persistConnection({
    required String? password,
    required String mode,
    required bool pending,
  }) async {
    final current = user;
    final connection = _connection;
    if (current == null || connection == null) return;
    await connection.save(
      SavedConnection(
        email: current.email,
        password: password,
        name: current.name,
        mode: mode,
        apiBase: apiBase,
        user: current,
        token: _token,
        pending: pending,
      ),
    );
    await connection.remember(
      email: current.email,
      userId: current.id,
      name: current.name,
      password: password,
    );
  }

  Future<void> _openSession() async {
    phase = SessionPhase.booting;
    bootError = null;
    notifyListeners();
    try {
      await _store?.close();
      _store = LocalStore(await openUserDatabase(user!.id));
      await syncNow();
      if (phase == SessionPhase.signedOut || _store == null) return;
      final created = await _store!.ensureDefaultProfile();
      profiles = await _store!.listProfiles();
      final stored = _prefs?.getString('active_profile:${user!.id}');
      activeProfileId = profiles.any((profile) => profile.id == stored)
          ? stored
          : profiles.first.id;
      await _prefs?.setString('active_profile:${user!.id}', activeProfileId!);
      if (created) await syncNow();
      if (phase == SessionPhase.signedOut || _store == null) return;
      await reload();
      phase = SessionPhase.ready;
      notifyListeners();
    } catch (error) {
      bootError = error is ApiException
          ? error.message
          : 'Ouverture impossible';
      phase = SessionPhase.failed;
      notifyListeners();
    }
  }

  Future<void> _refreshSyncStatus() async {
    final store = _store;
    if (store == null) return;
    lastSyncAt = await store.meta('sync:lastSyncAt:${user?.id}');
    if (pendingAuth || _token == null) {
      syncStatus = SyncStatus.offline;
      return;
    }
    if (syncError != null) return;
    final pending = await store.listOutbox();
    syncStatus = pending.isEmpty ? SyncStatus.synced : SyncStatus.pending;
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(syncNow());
    });
  }

  LocalStore _requireStore() {
    final store = _store;
    if (store == null) throw StateError('Base locale indisponible');
    return store;
  }

  String _requireProfile() {
    final id = activeProfileId;
    if (id == null) throw StateError('Aucun profil actif');
    return id;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    unawaited(_store?.close() ?? Future.value());
    super.dispose();
  }
}
