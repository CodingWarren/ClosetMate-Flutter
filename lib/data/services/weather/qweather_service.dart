import 'dart:convert';

import 'package:closetmate/data/services/api_config_service.dart';
import 'package:closetmate/data/services/weather/weather_service.dart';
import 'package:http/http.dart' as http;

/// 和风天气 API 服务
///
/// 文档：https://dev.qweather.com/docs/api/weather/weather-now/
class QWeatherService {
  static const Duration _timeout = Duration(seconds: 15);

  // ─── 公开接口 ─────────────────────────────────────────────────────────────

  /// 根据城市名称获取实时天气。
  static Future<WeatherResult> getWeatherByCity([String? cityName]) async {
    final apiKey = await ApiConfigService.qWeatherApiKey;
    final city = cityName ?? await ApiConfigService.qWeatherCity;

    if (apiKey.isEmpty) {
      return const WeatherError('和风天气 API Key 未配置，请在设置中填写');
    }

    try {
      // 1. 查询 Location ID
      final locationId = await _lookupLocationId(city, apiKey);
      if (locationId == null) {
        return WeatherError('未找到城市：$city');
      }

      // 2. 查询实时天气
      return await _fetchWeatherNow(locationId, city, apiKey);
    } on http.ClientException catch (e) {
      return WeatherError('网络请求失败：${e.message}');
    } catch (e) {
      return WeatherError('天气获取失败：$e');
    }
  }

  // ─── 私有方法 ─────────────────────────────────────────────────────────────

  static Future<String?> _lookupLocationId(String city, String apiKey) async {
    final uri = Uri.parse(
      'https://geoapi.qweather.com/v2/city/lookup'
      '?location=${Uri.encodeComponent(city)}&key=$apiKey',
    );

    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != '200') return null;

    final locations = json['location'] as List<dynamic>?;
    if (locations == null || locations.isEmpty) return null;

    return (locations.first as Map<String, dynamic>)['id'] as String?;
  }

  static Future<WeatherResult> _fetchWeatherNow(
    String locationId,
    String cityName,
    String apiKey,
  ) async {
    final uri = Uri.parse(
      'https://devapi.qweather.com/v7/weather/now'
      '?location=$locationId&key=$apiKey',
    );

    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      return WeatherError('天气 API 返回错误：HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != '200') {
      return WeatherError('天气 API 返回错误：code=${json['code']}');
    }

    final now = json['now'] as Map<String, dynamic>?;
    if (now == null) {
      return const WeatherError('天气数据解析失败');
    }

    return WeatherSuccess(
      WeatherInfo(
        temperature: int.tryParse(now['temp']?.toString() ?? '') ?? 20,
        feelsLike: int.tryParse(now['feelsLike']?.toString() ?? '') ?? 20,
        description: now['text']?.toString() ?? '',
        icon: now['icon']?.toString() ?? '',
        cityName: cityName,
        windSpeed: now['windSpeed']?.toString() ?? '',
        humidity: now['humidity']?.toString() ?? '',
      ),
    );
  }
}

// ─── 结果类型 ─────────────────────────────────────────────────────────────────

sealed class WeatherResult {
  const WeatherResult();
}

class WeatherSuccess extends WeatherResult {
  const WeatherSuccess(this.weather);

  final WeatherInfo weather;
}

class WeatherError extends WeatherResult {
  const WeatherError(this.message);

  final String message;
}
