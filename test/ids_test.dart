import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/src/ids.dart';

void main() {
  test('taskTagEntityId matches the extension hash', () {
    expect(
      taskTagEntityId(
        '550e8400-e29b-41d4-a716-446655440000',
        '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
      ),
      'tt_de8038292422cf7615cbca26ce0c0ba2',
    );
    expect(taskTagEntityId('task-a', 'tag-1'), 'tt_6347466cf0a5eb2f6251d0fe92f39c2d');
    expect(taskTagEntityId('task-a', 'tag-2'), 'tt_66474b25539bcf2ce7cb9c6a8ff39774');
    expect(taskTagEntityId('task-a', 'tag-1'), isNot(taskTagEntityId('task-a', 'tag-2')));
  });
}
