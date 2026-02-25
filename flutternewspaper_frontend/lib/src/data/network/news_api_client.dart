import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/news_article.dart';

class NewsApiException implements Exception {
  NewsApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'NewsApiException(statusCode: $statusCode, message: $message)';
}

class NewsApiClient {
  NewsApiClient({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  static const String _host = 'newsapi.org';
  static const String _path = '/v2/top-headlines';

  Future<List<NewsArticle>> fetchTopHeadlines({
    required String country,
    required String? category,
  }) async {
    final apiKey = dotenv.env['NEWSAPI_KEY'];

    // If the key is missing, do NOT throw. Preview environments often don't ship .env.
    // Instead, return mock content so the app remains usable and the UI can render.
    if (apiKey == null || apiKey.trim().isEmpty) {
      return _mockArticles(country: country, category: category);
    }

    final uri = Uri.https(_host, _path, <String, String>{
      'country': country,
      if (category != null && category.isNotEmpty) 'category': category,
      'apiKey': apiKey,
    });

    final request = await _httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    final decoded = jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? (decoded['message']?.toString() ?? 'Request failed') : 'Request failed';
      throw NewsApiException(message, statusCode: response.statusCode);
    }

    if (decoded is! Map) {
      throw NewsApiException('Unexpected response format');
    }

    final articles = decoded['articles'];
    if (articles is! List) return <NewsArticle>[];

    return articles
        .whereType<Map>()
        .map((e) => NewsArticle.fromNewsApiJson(Map<String, Object?>.from(e)))
        .where((a) => a.headLine.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<NewsArticle> _mockArticles({required String country, required String? category}) {
    final cat = (category == null || category.trim().isEmpty) ? 'general' : category.trim();

    final now = DateTime.now().toUtc();
    final ts = now.toIso8601String();

    return <NewsArticle>[
      NewsArticle(
        headLine: 'Setup required: add NEWSAPI_KEY to .env to fetch real headlines',
        image: null,
        description:
            'Preview mode is using mock data because NEWSAPI_KEY is not set. '
            'Create a .env file (see .env.example) and add NEWSAPI_KEY=...',
        url: null,
        source: 'App Setup',
        time: ts,
        content:
            'To enable live news: create a .env file at the Flutter project root and set NEWSAPI_KEY. '
            'You can also set NEWSAPI_COUNTRY (optional).',
      ),
      NewsArticle(
        headLine: 'Mock headline ($cat) — $country',
        image: null,
        description: 'This is placeholder content shown when the NewsAPI key is missing.',
        url: null,
        source: 'Mock Data',
        time: ts,
        content:
            'Once configured, the app will fetch top headlines from NewsAPI.org for the selected category.',
      ),
      NewsArticle(
        headLine: 'Mock headline 2 ($cat) — $country',
        image: null,
        description: 'UI preview article for layout/testing.',
        url: null,
        source: 'Mock Data',
        time: ts,
        content: 'Use this app preview without needing environment setup.',
      ),
    ];
  }

  void close() {
    _httpClient.close(force: true);
  }
}
