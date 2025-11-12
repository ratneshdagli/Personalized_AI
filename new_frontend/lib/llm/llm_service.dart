import '../services/api_service.dart';
import 'llm_adapter.dart';
import 'local_llm_adapter.dart';
import 'llm_config.dart';

/// LLM service that prefers the on-device adapter with transparent
/// fallback to the backend API when local inference fails or is disabled.
class LlmService {
  final ApiService _api = ApiService();
  final LocalLlmAdapter _local = LocalLlmAdapter();

  Future<String> summarizeText(String text, {int maxLength = 120}) async {
    if (await LlmConfig.preferLocal()) {
      try {
        return await _local.summarizeText(text, maxLength: maxLength);
      } catch (_) {
        if (!await LlmConfig.fallbackCloud()) rethrow;
      }
    }
    // No direct summarize endpoint yet – return local heuristic as safe default.
    return await _local.summarizeText(text, maxLength: maxLength);
  }

  Future<Map<String, dynamic>> extractTasks(String text) async {
    if (await LlmConfig.preferLocal()) {
      try {
        return await _local.extractTasks(text);
      } catch (_) {
        if (!await LlmConfig.fallbackCloud()) rethrow;
      }
    }
    // Backend fallback
    final res = await _api.extractTasks(text);
    return res.toJson();
  }

  Future<Map<String, dynamic>> extractEvents(String text) async {
    if (await LlmConfig.preferLocal()) {
      try {
        return await _local.extractEvents(text);
      } catch (_) {
        if (!await LlmConfig.fallbackCloud()) rethrow;
      }
    }
    // No backend events endpoint exposed separately; handled via ingestion.
    // Return local heuristic to keep UI consistent.
    return await _local.extractEvents(text);
  }

  Future<LlmStatus> status() => _local.status();
}
