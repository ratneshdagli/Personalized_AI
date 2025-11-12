/// Backend feed item model matching the API response
class BackendFeedItem {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String fullText;
  final DateTime date;
  final String source;
  final int priority;
  final double relevance;
  final Map<String, dynamic>? metaData;

  BackendFeedItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.fullText,
    required this.date,
    required this.source,
    required this.priority,
    required this.relevance,
    this.metaData,
  });

  factory BackendFeedItem.fromJson(Map<String, dynamic> json) {
    return BackendFeedItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      content: json['content'] ?? json['summary'] ?? '',
      fullText: json['full_text'] ?? json['content'] ?? json['summary'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      source: json['source'] ?? 'unknown',
      priority: json['priority'] ?? 1,
      relevance: (json['relevance'] ?? 0.0).toDouble(),
      metaData: json['metaData'] ?? json['meta_data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'full_text': fullText,
      'date': date.toIso8601String(),
      'source': source,
      'priority': priority,
      'relevance': relevance,
      'metaData': metaData,
    };
  }
}
