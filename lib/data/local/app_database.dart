import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String databaseName = 'closetmate.db';
  static const int databaseVersion = 1;

  static const String clothingTable = 'clothing';
  static const String outfitsTable = 'outfits';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, databaseName);

    return openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $clothingTable (
        id TEXT PRIMARY KEY,
        imageUris TEXT NOT NULL,
        category TEXT NOT NULL,
        seasons TEXT NOT NULL,
        colors TEXT NOT NULL,
        styles TEXT NOT NULL,
        brand TEXT NOT NULL DEFAULT '',
        price REAL NOT NULL DEFAULT 0,
        purchaseChannel TEXT NOT NULL DEFAULT '',
        purchaseDate TEXT NOT NULL DEFAULT '',
        storageLocation TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT '正常',
        wearCount INTEGER NOT NULL DEFAULT 0,
        lastWornAt INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        ownerId TEXT NOT NULL DEFAULT 'default',
        isShared INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0,
        aiTags TEXT NOT NULL DEFAULT '',
        imageProcessed INTEGER NOT NULL DEFAULT 0,
        originalImageUri TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE $outfitsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        topId TEXT NOT NULL DEFAULT '',
        bottomId TEXT NOT NULL DEFAULT '',
        outerId TEXT NOT NULL DEFAULT '',
        shoesId TEXT NOT NULL DEFAULT '',
        bagId TEXT NOT NULL DEFAULT '',
        accessoryIds TEXT NOT NULL DEFAULT '',
        sceneTags TEXT NOT NULL DEFAULT '',
        isFavorite INTEGER NOT NULL DEFAULT 0,
        wearCount INTEGER NOT NULL DEFAULT 0,
        lastWornAt INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        ownerId TEXT NOT NULL DEFAULT 'default',
        createdAt INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0,
        userFeedback TEXT NOT NULL DEFAULT 'NONE',
        isAiGenerated INTEGER NOT NULL DEFAULT 0,
        aiReason TEXT NOT NULL DEFAULT ''
      )
    ''');
  }
}
