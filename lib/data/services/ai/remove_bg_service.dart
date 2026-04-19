// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:closetmate/data/services/api_config_service.dart';
import 'package:closetmate/data/services/http_client.dart';
import 'package:closetmate/data/services/image_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Remove.bg 图片抠图服务
///
/// 优先使用代理服务器（PROXY_BASE_URL），代理不可用时回退到直连模式。
/// 文档：https://www.remove.bg/api
class RemoveBgService {
  static const String _directApiUrl = 'https://api.remove.bg/v1.0/removebg';
  static const Duration _directTimeout = Duration(seconds: 30);
  static const Duration _proxyTimeout = Duration(seconds: 45);

  // ─── 公开接口 ─────────────────────────────────────────────────────────────

  /// 对 [imagePath] 进行 AI 抠图，返回处理结果。
  ///
  /// 若配置了 PROXY_BASE_URL，则通过代理服务器转发请求（API Key 存于服务端）；
  /// 否则直接调用 remove.bg API（需要客户端配置 API Key）。
  static Future<RemoveBgResult> removeBackground(String imagePath) async {
    final proxyUrl = await ApiConfigService.proxyBaseUrl;

    if (proxyUrl.isNotEmpty) {
      print('[RemoveBg] 使用代理模式: $proxyUrl');
      return _removeBackgroundViaProxy(imagePath, proxyUrl);
    }

    print('[RemoveBg] 使用直连模式');
    return _removeBackgroundDirect(imagePath);
  }

  // ─── 代理模式 ─────────────────────────────────────────────────────────────

  static Future<RemoveBgResult> _removeBackgroundViaProxy(
    String imagePath,
    String proxyUrl,
  ) async {
    final file = File(imagePath);
    if (!file.existsSync()) return const RemoveBgError('图片文件不存在');

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);
    print('[RemoveBg] 图片大小: ${bytes.length} bytes，Base64 长度: ${base64Image.length}');

    try {
      final client = createHttpClient();
      final response = await client
          .post(
            Uri.parse('$proxyUrl/api/removebg'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image_base64': base64Image}),
          )
          .timeout(_proxyTimeout);

      print('[RemoveBg] 代理响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.startsWith('image/')) {
          // 新格式：云函数直接返回二进制 PNG，体积最小
          final processedPath = await _saveProcessedImage(response.bodyBytes);
          print('[RemoveBg] 抠图成功（代理-二进制），保存到: $processedPath');
          return RemoveBgSuccess(processedPath);
        } else {
          // 旧格式兼容：JSON 包装的 Base64
          try {
            final json = jsonDecode(response.body) as Map<String, dynamic>;
            final resultBase64 = json['image_base64'] as String?;
            if (resultBase64 != null && resultBase64.isNotEmpty) {
              final processedPath = await _saveProcessedImage(base64Decode(resultBase64));
              print('[RemoveBg] 抠图成功（代理-JSON），保存到: $processedPath');
              return RemoveBgSuccess(processedPath);
            }
          } catch (_) {}
          return const RemoveBgError('代理服务返回数据异常');
        }
      } else {
        final errorBody = response.body;
        print('[RemoveBg] 代理失败响应体: $errorBody');
        return RemoveBgError('代理服务返回错误：HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('[RemoveBg] 代理网络错误: $e');
      return const RemoveBgError('网络连接失败，请检查网络');
    } catch (e) {
      print('[RemoveBg] 代理未知错误: $e');
      return RemoveBgError('抠图失败：$e');
    }
  }

  // ─── 直连模式 ─────────────────────────────────────────────────────────────

  static Future<RemoveBgResult> _removeBackgroundDirect(String imagePath) async {
    final apiKey = await ApiConfigService.removeBgApiKey;
    if (apiKey.isEmpty) {
      return const RemoveBgError('Remove.bg API Key 未配置，请在设置中填写或配置代理服务器');
    }

    final file = File(imagePath);
    if (!file.existsSync()) return const RemoveBgError('图片文件不存在');

    print('[RemoveBg] 开始直连抠图: $imagePath');
    try {
      final client = createHttpClient();
      final request = http.MultipartRequest('POST', Uri.parse(_directApiUrl))
        ..headers['X-Api-Key'] = apiKey
        ..fields['size'] = 'preview' // preview 限制 0.25MP，体积小、速度快
        ..files.add(
          await http.MultipartFile.fromPath('image_file', imagePath),
        );

      print('[RemoveBg] 发起直连请求...');
      final streamedResponse = await client.send(request).timeout(_directTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      print('[RemoveBg] 直连响应状态: ${response.statusCode}');

      if (response.statusCode == 200) {
        final processedPath = await _saveProcessedImage(response.bodyBytes);
        print('[RemoveBg] 抠图成功（直连），保存到: $processedPath');
        return RemoveBgSuccess(processedPath);
      } else {
        print('[RemoveBg] 直连失败响应体: ${response.body}');
        return RemoveBgError('Remove.bg 返回错误：HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      print('[RemoveBg] 直连网络错误: $e');
      return const RemoveBgError('网络连接失败，请检查网络');
    } catch (e) {
      print('[RemoveBg] 直连未知错误: $e');
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

    final fileName = 'removebg_${DateTime.now().millisecondsSinceEpoch}.png';
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
