enum CloudAction { apply, delete, skip }

/// Last-write-wins on ISO timestamps. Same rules as `lib/sync/merge.ts`.
CloudAction shouldApplyCloud({
  required String? localUpdatedAt,
  required String updatedAt,
  required String? deletedAt,
}) {
  if (localUpdatedAt != null && localUpdatedAt.compareTo(updatedAt) > 0) {
    return CloudAction.skip;
  }
  if (deletedAt != null && deletedAt.isNotEmpty) return CloudAction.delete;
  return CloudAction.apply;
}
