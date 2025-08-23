import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/clothing_item.dart';
import '../models/saved_outfit.dart';

class DatabaseHelper {
  static const String _databaseName = "combiner_ai.db";
  static const int _databaseVersion = 3; // Version'ı artır

  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();
  
  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'clothing_database.db');
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Clothing items tablosu - createdAt kaldırıldı
  Future<void> _createClothingItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE clothing_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        description TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        
        -- AI ETIKETLERI --
        ai_analyzed INTEGER DEFAULT 0,
        ai_colors TEXT,
        ai_patterns TEXT,
        ai_style TEXT,
        ai_season TEXT,
        ai_formality TEXT,
        ai_material TEXT,
        ai_confidence INTEGER DEFAULT 0,
        ai_analysis_date TEXT
      )
    ''');
  }

  // Saved outfits tablosu - createdAt kaldırıldı
  Future<void> _createSavedOutfitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE saved_outfits(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        top_item_id INTEGER,
        bottom_item_id INTEGER,
        shoes_item_id INTEGER,
        accessory_item_id INTEGER,
        FOREIGN KEY (top_item_id) REFERENCES clothing_items (id),
        FOREIGN KEY (bottom_item_id) REFERENCES clothing_items (id),
        FOREIGN KEY (shoes_item_id) REFERENCES clothing_items (id),
        FOREIGN KEY (accessory_item_id) REFERENCES clothing_items (id)
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createClothingItemsTable(db);
    await _createSavedOutfitsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // createdAt sütununu kaldır
      await db.execute('DROP TABLE IF EXISTS clothing_items');
      await db.execute('DROP TABLE IF EXISTS saved_outfits');
      await _createClothingItemsTable(db);
      await _createSavedOutfitsTable(db);
    }
  }

  /// Kıyafet öğesi ekle
  Future<int> insertClothingItem(ClothingItem item) async {
    final db = await database;
    return await db.insert(
      'clothing_items',
      {
        'name': item.name,
        'category': item.category,
        'imagePath': item.imagePath,
        'description': item.description,
        'is_favorite': item.isFavorite ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Tüm kıyafet öğelerini getir
  Future<List<ClothingItem>> getAllClothingItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('clothing_items');

    return List.generate(maps.length, (i) {
      return ClothingItem(
        id: maps[i]['id'],
        name: maps[i]['name'],
        category: maps[i]['category'],
        imagePath: maps[i]['imagePath'],
        description: maps[i]['description'],
        isFavorite: maps[i]['is_favorite'] == 1,
      );
    });
  }

  /// Favori kıyafetleri getir
  Future<List<ClothingItem>> getFavoriteClothingItems() async {
    final db = await database;
    final maps = await db.query(
      'clothing_items',
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
    );

    return List.generate(maps.length, (i) {
      return ClothingItem.fromMap(maps[i]);
    });
  }

  /// Kıyafet öğesini güncelle
  Future<int> updateClothingItem(ClothingItem item) async {
    final db = await database;
    return await db.update(
      'clothing_items',
      {
        'name': item.name,
        'category': item.category,
        'imagePath': item.imagePath,
        'description': item.description,
        'is_favorite': item.isFavorite ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Favori durumunu güncelle
  Future<int> updateFavoriteStatus(int id, bool isFavorite) async {
    final db = await database;
    return await db.update(
      'clothing_items',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Kıyafet öğesini sil
  Future<int> deleteClothingItem(int id) async {
    final db = await database;
    return await db.delete(
      'clothing_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Kategori ID'sine göre kıyafetleri getir
  Future<List<ClothingItem>> getClothingItemsByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'clothing_items',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'id DESC',
    );

    return List.generate(maps.length, (i) {
      return ClothingItem.fromMap(maps[i]);
    });
  }

  /// Mevcut kategorileri getir (string listesi)
  Future<List<String>> getCategories() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM clothing_items ORDER BY category ASC'
    );
    
    return result.map((row) => row['category'] as String).toList();
  }

  /// Database'i kapat
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// Database'i sıfırla (File sistemi ile)
  Future<void> deleteDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'clothing_database.db');
    
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    _database = null;
  }

  /// Mevcut veritabanını kontrol et ve gerekirse güncelle
  Future<void> checkAndUpdateDatabase() async {
    final db = await database;
    final version = await db.getVersion();
    print('Mevcut database version: $version');
    
    if (version < _databaseVersion) {
      print('Database güncelleniyor...');
      await db.close();
      
      // Veritabanını sil ve yeniden oluştur
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, 'clothing_database.db');
      
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Yeni veritabanını oluştur
      _database = null;
      await database;
      print('Database başarıyla güncellendi');
    }
  }

  // ========== SAVED OUTFITS ========== //

  // Kombin kaydetme
  Future<int> saveOutfit(SavedOutfit outfit) async {
    final db = await database;
    return await db.insert(
      'saved_outfits',
      {
        'name': outfit.name,
        'top_item_id': outfit.topItemId,
        'bottom_item_id': outfit.bottomItemId,
        'shoes_item_id': outfit.shoesItemId,
        'accessory_item_id': outfit.accessoryItemId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Kaydedilen kombinleri getirme
  Future<List<SavedOutfit>> getSavedOutfits() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('saved_outfits');

    return List.generate(maps.length, (i) {
      return SavedOutfit(
        id: maps[i]['id'],
        name: maps[i]['name'],
        topItemId: maps[i]['top_item_id'],
        bottomItemId: maps[i]['bottom_item_id'],
        shoesItemId: maps[i]['shoes_item_id'],
        accessoryItemId: maps[i]['accessory_item_id'],
      );
    });
  }

  // Kombin silme
  Future<void> deleteOutfit(int id) async {
    final db = await database;
    await db.delete('saved_outfits', where: 'id = ?', whereArgs: [id]);
  }

  // Kombin yükleme (ID'lerden kıyafetleri getirme)
  Future<Map<String, ClothingItem?>> loadOutfitItems(SavedOutfit outfit) async {
    final db = await database;
    
    ClothingItem? topItem, bottomItem, shoesItem, accessoryItem;
    
    if (outfit.topItemId != null) {
      final result = await db.query('clothing_items', where: 'id = ?', whereArgs: [outfit.topItemId]);
      if (result.isNotEmpty) topItem = ClothingItem.fromMap(result.first);
    }
    
    if (outfit.bottomItemId != null) {
      final result = await db.query('clothing_items', where: 'id = ?', whereArgs: [outfit.bottomItemId]);
      if (result.isNotEmpty) bottomItem = ClothingItem.fromMap(result.first);
    }
    
    if (outfit.shoesItemId != null) {
      final result = await db.query('clothing_items', where: 'id = ?', whereArgs: [outfit.shoesItemId]);
      if (result.isNotEmpty) shoesItem = ClothingItem.fromMap(result.first);
    }
    
    if (outfit.accessoryItemId != null) {
      final result = await db.query('clothing_items', where: 'id = ?', whereArgs: [outfit.accessoryItemId]);
      if (result.isNotEmpty) accessoryItem = ClothingItem.fromMap(result.first);
    }
    
    return {
      'top': topItem,
      'bottom': bottomItem,
      'shoes': shoesItem,
      'accessory': accessoryItem,
    };
  }

  /// Veritabanını tamamen sıfırla ve yeniden oluştur
Future<void> resetDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  final path = join(directory.path, 'clothing_database.db');
  
  // Mevcut bağlantıyı kapat
  if (_database != null) {
    await _database!.close();
    _database = null;
  }
  
  // Dosyayı sil
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      print('✅ Eski veritabanı silindi');
    }
  } catch (e) {
    print('Veritabanı silinirken hata: $e');
  }
  
  // Yeni veritabanını oluştur
  _database = await _initDatabase();
  print('✅ Yeni veritabanı oluşturuldu');
}

  // AI analiz durumunu kontrol et
  Future<List<ClothingItem>> getUnanalyzedItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clothing_items',
      where: 'ai_analyzed = ? OR ai_analyzed IS NULL',
      whereArgs: [0],
    );
    
    return List.generate(maps.length, (i) => ClothingItem.fromMap(maps[i]));
  }

  // AI analiz sonucunu kaydet
  Future<void> updateAIAnalysis(int id, Map<String, dynamic> analysis) async {
    final db = await database;
    await db.update(
      'clothing_items',
      {
        'ai_analyzed': 1,
        'ai_colors': analysis['colors'],
        'ai_patterns': analysis['patterns'],
        'ai_style': analysis['style'],
        'ai_season': analysis['season'],
        'ai_formality': analysis['formality'],
        'ai_material': analysis['material'],
        'ai_confidence': analysis['confidence'],
        'ai_analysis_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
