import 'package:flutter/foundation.dart';

@immutable
class NewsArticle {
  const NewsArticle({
    required this.headLine,
    required this.image,
    required this.description,
    required this.url,
    required this.source,
    required this.time,
    required this.content,
  });

  /// Kotlin parity: used as primary key in Room (headline is the unique id).
  final String headLine;

  final String? image;
  final String? description;
  final String? url;
  final String? source;

  /// NewsAPI ISO date string (publishedAt).
  final String? time;

  final String? content;

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'headline': headLine,
      'imgurl': image,
      'description': description,
      'url': url,
      'source': source,
      'time': time,
      'content': content,
    };
  }

  static NewsArticle fromDbMap(Map<String, Object?> map) {
    return NewsArticle(
      headLine: (map['headline'] as String?) ?? '',
      image: map['imgurl'] as String?,
      description: map['description'] as String?,
      url: map['url'] as String?,
      source: map['source'] as String?,
      time: map['time'] as String?,
      content: map['content'] as String?,
    );
  }

  static NewsArticle fromNewsApiJson(Map<String, Object?> json) {
    final source = json['source'];
    String? sourceName;
    if (source is Map) {
      sourceName = source['name']?.toString();
    }

    return NewsArticle(
      headLine: json['title']?.toString() ?? '',
      image: json['urlToImage']?.toString(),
      description: json['description']?.toString(),
      url: json['url']?.toString(),
      source: sourceName,
      time: json['publishedAt']?.toString(),
      content: json['content']?.toString(),
    );
  }
}
