import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'qr_payload.dart';

class UnlockResult {
  const UnlockResult.ok(this.value) : error = null;
  const UnlockResult.fail(this.error) : value = null;
  final String? value;
  final String? error;
  bool get isOk => error == null;
}

/// Permanent JUNIOR unlock, device-bound, nonce single-use. Matches Bee Seller.
class UnlockStore {
  static const _idKey = 'beeplus_device_id_v1';
  static const _flagKey = 'beeplus_junior_unlocked';
  static const _nonceKey = 'beeplus_used_nonces';

  SharedPreferences? _prefs;
  String? _deviceId;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await deviceId();
  }

  bool get isUnlocked => _prefs?.getBool(_flagKey) ?? false;

  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = _prefs!;
    var id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      id = _mint();
      await prefs.setString(_idKey, id);
    }
    _deviceId = id;
    return id;
  }

  Future<UnlockResult> applyPayload(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) {
      return const UnlockResult.fail('Paste or scan the code from Bee Seller.');
    }
    final payload = QrPayload.tryParse(text);
    if (payload == null) return const UnlockResult.fail('That is not a Bee Seller code.');
    if (!payload.isSignatureValid) return const UnlockResult.fail('Invalid signature.');
    final current = await deviceId();
    if (!payload.matchesDevice(current)) {
      return UnlockResult.fail('This code is for another phone.');
    }
    if (!payload.isJunior) {
      return const UnlockResult.fail('This code is for 4, not Bee Plus.');
    }
    final prefs = _prefs!;
    final used = prefs.getStringList(_nonceKey) ?? const <String>[];
    if (used.contains(payload.nonce)) {
      return const UnlockResult.fail('This code was already used.');
    }
    await prefs.setBool(_flagKey, true);
    await prefs.setStringList(_nonceKey, [...used, payload.nonce]);
    return const UnlockResult.ok('Bee Plus is unlocked on this phone.');
  }

  static String _mint() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(12, (_) => alphabet[r.nextInt(alphabet.length)]).join();
  }
}
