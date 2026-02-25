import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../models/news_article.dart';
import '../../../state/news_app_state.dart';
import '../../read/read_article_screen.dart';
import '../widgets/news_list_item.dart';

class CategoryTab extends StatelessWidget {
  const CategoryTab({
    super.key,
    required this.category,
  });

  final String category;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewsAppState>();
    final articles = state.articlesFor(category);

    if (state.isLoading && articles.isEmpty) {
      return const _ShimmerList();
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Note: no context usage after await (we only call state method)
        await context.read<NewsAppState>().refreshCategory(category);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final a = articles[index];
          return NewsListItem(
            article: a,
            showAbsoluteDate: false,
            onTap: () => _open(context, a),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, NewsArticle article) {
    Navigator.of(context).pushNamed(
      ReadArticleScreen.routeName,
      arguments: ReadArticleArgs(article: article),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey.withAlpha(0x44);
    final highlightColor = Colors.grey.withAlpha(0x22);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: 8,
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(width: 120, height: 90, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(height: 14, width: 220, color: Colors.white),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(height: 12, width: 90, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
