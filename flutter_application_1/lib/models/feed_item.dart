class FeedItem {
  final String id;
  final String title;
  final String summary;
  final String content;
  final DateTime date; // Store as DateTime
  final String source;
  final int priority;
  final double relevance;
  final Map<String, dynamic>? metaData;

  FeedItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.date,
    required this.source,
    required this.priority,
    required this.relevance,
    this.metaData,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'],
      title: json['title'],
      summary: json['summary'],
      content: json['content'] ?? json['summary'],
      date: DateTime.parse(json['date']), // Parse the date string
      source: json['source'],
      priority: json['priority'],
      relevance: (json['relevance'] ?? 0.0).toDouble(),
      metaData: json['metaData'],
    );
  }
}