import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/news_article.dart';

class SavedNewsDb {
  Database? _db;

  static const _dbFileName = 'LOGIN_DATABASE.db'; // Kotlin parity (Constants.DATABASE_NAME)
  static const _table = 'News_Table';

  Future<void> ensureInitialized() async {
    if (_db != null) return;

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, _dbFileName);

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
CREATE TABLE $_table (
  headline TEXT PRIMARY KEY,
  imgurl TEXT,
  description TEXT,
  url TEXT,
  source TEXT,
  time TEXT,
  content TEXT
)
''');
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('DB not initialized. Call ensureInitialized() first.');
    }
    return db;
  }

  Future<void> upsert(NewsArticle article) async {
    await _database.insert(
      _table,
      article.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteByHeadline(String headline) async {
    await _database.delete(_table, where: 'headline = ?', whereArgs: <Object>[headline]);
  }

  Future<List<NewsArticle>> getAll() async {
    final rows = await _database.query(_table, orderBy: 'time DESC');
    return rows.map((m) => NewsArticle.fromDbMap(m)).toList(growable: false);
  }
}
