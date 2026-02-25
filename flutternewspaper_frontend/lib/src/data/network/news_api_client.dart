import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  String _maskApiKeyInUrl(Uri uri) {
    final qp = Map<String, String>.from(uri.queryParameters);
    if (qp.containsKey('apiKey')) {
      qp['apiKey'] = '***';
    }
    return uri.replace(queryParameters: qp).toString();
  }

  /// Attempts to extract a helpful NewsAPI error message from a decoded JSON payload.
  String? _extractNewsApiErrorMessage(Object? decoded) {
    if (decoded is Map) {
      final map = Map<String, Object?>.from(decoded);
      final msg = map['message']?.toString();
      if (msg != null && msg.trim().isNotEmpty) return msg.trim();

      // Some proxies/providers might nest error details.
      final err = map['error'];
      if (err is Map) {
        final errMap = Map<String, Object?>.from(err);
        final errMsg = errMap['message']?.toString();
        if (errMsg != null && errMsg.trim().isNotEmpty) return errMsg.trim();
      }
    }
    return null;
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(message);
    }
  }

  Future<List<NewsArticle>> fetchTopHeadlines({
    required String country,
    required String? category,
  }) async {
    final apiKey = dotenv.env['NEWSAPI_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw NewsApiException(
        'Missing NEWSAPI_KEY. Create a .env file and set NEWSAPI_KEY.',
      );
    }

    final uri = Uri.https(_host, _path, <String, String>{
      'country': country,
      if (category != null && category.isNotEmpty) 'category': category,
      'apiKey': apiKey,
    });

    try {
      _debugLog('NewsApiClient: GET ${_maskApiKeyInUrl(uri)}');

      final request = await _httpClient.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();

      final snippet = body.length > 400 ? body.substring(0, 400) : body;
      _debugLog('NewsApiClient: status=${response.statusCode} bodySnippet=$snippet');

      Object? decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException catch (e) {
        throw NewsApiException(
          'Invalid JSON from NewsAPI: ${e.message}\nURL: ${_maskApiKeyInUrl(uri)}\nBody: $snippet',
          statusCode: response.statusCode,
        );
      }

      // NewsAPI can return:
      // - HTTP non-2xx with {"message": "..."}
      // - HTTP 200 with {"status":"error","message":"..."}
      // So we check both HTTP status and JSON status.
      final decodedMap = decoded is Map ? Map<String, Object?>.from(decoded) : null;
      final newsApiStatus = decodedMap?['status']?.toString();
      final newsApiMessage = _extractNewsApiErrorMessage(decoded);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NewsApiException(
          'NewsAPI error (HTTP ${response.statusCode}): ${newsApiMessage ?? 'Request failed'}\nURL: ${_maskApiKeyInUrl(uri)}',
          statusCode: response.statusCode,
        );
      }

      if (decodedMap == null) {
        throw NewsApiException(
          'Unexpected response format from NewsAPI (expected JSON object).\nURL: ${_maskApiKeyInUrl(uri)}\nBody: $snippet',
          statusCode: response.statusCode,
        );
      }

      // If NewsAPI responds with status=error (even on HTTP 200), surface it.
      if (newsApiStatus != null && newsApiStatus.toLowerCase() != 'ok') {
        throw NewsApiException(
          'NewsAPI error: ${newsApiMessage ?? 'Unknown error'}\nURL: ${_maskApiKeyInUrl(uri)}',
          statusCode: response.statusCode,
        );
      }

      final articles = decodedMap['articles'];
      if (articles is! List) {
        // If NewsAPI returns ok but no articles, return empty list and let UI show "No news found".
        return <NewsArticle>[];
      }

      // Robust per-item parsing: avoid type-filter pitfalls and ignore malformed entries
      // so one bad entry doesn't empty the whole list.
      final parsed = <NewsArticle>[];
      for (final item in articles) {
        if (item is Map) {
          final article = NewsArticle.fromNewsApiJson(Map<String, Object?>.from(item));
          if (article.headLine.trim().isNotEmpty) {
            parsed.add(article);
          }
        }
      }
      return parsed;
    } on SocketException catch (e) {
      throw NewsApiException(
        'Network unavailable (DNS/connection error): ${e.message}',
      );
    } on HttpException catch (e) {
      throw NewsApiException(
        'Network error while contacting NewsAPI: ${e.message}',
      );
    } on IOException catch (e) {
      throw NewsApiException(
        'Network I/O error while contacting NewsAPI: $e',
      );
    } on TimeoutException {
      throw NewsApiException(
        'NewsAPI request timed out.\nURL: ${_maskApiKeyInUrl(uri)}',
      );
    } catch (e) {
      // Safety net: never let unknown exceptions from HttpClient crash preview.
      throw NewsApiException(
        'Unexpected error while contacting NewsAPI: $e\nURL: ${_maskApiKeyInUrl(uri)}',
      );
    }
  }

  void close() {
    _httpClient.close(force: true);
  }
}
