import 'package:flutter_test/flutter_test.dart';
import 'package:todo_mobile/src/api_client.dart';

void main() {
  test('server down covers offline and gateway failures', () {
    expect(ApiException('Hors ligne', 0).serverDown, isTrue);
    expect(ApiException('bad gateway', 502).serverDown, isTrue);
    expect(ApiException('unavailable', 503).serverDown, isTrue);
    expect(ApiException('timeout', 504).serverDown, isTrue);
    expect(ApiException('unauthorized', 401).serverDown, isFalse);
    expect(ApiException('invalid', 400).serverDown, isFalse);
  });
}
