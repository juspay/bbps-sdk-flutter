import 'dart:async';

import 'bbps_sdk_flutter_platform_interface.dart';

export 'bbps_sdk_flutter_platform_interface.dart' show BbpsEvent;

/// BBPS Flutter Plugin main class
class BbpsFlutter {
  /// Create BBPS service
  static Future<bool> createService({Map<String, dynamic>? params}) {
    return BbpsFlutterPlatform.instance.createService(params: params);
  }

  /// Initiate BBPS session
  static Future<void> initiate({Map<String, dynamic>? params}) {
    return BbpsFlutterPlatform.instance.initiate(params: params);
  }

  /// Process BBPS action
  static Future<dynamic> process({Map<String, dynamic>? params}) {
    return BbpsFlutterPlatform.instance.process(params: params);
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
