import '../../models/news_article.dart';

/// In-app mock articles used as a fallback when the network is unreachable.
///
/// Keeping these in code (not assets) ensures the preview works even when
/// DNS/network access to NewsAPI is unavailable.
class MockNewsData {
  MockNewsData._();

  static List<NewsArticle> forCategory(String category) {
    // Keep category-specific variety but also reuse a shared pool.
    final base = <NewsArticle>[
      NewsArticle(
        headLine: 'Preview mode: Welcome to the News App',
        image: null,
        description: 'This is mock data shown when NewsAPI cannot be reached.',
        url: null,
        source: 'MockNews',
        time: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        content: 'Network appears offline or DNS failed. Pull to refresh to try again.',
      ),
      NewsArticle(
        headLine: 'Tip: Add a NEWSAPI_KEY to enable live headlines',
        image: null,
        description: 'Create a .env file and set NEWSAPI_KEY to fetch real articles.',
        url: null,
        source: 'MockNews',
        time: DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        content: 'Once configured, the app will load top headlines from newsapi.org.',
      ),
      NewsArticle(
        headLine: 'Offline-first UX: Saved articles are still available',
        image: null,
        description: 'Bookmarks and saved items work without network.',
        url: null,
        source: 'MockNews',
        time: DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        content: 'Visit the Saved News screen to see locally stored articles.',
      ),
    ];

    // Create a couple of lightweight category-specific items.
    final categoryExtras = <NewsArticle>[
      NewsArticle(
        headLine: 'Mock: $category — headline 1',
        image: null,
        description: 'Sample $category story shown during offline preview.',
        url: null,
        source: 'MockNews',
        time: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        content: 'Pull to refresh when connectivity returns.',
      ),
      NewsArticle(
        headLine: 'Mock: $category — headline 2',
        image: null,
        description: 'Another sample $category story.',
        url: null,
        source: 'MockNews',
        time: DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
        content: 'This content is static and only intended for preview/offline use.',
      ),
    ];

    return <NewsArticle>[...categoryExtras, ...base];
  }
}
