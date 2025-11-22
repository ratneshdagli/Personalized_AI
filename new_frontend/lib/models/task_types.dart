/// Task types for different AI interactions, inspired by Google AI Edge Gallery
enum TaskType {
  llmChat('llm_chat', 'AI Chat'),
  llmPromptLab('llm_prompt_lab', 'Prompt Lab'),
  llmAskImage('llm_ask_image', 'Ask Image'),
  llmAskAudio('llm_ask_audio', 'Ask Audio');

  const TaskType(this.id, this.displayName);
  
  final String id;
  final String displayName;

  static TaskType fromId(String id) {
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => TaskType.llmChat,
    );
  }
}

/// Performance metrics for benchmarking, inspired by Edge Gallery
class PerformanceMetrics {
  final double timeToFirstToken; // in seconds
  final double prefillSpeed; // tokens per second
  final double decodeSpeed; // tokens per second
  final double latency; // total time in seconds
  final int totalTokens;
  final bool isRunning;

  const PerformanceMetrics({
    required this.timeToFirstToken,
    required this.prefillSpeed,
    required this.decodeSpeed,
    required this.latency,
    required this.totalTokens,
    this.isRunning = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'timeToFirstToken': timeToFirstToken,
      'prefillSpeed': prefillSpeed,
      'decodeSpeed': decodeSpeed,
      'latency': latency,
      'totalTokens': totalTokens,
      'isRunning': isRunning,
    };
  }

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      timeToFirstToken: (json['timeToFirstToken'] ?? 0.0).toDouble(),
      prefillSpeed: (json['prefillSpeed'] ?? 0.0).toDouble(),
      decodeSpeed: (json['decodeSpeed'] ?? 0.0).toDouble(),
      latency: (json['latency'] ?? 0.0).toDouble(),
      totalTokens: json['totalTokens'] ?? 0,
      isRunning: json['isRunning'] ?? false,
    );
  }
}

/// Task configuration for different AI interactions
class TaskConfig {
  final TaskType type;
  final String name;
  final String description;
  final String? docUrl;
  final String? sourceCodeUrl;
  final List<String> supportedModelIds;
  final String agentName;
  final String inputPlaceholder;

  const TaskConfig({
    required this.type,
    required this.name,
    required this.description,
    this.docUrl,
    this.sourceCodeUrl,
    this.supportedModelIds = const [],
    this.agentName = 'AI Assistant',
    this.inputPlaceholder = 'Type your message...',
  });

  // Add displayName getter
  String get displayName => type.displayName;

  factory TaskConfig.fromModelAllowlist(Map<String, dynamic> modelData, TaskType type) {
    final name = modelData['name'] as String;
    final description = modelData['description'] as String;
    final taskTypes = List<String>.from(modelData['taskTypes'] ?? []);
    
    return TaskConfig(
      type: type,
      name: name,
      description: description,
      supportedModelIds: taskTypes.contains(type.id) ? [modelData['modelId'] as String] : [],
    );
  }
}

/// Built-in task configurations
class BuiltInTasks {
  static const List<TaskConfig> tasks = [
    TaskConfig(
      type: TaskType.llmChat,
      name: 'AI Chat',
      description: 'Engage in multi-turn conversations with the AI assistant.',
      agentName: 'Chat Assistant',
      inputPlaceholder: 'Type your message...',
    ),
    TaskConfig(
      type: TaskType.llmPromptLab,
      name: 'Prompt Lab',
      description: 'Experiment with single-turn prompts for various tasks like summarization, rewriting, and code generation.',
      agentName: 'Prompt Assistant',
      inputPlaceholder: 'Enter instruction...',
    ),
    TaskConfig(
      type: TaskType.llmAskImage,
      name: 'Ask Image',
      description: 'Upload images and ask questions about them. Get descriptions, solve problems, or identify objects.',
      agentName: 'Vision Assistant',
      inputPlaceholder: 'Ask about the image...',
    ),
    TaskConfig(
      type: TaskType.llmAskAudio,
      name: 'Ask Audio',
      description: 'Transcribe audio clips or translate them into another language.',
      agentName: 'Audio Assistant',
      inputPlaceholder: 'Upload or record audio...',
    ),
  ];

  static TaskConfig? getTaskById(String id) {
    try {
      final taskType = TaskType.fromId(id);
      return tasks.firstWhere((task) => task.type == taskType);
    } catch (e) {
      return null;
    }
  }

  static TaskConfig? getTaskByType(TaskType type) {
    try {
      return tasks.firstWhere((task) => task.type == type);
    } catch (e) {
      return null;
    }
  }
}
