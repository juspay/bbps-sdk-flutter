import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';

/// RSA signing for the HyperUPI signature-auth variant.
///
/// Ported from hyper-sdk-android:
///   app/src/main/java/in/juspay/godel/demo/Utils.java
///     - newSign(String)       -> [signPayload]
///     - getSignedData(..)     -> Signature.getInstance("SHA256withRSA"), then
///                                Base64 of the raw signature bytes
///   app/src/main/java/in/juspay/godel/demo/ManageActivity.java
///     - getSignaturePayload() -> [buildSignaturePayload]
///
/// The private key is NOT embedded here. The Android sample hardcodes its
/// sandbox key in Utils.getPrivateKeyString(), but a key committed to a repo
/// is a key that leaks, so this reads it from a compile-time define instead:
///
///   flutter run --dart-define=HYPER_SIGNING_KEY="$(cat sandbox_key.pem)"
///
/// In production the merchant's server holds the key and returns only the
/// signature; the app should never see it at all.
class HyperSignature {
  HyperSignature._();

  /// PEM private key supplied at build time. Accepts either PKCS#1
  /// ("BEGIN RSA PRIVATE KEY") or PKCS#8 ("BEGIN PRIVATE KEY").
  ///
  /// Note the Android sample stores a bare base64 body and feeds it to
  /// PKCS8EncodedKeySpec even though it is actually PKCS#1; Android's provider
  /// tolerates that, Dart does not. If you pass a bare base64 body here it is
  /// wrapped with the PKCS#1 header, matching how that key is really encoded.
  static const String _keyFromEnv = String.fromEnvironment('HYPER_SIGNING_KEY');

  static bool get hasKey => _keyFromEnv.isNotEmpty;

  static String _wrap(String body, String label) {
    final lines = <String>[];
    for (var i = 0; i < body.length; i += 64) {
      lines.add(body.substring(i, i + 64 > body.length ? body.length : i + 64));
    }
    return '-----BEGIN $label-----\n'
        '${lines.join('\n')}\n'
        '-----END $label-----';
  }

  /// Loads a key given either a full PEM or a bare base64 body.
  ///
  /// merchant_config.json stores bare bodies in BOTH encodings — the hyperupi
  /// sandbox key is PKCS#1 (MIIEp...) while popclub-jws is PKCS#8
  /// (MIIEvQIBADANBgkq...) — and each needs a different parser, so when the
  /// encoding is not declared by a header both are attempted.
  static RSAPrivateKey _loadKey(String raw) {
    final key = raw.trim();
    if (key.contains('BEGIN')) {
      return key.contains('BEGIN RSA PRIVATE KEY')
          ? CryptoUtils.rsaPrivateKeyFromPemPkcs1(key)
          : CryptoUtils.rsaPrivateKeyFromPem(key);
    }
    final body = key.replaceAll(RegExp(r'\s+'), '');
    try {
      return CryptoUtils.rsaPrivateKeyFromPem(_wrap(body, 'PRIVATE KEY'));
    } catch (_) {
      return CryptoUtils.rsaPrivateKeyFromPemPkcs1(
        _wrap(body, 'RSA PRIVATE KEY'),
      );
    }
  }

  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// Builds the v3 / protected-signature fields, mirroring
  /// hyper-sdk-android Helpers.getJWSSignature() + its caller at Helpers.java:912:
  ///
  ///   String[] jws = getJWSSignature(payload, privateKey, kid).split("\\.");
  ///   protected = jws[0]; signaturePayload = jws[1]; signature = jws[2];
  ///
  /// i.e. a standard compact JWS (RS256) split across three payload fields.
  /// Note this differs from the v2 variant [signPayload] implements: v2 signs
  /// the raw JSON string and sends it as-is, v3 base64url-encodes everything
  /// and signs "protected.signaturePayload".
  static Map<String, String>? buildJwsFields({
    required String kid,
    required Map<String, dynamic> claims,
    String? privateKeyPem,
  }) {
    final pem = privateKeyPem ?? _keyFromEnv;
    if (pem.isEmpty) {
      return null;
    }
    // kid before alg, matching the captured header's field order.
    final header = _b64url(utf8.encode(jsonEncode({'kid': kid, 'alg': 'RS256'})));
    final payload = _b64url(utf8.encode(jsonEncode(claims)));
    final signature = CryptoUtils.rsaSign(
      _loadKey(pem),
      Uint8List.fromList(utf8.encode('$header.$payload')),
      algorithmName: 'SHA-256/RSA',
    );
    return {
      'protected': header,
      'signaturePayload': payload,
      'signature': _b64url(signature),
    };
  }

  /// Claim set for the v3 signaturePayload, matching the captured UAT request.
  static Map<String, dynamic> buildJwsClaims({
    required String merchantId,
    required String merchantChannelId,
    required String merchantCustomerId,
    required String customerMobileNumber,
    required String timestamp,
  }) => {
    'merchantId': merchantId,
    'merchantChannelId': merchantChannelId,
    'merchantCustomerId': merchantCustomerId,
    'customerMobileNumber': customerMobileNumber,
    'timestamp': timestamp,
  };

  /// Mirrors ManageActivity.getSignaturePayload(). Returns the STRINGIFIED
  /// JSON that is both signed and sent as the `signaturePayload` field — the
  /// two must be byte-identical or the signature will not verify.
  ///
  /// [timestamp] is caller-supplied so the same value can also be sent as the
  /// payload-level `timestamp` field; the SDK cross-checks the two, so
  /// generating them independently makes them disagree.
  static String buildSignaturePayload({
    required String merchantId,
    required String customerId,
    required String timestamp,
    String? orderId,
  }) {
    final payload = <String, dynamic>{
      'merchant_id': merchantId,
      'customer_id': customerId,
      'timestamp': timestamp,
    };
    if (orderId != null) {
      payload['order_id'] = orderId;
    }
    return jsonEncode(payload);
  }

  /// Convenience for "now" in the format the SDK expects (epoch millis as a
  /// string, per ManageActivity's String.valueOf(System.currentTimeMillis())).
  static String nowTimestamp() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  /// Mirrors Utils.newSign(): SHA256withRSA over the UTF-8 bytes of
  /// [signaturePayload], Base64-encoded.
  ///
  /// Returns null when no key was provided, so callers can fall back to the
  /// clientAuthToken variant instead of sending a bogus signature.
  static String? signPayload(String signaturePayload, {String? privateKeyPem}) {
    final pem = privateKeyPem ?? _keyFromEnv;
    if (pem.isEmpty) {
      return null;
    }
    final signature = CryptoUtils.rsaSign(
      _loadKey(pem),
      Uint8List.fromList(utf8.encode(signaturePayload)),
      algorithmName: 'SHA-256/RSA',
    );
    return base64.encode(signature);
  }
}
