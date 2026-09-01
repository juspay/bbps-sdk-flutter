import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:hypersdkflutter/hypersdkflutter.dart';
import 'package:bbps_sdk_flutter/bbps_sdk_flutter.dart';

import 'hyper_signature.dart';

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

  // HyperUPI (In-App UPI) runs on HyperSDK alongside BBPS, through its own
  // hypersdkflutter channel.
  final HyperSDK _hyperSDK = HyperSDK();
  bool _isHyperUpiInitialized = false;
  String _lastHyperEvent = 'No HyperSDK events';

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
  final String _agentId = 'YB71YB72MOB511066132';
  final String _mobile = '9889993924';
  // HyperUPI (In-App UPI) credentials — replace with the merchant's own values.
  // These are the sandbox values for the `hyperupi` test merchant, taken from
  // hyper-sdk-android's app/src/main/assets/merchant_config.json.
  // Note clientId != merchantId here, and _hyperClientId must match the
  // clientId in ios/MerchantConfig.txt, since that is the client whose asset
  // bundle is fused into HyperSDK.xcframework.
  // Switched to the popclub-jws merchant so the initiate session and the
  // signed process call belong to the SAME merchant — a process call signed as
  // POPCLUBUAT against a session initiated as hyperupi is rejected.
  final String _hyperMerchantId = 'popclub';
  final String _hyperClientId = 'popclub';
  final String _hyperEnvironment = 'sandbox';
  // NOTE: the SDK_INITIATION doc also lists `upiEnvironment`, which would need
  // to stay 'sandbox' while ios/CommonLibrary.podspec points at the UAT build
  // of the NPCI Common Library. The Android management flow does not send it,
  // so it is omitted here — add it back if you follow the doc's payload.
  final String _hyperIssuingPsp = 'YES_BIZ';
  // Required by initiate when shouldCreateCustomer is true. Must be the
  // merchant's stable per-user identifier, not a per-session value.
  final String _hyperCustomerId = 'bbps_demo_customer_001';
  // merchant_config.json -> hyperupi.sandbox.merchantKeyId. Identifies which
  // public key the backend verifies the signature against. The matching
  // sandbox private key (hyperupi.sandbox.privateKey) is supplied at build
  // time via --dart-define=HYPER_SIGNING_KEY rather than committed here.
  final String _hyperMerchantKeyId = '35554';

  // Obtained from the merchant's own server. The signature/merchantKeyId
  // variant is the alternative; see the initiate payload below.
  final String _hyperClientAuthToken = '<CLIENT_AUTH_TOKEN>';
  // hyper-sdk-android uses in.juspay.hyperupi for BOTH initiate and the
  // Management process call (ManageActivity.initiateManagement / startM).
  // The `Management` action does not exist on in.juspay.hyperapi.
  final String _hyperService = 'in.juspay.hyperapi';

  // Service + action for the process call. The captured UAT request uses the
  // inappupi service, and both that request and the docs
  // (memory-bank/03_payload_examples/UPI_GET_SESSION_TOKEN) name the action
  // `upiGetSessionToken` — note the `upi` prefix, which a bare
  // `getSessionToken` is missing and which the SDK rejects as an unknown
  // action.
  final String _hyperProcessService = 'in.juspay.hyperapi';
  final String _hyperProcessAction = 'upiGetSessionToken';

  // v3 / protected-signature merchant: merchant_config.json -> popclub-jws.
  // The captured PAYBYUAT request could never work here — its signaturePayload
  // bakes in a fixed timestamp (so it expires within minutes) and a different
  // merchant than the one we initiate as. These are signed live instead.
  //
  // merchantId/merchantChannelId come from the psp* fields, matching the
  // captured payload's POPCLUBUAT/POPCLUBUATAPP shape. The sandbox private key
  // (popclub-jws.sandbox.privateKey, PKCS#8) is passed via
  // --dart-define=HYPER_SIGNING_KEY.
  final String _jwsKid = '0185db89-4b31-dcb0-eb33-7d14f72e4ec4';
  final String _jwsMerchantId = 'POPCLUBUAT';
  final String _jwsMerchantChannelId = 'POPCLUBUATAPP';
  final String _jwsMerchantCustomerId = '674da8233fc14f71bb6666fa';
  final String _jwsCustomerMobileNumber = '918655226822';

  final String _sampleToken =
      'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IllCNzFZQjcyTU9CNTExMDY2MTMyIn0.eyJtb2JpbGUiOiI5MDEwMjAzMDQwIiwiZGV2aWNlX2lkIjoiZGV2aWNlMDAxIiwiaWF0IjoxNzc5Mjc0OTIwfQ.G9grwYRWPAQTuWVxykrwNl23iCebv55HMbEo7pg7jcVV69NhVZiMXWsPmIFG2wlYYWZJBbQ5yPH40lqSRaOfkENbugcku7eGel2WNulDvCKiZmnqmtKNloj11LE4Ka-IbFghAEid1ONLDgYixtzR7kN8nzQSrmltQOnK1z3nUN6-a7OacFJ0bH2Wnz0cmZ_iTQk4flnCHbQuOVF-5XG6OzvRdRgGE1_-C7lsCMGmyRgBaDUjM1c8qQptn3bLLgs9h-MlBFp4Std-6NW77nNz6aaYAE_s0ovJ0N2dunsLDcr11XHaxS2Lng5ysQSzeVYihby3r_vLkhFR0rgpEK3FDw';
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
      await BbpsFlutter.createService(params: {'clientId': 'stock'});
      _showSnackBar('Service Created Successfully');
    } catch (e) {
      _showSnackBar('Error creating service: $e');
    }
  }

  Future<void> _initiate() async {
    try {
      await BbpsFlutter.initiate(
        params: {
          'action': 'initiate',
          'agentId': _agentId,
          'mobile': _mobile,
          'deviceId': '356152103690000',
          'clientId': 'stock',
          'issuingCou': 'yes_biz',
        },
      );
      setState(() {
        _isInitialized = true;
      });
      _showSnackBar('Initiated Successfully');
    } catch (e) {
      _showSnackBar('Error initiating: $e');
    }
  }

  /// Auth fields shared by the HyperUPI calls, mirroring ManageActivity's
  /// `isSignatureBased` switch in hyper-sdk-android: either the RSA signature
  /// pair, or a clientAuthToken.
  ///
  /// Only `signature` + `signaturePayload` are sent. Android also sets
  /// merchantKeyId from Utils.getMerchantKeyID(), but that lookup has no entry
  /// for this merchant and returns "" — merchant_config.json carries the real
  /// value (hyperupi.sandbox.merchantKeyId = 35554) if it is needed again.
  ///
  /// signaturePayload is the STRINGIFIED JSON, matching Android's
  /// getSignaturePayload().toString(); the signed bytes and the transmitted
  /// string must be byte-identical, so it is built once and reused (the
  /// timestamp changes on every call).
  ///
  /// Falls back to the token when no signing key was supplied via
  /// --dart-define=HYPER_SIGNING_KEY, so the app still runs without one.
  /// Currently unused: popclub-jws is a v3 merchant and uses
  /// [_jwsAuthFields] instead. Kept because v2 (merchantKeyId + raw-JSON
  /// signature) is still the right variant for merchants without a `kid`,
  /// e.g. hyperupi — switch the constants back and call this instead.
  // ignore: unused_element
  Map<String, dynamic> _authFields() {
    if (HyperSignature.hasKey) {
      // One timestamp, used both inside the signed payload and as the
      // payload-level `timestamp`. Generating them separately would make the
      // two disagree by a few milliseconds.
      final timestamp = HyperSignature.nowTimestamp();
      final signaturePayload = HyperSignature.buildSignaturePayload(
        merchantId: _hyperMerchantId,
        customerId: _hyperCustomerId,
        timestamp: timestamp,
      );
      return {
        'signature': HyperSignature.signPayload(signaturePayload),
        'signaturePayload': signaturePayload,
        'timestamp': timestamp,
        // Required: without it the process call fails with
        // "JP_012 Invalid authentication data" — the backend needs the key id
        // to know which public key to verify the signature against.
        'merchantKeyId': _hyperMerchantKeyId,
      };
    }
    return {'clientAuthToken': _hyperClientAuthToken};
  }

  /// v3 protected-signature auth fields, signed fresh on every call.
  ///
  /// Returns `protected` / `signaturePayload` / `signature` — the three parts
  /// of a compact JWS, exactly as hyper-sdk-android splits it at
  /// Helpers.java:912. The timestamp is generated at call time, which is why
  /// a captured payload cannot be reused: it is inside the signed bytes.
  Map<String, String>? _jwsAuthFields() {
    final fields = HyperSignature.buildJwsFields(
      kid: _jwsKid,
      claims: HyperSignature.buildJwsClaims(
        merchantId: _jwsMerchantId,
        merchantChannelId: _jwsMerchantChannelId,
        merchantCustomerId: _jwsMerchantCustomerId,
        customerMobileNumber: _jwsCustomerMobileNumber,
        timestamp: HyperSignature.nowTimestamp(),
      ),
    );
    if (fields == null) {
      _showSnackBar('No signing key: pass --dart-define=HYPER_SIGNING_KEY');
    }
    return fields;
  }

  /// Runs the HyperUPI `initiate` handshake.
  ///
  /// Must report a successful `initiate_result` before any `process` call.
  Future<void> _hyperUpiInitiate() async {
    try {
      // initiate() may only be called once per HyperSDK instance; calling it
      // again without terminate() fails with JP_017.
      if (await _hyperSDK.isInitialised()) {
        _showSnackBar('HyperUPI already initialised');
        return;
      }

      // Mirrors ManageActivity.initiateManagement() in hyper-sdk-android.
      // Deliberately does NOT send upiEnvironment / shouldCreateCustomer /
      // merchantLoader: the Android management flow omits them, and the set of
      // keys here decides which product flow the SDK registers. logLevel is a
      // string and merchant_id is repeated alongside merchantId, both as the
      // Android sample does.
      final payload = {
        'requestId': _uuid.v4(),
        'service': _hyperService,
        'payload': {
          'action': 'initiate',
          'clientId': _hyperClientId,
          'merchantId': _hyperMerchantId,
          'merchant_id': _hyperMerchantId,
          'customerId': _jwsMerchantCustomerId,
          'environment': _hyperEnvironment,
          'logLevel': '1',
          'issuingPsp': _hyperIssuingPsp,
          // popclub-jws is an apiVersion:v3 merchant — it has a `kid` and no
          // sandbox merchantKeyId, so it uses the protected-signature variant
          // for initiate as well, not the v2 _authFields() triple. The
          // timestamp lives inside the signed claims, so none is sent here.
          ...?_jwsAuthFields(),
        },
      };

      // NOTE: do NOT call _hyperSDK.createHyperServices() first. In
      // hypersdkflutter 4.0.57 the iOS side of that method never fulfils its
      // FlutterResult on the first call, so the await hangs forever and
      // initiate is never reached. initiate() creates HyperServices itself
      // when it is nil.
      debugPrint('HyperUPI initiate payload: ${jsonEncode(payload)}');
      await _hyperSDK.initiate(payload, _onHyperEvent);
    } catch (e) {
      _showSnackBar('Error initiating HyperUPI: $e');
    }
  }

  /// Runs the HyperUPI `management` process call.
  ///
  /// Opens the UPI management surface (linked accounts, deregister, etc.).
  /// Requires a successful `initiate` first — hypersdkflutter's iOS `process`
  /// returns false outright when the SDK is not initialised.
  ///
  /// Auth here is the merchantKeyId + signature variant; `signaturePayload`
  /// is a STRINGIFIED JSON object, not a nested one.
  ///
  /// The TPAP/bank-direct integrations instead use protected signatures:
  /// replace merchantKeyId with `protected` (base64 of {kid, alg:"RS256"}) and
  /// base64-encode both signaturePayload and signature. The signaturePayload
  /// keys differ too: merchantId / merchantChannelId / merchantCustomerId
  /// (plus simSerialNos and deviceId for bank-direct).
  Future<void> _hyperUpiManagement() async {
    try {
      if (!await _hyperSDK.isInitialised()) {
        _showSnackBar('Run HyperUPI Initiate first');
        return;
      }

      // TEMPORARY: auth values captured from a working UAT request, hardcoded
      // so the flow can be exercised end to end. They embed a fixed timestamp
      // and customer, so they will expire — swap back to _authFields() (which
      // signs live via HyperSignature) once the protected-signature variant is
      // wired to the merchant's key.
      //
      // This is the TPAP/protected-signature variant: `protected` is base64 of
      // {kid, alg:"RS256"}, and signaturePayload/signature are base64url — not
      // the merchantKeyId + stringified-JSON variant _authFields() builds.
      final payload = {
        'requestId': _uuid.v4(),
        // The captured request runs on in.juspay.inappupi, not the
        // in.juspay.hyperupi used for initiate.
        'service': _hyperProcessService,
        'payload': {'action': _hyperProcessAction, ...?_jwsAuthFields()},
      };

      debugPrint('HyperUPI management payload: ${jsonEncode(payload)}');
      await _hyperSDK.process(payload, _onHyperEvent);
    } catch (e) {
      _showSnackBar('Error running HyperUPI management: $e');
    }
  }

  void _onHyperEvent(MethodCall methodCall) {
    debugPrint(
      'HyperSDK Event: ${methodCall.method}, Args: ${methodCall.arguments}',
    );

    Map<String, dynamic> args = {};
    try {
      args = jsonDecode(methodCall.arguments.toString()) as Map<String, dynamic>;
    } catch (_) {
      // Some events arrive as plain strings; the raw value is still shown below.
    }

    final error = args['error'] == true;

    if (methodCall.method == 'initiate_result') {
      setState(() {
        _isHyperUpiInitialized = !error;
      });
      _showSnackBar(
        error
            ? 'HyperUPI initiate failed '
                  '[${args['errorCode']}]: ${args['errorMessage']}'
            : 'HyperUPI initiated',
      );
    } else if (methodCall.method == 'process_result') {
      final action = (args['payload'] as Map?)?['action'] ?? 'process';
      final status = (args['payload'] as Map?)?['status'];
      _showSnackBar(
        error
            ? '$action failed [${args['errorCode']}]: ${args['errorMessage']}'
            : '$action: ${status ?? 'done'}',
      );
    }

    setState(() {
      _lastHyperEvent = '${methodCall.method}: ${methodCall.arguments}';
    });
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
      final result = await BbpsFlutter.process(params: payload);
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
              const SizedBox(height: 24),
              const Divider(),
              const Text(
                'HyperUPI (In-App UPI)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${_isHyperUpiInitialized ? 'Initialized' : 'Not Initialized'}',
                style: TextStyle(
                  fontSize: 14,
                  color: _isHyperUpiInitialized ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _lastHyperEvent,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _hyperUpiInitiate,
                child: const Text('HyperUPI: Initiate'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isHyperUpiInitialized ? _hyperUpiManagement : null,
                child: const Text('HyperUPI: GST'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
