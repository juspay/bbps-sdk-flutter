import 'dart:async';

import 'bbps_flutter_platform_interface.dart';

export 'bbps_flutter_platform_interface.dart' show BbpsEvent;

/// BBPS Flutter Plugin main class
class BbpsFlutter {
  /// Create BBPS service with clientId
  static Future<bool> createService(String clientId) {
    print("PAWAN >>> lib root createService");
    return BbpsFlutterPlatform.instance.createService(clientId);
  }

  /// Initiate BBPS session
  static Future<void> initiate({
    required String agentId,
    required String mobile,
    required String deviceId,
    required String clientId,
    required String action,
    String? authToken,
  }) {
    return BbpsFlutterPlatform.instance.initiate(
      agentId: agentId,
      mobile: mobile,
      deviceId: deviceId,
      clientId: clientId,
      authToken: authToken,
      action: action,
    );
  }

  /// Process BBPS action
  static Future<dynamic> process(
    String action, {
    Map<String, dynamic>? params,
  }) {
    return BbpsFlutterPlatform.instance.process(action, params: params);
  }

  /// Terminate BBPS service
  static Future<bool> terminate() {
    return BbpsFlutterPlatform.instance.terminate();
  }

  /// Handle back press
  static Future<bool> onBackPressed() {
    return BbpsFlutterPlatform.instance.onBackPressed();
  }

  /// Stream of BBPS events
  static Stream<BbpsEvent> get eventStream =>
      BbpsFlutterPlatform.instance.eventStream;
}
