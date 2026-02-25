import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/news_article.dart';
import '../../state/news_app_state.dart';
import '../home/widgets/news_list_item.dart';
import '../read/read_article_screen.dart';

class SavedNewsScreen extends StatelessWidget {
  const SavedNewsScreen({super.key});

  static const routeName = '/saved';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewsAppState>();
    final saved = state.saved;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved News'),
      ),
      body: saved.isEmpty
          ? const Center(child: Text('No saved news.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: saved.length,
              itemBuilder: (context, index) {
                final a = saved[index];
                return GestureDetector(
                  onLongPress: () => _confirmDelete(context, a),
                  child: NewsListItem(
                    article: a,
                    showAbsoluteDate: true,
                    onTap: () => _open(context, a),
                  ),
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

  Future<void> _confirmDelete(BuildContext context, NewsArticle article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alert!'),
        content: const Text('Delete this News?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await context.read<NewsAppState>().deleteSavedByHeadline(article.headLine);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted!')));
  }
}
