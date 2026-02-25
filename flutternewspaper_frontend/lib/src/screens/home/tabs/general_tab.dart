import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../models/news_article.dart';
import '../../../state/news_app_state.dart';
import '../../read/read_article_screen.dart';
import '../widgets/news_list_item.dart';
import '../widgets/top_headline_card.dart';

class GeneralTab extends StatelessWidget {
  const GeneralTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewsAppState>();

    final top = state.topHeadlines();
    final down = state.generalDownList();

    if (state.isLoading && top.isEmpty && down.isEmpty) {
      return const _GeneralShimmer();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<NewsAppState>().refreshCategory('general');
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Text(
              'Top Headlines',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          if (top.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: CarouselSlider.builder(
                itemCount: top.length,
                itemBuilder: (context, index, _) {
                  final a = top[index];
                  return TopHeadlineCard(
                    article: a,
                    onTap: () => _open(context, a),
                  );
                },
                options: CarouselOptions(
                  height: 300,
                  viewportFraction: 0.92,
                  autoPlay: true,
                  autoPlayInterval: const Duration(milliseconds: 3000),
                  enlargeCenterPage: false,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          const SizedBox(height: 6),
          ...down.map(
            (a) => NewsListItem(
              article: a,
              showAbsoluteDate: false,
              onTap: () => _open(context, a),
            ),
          ),
          if (!state.isLoading && top.isEmpty && down.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No news found.')),
            ),
        ],
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

class _GeneralShimmer extends StatelessWidget {
  const _GeneralShimmer();

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey.withAlpha(0x44);
    final highlightColor = Colors.grey.withAlpha(0x22);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            width: 140,
            height: 16,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          ),
        ),
        const SizedBox(height: 12),
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: 280,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < 6; i++)
          Shimmer.fromColors(
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
          ),
      ],
    );
  }
}
