import 'package:flutter_test/flutter_test.dart';
import 'package:figma/llm/llm_service.dart';

void main() {
  group('Local LLM Adapter', () {
    test('summarizeText returns non-empty string without network', () async {
      final svc = LlmService();
      final summary = await svc.summarizeText(
        'Meeting tomorrow at 2 PM. Please submit the report by Friday.',
        maxLength: 80,
      );
      expect(summary.isNotEmpty, true);
    });

    test('extractTasks returns deterministic tasks without backend', () async {
      final svc = LlmService();
      final res = await svc.extractTasks(
        'Please submit the project report by Monday and attend the team meeting tomorrow.',
      );
      expect(res['summary'] is String, true);
      expect(res['tasks'] is List, true);
    });
  });
}
