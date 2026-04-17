import 'dart:convert';
import 'dart:io';

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
/// 备份格式：JSON 文件（closetmate_backup_YYYYMMDD_HHmmss.json）
/// 包含：clothing 列表 + outfits 列表
class BackupService {
  static final ClothingRepository _clothingRepo = ClothingRepository();
  static final OutfitRepository _outfitRepo = OutfitRepository();

  // ─── 备份 ─────────────────────────────────────────────────────────────────

  /// 创建备份 JSON 文件并调用系统分享面板。
  static Future<BackupResult> createAndShareBackup() async {
    try {
      final clothing = await _clothingRepo.getAllClothing();
      final outfits = await _outfitRepo.getAllOutfits();

      final data = {
        'version': 1,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'clothing': clothing.map((c) => c.toMap()).toList(),
        'outfits': outfits.map((o) => o.toMap()).toList(),
      };

      final json = const JsonEncoder.withIndent('  ').convert(data);

      final cacheDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File(p.join(cacheDir.path, 'closetmate_backup_$timestamp.json'));
      await file.writeAsString(json, encoding: utf8);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'ClosetMate 衣橱数据备份',
          text: 'ClosetMate 衣橱数据备份文件',
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

  /// 从指定文件路径恢复数据。
  static Future<RestoreResult> restoreFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return const RestoreError('备份文件不存在');
      }

      final json = await file.readAsString(encoding: utf8);
      final data = jsonDecode(json) as Map<String, dynamic>;

      final version = data['version'] as int? ?? 0;
      if (version < 1) {
        return const RestoreError('备份文件格式不兼容');
      }

      final clothingList = (data['clothing'] as List<dynamic>?)
              ?.map((e) => ClothingModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];

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
