class WeatherService {
  static const int tempVeryCold = 10;
  static const int tempCool = 20;
  static const int tempWarm = 30;
}

class WeatherInfo {
  const WeatherInfo({
    required this.temperature,
    required this.feelsLike,
    required this.description,
    required this.icon,
    required this.cityName,
    required this.windSpeed,
    required this.humidity,
  });

  final int temperature;
  final int feelsLike;
  final String description;
  final String icon;
  final String cityName;
  final String windSpeed;
  final String humidity;

  String get dressAdvice {
    if (temperature < WeatherService.tempVeryCold) {
      return '今天较冷，建议穿厚外套';
    }
    if (temperature < WeatherService.tempCool) {
      return '今天凉爽，建议穿薄外套';
    }
    if (temperature < WeatherService.tempWarm) {
      return '今天温暖，单衣即可';
    }
    return '今天炎热，建议穿短袖或裙装';
  }

  String get weatherEmoji {
    if (description.contains('晴')) return '☀️';
    if (description.contains('云')) return '⛅';
    if (description.contains('阴')) return '☁️';
    if (description.contains('雨')) return '🌧️';
    if (description.contains('雪')) return '❄️';
    if (description.contains('雾') || description.contains('霾')) return '🌫️';
    if (description.contains('风')) return '💨';
    return '🌤️';
  }
}
