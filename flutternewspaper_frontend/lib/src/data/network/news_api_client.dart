import 'dart:async';
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

    try {
      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();

      final decoded = jsonDecode(body);

      // NewsAPI can return:
      // - HTTP non-2xx with {"message": "..."}
      // - HTTP 200 with {"status":"error","message":"..."}
      // So we check both HTTP status and JSON status.
      Map<String, Object?>? decodedMap;
      if (decoded is Map) {
        decodedMap = Map<String, Object?>.from(decoded);
      }

      final newsApiStatus = decodedMap?['status']?.toString();
      final newsApiMessage = decodedMap?['message']?.toString();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NewsApiException(
          'NewsAPI error (HTTP ${response.statusCode}): ${newsApiMessage ?? 'Request failed'}\nURL: $uri',
          statusCode: response.statusCode,
        );
      }

      if (decodedMap == null) {
        final snippet = body.length > 400 ? body.substring(0, 400) : body;
        throw NewsApiException(
          'Unexpected response format from NewsAPI (expected JSON object).\nURL: $uri\nBody: $snippet',
          statusCode: response.statusCode,
        );
      }

      if (newsApiStatus != null && newsApiStatus.toLowerCase() != 'ok') {
        throw NewsApiException(
          'NewsAPI error: ${newsApiMessage ?? 'Unknown error'}\nURL: $uri',
          statusCode: response.statusCode,
        );
      }

      final articles = decodedMap['articles'];
      if (articles is! List) return <NewsArticle>[];

      // IMPORTANT: jsonDecode returns Map<String, dynamic> per item.
      // Using whereType<Map>() filters out all entries (because Map<String,dynamic> is not Map<dynamic,dynamic>),
      // causing the UI to show "No news found".
      return articles
          .whereType<Map<String, dynamic>>()
          .map((e) => NewsArticle.fromNewsApiJson(Map<String, Object?>.from(e)))
          .where((a) => a.headLine.trim().isNotEmpty)
          .toList(growable: false);
    } on SocketException {
      // DNS failure / offline / captive portal, etc.
      throw NewsApiException(
        'Network unavailable (DNS/connection error). Showing offline preview data.',
      );
    } on HttpException {
      throw NewsApiException(
        'Network error while contacting NewsAPI. Showing offline preview data.',
      );
    } on IOException {
      // Covers a broader class of low-level network/IO errors.
      throw NewsApiException(
        'Network I/O error while contacting NewsAPI. Showing offline preview data.',
      );
    } on FormatException catch (e) {
      throw NewsApiException(
        'Unexpected/invalid JSON from NewsAPI: ${e.message}. Showing offline preview data.',
      );
    } on TimeoutException {
      throw NewsApiException(
        'NewsAPI request timed out. Showing offline preview data.',
      );
    } catch (e) {
      // Safety net: never let unknown exceptions from HttpClient crash preview.
      throw NewsApiException(
        'Unexpected error while contacting NewsAPI: $e. Showing offline preview data.',
      );
    }
  }

  void close() {
    _httpClient.close(force: true);
  }
}
