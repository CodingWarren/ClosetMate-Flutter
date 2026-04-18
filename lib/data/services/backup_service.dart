import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:closetmate/data/local/app_database.dart';
import 'package:closetmate/data/models/clothing_model.dart';
import 'package:closetmate/data/models/outfit_model.dart';
import 'package:closetmate/data/repositories/clothing_repository.dart';
import 'package:closetmate/data/repositories/outfit_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 数据备份与恢复服务
///
/// 备份格式 v2：JSON 文件（closetmate_backup_YYYYMMDD_HHmmss.json）
/// 包含：clothing 列表 + outfits 列表 + 图片 Base64 数据（跨平台兼容）
class BackupService {
  static final ClothingRepository _clothingRepo = ClothingRepository();
  static final OutfitRepository _outfitRepo = OutfitRepository();

  // ─── 备份 ─────────────────────────────────────────────────────────────────

  /// 创建备份 JSON 文件（含图片 Base64）并调用系统分享面板。
  /// [sharePositionOrigin] iOS 必须传入按钮的屏幕坐标，否则分享面板会崩溃。
  static Future<BackupResult> createAndShareBackup({Rect? sharePositionOrigin}) async {
    try {
      final clothing = await _clothingRepo.getAllClothing();
      final outfits = await _outfitRepo.getAllOutfits();

      // 收集所有图片，编码为 Base64
      // images map: { "filename.jpg": "base64string" }
      final imagesMap = <String, String>{};

      final clothingMaps = <Map<String, dynamic>>[];
      for (final c in clothing) {
        final map = c.toMap();

        // 把绝对路径转换为相对文件名列表
        final uriList = c.imageUriList;
        final relativeNames = <String>[];

        for (final uri in uriList) {
          final file = File(uri);
          if (file.existsSync()) {
            final filename = p.basename(uri);
            final bytes = await file.readAsBytes();
            imagesMap[filename] = base64Encode(bytes);
            relativeNames.add(filename);
          }
        }

        // 备份中只存相对文件名，不存绝对路径
        map['imageUris'] = relativeNames.join(',');
        clothingMaps.add(map);
      }

      final data = {
        'version': 2,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'clothing': clothingMaps,
        'outfits': outfits.map((o) => o.toMap()).toList(),
        'images': imagesMap,
      };

      final json = const JsonEncoder.withIndent('  ').convert(data);

      final cacheDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(
          p.join(cacheDir.path, 'closetmate_backup_$timestamp.json'));
      await file.writeAsString(json, encoding: utf8);

      // iOS 需要提供 sharePositionOrigin（锚点），否则分享面板会崩溃
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'ClosetMate 衣橱数据备份',
          text: 'ClosetMate 衣橱数据备份文件（含图片，可跨平台恢复）',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      return BackupSuccess(
        clothingCount: clothing.length,
        outfitCount: outfits.length,
      );
    } catch (e) {
      return BackupError('备份失败：$e');
    }
  }

  // ─── 恢复 ─────────────────────────────────────────────────────────────────

  /// 让用户选择备份文件并恢复数据。
  static Future<RestoreResult> pickAndRestore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return const RestoreCancelled();
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return const RestoreError('无法读取文件路径');
      }

      return await restoreFromFile(filePath);
    } catch (e) {
      return RestoreError('恢复失败：$e');
    }
  }

  /// 从指定文件路径恢复数据（支持 v1 和 v2 格式）。
  static Future<RestoreResult> restoreFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return const RestoreError('备份文件不存在');
      }

      final json = await file.readAsString(encoding: utf8);
      final data = jsonDecode(json) as Map<String, dynamic>;

      final version = data['version'] as int? ?? 1;

      // 准备图片存储目录
      final appDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory(p.join(appDir.path, 'clothing_images'));
      if (!imgDir.existsSync()) {
        await imgDir.create(recursive: true);
      }

      // v2：解码并写入图片文件
      final imagesMap = <String, String>{};
      if (version >= 2) {
        final rawImages = data['images'] as Map<String, dynamic>?;
        if (rawImages != null) {
          for (final entry in rawImages.entries) {
            imagesMap[entry.key] = entry.value as String;
          }
        }
      }

      final clothingList = <ClothingModel>[];
      for (final e in (data['clothing'] as List<dynamic>? ?? [])) {
        final map = Map<String, dynamic>.from(e as Map<String, dynamic>);

        if (version >= 2) {
          // 把相对文件名还原为当前设备的绝对路径
          final relativeNames = (map['imageUris'] as String? ?? '')
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList();

          final absolutePaths = <String>[];
          for (final name in relativeNames) {
            final destPath = p.join(imgDir.path, name);
            final destFile = File(destPath);

            // 如果图片 Base64 存在，写入文件
            if (imagesMap.containsKey(name) && !destFile.existsSync()) {
              final bytes = base64Decode(imagesMap[name]!);
              await destFile.writeAsBytes(bytes);
            }

            if (destFile.existsSync()) {
              absolutePaths.add(destPath);
            }
          }

          map['imageUris'] = absolutePaths.join(',');
        }
        // v1 格式：imageUris 是绝对路径，在同一设备上可以直接用
        // 跨平台时图片会丢失，但数据库记录可以恢复

        clothingList.add(ClothingModel.fromMap(map));
      }

      final outfitList = (data['outfits'] as List<dynamic>?)
              ?.map((e) => OutfitModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];

      // 清空现有数据并写入备份数据
      final db = await AppDatabase.instance.database;
      await db.transaction((txn) async {
        await txn.delete(AppDatabase.clothingTable);
        await txn.delete(AppDatabase.outfitsTable);

        for (final c in clothingList) {
          await txn.insert(AppDatabase.clothingTable, c.toMap());
        }
        for (final o in outfitList) {
          await txn.insert(AppDatabase.outfitsTable, o.toMap());
        }
      });

      return RestoreSuccess(
        clothingCount: clothingList.length,
        outfitCount: outfitList.length,
      );
    } catch (e) {
      return RestoreError('恢复失败：$e');
    }
  }
}

// ─── 结果类型 ─────────────────────────────────────────────────────────────────

sealed class BackupResult {
  const BackupResult();
}

class BackupSuccess extends BackupResult {
  const BackupSuccess({
    required this.clothingCount,
    required this.outfitCount,
  });

  final int clothingCount;
  final int outfitCount;
}

class BackupError extends BackupResult {
  const BackupError(this.message);

  final String message;
}

sealed class RestoreResult {
  const RestoreResult();
}

class RestoreSuccess extends RestoreResult {
  const RestoreSuccess({
    required this.clothingCount,
    required this.outfitCount,
  });

  final int clothingCount;
  final int outfitCount;
}

class RestoreError extends RestoreResult {
  const RestoreError(this.message);

  final String message;
}

class RestoreCancelled extends RestoreResult {
  const RestoreCancelled();
}
