import 'dart:async';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'bbps_sdk_flutter_method_channel.dart';

/// BBPS Event callback type
typedef BbpsEventCallback = void Function(BbpsEvent event);

/// Represents BBPS SDK events
class BbpsEvent {
  final String event;
  final Map<String, dynamic>? payload;
  final String? error;
  final String? requestId;
  final String? service;
  final String? errorCode;
  final String? errorMessage;

  BbpsEvent({
    required this.event,
    this.payload,
    this.error,
    this.requestId,
    this.service,
    this.errorCode,
    this.errorMessage,
  });

  factory BbpsEvent.fromMap(Map<dynamic, dynamic> map) {
    Map<String, dynamic>? payload;
    if (map['payload'] != null) {
      // Parse JSON string payload if needed
      payload = map['payload'] is String
          ? {'raw': map['payload']}
          : Map<String, dynamic>.from(map['payload']);
    }

    return BbpsEvent(
      event: map['event'] ?? '',
      payload: payload,
      error: map['error']?.toString(),
      requestId: map['requestId']?.toString(),
      service: map['service']?.toString(),
      errorCode: map['errorCode']?.toString(),
      errorMessage: map['errorMessage']?.toString(),
    );
  }

  @override
  String toString() =>
      'BbpsEvent(event: $event, payload: $payload, error: $error, requestId: $requestId, service: $service, errorCode: $errorCode, errorMessage: $errorMessage)';
}

/// Platform interface for BBPS Flutter Plugin
abstract class BbpsFlutterPlatform extends PlatformInterface {
  BbpsFlutterPlatform() : super(token: _token);

  static final Object _token = Object();
  static BbpsFlutterPlatform _instance = MethodChannelBbpsFlutter();

  static BbpsFlutterPlatform get instance => _instance;

  static set instance(BbpsFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Create BBPS service
  Future<bool> createService({Map<String, dynamic>? params});

  /// Initiate BBPS session
  Future<void> initiate({Map<String, dynamic>? params});

  /// Process BBPS action
  Future<dynamic> process({Map<String, dynamic>? params});

  /// Terminate BBPS service
  Future<bool> terminate();

  /// Handle back press
  Future<bool> onBackPressed();

  /// Stream of BBPS events
  Stream<BbpsEvent> get eventStream;
}
