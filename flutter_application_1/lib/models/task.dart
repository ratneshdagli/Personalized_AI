// Represents extracted task with due date
class Task {
  final String id;
  final String title;
  final String verb;
  final DateTime? dueDate;
  final String text;
  final int priority;
  bool isCompleted;
  DateTime? completedAt;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required this.verb,
    this.dueDate,
    required this.text,
    this.priority = 1,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
    String? description,
    String? source,
    String? sourceId,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? json['text'] ?? '',
      verb: json['verb'] ?? '',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      text: json['text'] ?? '',
      priority: json['priority'] ?? 1,
      isCompleted: json['isCompleted'] ?? false,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'verb': verb,
      'due_date': dueDate?.toIso8601String(),
      'text': text,
      'priority': priority,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Represents the result of task extraction
class TaskExtractionResult {
  final String summary;
  final List<Task> tasks;

  TaskExtractionResult({required this.summary, required this.tasks});

  factory TaskExtractionResult.fromJson(Map<String, dynamic> json) {
    return TaskExtractionResult(
      summary: json['summary'] ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
          ?.map((task) => Task.fromJson(task))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'tasks': tasks.map((task) => task.toJson()).toList(),
    };
  }
}
