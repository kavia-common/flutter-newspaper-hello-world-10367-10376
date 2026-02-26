import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/news_article.dart';

class NewsListItem extends StatelessWidget {
  const NewsListItem({
    super.key,
    required this.article,
    required this.onTap,
    required this.showAbsoluteDate,
  });

  final NewsArticle article;
  final VoidCallback onTap;

  /// Kotlin parity:
  /// - SavedNewsActivity shows absolute date (YYYY-MM-DD extracted)
  /// - Main feed shows "x hour ago"
  final bool showAbsoluteDate;

  @override
  Widget build(BuildContext context) {
    final title = article.headLine;
    final timeText = _formatTime(article.time, absolute: showAbsoluteDate);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: SizedBox(
          height: 120,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: _ArticleImage(url: article.image),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            timeText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? iso, {required bool absolute}) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      if (absolute) {
        // Kotlin used substring before 'T'
        return ' ${DateFormat('yyyy-MM-dd').format(dt)}';
      }
      final diff = DateTime.now().difference(dt);
      final hours = diff.inHours;
      if (hours <= 0) return ' 0 hour ago';
      return ' $hours hour ago';
    } catch (_) {
      return '';
    }
  }
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return Container(
        color: Colors.grey.withAlpha(0x22),
        child: const Icon(Icons.image_outlined, size: 36),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Colors.grey.withAlpha(0x22),
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.withAlpha(0x22),
        child: const Icon(Icons.broken_image_outlined, size: 36),
      ),
    );
  }
}
