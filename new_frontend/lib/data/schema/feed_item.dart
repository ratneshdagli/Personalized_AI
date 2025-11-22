import 'package:isar/isar.dart';

part 'feed_item.g.dart';

@collection
class FeedItem {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String source; // e.g., 'whatsapp', 'gmail', 'system'

  late String content;
  late String summary;

  List<int>? secondaryHubIds;

  @Index()
  late DateTime timestamp;

  @Index()
  int priority = 5; // 1-10 scale (1=low, 5=medium, 10=high)
  
  bool isRead = false;
  
  // New field for Priority Spotlight
  bool inPrioritySpotlight = false;
  
  @Index()
  int? hubId; // Primary hub assignment

  // Storing raw JSON metadata as a string since Isar doesn't support Map<String, dynamic> directly
  String? metadataJson;

  // Optional embedding for semantic search
  List<double>? embedding;
}
