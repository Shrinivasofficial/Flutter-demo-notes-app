import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance =
      DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initializeDatabase();

    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(
      databasePath,
      'student_notes.db',
    );

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ============================================================
  // CREATE
  // ============================================================

  Future<int> createNote({
    required String title,
    required String content,
  }) async {
    final db = await database;

    final now = DateTime.now().toIso8601String();

    return db.insert(
      'notes',
      {
        'title': title,
        'content': content,
        'createdAt': now,
        'updatedAt': now,
      },
    );
  }

  // ============================================================
  // READ
  // ============================================================

  Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await database;

    return db.query(
      'notes',
      orderBy: 'updatedAt DESC',
    );
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<int> updateNote({
    required int id,
    required String title,
    required String content,
  }) async {
    final db = await database;

    return db.update(
      'notes',
      {
        'title': title,
        'content': content,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<int> deleteNote(int id) async {
    final db = await database;

    return db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // INSERT / REPLACE
  // ============================================================

  Future<void> insertOrReplaceNote(
    Map<String, dynamic> note,
  ) async {
    final db = await database;

    await db.insert(
      'notes',
      note,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}