import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 图片本地持久化服务
///
/// 将相册/相机返回的临时路径复制到 App 私有目录，
/// 并压缩至 500KB 以内，返回持久化后的绝对路径。
class ImageStorageService {
  static const int maxSizeBytes = 500 * 1024; // 500 KB — 公开供外部使用
  static const int _maxSizeBytes = maxSizeBytes;
  static const int _maxDimension = 2048;

  /// 将 [sourcePath] 复制并压缩到 App 私有目录。
  /// 返回持久化后的文件路径；失败时返回原路径。
  static Future<String> copyAndCompress(String sourcePath) async {
    try {
      final dir = await _clothingImagesDir();
      final fileName =
          'img_${DateTime.now().millisecondsSinceEpoch}_${_rand4()}.jpg';
      final destFile = File(p.join(dir.path, fileName));

      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) return sourcePath;

      final bytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        // 无法解码，直接复制
        await sourceFile.copy(destFile.path);
        return destFile.path;
      }

      // 等比缩放
      img.Image resized = decoded;
      if (decoded.width > _maxDimension || decoded.height > _maxDimension) {
        resized = img.copyResize(
          decoded,
          width: decoded.width > decoded.height ? _maxDimension : -1,
          height: decoded.height >= decoded.width ? _maxDimension : -1,
        );
      }

      // 逐步降质压缩
      int quality = 90;
      List<int> compressed;
      do {
        compressed = img.encodeJpg(resized, quality: quality);
        if (compressed.length <= _maxSizeBytes || quality <= 40) break;
        quality -= 10;
      } while (true);

      await destFile.writeAsBytes(compressed);
      return destFile.path;
    } catch (e) {
      // 降级：直接返回原路径
      return sourcePath;
    }
  }

  /// 批量处理，返回持久化后的路径列表。
  static Future<List<String>> copyAndCompressAll(List<String> paths) async {
    final results = <String>[];
    for (final path in paths) {
      results.add(await copyAndCompress(path));
    }
    return results;
  }

  /// 删除 App 私有目录中的图片文件。
  static Future<void> deleteImage(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// 获取（并创建）衣物图片私有目录。
  static Future<Directory> _clothingImagesDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'clothing_images'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _rand4() =>
      (DateTime.now().microsecond % 10000).toString().padLeft(4, '0');
}
