import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceIdProvider {
  static const _storageKey = 'beeplus_device_id_v1';
  static final _secure = FlutterSecureStorage(
      aOptions: const AndroidOptions(encryptedSharedPreferences: true));
  static String? _cached;
  static Future<String> getId() async {
    if (_cached != null) return _cached!;
    final existing = await _secure.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    String candidate;
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        candidate = 'and_${a.id}_${a.fingerprint.hashCode.toRadixString(16)}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        candidate = 'ios_${i.identifierForVendor ?? const Uuid().v4()}';
      } else {
        candidate = 'oth_${const Uuid().v4()}';
      }
    } catch (_) {
      candidate = 'fb_${const Uuid().v4()}';
    }
    await _secure.write(key: _storageKey, value: candidate);
    _cached = candidate;
    return candidate;
  }
}
