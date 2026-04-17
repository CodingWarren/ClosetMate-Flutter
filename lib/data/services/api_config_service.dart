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

  // ─── 和风天气 ─────────────────────────────────────────────────────────────

  static Future<String> get qWeatherApiKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQWeatherApiKey) ?? '';
  }

  static Future<void> setQWeatherApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQWeatherApiKey, key);
  }

  static Future<String> get qWeatherCity async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQWeatherCity) ?? '北京';
  }

  static Future<void> setQWeatherCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQWeatherCity, city);
  }

  // ─── Remove.bg ────────────────────────────────────────────────────────────

  static Future<String> get removeBgApiKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRemoveBgApiKey) ?? '';
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
    return prefs.getString(_keyBaiduAiApiKey) ?? '';
  }

  static Future<String> get baiduSecretKey async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaiduAiSecretKey) ?? '';
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
