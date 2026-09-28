import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'device_id.dart';
import 'qr_payload.dart';

class UnlockResult {
  const UnlockResult.ok(this.value) : error = null;
  const UnlockResult.fail(this.error) : value = null;
  final String? value;
  final String? error;
  bool get isOk => error == null;
}

class UnlockStore {
  UnlockStore._();
  static final instance = UnlockStore._();

  static const _boxName = 'unlock';
  static const _deviceKey = 'device_id';
  static const _packagesKey = 'unlocked_packages';
  static const _usedNoncesKey = 'used_nonces';
  static const _secure = FlutterSecureStorage();

  Box? _box;
  String? _deviceId;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    await deviceId();
  }

  Future<String> deviceId() async {
    if (_deviceId != null) return _deviceId!;
    try {
      final id = await DeviceIdProvider.getId();
      _deviceId = id;
      await _box?.put(_deviceKey, id);
      return id;
    } catch (_) {}
    String? id = await _secure.read(key: _deviceKey);
    id ??= _box?.get(_deviceKey) as String?;
    if (id == null || id.isEmpty) {
      id = const Uuid().v4().replaceAll('-', '').substring(0, 12).toUpperCase();
      await _secure.write(key: _deviceKey, value: id);
      await _box?.put(_deviceKey, id);
    }
    _deviceId = id;
    return id;
  }

  bool get isUnlocked => unlockedPackages.contains('JUNIOR');

  Set<String> get unlockedPackages {
    final raw = _box?.get(_packagesKey);
    if (raw is List) return raw.map((e) => '$e').toSet();
    return {};
  }

  Set<String> get _usedNonces {
    final raw = _box?.get(_usedNoncesKey);
    if (raw is List) return raw.map((e) => '$e').toSet();
    return {};
  }

  Future<UnlockResult> applyPayload(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) {
      return const UnlockResult.fail('Paste the unlock code from Bee Seller.');
    }
    final payload = QrPayload.tryParse(text);
    if (payload == null) {
      return const UnlockResult.fail('Invalid code format.');
    }
    if (!payload.isSignatureValid) {
      return const UnlockResult.fail('Invalid signature.');
    }
    final currentId = await deviceId();
    if (!payload.matchesDevice(currentId)) {
      return UnlockResult.fail(
          'Code is for another device. This device: $currentId');
    }
    if (_usedNonces.contains(payload.nonce)) {
      return const UnlockResult.fail('This code was already used.');
    }
    final pkg = UnlockPackageX.fromCode(payload.packageCode);
    if (pkg != UnlockPackage.junior) {
      return const UnlockResult.fail('This code is not for Bee Plus (JUNIOR).');
    }
    final pkgs = unlockedPackages..add(pkg!.code);
    await _box?.put(_packagesKey, pkgs.toList());
    final used = _usedNonces..add(payload.nonce);
    await _box?.put(_usedNoncesKey, used.toList());
    return const UnlockResult.ok('Unlocked JUNIOR. Permanent on this device.');
  }
}
