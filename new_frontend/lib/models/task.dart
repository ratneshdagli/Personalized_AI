/// Backend task model matching the API response
class BackendTask {
  final String id;
  final String title;
  final String verb;
  final DateTime? dueDate;
  final String text;
  final int priority;
  bool isCompleted;
  DateTime? completedAt;
  final DateTime createdAt;

  BackendTask({
    required this.id,
    required this.title,
    required this.verb,
    this.dueDate,
    required this.text,
    this.priority = 1,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BackendTask.fromJson(Map<String, dynamic> json) {
    return BackendTask(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? json['text'] ?? '',
      verb: json['verb'] ?? '',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      text: json['text'] ?? '',
      priority: json['priority'] ?? 1,
      isCompleted: json['isCompleted'] ?? json['is_completed'] ?? false,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : (json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : (json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now()),
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

/// Task extraction result from the backend
class TaskExtractionResult {
  final String summary;
  final List<BackendTask> tasks;

  TaskExtractionResult({required this.summary, required this.tasks});

  factory TaskExtractionResult.fromJson(Map<String, dynamic> json) {
    return TaskExtractionResult(
      summary: json['summary'] ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((task) => BackendTask.fromJson(task))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'tasks': tasks.map((task) => task.toJson()).toList(),
    };
  }
}
