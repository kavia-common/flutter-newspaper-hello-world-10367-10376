import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/news_article.dart';

class TopHeadlineCard extends StatelessWidget {
  const TopHeadlineCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: _HeroImage(url: article.image),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                height: 70,
                child: Text(
                  article.headLine,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return Container(
        color: Colors.grey.withAlpha(0x22),
        child: const Center(child: Icon(Icons.image_outlined, size: 48)),
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
        child: const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
      ),
    );
  }
}
