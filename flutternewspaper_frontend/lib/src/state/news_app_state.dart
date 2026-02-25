import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/constants.dart';
import '../data/db/saved_news_db.dart';
import '../data/network/news_api_client.dart';
import '../data/repositories/news_repository.dart';
import '../models/news_article.dart';

class NewsAppState extends ChangeNotifier {
  NewsAppState({
    required SavedNewsDb db,
    NewsRepository? repository,
  })  : _db = db,
        _repository = repository ?? NewsRepository();

  final SavedNewsDb _db;
  final NewsRepository _repository;

  bool isLoading = true;
  String? errorMessage;

  final Map<String, List<NewsArticle>> _byCategory = <String, List<NewsArticle>>{};
  List<NewsArticle> saved = <NewsArticle>[];

  String get _country => (dotenv.env['NEWSAPI_COUNTRY']?.trim().isNotEmpty ?? false)
      ? dotenv.env['NEWSAPI_COUNTRY']!.trim()
      : 'in';

  // PUBLIC_INTERFACE
  /// Initializes the application state: loads saved news and fetches remote categories.
  Future<void> init() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    // Load saved items first (fast)
    saved = await _db.getAll();

    try {
      // Kotlin app triggers all requests up-front.
      await Future.wait(<Future<void>>[
        _fetchCategory(AppConstants.general),
        _fetchCategory(AppConstants.business),
        _fetchCategory(AppConstants.entertainment),
        _fetchCategory(AppConstants.science),
        _fetchCategory(AppConstants.sports),
        _fetchCategory(AppConstants.technology),
        _fetchCategory(AppConstants.health),
      ]);
    } on NewsApiException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<NewsArticle> articlesFor(String category) => _byCategory[category] ?? const <NewsArticle>[];

  List<NewsArticle> topHeadlines() {
    final general = articlesFor(AppConstants.general);
    if (general.length <= AppConstants.topHeadlinesCount) return general;
    return general.take(AppConstants.topHeadlinesCount).toList(growable: false);
  }

  List<NewsArticle> generalDownList() {
    final general = articlesFor(AppConstants.general);
    if (general.length <= AppConstants.topHeadlinesCount) return const <NewsArticle>[];
    return general.skip(AppConstants.topHeadlinesCount).toList(growable: false);
  }

  // PUBLIC_INTERFACE
  /// Refreshes a single category from the network.
  Future<void> refreshCategory(String category) async {
    errorMessage = null;
    notifyListeners();
    try {
      await _fetchCategory(category);
    } on NewsApiException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> _fetchCategory(String category) async {
    final list = await _repository.getNews(country: _country, category: category);
    _byCategory[category] = list;
  }

  bool isSaved(String headline) => saved.any((a) => a.headLine == headline);

  // PUBLIC_INTERFACE
  /// Saves an article to local database (upsert), then refreshes saved list.
  Future<void> saveArticle(NewsArticle article) async {
    await _db.upsert(article);
    saved = await _db.getAll();
    notifyListeners();
  }

  // PUBLIC_INTERFACE
  /// Deletes a saved article by its headline, then refreshes saved list.
  Future<void> deleteSavedByHeadline(String headline) async {
    await _db.deleteByHeadline(headline);
    saved = await _db.getAll();
    notifyListeners();
  }
}
