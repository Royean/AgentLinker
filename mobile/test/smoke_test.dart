import 'package:flutter_test/flutter_test.dart';

import 'package:agentlinker_mobile/config/constants.dart';

void main() {
  test('默认 WebSocket 地址含 /ws/client', () {
    expect(kDefaultServerUrl.contains('/ws/client'), isTrue);
    expect(kDefaultServerUrlEmulator.contains('10.0.2.2'), isTrue);
  });
}
