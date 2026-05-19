import 'package:flutter_test/flutter_test.dart';
import 'package:bbps_sdk_flutter/bbps_sdk_flutter.dart';
import 'package:bbps_sdk_flutter/bbps_sdk_flutter_platform_interface.dart';
import 'package:bbps_sdk_flutter/bbps_sdk_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockBbpsFlutterPlatform
    with MockPlatformInterfaceMixin
    implements BbpsFlutterPlatform {
  @override
  Future<bool> createService(String clientId) => Future.value(true);

  @override
  Future<void> initiate({
    required String agentId,
    required String mobile,
    required String deviceId,
    required String clientId,
    required String action,
    String? authToken,
  }) => Future.value();

  @override
  Future<dynamic> process(String action, {Map<String, dynamic>? params}) =>
      Future.value();

  @override
  Future<bool> terminate() => Future.value(true);

  @override
  Future<bool> onBackPressed() => Future.value(false);

  @override
  Stream<BbpsEvent> get eventStream => const Stream.empty();
}

void main() {
  test('$MethodChannelBbpsFlutter is the default instance', () {
    expect(
      BbpsFlutterPlatform.instance,
      isInstanceOf<MethodChannelBbpsFlutter>(),
    );
  });
}
