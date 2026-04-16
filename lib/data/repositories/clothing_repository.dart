import 'package:closetmate/data/local/app_database.dart';
import 'package:closetmate/data/models/clothing_model.dart';
import 'package:sqflite/sqflite.dart';

class ClothingRepository {
  ClothingRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<ClothingModel>> getAllClothing() async {
    final db = await _database.database;
    final result = await db.query(
      AppDatabase.clothingTable,
      orderBy: 'updatedAt DESC',
    );
    return result.map(ClothingModel.fromMap).toList();
  }

  Future<ClothingModel?> getClothingById(String id) async {
    final db = await _database.database;
    final result = await db.query(
      AppDatabase.clothingTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return ClothingModel.fromMap(result.first);
  }

  Future<void> insertClothing(ClothingModel clothing) async {
    final db = await _database.database;
    await db.insert(
      AppDatabase.clothingTable,
      clothing.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateClothing(ClothingModel clothing) async {
    final db = await _database.database;
    await db.update(
      AppDatabase.clothingTable,
      clothing.toMap(),
      where: 'id = ?',
      whereArgs: [clothing.id],
    );
  }

  Future<void> deleteClothing(String id) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.clothingTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateStatus(String id, String status) async {
    final db = await _database.database;
    await db.update(
      AppDatabase.clothingTable,
      {
        'status': status,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> incrementWearCount(String id) async {
    final item = await getClothingById(id);
    if (item == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await updateClothing(
      item.copyWith(
        wearCount: item.wearCount + 1,
        lastWornAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> getTotalCount() async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppDatabase.clothingTable}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<double> getTotalSpending() async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT SUM(price) as total FROM ${AppDatabase.clothingTable}',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getCategoryStats() async {
    final db = await _database.database;
    return db.rawQuery(
      'SELECT category, COUNT(*) as count FROM ${AppDatabase.clothingTable} '
      'GROUP BY category ORDER BY count DESC',
    );
  }

  Future<List<ClothingModel>> searchClothing({
    String? keyword,
    String? category,
    String? season,
    String? status,
  }) async {
    final db = await _database.database;

    final conditions = <String>[];
    final args = <Object?>[];

    if (keyword != null && keyword.trim().isNotEmpty) {
      conditions.add('(category LIKE ? OR colors LIKE ? OR styles LIKE ? OR brand LIKE ? OR notes LIKE ?)');
      final like = '%${keyword.trim()}%';
      args.addAll([like, like, like, like, like]);
    }

    if (category != null && category.isNotEmpty) {
      conditions.add('category = ?');
      args.add(category);
    }

    if (season != null && season.isNotEmpty) {
      conditions.add('seasons LIKE ?');
      args.add('%$season%');
    }

    if (status != null && status.isNotEmpty) {
      conditions.add('status = ?');
      args.add(status);
    }

    final result = await db.query(
      AppDatabase.clothingTable,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'updatedAt DESC',
    );

    return result.map(ClothingModel.fromMap).toList();
  }
}
