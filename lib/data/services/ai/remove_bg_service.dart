import 'dart:io';

import 'package:closetmate/data/services/api_config_service.dart';
import 'package:closetmate/data/services/image_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Remove.bg 图片抠图服务
///
/// 文档：https://www.remove.bg/api
class RemoveBgService {
  static const String _apiUrl = 'https://api.remove.bg/v1.0/removebg';
  static const Duration _timeout = Duration(seconds: 8);

  // ─── 公开接口 ─────────────────────────────────────────────────────────────

  /// 对 [imagePath] 进行 AI 抠图，返回处理结果。
  static Future<RemoveBgResult> removeBackground(String imagePath) async {
    final apiKey = await ApiConfigService.removeBgApiKey;
    if (apiKey.isEmpty) {
      return const RemoveBgError('Remove.bg API Key 未配置，请在设置中填写');
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      return const RemoveBgError('图片文件不存在');
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl))
        ..headers['X-Api-Key'] = apiKey
        ..fields['size'] = 'auto'
        ..files.add(
          await http.MultipartFile.fromPath('image_file', imagePath),
        );

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // 保存处理后的图片到私有目录
        final processedPath = await _saveProcessedImage(response.bodyBytes);
        return RemoveBgSuccess(processedPath);
      } else {
        return RemoveBgError(
          'Remove.bg 返回错误：HTTP ${response.statusCode}',
        );
      }
    } on SocketException {
      return const RemoveBgError('网络连接失败，请检查网络');
    } catch (e) {
      return RemoveBgError('抠图失败：$e');
    }
  }

  // ─── 私有方法 ─────────────────────────────────────────────────────────────

  static Future<String> _saveProcessedImage(List<int> bytes) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'clothing_images'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final fileName =
        'removebg_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);

    // 如果文件超过 500KB，再压缩一次
    if (bytes.length > ImageStorageService.maxSizeBytes) {
      return ImageStorageService.copyAndCompress(file.path);
    }

    return file.path;
  }
}

// ─── 结果类型 ─────────────────────────────────────────────────────────────────

sealed class RemoveBgResult {
  const RemoveBgResult();
}

class RemoveBgSuccess extends RemoveBgResult {
  const RemoveBgSuccess(this.processedPath);

  final String processedPath;
}

class RemoveBgError extends RemoveBgResult {
  const RemoveBgError(this.message);

  final String message;
}
