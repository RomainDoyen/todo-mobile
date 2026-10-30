import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Same shape as the extension (`crypto.randomUUID()`): 36 chars, hyphens allowed by Appwrite.
String createId() => _uuid.v4();

/// Deterministic Appwrite row id for a task↔tag link.
/// Must match `todo-extension/lib/sync/ids.ts` (FNV-1a, 32-bit imul).
String taskTagEntityId(String taskId, String tagId) {
  return 'tt_${_fnvHex('$taskId\u0000$tagId', 32)}';
}

int _u32(int n) => n & 0xFFFFFFFF;

int _imul(int a, int b) {
  final product = a.toSigned(32) * b.toSigned(32);
  return product.toSigned(32) & 0xFFFFFFFF;
}

String _fnvHex(String input, int hexLen) {
  var h1 = 0x811c9dc5;
  var h2 = 0x811c9dc5 ^ 0x9e3779b9;
  var h3 = 0x811c9dc5 ^ 0x85ebca6b;
  var h4 = 0x811c9dc5 ^ 0xc2b2ae35;

  for (var i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    h1 = _imul(h1 ^ c, 0x01000193);
    h2 = _imul(h2 ^ c, 0x01000193);
    h3 = _imul(h3 ^ c, 0x01000193);
    h4 = _imul(h4 ^ c, 0x01000193);
    h2 = _imul(h2 ^ (c << (i % 7)), 0x85ebca6b);
    h3 = _imul(h3 ^ (i * c), 0xc2b2ae35);
  }

  String part(int n) => _u32(n).toRadixString(16).padLeft(8, '0');
  final hex = '${part(h1)}${part(h2)}${part(h3)}${part(h4)}';
  return hex.substring(0, hexLen);
}
