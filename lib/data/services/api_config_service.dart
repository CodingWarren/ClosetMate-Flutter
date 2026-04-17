import 'package:shared_preferences/shared_preferences.dart';

/// API Key 配置服务
///
/// 所有外部 API Key 均通过 SharedPreferences 本地存储，
/// 不上传任何服务器。
class ApiConfigService {
  static const String _keyQWeatherApiKey = 'api_qweather_key';
  static const String _keyQWeatherCity = 'api_qweather_city';
  static const String _keyRemoveBgApiKey = 'api_removebg_key';
  static const String _keyBaiduAiAppId = 'api_baidu_app_id';
  static const String _keyBaiduAiApiKey = 'api_baidu_api_key';
  static const String _keyBaiduAiSecretKey = 'api_baidu_secret_key';
  static const String _keyInitialized = 'api_keys_initialized';

  // ─── 默认 Key（从原版 Android 项目迁移） ─────────────────────────────────

  static const String _defaultQWeatherKey = 'b1addc8c550240c99d731e9e926fd8b6';
  static const String _defaultQWeatherCity = '北京';
  static const String _defaultRemoveBgKey = 'etiNr7vQKtGFMQbHtj34J2G6';
  static const String _defaultBaiduApiKey = 'RT2EqRIcwsgEX1U2TYXq9zca';
  static const String _defaultBaiduSecretKey = 'MMT0GH5tkLT1iVIOPldOKjxM9J1SUUYN';

  /// 首次启动时写入默认 Key（不覆盖用户已修改的值）
  static Future<void> initDefaultKeys() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyInitialized) == true) return;

    await prefs.setString(_keyQWeatherApiKey, _defaultQWeatherKey);
    await prefs.setString(_keyQWeatherCity, _defaultQWeatherCity);
    await prefs.setString(_keyRemoveBgApiKey, _defaultRemoveBgKey);
    await prefs.setString(_keyBaiduAiApiKey, _defaultBaiduApiKey);
    await prefs.setString(_keyBaiduAiSecretKey, _defaultBaiduSecretKey);
    await prefs.setBool(_keyInitialized, true);
  }

  // ─── 和风天气 ─────────────────────────────────────────────────────────────

  static Future<String> get qWeatherApiKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQWeatherApiKey) ?? _defaultQWeatherKey;
  }

  static Future<void> setQWeatherApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQWeatherApiKey, key);
  }

  static Future<String> get qWeatherCity async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQWeatherCity) ?? _defaultQWeatherCity;
  }

  static Future<void> setQWeatherCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQWeatherCity, city);
  }

  // ─── Remove.bg ────────────────────────────────────────────────────────────

  static Future<String> get removeBgApiKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRemoveBgApiKey) ?? _defaultRemoveBgKey;
  }

  static Future<void> setRemoveBgApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRemoveBgApiKey, key);
  }

  // ─── 百度 AI ──────────────────────────────────────────────────────────────

  static Future<String> get baiduAppId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaiduAiAppId) ?? '';
  }

  static Future<String> get baiduApiKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaiduAiApiKey) ?? _defaultBaiduApiKey;
  }

  static Future<String> get baiduSecretKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaiduAiSecretKey) ?? _defaultBaiduSecretKey;
  }

  static Future<void> setBaiduCredentials({
    required String appId,
    required String apiKey,
    required String secretKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaiduAiAppId, appId);
    await prefs.setString(_keyBaiduAiApiKey, apiKey);
    await prefs.setString(_keyBaiduAiSecretKey, secretKey);
  }
}
