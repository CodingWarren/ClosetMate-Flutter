import 'dart:convert';
import 'dart:io';

import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/services/api_config_service.dart';
import 'package:http/http.dart' as http;

/// 百度 AI 图像识别服务
///
/// 使用百度 AI 开放平台的图像识别能力，自动识别衣物品类、颜色、风格。
/// 文档：https://ai.baidu.com/ai-doc/IMAGERECOGNITION/Fk3bcxdte
class BaiduAiService {
  static const Duration _timeout = Duration(seconds: 8);

  // ─── 公开接口 ─────────────────────────────────────────────────────────────

  /// 识别 [imagePath] 中的衣物信息，返回识别结果。
  static Future<AiTagResult> recognizeClothing(String imagePath) async {
    final apiKey = await ApiConfigService.baiduApiKey;
    final secretKey = await ApiConfigService.baiduSecretKey;

    if (apiKey.isEmpty || secretKey.isEmpty) {
      return const AiTagError('百度 AI API Key 未配置，请在设置中填写');
    }

    try {
      // 1. 获取 Access Token
      final accessToken = await _getAccessToken(apiKey, secretKey);
      if (accessToken == null) {
        return const AiTagError('百度 AI 鉴权失败，请检查 API Key');
      }

      // 2. 读取图片并 Base64 编码
      final file = File(imagePath);
      if (!file.existsSync()) {
        return const AiTagError('图片文件不存在');
      }
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 3. 调用服装识别接口
      final result = await _callClothingRecognition(accessToken, base64Image);
      return result;
    } on SocketException {
      return const AiTagError('网络连接失败，请检查网络');
    } catch (e) {
      return AiTagError('识别失败：$e');
    }
  }

  // ─── 私有方法 ─────────────────────────────────────────────────────────────

  static Future<String?> _getAccessToken(
    String apiKey,
    String secretKey,
  ) async {
    final uri = Uri.parse(
      'https://aip.baidubce.com/oauth/2.0/token'
      '?grant_type=client_credentials'
      '&client_id=$apiKey'
      '&client_secret=$secretKey',
    );

    final response = await http.post(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['access_token'] as String?;
  }

  static Future<AiTagResult> _callClothingRecognition(
    String accessToken,
    String base64Image,
  ) async {
    final uri = Uri.parse(
      'https://aip.baidubce.com/rest/2.0/image-classify/v1/classify/clothes'
      '?access_token=$accessToken',
    );

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'image=${Uri.encodeComponent(base64Image)}',
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      return AiTagError('百度 AI 返回错误：HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json.containsKey('error_code')) {
      return AiTagError('百度 AI 错误：${json['error_msg']}');
    }

    final results = json['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return const AiTagError('未识别到衣物信息');
    }

    // 解析识别结果
    return _parseResults(results);
  }

  static AiTagResult _parseResults(List<dynamic> results) {
    String category = '';
    final colors = <String>[];
    final styles = <String>[];

    for (final item in results) {
      final map = item as Map<String, dynamic>;
      final name = map['name']?.toString() ?? '';
      final score = (map['score'] as num?)?.toDouble() ?? 0.0;

      if (score < 0.3) continue; // 置信度过低，跳过

      // 品类映射
      if (category.isEmpty) {
        final mapped = _mapCategory(name);
        if (mapped.isNotEmpty) category = mapped;
      }

      // 颜色映射
      final color = _mapColor(name);
      if (color.isNotEmpty && !colors.contains(color)) {
        colors.add(color);
      }

      // 风格映射
      final style = _mapStyle(name);
      if (style.isNotEmpty && !styles.contains(style)) {
        styles.add(style);
      }
    }

    return AiTagSuccess(
      category: category,
      colors: colors,
      styles: styles,
    );
  }

  static String _mapCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('t恤') || lower.contains('t-shirt')) {
      return ClothingCategory.tShirt;
    }
    if (lower.contains('衬衫') || lower.contains('shirt')) {
      return ClothingCategory.shirt;
    }
    if (lower.contains('毛衣') || lower.contains('sweater')) {
      return ClothingCategory.sweater;
    }
    if (lower.contains('卫衣') || lower.contains('hoodie')) {
      return ClothingCategory.hoodie;
    }
    if (lower.contains('上衣') || lower.contains('top')) {
      return ClothingCategory.top;
    }
    if (lower.contains('裤') || lower.contains('pants') || lower.contains('jeans')) {
      return ClothingCategory.pants;
    }
    if (lower.contains('裙') || lower.contains('skirt')) {
      return ClothingCategory.skirt;
    }
    if (lower.contains('连衣裙') || lower.contains('dress')) {
      return ClothingCategory.dress;
    }
    if (lower.contains('外套') || lower.contains('jacket')) {
      return ClothingCategory.jacket;
    }
    if (lower.contains('大衣') || lower.contains('coat')) {
      return ClothingCategory.coat;
    }
    if (lower.contains('羽绒') || lower.contains('down')) {
      return ClothingCategory.downJacket;
    }
    if (lower.contains('鞋') || lower.contains('shoe')) {
      return ClothingCategory.shoes;
    }
    if (lower.contains('包') || lower.contains('bag')) {
      return ClothingCategory.bag;
    }
    return '';
  }

  static String _mapColor(String name) {
    const colorMap = {
      '白': '白', '黑': '黑', '灰': '灰', '米': '米', '红': '红',
      '粉': '粉', '橙': '橙', '黄': '黄', '绿': '绿', '蓝': '蓝',
      '紫': '紫', '棕': '棕', '花纹': '花纹', '条纹': '条纹', '格纹': '格纹',
    };
    for (final entry in colorMap.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return '';
  }

  static String _mapStyle(String name) {
    if (name.contains('休闲') || name.contains('casual')) {
      return ClothingStyle.casual;
    }
    if (name.contains('运动') || name.contains('sport')) {
      return ClothingStyle.sport;
    }
    if (name.contains('正式') || name.contains('formal')) {
      return ClothingStyle.formal;
    }
    if (name.contains('通勤') || name.contains('office')) {
      return ClothingStyle.commute;
    }
    if (name.contains('街头') || name.contains('street')) {
      return ClothingStyle.street;
    }
    if (name.contains('复古') || name.contains('vintage')) {
      return ClothingStyle.vintage;
    }
    return '';
  }
}

// ─── 结果类型 ─────────────────────────────────────────────────────────────────

sealed class AiTagResult {
  const AiTagResult();
}

class AiTagSuccess extends AiTagResult {
  const AiTagSuccess({
    required this.category,
    required this.colors,
    required this.styles,
  });

  final String category;
  final List<String> colors;
  final List<String> styles;
}

class AiTagError extends AiTagResult {
  const AiTagError(this.message);

  final String message;
}
