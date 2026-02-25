import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/news_article.dart';

/// Persistence layer for saved/bookmarked articles.
///
/// In some preview/test environments (and on web), `sqflite` is unavailable.
/// To prevent a blank UI, this class supports a safe in-memory fallback.
class SavedNewsDb {
  Database? _db;

  bool _useMemoryFallback = false;
  final Map<String, NewsArticle> _memoryStore = <String, NewsArticle>{};

  static const _dbFileName = 'LOGIN_DATABASE.db'; // Kotlin parity (Constants.DATABASE_NAME)
  static const _table = 'News_Table';

  // PUBLIC_INTERFACE
  /// Initializes the underlying database if available.
  ///
  /// If initialization fails (e.g., sqflite not supported in preview/web),
  /// this instance transparently switches to an in-memory fallback so the app
  /// can still render and function.
  Future<void> ensureInitialized() async {
    if (_db != null || _useMemoryFallback) return;

    try {
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
    } catch (_) {
      // Fallback: keep the app usable in preview/test/web.
      _useMemoryFallback = true;
      _db = null;
    }
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('DB not initialized. Call ensureInitialized() first.');
    }
    return db;
  }

  // PUBLIC_INTERFACE
  /// Saves or updates an article.
  Future<void> upsert(NewsArticle article) async {
    if (_useMemoryFallback) {
      _memoryStore[article.headLine] = article;
      return;
    }

    await _database.insert(
      _table,
      article.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // PUBLIC_INTERFACE
  /// Deletes an article by headline.
  Future<void> deleteByHeadline(String headline) async {
    if (_useMemoryFallback) {
      _memoryStore.remove(headline);
      return;
    }

    await _database.delete(_table, where: 'headline = ?', whereArgs: <Object>[headline]);
  }

  // PUBLIC_INTERFACE
  /// Returns all saved articles.
  Future<List<NewsArticle>> getAll() async {
    if (_useMemoryFallback) {
      final items = _memoryStore.values.toList(growable: false);
      // Keep ordering roughly consistent (newest first) using ISO timestamps when available.
      items.sort((a, b) => (b.time ?? '').compareTo(a.time ?? ''));
      return items;
    }

    final rows = await _database.query(_table, orderBy: 'time DESC');
    return rows.map((m) => NewsArticle.fromDbMap(m)).toList(growable: false);
  }
}
