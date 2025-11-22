import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/extraction_result.dart';
import 'local_llm_service.dart';

class TaskExtractor {
  final LocalLLMService _llmService;

  TaskExtractor(this._llmService);

  Future<ExtractionResult> extractFromText(String text, String systemPrompt) async {
    if (!_llmService.isInitialized) {
      debugPrint('[TaskExtractor] ⚠️ LLM not initialized. Attempting auto-initialization...');
      
      try {
        final lastModelPath = await LocalLLMService.getDownloadedModelPath();
        
        if (lastModelPath != null && lastModelPath.isNotEmpty) {
          debugPrint('[TaskExtractor] Found last-used model: $lastModelPath');
          await _llmService.initialize(modelPath: lastModelPath);
          debugPrint('[TaskExtractor] ✅ Auto-initialization successful!');
        } else {
          debugPrint('[TaskExtractor] ❌ No model found. Please select a model in Settings.');
          throw Exception('No LLM model selected. Please go to Settings > Active Model to select a model.');
        }
      } catch (e) {
        debugPrint('[TaskExtractor] ❌ Auto-initialization failed: $e');
        throw Exception('Failed to initialize LLM: $e');
      }
    }

    // Truncate text to avoid token exhaustion
    final truncatedText = text.length > 1000 ? text.substring(0, 1000) : text;
    
    final prompt = '''
$systemPrompt

Notification:
"""
$truncatedText
"""

Output valid JSON only. No conversational text.
''';

    try {
      debugPrint('[TaskExtractor] Processing notification (${truncatedText.length} chars)...');
      
      final stream = _llmService.generateResponseWithoutDefaultPrompt(prompt);
      String fullResponse = '';
      
      await for (final chunk in stream.timeout(
        const Duration(seconds: 60),
        onTimeout: (sink) {
          debugPrint('[TaskExtractor] ⚠️ Stream timeout after 60 seconds');
        },
      )) {
        fullResponse += chunk; // FIX: Append chunk, don't replace
      }
      
      debugPrint('[TaskExtractor] ✅ Got LLM response (${fullResponse.length} chars)');
      
      var jsonString = _extractJson(fullResponse);
      
      if (jsonString == null) {
        debugPrint('[TaskExtractor] No JSON found in direct extraction, trying cleanup');
        final cleaned = _cleanJsonString(fullResponse);
        jsonString = _extractJson(cleaned);
        
        if (jsonString == null) {
          debugPrint('[TaskExtractor] Still no JSON after cleanup. Raw response (first 500 chars):');
          debugPrint(fullResponse.substring(0, fullResponse.length > 500 ? 500 : fullResponse.length));
          throw Exception('No JSON found in LLM response after cleanup');
        }
      }

      debugPrint('[TaskExtractor] Extracted JSON: ${jsonString.length} chars');
      
      jsonString = _validateAndRepairJson(jsonString);
      
      Map<String, dynamic> jsonMap;
      try {
        jsonMap = json.decode(jsonString);
      } catch (e) {
        debugPrint('[TaskExtractor] JSON parse failed, retrying with additional cleanup. Error: $e');
        final cleaned = _cleanJsonString(jsonString);
        debugPrint('[TaskExtractor] Cleaned JSON (first 200 chars): ${cleaned.substring(0, cleaned.length > 200 ? 200 : cleaned.length)}');
        jsonMap = json.decode(cleaned);
      }
      
      return ExtractionResult.fromJson(jsonMap);
    } on Exception catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Packet timestamp mismatch') || 
          errorStr.contains('last_processed_modality_type') ||
          errorStr.contains('INVALID_ARGUMENT: Graph has errors')) {
        debugPrint('[TaskExtractor] ⚠️ MediaPipe timestamp warning (non-fatal, continuing...)');
        // Fallback for MediaPipe errors - still try to show if possible, or hide if critical
        return ExtractionResult(
          importance: 'medium',
          shouldShow: true,
          inPrioritySpotlight: false,
          assignedHubs: [],
          todoItems: [],
          events: [],
          summary: text.length > 50 ? text.substring(0, 50) + '...' : text,
          meta: {'warning': 'MediaPipe timestamp issue (non-fatal)'},
        );
      }
      
      debugPrint('[TaskExtractor] ❌ Error extracting tasks: $e');
      // On critical errors, default to NOT showing to avoid spamming user with unclassified junk
      return ExtractionResult(
        importance: 'low',
        shouldShow: false, // Default to hidden on error
        inPrioritySpotlight: false,
        assignedHubs: [],
        todoItems: [],
        events: [],
        summary: 'Error processing notification',
        meta: {'error': e.toString()},
      );
    } catch (e) {
      debugPrint('[TaskExtractor] ❌ Critical error extracting tasks: $e');
      return ExtractionResult(
        importance: 'low',
        shouldShow: false, // Default to hidden on error
        inPrioritySpotlight: false,
        assignedHubs: [],
        todoItems: [],
        events: [],
        summary: 'Error processing notification',
        meta: {'error': e.toString()},
      );
    }
  }

  String _validateAndRepairJson(String jsonStr) {
    int openBraces = 0;
    int closeBraces = 0;
    
    for (int i = 0; i < jsonStr.length; i++) {
      if (jsonStr[i] == '{') openBraces++;
      if (jsonStr[i] == '}') closeBraces++;
    }
    
    if (openBraces > closeBraces) {
      final missing = openBraces - closeBraces;
      debugPrint('[TaskExtractor] JSON has $missing unclosed braces, attempting to repair...');
      jsonStr = jsonStr + ('}' * missing);
      debugPrint('[TaskExtractor] Repaired JSON (first 300 chars): ${jsonStr.substring(0, jsonStr.length > 300 ? 300 : jsonStr.length)}');
    }
    
    return jsonStr;
  }

  String? _extractJson(String text) {
    var startIndex = text.indexOf('{');
    var endIndex = text.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return text.substring(startIndex, endIndex + 1);
    }
    
    return null;
  }

  String _cleanJsonString(String raw) {
    var cleaned = raw.trim();
    
    cleaned = cleaned.replaceAll(RegExp(r'```json\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'`'), '');
    
    final firstBrace = cleaned.indexOf('{');
    if (firstBrace != -1) {
      cleaned = cleaned.substring(firstBrace);
    }
    
    final lastBrace = cleaned.lastIndexOf('}');
    if (lastBrace != -1 && lastBrace < cleaned.length - 1) {
      cleaned = cleaned.substring(0, lastBrace + 1);
    }
    
    return cleaned.trim();
  }
}
