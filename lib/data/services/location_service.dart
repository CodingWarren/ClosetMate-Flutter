// ignore_for_file: avoid_print
import 'package:geolocator/geolocator.dart';

/// GPS 定位服务
///
/// 获取设备当前位置，并转换为和风天气 GeoAPI 支持的坐标格式（经度,纬度）。
class LocationService {
  /// 获取当前位置坐标字符串，格式为 "经度,纬度"（如 "116.40,39.90"）。
  ///
  /// 返回 null 的情况：
  /// - 位置服务未开启
  /// - 用户拒绝授权
  /// - 获取超时或发生异常
  static Future<String?> getCurrentLocationString() async {
    try {
      // 1. 检查位置服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[Location] 位置服务未开启');
        return null;
      }

      // 2. 检查并请求权限
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('[Location] 请求位置权限...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[Location] 用户拒绝位置权限');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        print('[Location] 位置权限被永久拒绝');
        return null;
      }

      // 3. 获取当前位置（低精度，速度快，省电）
      print('[Location] 正在获取位置...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('[Location] 获取位置超时');
          throw Exception('Location timeout');
        },
      );

      // 和风天气 GeoAPI 接受 "经度,纬度" 格式，精度保留 2 位小数
      final lon = position.longitude.toStringAsFixed(2);
      final lat = position.latitude.toStringAsFixed(2);
      final result = '$lon,$lat';
      print('[Location] 获取位置成功: $result');
      return result;
    } catch (e) {
      print('[Location] 获取位置失败: $e');
      return null;
    }
  }

  /// 检查是否已授予位置权限（不弹出请求弹窗）
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
