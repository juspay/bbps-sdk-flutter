import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'bbps_sdk_flutter_platform_interface.dart';

/// An implementation of [BbpsFlutterPlatform] that uses method channels.
class MethodChannelBbpsFlutter extends BbpsFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('bbps_sdk_flutter');

  /// The event channel for receiving BBPS events.
  @visibleForTesting
  final eventChannel = const EventChannel('bbps_sdk_flutter_events');

  Stream<BbpsEvent>? _eventStream;

  @override
  Future<bool> createService(String clientId) async {
    final result = await methodChannel.invokeMethod<bool>('createService', {
      'clientId': clientId,
    });
    return result ?? false;
  }

  @override
  Future<void> initiate({
    required String agentId,
    required String mobile,
    required String deviceId,
    required String clientId,
    required String action,
    String? authToken,
  }) async {
    final params = <String, dynamic>{
      'agentId': agentId,
      'mobile': mobile,
      'deviceId': deviceId,
      'clientId': clientId,
      'action': action,
      if (authToken != null) 'authToken': authToken,
    };
    await methodChannel.invokeMethod('initiate', {'params': params});
  }

  @override
  Future<dynamic> process(String action, {Map<String, dynamic>? params}) async {
    final result = await methodChannel.invokeMethod<dynamic>('process', {
      'action': action,
      'params': params ?? {},
    });

    // Try to parse result as JSON if it's a string
    if (result is String) {
      try {
        return jsonDecode(result);
      } catch (_) {
        return result;
      }
    }
    return result;
  }

  @override
  Future<bool> terminate() async {
    final result = await methodChannel.invokeMethod<bool>('terminate');
    return result ?? false;
  }

  @override
  Future<bool> onBackPressed() async {
    final result = await methodChannel.invokeMethod<bool>('onBackPressed');
    return result ?? false;
  }

  @override
  Stream<BbpsEvent> get eventStream {
    _eventStream ??= eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        return BbpsEvent.fromMap(event);
      }
      return BbpsEvent(event: 'UNKNOWN', payload: {'raw': event});
    });
    return _eventStream!;
  }
}
