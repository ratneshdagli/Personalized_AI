import 'package:flutter_test/flutter_test.dart';
import 'package:personalized_ai/services/task_extractor.dart';
import 'package:personalized_ai/services/local_llm_service.dart';
import 'dart:async';

// Mock LocalLLMService
class MockLocalLLMService extends LocalLLMService {
  final String _mockResponse;
  
  MockLocalLLMService(this._mockResponse);

  @override
  bool get isInitialized => true;

  @override
  Stream<String> generateResponse(String prompt, {List<int>? imageBytes}) async* {
    // Simulate streaming response
    final chunks = _mockResponse.split('');
    String accumulated = '';
    for (final chunk in chunks) {
      accumulated += chunk;
      yield accumulated;
      await Future.delayed(Duration(milliseconds: 1));
    }
  }
}

void main() {
  group('TaskExtractor', () {
    test('extractFromText returns parsed JSON when LLM returns valid JSON', () async {
      final mockJson = '''
      {
        "importance": "high",
        "should_show": true,
        "hubs": ["Work", "Urgent"],
        "tasks": [
          {"title": "Finish report", "priority": "high", "is_actionable": true}
        ],
        "events": [],
        "summary": "Need to finish the report by EOD."
      }
      ''';
      
      final mockService = MockLocalLLMService(mockJson);
      final extractor = TaskExtractor(mockService);
      
      final result = await extractor.extractFromText("Finish report by EOD", "System Prompt");
      
      expect(result['importance'], 'high');
      expect(result['should_show'], true);
      expect(result['hubs'], contains('Work'));
      expect(result['tasks'].length, 1);
      expect(result['tasks'][0]['title'], 'Finish report');
    });

    test('extractFromText handles JSON embedded in text', () async {
      final mockResponse = '''
      Here is the analysis:
      ```json
      {
        "importance": "medium",
        "should_show": true,
        "hubs": ["Personal"],
        "tasks": [],
        "events": [],
        "summary": "Just a note."
      }
      ```
      Hope that helps!
      ''';
      
      final mockService = MockLocalLLMService(mockResponse);
      final extractor = TaskExtractor(mockService);
      
      final result = await extractor.extractFromText("Just a note", "System Prompt");
      
      expect(result['importance'], 'medium');
      expect(result['summary'], 'Just a note.');
    });

    test('extractFromText returns fallback when JSON is invalid', () async {
      final mockResponse = 'This is not JSON.';
      
      final mockService = MockLocalLLMService(mockResponse);
      final extractor = TaskExtractor(mockService);
      
      final result = await extractor.extractFromText("Some text", "System Prompt");
      
      expect(result['should_show'], true); // Fallback default
      expect(result['meta']['error'], isNotNull);
    });
  });
}
