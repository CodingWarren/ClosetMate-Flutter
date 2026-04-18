import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:closetmate/data/local/app_database.dart';
import 'package:closetmate/data/models/clothing_model.dart';
import 'package:sqflite/sqflite.dart';

/// 图片路径修复服务
///
/// 修复应用重装后图片路径损坏的问题：
/// - 应用重装后，UUID 改变，图片绝对路径失效
/// - 此服务将路径转换为相对于应用文档目录的格式
class ImagePathFixer {
  /// 修复数据库中的所有图片路径
  /// 返回修复的衣物数量
  static Future<int> fixAllImagePaths() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory(p.join(appDir.path, 'clothing_images'));

      if (!imgDir.existsSync()) {
        await imgDir.create(recursive: true);
      }

      final db = await AppDatabase.instance.database;
      final allClothing = await db.query(AppDatabase.clothingTable);

      int fixedCount = 0;

      for (final row in allClothing) {
        final clothing = ClothingModel.fromMap(row);
        final originalUris = clothing.imageUris;

        if (originalUris.isEmpty) continue;

        final fixedUris = await _fixImageUris(originalUris, imgDir);

        if (fixedUris != originalUris) {
          await db.update(
            AppDatabase.clothingTable,
            {'imageUris': fixedUris},
            where: 'id = ?',
            whereArgs: [clothing.id],
          );
          fixedCount++;
          print('Fixed image paths for clothing: ${clothing.id}');
        }
      }

      print('ImagePathFixer: Fixed $fixedCount clothing items');
      return fixedCount;
    } catch (e) {
      print('ImagePathFixer error: $e');
      rethrow;
    }
  }

  /// 修复单个 imageUris 字符串
  static Future<String> _fixImageUris(String imageUris, Directory imgDir) async {
    if (imageUris.isEmpty) return imageUris;

    final uris = imageUris.split(',').where((uri) => uri.isNotEmpty).toList();
    final fixedUris = <String>[];

    for (final uri in uris) {
      final fixedUri = await _fixSingleUri(uri, imgDir);
      fixedUris.add(fixedUri);
    }

    return fixedUris.join(',');
  }

  /// 修复单个图片 URI
  static Future<String> _fixSingleUri(String uri, Directory imgDir) async {
    // 如果是网络URL，直接返回
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return uri;
    }

    final file = File(uri);

    // 如果文件存在，直接返回原路径
    if (file.existsSync()) {
      return uri;
    }

    // 尝试从路径中提取文件名
    final filename = p.basename(uri);
    if (filename.isEmpty) {
      return uri; // 无法修复
    }

    // 检查是否在 clothing_images 目录中
    final possiblePath = p.join(imgDir.path, filename);
    final possibleFile = File(possiblePath);

    if (possibleFile.existsSync()) {
      print('ImagePathFixer: Fixed path $uri -> $possiblePath');
      return possiblePath;
    }

    // 如果还是找不到，尝试在 clothing_images 目录中查找同名文件
    // （用于备份恢复后的情况）
    try {
      final files = imgDir.listSync();
      for (final f in files) {
        if (f is File && p.basename(f.path) == filename) {
          print('ImagePathFixer: Found matching file: ${f.path}');
          return f.path;
        }
      }
    } catch (e) {
      print('ImagePathFixer: Error searching for file: $e');
    }

    // 无法修复，返回原路径
    return uri;
  }

  /// 检查是否需要修复
  static Future<bool> needsFix() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final db = await AppDatabase.instance.database;
      final allClothing = await db.query(AppDatabase.clothingTable);

      for (final row in allClothing) {
        final clothing = ClothingModel.fromMap(row);
        if (clothing.imageUris.isEmpty) continue;

        final uris = clothing.imageUris.split(',').where((uri) => uri.isNotEmpty);
        for (final uri in uris) {
          if (uri.startsWith('http://') || uri.startsWith('https://')) continue;

          final file = File(uri);
          if (!file.existsSync()) {
            return true; // 至少有一个文件不存在
          }
        }
      }

      return false;
    } catch (e) {
      print('ImagePathFixer.needsFix error: $e');
      return false;
    }
  }
}