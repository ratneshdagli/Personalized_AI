import 'package:flutter/foundation.dart';

class LlmStatus {
  final bool modelLoaded;
  final String? modelName;
  final String? modelPath;
  final int? modelSizeBytes;
  final bool checksumVerified;
  final int? lastLatencyMs;
  final DateTime? downloadDate;

  const LlmStatus({
    required this.modelLoaded,
    this.modelName,
    this.modelPath,
    this.modelSizeBytes,
    this.checksumVerified = false,
    this.lastLatencyMs,
    this.downloadDate,
  });
}

abstract class LlmAdapter {
  Future<String> summarizeText(String text, {int maxLength});
  Future<Map<String, dynamic>> extractTasks(String text);
  Future<Map<String, dynamic>> extractEvents(String text);
  Future<LlmStatus> status();
}
