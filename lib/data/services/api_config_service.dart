import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API Key 配置服务
///
/// 优先级：用户在设置页手动填写的值 > .env 文件中的默认值 > 空字符串
/// .env 文件在 .gitignore 中排除，不会上传到 GitHub。
class ApiConfigService {
  static const String _keyQWeatherApiKey = 'api_qweather_key';
  static const String _keyQWeatherCity = 'api_qweather_city';
  static const String _keyRemoveBgApiKey = 'api_removebg_key';
  static const String _keyBaiduAiAppId = 'api_baidu_app_id';
  static const String _keyBaiduAiApiKey = 'api_baidu_api_key';
  static const String _keyBaiduAiSecretKey = 'api_baidu_secret_key';
  static const String _keyInitialized = 'api_keys_initialized';

  // ─── 从 .env 文件读取默认值 ───────────────────────────────────────────────

  static String get _defaultQWeatherKey =>
      dotenv.env['QWEATHER_API_KEY'] ?? '';
  static String get _defaultQWeatherCity =>
      dotenv.env['QWEATHER_DEFAULT_CITY'] ?? '北京';
  static String get _defaultRemoveBgKey =>
      dotenv.env['REMOVEBG_API_KEY'] ?? '';
  static String get _defaultBaiduApiKey =>
      dotenv.env['BAIDU_AI_API_KEY'] ?? '';
  static String get _defaultBaiduSecretKey =>
      dotenv.env['BAIDU_AI_SECRET_KEY'] ?? '';

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
