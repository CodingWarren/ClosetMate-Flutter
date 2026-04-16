import 'package:closetmate/data/local/app_database.dart';
import 'package:closetmate/data/models/outfit_model.dart';
import 'package:sqflite/sqflite.dart';

class OutfitRepository {
  OutfitRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<OutfitModel>> getAllOutfits() async {
    final db = await _database.database;
    final result = await db.query(
      AppDatabase.outfitsTable,
      orderBy: 'updatedAt DESC',
    );
    return result.map(OutfitModel.fromMap).toList();
  }

  Future<OutfitModel?> getOutfitById(String id) async {
    final db = await _database.database;
    final result = await db.query(
      AppDatabase.outfitsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return OutfitModel.fromMap(result.first);
  }

  Future<void> insertOutfit(OutfitModel outfit) async {
    final db = await _database.database;
    await db.insert(
      AppDatabase.outfitsTable,
      outfit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateOutfit(OutfitModel outfit) async {
    final db = await _database.database;
    await db.update(
      AppDatabase.outfitsTable,
      outfit.toMap(),
      where: 'id = ?',
      whereArgs: [outfit.id],
    );
  }

  Future<void> deleteOutfit(String id) async {
    final db = await _database.database;
    await db.delete(
      AppDatabase.outfitsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<OutfitModel>> getFavoriteOutfits() async {
    final db = await _database.database;
    final result = await db.query(
      AppDatabase.outfitsTable,
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'updatedAt DESC',
    );
    return result.map(OutfitModel.fromMap).toList();
  }
}
