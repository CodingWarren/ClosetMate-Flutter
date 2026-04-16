import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const String _keyPinHash = 'app_lock_pin_hash';
  static const String _keyLockEnabled = 'app_lock_enabled';
  static const String _keyBiometricEnabled = 'app_lock_biometric';

  static final LocalAuthentication _localAuth = LocalAuthentication();

  // ─── PIN 管理 ─────────────────────────────────────────────────────────────

  static Future<bool> get isLockEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLockEnabled) ?? false;
  }

  static Future<bool> get isBiometricEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    // 简单哈希：实际生产应使用 bcrypt 等，这里用 SHA-256 模拟
    final hash = _simpleHash(pin);
    await prefs.setString(_keyPinHash, hash);
    await prefs.setBool(_keyLockEnabled, true);
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.setBool(_keyLockEnabled, false);
    await prefs.setBool(_keyBiometricEnabled, false);
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPinHash);
    if (stored == null) return false;
    return _simpleHash(pin) == stored;
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  // ─── 生物识别 ─────────────────────────────────────────────────────────────

  static Future<bool> get isBiometricAvailable async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: '请验证身份以解锁 ClosetMate',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // ─── 工具 ─────────────────────────────────────────────────────────────────

  static String _simpleHash(String input) {
    // 简单的字符串哈希，生产环境应替换为 crypto 包的 SHA-256
    var hash = 0;
    for (final char in input.codeUnits) {
      hash = (hash * 31 + char) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
