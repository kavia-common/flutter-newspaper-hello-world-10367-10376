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
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw NewsApiException(
        'Missing NEWSAPI_KEY. Create a .env file and set NEWSAPI_KEY (see .env.example).',
      );
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

  void close() {
    _httpClient.close(force: true);
  }
}
