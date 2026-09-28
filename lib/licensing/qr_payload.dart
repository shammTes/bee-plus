import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Same offline payload Bee Seller signs.
/// `BEE1|JUNIOR|<deviceId>|<nonce>|<hmac-sha256-hex>`
class QrPayload {
  static const version = 'BEE1';
  static const _signingKey = String.fromEnvironment(
    'BEE_HMAC_KEY',
    defaultValue: 'BEE_PLUS_ERITREA_OFFLINE_HMAC_V1_CHANGE_IN_RELEASE',
  );

  final String packageCode;
  final String deviceId;
  final String nonce;
  final String signature;

  const QrPayload({
    required this.packageCode,
    required this.deviceId,
    required this.nonce,
    required this.signature,
  });

  String get canonical => '$version|$packageCode|$deviceId|$nonce';

  static QrPayload? tryParse(String raw) {
    var text = raw.trim();
    final i = text.indexOf('$version|');
    if (i > 0) text = text.substring(i);
    final parts = text.split('|');
    if (parts.length != 5) return null;
    if (parts[0] != version) return null;
    return QrPayload(
      packageCode: parts[1],
      deviceId: parts[2],
      nonce: parts[3],
      signature: parts[4],
    );
  }

  bool get isSignatureValid => _constantTimeEquals(_hmac(canonical), signature);

  bool matchesDevice(String currentDeviceId) => deviceId.isNotEmpty && deviceId == currentDeviceId;

  bool get isJunior => packageCode.toUpperCase() == 'JUNIOR';

  static String _hmac(String body) {
    final key = utf8.encode(_signingKey);
    return Hmac(sha256, key).convert(utf8.encode(body)).toString();
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }
}
