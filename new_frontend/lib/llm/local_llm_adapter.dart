import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'llm_adapter.dart';
import 'model_manager.dart';

class LocalLlmAdapter implements LlmAdapter {
  tfl.Interpreter? _interpreter; // not used yet – placeholder for future model
  ModelInfo? _info;
  String? _modelPath;
  int? _lastLatencyMs;
  bool _checksumVerified = false;
  int? _modelSizeBytes;
  DateTime? _downloadDate;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null || _modelPath != null) return;
    
    // Try to load from Hugging Face installed model first
    final prefs = await SharedPreferences.getInstance();
    _modelPath = prefs.getString('hf_installed_model_path');
    
    // Fallback to legacy model manager
    if (_modelPath == null) {
      final status = await ModelManager.getCachedStatus();
      _modelPath = await ModelManager.getCachedModelPath();
      _modelSizeBytes = status['size'] as int?;
      _checksumVerified = (status['sha256'] != null);
      final ts = status['downloadedAt'] as int?;
      if (ts != null) _downloadDate = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      // Get HF model metadata
      final sha = prefs.getString('hf_installed_model_sha256');
      _checksumVerified = (sha != null && sha.isNotEmpty);
      final ts = prefs.getInt('hf_installed_at');
      if (ts != null) _downloadDate = DateTime.fromMillisecondsSinceEpoch(ts);
      
      final file = File(_modelPath!);
      if (await file.exists()) {
        _modelSizeBytes = await file.length();
      }
    }

    // Load model with CPU-only interpreter
    if (_modelPath != null && await File(_modelPath!).exists()) {
      try {
        debugPrint('[LocalLlmAdapter] Loading model from: $_modelPath');
        _interpreter = await ModelManager.loadLocalModel(_modelPath!);
        if (_interpreter != null) {
          debugPrint('[LocalLlmAdapter] CPU-only interpreter initialized successfully');
        } else {
          debugPrint('[LocalLlmAdapter] Failed to initialize interpreter');
        }
      } catch (e) {
        debugPrint('[LocalLlmAdapter] Error loading model: $e');
        _interpreter = null;
      }
    }
  }

  @override
  Future<String> summarizeText(String text, {int maxLength = 120}) async {
    final sw = Stopwatch()..start();
    await _ensureLoaded();
    // Heuristic local summarizer: first sentence / truncate
    final summary = _simpleSummary(text, maxLength);
    _lastLatencyMs = sw.elapsedMilliseconds;
    return summary;
  }

  // Compatibility wrappers
  Future<String> summarize_text(String text, {int maxLength = 120}) => summarizeText(text, maxLength: maxLength);
  Future<String> generate_summary(String text, {int maxLength = 120}) => summarizeText(text, maxLength: maxLength);

  @override
  Future<Map<String, dynamic>> extractTasks(String text) async {
    final sw = Stopwatch()..start();
    await _ensureLoaded();
    final tasks = _extractTasksRules(text);
    _lastLatencyMs = sw.elapsedMilliseconds;
    return {
      'summary': _simpleSummary(text, 100),
      'tasks': tasks,
    };
  }

  @override
  Future<Map<String, dynamic>> extractEvents(String text) async {
    final sw = Stopwatch()..start();
    await _ensureLoaded();
    final events = _extractEventsRules(text);
    _lastLatencyMs = sw.elapsedMilliseconds;
    return {
      'summary': _simpleSummary(text, 100),
      'events': events,
    };
  }

  @override
  Future<LlmStatus> status() async {
    await _ensureLoaded();
    return LlmStatus(
      modelLoaded: _interpreter != null || _modelPath != null,
      modelName: _info?.name,
      modelPath: _modelPath,
      modelSizeBytes: _modelSizeBytes,
      checksumVerified: _checksumVerified,
      lastLatencyMs: _lastLatencyMs,
      downloadDate: _downloadDate,
    );
  }

  // --- Heuristic fallbacks ---
  String _simpleSummary(String text, int maxLength) {
    final dot = text.indexOf('.') >= 0 ? text.indexOf('.') : text.length;
    final sent = text.substring(0, dot).trim();
    if (sent.length <= maxLength) return sent;
    return sent.substring(0, maxLength - 3) + '...';
  }

  List<Map<String, dynamic>> _extractTasksRules(String text) {
    final lower = text.toLowerCase();
    final List<Map<String, dynamic>> tasks = [];
    final patterns = <RegExp>[
      RegExp(r'(submit|hand in|turn in|send)\s+([^.!?]*(assignment|project|report|form|application)[^.!?]*)'),
      RegExp(r'(complete|finish|do)\s+([^.!?]*(assignment|project|task)[^.!?]*)'),
      RegExp(r'(attend|go to|join)\s+([^.!?]*(meeting|event|class|session)[^.!?]*)'),
      RegExp(r'(register|sign up|apply)\s+([^.!?]*(for|to)[^.!?]*)'),
      RegExp(r'(pay|submit payment)\s+([^.!?]*(fee|bill|payment)[^.!?]*)'),
      RegExp(r'(review|check|read)\s+([^.!?]*(document|email|message)[^.!?]*)'),
    ];
    for (final re in patterns) {
      for (final m in re.allMatches(lower)) {
        final verb = m.group(1) ?? 'do';
        final snippet = (m.group(2) ?? m.group(0) ?? '').trim();
        tasks.add({'verb': verb, 'due_date': null, 'text': snippet});
      }
    }
    return tasks.take(5).toList();
  }

  List<Map<String, dynamic>> _extractEventsRules(String text) {
    final lower = text.toLowerCase();
    final List<Map<String, dynamic>> events = [];
    final re = RegExp(r'(meeting|call|appointment|session|interview|dinner|lunch|breakfast)\s+([^.!?]*)');
    for (final m in re.allMatches(lower)) {
      final title = m.group(1) ?? 'event';
      final ctx = (m.group(2) ?? '').trim();
      events.add({
        'title': '${title[0].toUpperCase()}${title.substring(1)}: ${ctx.split(' ').take(10).join(' ')}',
        'start_time': null,
        'duration_minutes': 60,
        'location': null,
        'description': ctx,
      });
    }
    return events.take(3).toList();
  }
}
