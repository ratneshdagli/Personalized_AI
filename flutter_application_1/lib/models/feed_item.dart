class FeedItem {
  final String id;
  final String title;
  final String summary;
  final String source;
  final int priority;

  FeedItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.priority,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'],
      title: json['title'],
      summary: json['summary'],
      source: json['source'],
      priority: json['priority'],
    );
  }
}
