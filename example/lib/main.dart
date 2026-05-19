import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:bbps_sdk_flutter/bbps_sdk_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _lastEvent = 'No events';
  late StreamSubscription<BbpsEvent> _eventSubscription;
  bool _isInitialized = false;

  String _selectedAction = 'BBPS_PAYMENT';

  final List<String> _actions = [
    'BBPS_PAYMENT',
    'SET_TXN_STATUS',
    'BBPS_BILLERS_LIST',
    'BBPS_LIST_TXN',
    'BBPS_LIST_PENDING_BILLS',
    'GENERATE_KEY',
  ];

  // Demo values
  final String _agentId = 'JP01JP21INB519364396';
  final String _mobile = '9889993924';
  final String _sampleToken =
      'eyJhbGciOiJSUzI1NiIsImtpZCI6IkpQMDFKUDIxSU5CNTE5MzY0Mzk2IiwidHlwIjoiSldUIn0.eyJtb2JpbGUiOiI5MTEwMjAzMDQwIiwiZGV2aWNlX2lkIjoiZGV2aWNlMDAxIiwiaWF0IjoxNzM1NTYzNDcxfQ.Z6N9R-KFHPIj0bHJFfuTJAidETswTz3RC3MfHcuAPwosbUYreI9Fl577BXVywteVQD1eVZ1YQ67D89Pp57G5b4HhBDT8xx-P4QYY_DQ-rByc99ZfmO8QWQH0Y51sdqNKRkxYgo6BJhAl_C4dJwqKZuNPyCJzAhLVzYfcmqNmECTt9yoBiQe_ELnqBEyRbXlvpnL77A7Vw7RhH8J6KLYAlyrGGak2_tZ3WXZ9XzWPcum9OnFIm2rD2G1IhK7MfYBdkIbzxeNqVF6tyx8lov32csjjXswPhgZDIYoCqwdr3vH8GahRMdCf8cJ-2SZkvGytTfTn-rmNw5jw1XX_L-tQOg';
  final Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _listenToEvents();
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }

  void _listenToEvents() {
    _eventSubscription = BbpsFlutter.eventStream.listen((event) {
      setState(() {
        _lastEvent = '${event.event}: ${jsonEncode(event.payload)}';
      });
      debugPrint('BBPS Event: ${event.event}, Payload: ${event.payload}');
    });
  }

  Future<void> _createService() async {
    try {
      await BbpsFlutter.createService('fibe');
      _showSnackBar('Service Created Successfully');
    } catch (e) {
      _showSnackBar('Error creating service: $e');
    }
  }

  Future<void> _initiate() async {
    try {
      await BbpsFlutter.initiate(
        agentId: _agentId,
        mobile: _mobile,
        deviceId: '356152103690000',
        clientId: 'fibe',
        action: 'initiate',
      );
      setState(() {
        _isInitialized = true;
      });
      _showSnackBar('Initiated Successfully');
    } catch (e) {
      _showSnackBar('Error initiating: $e');
    }
  }

  Map<String, dynamic> _buildPayload(String action) {
    switch (action) {
      case 'BBPS_PAYMENT':
        return {
          'action': action,
          'agentId': _agentId,
          'authToken': _sampleToken,
        };

      case 'SET_TXN_STATUS':
        final paymentParam = {};
        final paymentParams = [paymentParam];
        final lastTxnRefId = _uuid.v4();

        final paymentDetails = {
          'payeeName': 'Neha Jain',
          'txnAmount': '100.00',
          'txnRefId': lastTxnRefId,
          'paymentMode': 'UPI',
          'custConvFee': '0',
          'paymentParams': paymentParams,
        };

        final data = {
          'response': 'Success',
          'note': 'Sending Money',
          'bbpsTxnId': 'demo-txn-id-${DateTime.now().millisecondsSinceEpoch}',
          'paymentDetails': paymentDetails,
        };

        return {'mobile': _mobile, 'action': 'SET_TXN_STATUS', 'data': data};

      case 'BBPS_BILLERS_LIST':
        final category = {
          'subCategories': <String>[],
          'categoryName': 'Broadband Postpaid',
          'categoryIcon': '',
        };
        return {'action': action, 'category': category};

      case 'BBPS_LIST_TXN':
        return {'action': action, 'offset': 0, 'limit': 15};

      case 'BBPS_LIST_PENDING_BILLS':
        return {'action': action};

      case 'GENERATE_KEY':
        return {
          'action': action,
          'agentId': _agentId,
          'authToken': _sampleToken,
        };

      default:
        return {'action': action};
    }
  }

  Future<void> _process() async {
    try {
      final payload = _buildPayload(_selectedAction);
      debugPrint('PAWAN >>> Process payload: ${jsonEncode(payload)}');
      final result = await BbpsFlutter.process(
        _selectedAction,
        params: payload,
      );
      _showSnackBar('Process result: $result');
    } catch (e) {
      _showSnackBar('Error processing: $e');
    }
  }

  Future<void> _onBackPressed() async {
    try {
      final result = await BbpsFlutter.onBackPressed();
      _showSnackBar('Back pressed handled: $result');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _terminate() async {
    try {
      await BbpsFlutter.terminate();
      setState(() {
        _isInitialized = false;
      });
      _showSnackBar('BBPS Terminated');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger != null) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('BBPS Flutter Example')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Status: ${_isInitialized ? 'Initialized' : 'Not Initialized'}',
                style: TextStyle(
                  fontSize: 14,
                  color: _isInitialized ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Last Event:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_lastEvent, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _createService,
                child: const Text('Create Service'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isInitialized ? null : _initiate,
                child: const Text('Initiate'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Process Action:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedAction,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _actions.map((action) {
                  return DropdownMenuItem(
                    value: action,
                    child: Text(action, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: _isInitialized
                    ? (value) {
                        setState(() {
                          _selectedAction = value!;
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isInitialized ? _process : null,
                child: Text('Process: $_selectedAction'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ElevatedButton(
                onPressed: _isInitialized ? _onBackPressed : null,
                child: const Text('On Back Pressed'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isInitialized ? _terminate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Terminate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
