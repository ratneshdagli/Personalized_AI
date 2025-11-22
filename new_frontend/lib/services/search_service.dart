import '../data/repositories/feed_repository.dart';
import '../data/schema/feed_item.dart';

class SearchService {
  final FeedRepository _feedRepository;

  SearchService(this._feedRepository);

  Future<List<FeedItem>> search(String query) async {
    if (query.isEmpty) return [];
    
    // Basic text search using Isar's filter
    // Future enhancement: Semantic search using embeddings
    return await _feedRepository.searchFeed(query);
  }
}
