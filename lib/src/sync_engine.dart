import 'api_client.dart';
import 'ids.dart';
import 'local_store.dart';
import 'models.dart';
import 'time.dart';

const _defaultSince = '1970-01-01T00:00:00.000Z';
final _appwriteUid = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_]{0,35}$');

class SyncEngine {
  SyncEngine(this.store, this.api);

  final LocalStore store;
  final ApiClient api;

  Future<void> sync({required String token, required String userId}) async {
    await _push(token);
    await _pull(token, userId);
  }

  Future<void> _push(String token) async {
    await store.seedRelationsOnce();
    final entries = await store.listOutbox();
    if (entries.isEmpty) return;

    final normalized = entries.map(_normalize).toList();
    final response = await api.post(
      '/sync/push',
      token: token,
      body: {
        'mutations': normalized
            .map(
              (entry) => {
                'collection': entry.entity,
                'id': entry.entityId,
                'op': entry.op,
                'payload': entry.payload,
                'updatedAt': entry.updatedAt,
              },
            )
            .toList(),
      },
    );

    final winners = (response['winners'] as List?) ?? const [];
    final documents = <String, List<Map<String, dynamic>>>{
      for (final entity in syncEntities) entity: <Map<String, dynamic>>[],
    };
    final byEntityId = {for (final entry in normalized) entry.entityId: entry};
    for (final raw in winners) {
      if (raw is! Map) continue;
      final doc = Map<String, dynamic>.from(raw);
      final id = (doc['id'] ?? doc['\$id'] ?? '').toString();
      final entry = byEntityId[id];
      if (entry == null) continue;
      documents[entry.entity]!.add(doc);
    }
    await store.applyCloudDocuments(documents);

    final applied = ((response['applied'] as List?) ?? const []).map((id) => id.toString());
    final winnerIds = winners.whereType<Map>().map(
          (doc) => (doc['id'] ?? doc['\$id'] ?? '').toString(),
        );
    final resolved = {...applied, ...winnerIds};
    final removeIds = entries
        .where((entry) => resolved.contains(_normalize(entry).entityId))
        .map((entry) => entry.id)
        .toList();
    await store.removeOutbox(removeIds);
  }

  Future<void> _pull(String token, String userId) async {
    final since = await store.meta('sync:lastSyncAt:$userId') ?? _defaultSince;
    final response = await api.get(
      '/sync/pull',
      token: token,
      query: {'since': since},
    );
    final rawDocs = response['documents'];
    final documents = <String, List<Map<String, dynamic>>>{
      for (final entity in syncEntities) entity: <Map<String, dynamic>>[],
    };
    if (rawDocs is Map) {
      for (final entity in syncEntities) {
        final list = rawDocs[entity];
        if (list is! List) continue;
        documents[entity] = list.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    }
    await store.applyCloudDocuments(documents);
    await store.setMeta('sync:lastSyncAt:$userId', nowIso());
  }
}

OutboxEntry _normalize(OutboxEntry entry) {
  if (entry.entity != 'task_tags') return entry;
  final taskId = entry.payload['taskId']?.toString() ?? '';
  final tagId = entry.payload['tagId']?.toString() ?? '';
  if (taskId.isEmpty || tagId.isEmpty) return entry;
  final entityId = taskTagEntityId(taskId, tagId);
  if (!_appwriteUid.hasMatch(entityId) || entityId.length > 36) return entry;
  if (entry.entityId == entityId) return entry;
  return OutboxEntry(
    id: entry.id,
    entity: entry.entity,
    entityId: entityId,
    op: entry.op,
    payload: entry.payload,
    updatedAt: entry.updatedAt,
  );
}
