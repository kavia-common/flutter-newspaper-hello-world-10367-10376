import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/constants.dart';
import '../data/db/saved_news_db.dart';
import '../data/mock/mock_news_data.dart';
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

  /// When set, the UI can show a friendly banner/message to the user.
  /// The app will still render using cached/saved/mock data where possible.
  String? errorMessage;

  final Map<String, List<NewsArticle>> _byCategory = <String, List<NewsArticle>>{};
  List<NewsArticle> saved = <NewsArticle>[];

  String get _country => (dotenv.env['NEWSAPI_COUNTRY']?.trim().isNotEmpty ?? false)
      ? dotenv.env['NEWSAPI_COUNTRY']!.trim()
      : 'in';

  // PUBLIC_INTERFACE
  /// Initializes the application state: loads saved news and fetches remote categories.
  ///
  /// If NewsAPI is unreachable (DNS/offline), we fall back to mock data so the
  /// preview remains usable and the UI does not crash.
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
      // Populate with mock data so UI still renders.
      errorMessage = e.message;
      _useMockForAllCategories();
    } catch (e) {
      errorMessage = e.toString();
      _useMockForAllCategories();
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
  ///
  /// On network errors, keeps the current list and sets an error message. If the
  /// list is empty (first load), mock data is used as a preview fallback.
  Future<void> refreshCategory(String category) async {
    errorMessage = null;
    notifyListeners();

    try {
      await _fetchCategory(category);
    } on NewsApiException catch (e) {
      errorMessage = e.message;

      // Only inject mock data if there's nothing to show.
      if (articlesFor(category).isEmpty) {
        _byCategory[category] = MockNewsData.forCategory(category);
      }
    } catch (e) {
      errorMessage = e.toString();
      if (articlesFor(category).isEmpty) {
        _byCategory[category] = MockNewsData.forCategory(category);
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> _fetchCategory(String category) async {
    final list = await _repository.getNews(country: _country, category: category);
    _byCategory[category] = list;
  }

  void _useMockForAllCategories() {
    _byCategory[AppConstants.general] = MockNewsData.forCategory(AppConstants.general);
    _byCategory[AppConstants.business] = MockNewsData.forCategory(AppConstants.business);
    _byCategory[AppConstants.entertainment] = MockNewsData.forCategory(AppConstants.entertainment);
    _byCategory[AppConstants.science] = MockNewsData.forCategory(AppConstants.science);
    _byCategory[AppConstants.sports] = MockNewsData.forCategory(AppConstants.sports);
    _byCategory[AppConstants.technology] = MockNewsData.forCategory(AppConstants.technology);
    _byCategory[AppConstants.health] = MockNewsData.forCategory(AppConstants.health);
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
