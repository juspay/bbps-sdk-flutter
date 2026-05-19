import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bbps_flutter/bbps_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelBbpsFlutter platform = MethodChannelBbpsFlutter();
  const MethodChannel channel = MethodChannel('bbps_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'createService':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('createService', () async {
    expect(await platform.createService('test-client'), true);
  });
}
