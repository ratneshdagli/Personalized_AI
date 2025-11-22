import 'package:isar/isar.dart';
import '../schema/feed_item.dart';

class FeedRepository {
  final Isar isar;

  FeedRepository(this.isar);

  Future<List<FeedItem>> getFeed({int limit = 50, int offset = 0}) async {
    return await isar.feedItems
        .where()
        .sortByTimestampDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<int> addFeedItem(FeedItem item) async {
    return await isar.writeTxn(() async {
      return await isar.feedItems.put(item);
    });
  }

  Future<void> deleteFeedItem(int id) async {
    await isar.writeTxn(() async {
      await isar.feedItems.delete(id);
    });
  }

  Future<void> clearFeed() async {
    await isar.writeTxn(() async {
      await isar.feedItems.clear();
    });
  }

  Future<List<FeedItem>> searchFeed(String query) async {
    // Basic text search on content and summary
    return await isar.feedItems
        .filter()
        .contentContains(query, caseSensitive: false)
        .or()
        .summaryContains(query, caseSensitive: false)
        .sortByTimestampDesc()
        .findAll();
  }
  
  // Get a single feed item by ID
  Future<FeedItem?> getFeedItemById(int id) async {
    return await isar.feedItems.get(id);
  }
  
  // Find items since a specific time (for sync or updates)
  Future<List<FeedItem>> findSince(DateTime since) async {
    return await isar.feedItems
        .filter()
        .timestampGreaterThan(since)
        .sortByTimestampDesc()
        .findAll();
  }
}
