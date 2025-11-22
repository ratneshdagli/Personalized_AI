import 'dart:convert';

class ExtractionResult {
  final bool shouldShow;
  final bool inPrioritySpotlight;
  final List<ExtractedHub> assignedHubs;
  final List<ExtractedTodoItem> todoItems;
  final List<ExtractedEvent> events;
  final String importance;
  final String summary;
  final Map<String, dynamic> meta;

  ExtractionResult({
    required this.shouldShow,
    required this.inPrioritySpotlight,
    required this.assignedHubs,
    required this.todoItems,
    required this.events,
    required this.importance,
    required this.summary,
    this.meta = const {},
  });

  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    try {
      // Helper to safely convert to list
      List<T> safeListConversion<T>(dynamic value, T Function(Map<String, dynamic>) fromJson) {
        if (value == null) return [];
        if (value is! List) return [];
        return value.map((e) {
          try {
            if (e is Map<String, dynamic>) {
              return fromJson(e);
            }
            return null;
          } catch (e) {
            print('[ExtractionResult] Error parsing list item: $e');
            return null;
          }
        }).whereType<T>().toList();
      }

      return ExtractionResult(
        shouldShow: json['should_show'] == true,
        inPrioritySpotlight: json['in_priority_spotlight'] == true,
        assignedHubs: safeListConversion(json['assigned_hubs'], ExtractedHub.fromJson),
        todoItems: safeListConversion(json['todo_items'], ExtractedTodoItem.fromJson),
        events: safeListConversion(json['events'], ExtractedEvent.fromJson),
        importance: (json['importance'] as String?) ?? 'low',
        summary: (json['summary'] as String?) ?? '',
        meta: (json['meta'] as Map<String, dynamic>?) ?? {},
      );
    } catch (e, stack) {
      print('[ExtractionResult] Error parsing JSON: $e');
      print('[ExtractionResult] Stack trace: $stack');
      print('[ExtractionResult] Raw JSON: $json');
      // Return a safe default
      return ExtractionResult(
        shouldShow: false,
        inPrioritySpotlight: false,
        assignedHubs: [],
        todoItems: [],
        events: [],
        importance: 'low',
        summary: 'Error parsing notification',
        meta: {'error': e.toString()},
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'should_show': shouldShow,
      'in_priority_spotlight': inPrioritySpotlight,
      'assigned_hubs': assignedHubs.map((e) => e.toJson()).toList(),
      'todo_items': todoItems.map((e) => e.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'importance': importance,
      'summary': summary,
      'meta': meta,
    };
  }
}

class ExtractedHub {
  final String hubName;
  final double confidence;

  ExtractedHub({
    required this.hubName,
    required this.confidence,
  });

  factory ExtractedHub.fromJson(Map<String, dynamic> json) {
    return ExtractedHub(
      hubName: json['hub_name'] ?? '', // Allow empty, will be filtered out or handled by service
      confidence: json['confidence'] is num 
          ? (json['confidence'] as num).toDouble() 
          : (json['confidence'] == 'high' ? 0.9 : 0.5), // Handle string confidence like "high"
    );
  }

  Map<String, dynamic> toJson() => {
        'hub_name': hubName,
        'confidence': confidence,
      };
}

class ExtractedTodoItem {
  final String title;
  final DateTime? dueDate;
  final String priority;

  ExtractedTodoItem({
    required this.title,
    this.dueDate,
    required this.priority,
  });

  factory ExtractedTodoItem.fromJson(Map<String, dynamic> json) {
    // Helper to parse priority - handle cases like "low|medium|high"
    String parsePriority(dynamic value) {
      if (value == null) return 'low';
      final str = value.toString().toLowerCase();
      if (str.contains('high')) return 'high';
      if (str.contains('medium')) return 'medium';
      if (str.contains('low')) return 'low';
      return 'low';
    }
    
    return ExtractedTodoItem(
      title: json['title'] ?? '',
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      priority: parsePriority(json['priority']),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
      };
}

class ExtractedEvent {
  final String title;
  final DateTime? date;
  final bool allDay;
  final String priority;

  ExtractedEvent({
    required this.title,
    this.date,
    required this.allDay,
    required this.priority,
  });

  factory ExtractedEvent.fromJson(Map<String, dynamic> json) {
    // Helper to parse priority - handle cases like "low|medium|high"
    String parsePriority(dynamic value) {
      if (value == null) return 'low';
      final str = value.toString().toLowerCase();
      if (str.contains('high')) return 'high';
      if (str.contains('medium')) return 'medium';
      if (str.contains('low')) return 'low';
      return 'low';
    }
    
    return ExtractedEvent(
      title: json['title'] ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      allDay: json['all_day'] ?? false,
      priority: parsePriority(json['priority']),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date?.toIso8601String(),
        'all_day': allDay,
        'priority': priority,
      };
}
