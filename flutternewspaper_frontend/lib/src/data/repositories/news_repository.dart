import '../../models/news_article.dart';
import '../network/news_api_client.dart';

class NewsRepository {
  NewsRepository({NewsApiClient? apiClient}) : _apiClient = apiClient ?? NewsApiClient();

  final NewsApiClient _apiClient;

  Future<List<NewsArticle>> getNews({
    required String country,
    required String category,
  }) {
    return _apiClient.fetchTopHeadlines(country: country, category: category);
  }
}
