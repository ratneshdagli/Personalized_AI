import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/local_llm_service.dart';
import '../services/task_extractor.dart';
import '../data/repositories/hub_repository.dart';
import 'package:isar/isar.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

// Simple mock class to satisfy buildSystemPrompt interface
class MockHub {
  final String name;
  MockHub(this.name);
}

class DebugLlmScreen extends StatefulWidget {
  const DebugLlmScreen({super.key});

  @override
  State<DebugLlmScreen> createState() => _DebugLlmScreenState();
}

class _DebugLlmScreenState extends State<DebugLlmScreen> {
  final TextEditingController _controller = TextEditingController();
  final LocalLLMService _llmService = LocalLLMService();
  late TaskExtractor _extractor;
  
  bool _isLoading = false;
  String? _rawJson;
  Map<String, dynamic>? _parsedResult;
  String? _error;
  bool _isCheckingModel = true;
  String _modelStatus = 'Checking model...';

  @override
  void initState() {
    super.initState();
    _extractor = TaskExtractor(_llmService);
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    setState(() {
      _isCheckingModel = true;
      _modelStatus = 'Checking model status...';
    });

    try {
      // Check if already initialized
      if (_llmService.isInitialized) {
        setState(() {
          _isCheckingModel = false;
          _modelStatus = 'Model ready';
        });
        return;
      }

      // Try to get saved model path
      final modelPath = await LocalLLMService.getDownloadedModelPath();
      final modelName = await LocalLLMService.getDownloadedModelName();

      if (modelPath == null || modelName == null) {
        setState(() {
          _isCheckingModel = false;
          _modelStatus = 'No model selected. Please go to Settings > Active Model to select and initialize a model.';
          _error = _modelStatus;
        });
        return;
      }

      // Model path exists but not initialized - initialize it
      setState(() {
        _modelStatus = 'Initializing model: $modelName...';
      });

      await _llmService.initialize(
        modelPath: modelPath,
        modelName: modelName,
      );

      setState(() {
        _isCheckingModel = false;
        _modelStatus = 'Model ready: $modelName';
      });
    } catch (e) {
      debugPrint('Error checking model status: $e');
      setState(() {
        _isCheckingModel = false;
        _modelStatus = 'Error: $e';
        _error = 'Failed to initialize model: $e\n\nPlease go to Settings and select a model.';
      });
    }
  }

  Future<void> _processText() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _rawJson = null;
      _parsedResult = null;
    });

    try {
      // Double-check initialization before processing
      if (!_llmService.isInitialized) {
        setState(() {
          _error = 'Local LLM not initialized. Attempting to initialize...';
        });
        await _checkModelStatus();
        
        if (!_llmService.isInitialized) {
          return; // Error already set in _checkModelStatus
        }
      }

      // Get hubs for context
      final appState = Provider.of<AppState>(context, listen: false);
      
      // Use a basic hub list for the debug screen
      // Convert to Hub-like objects for the prompt builder
      final hubsList = [
        MockHub('Work'),
        MockHub('Personal'),
        MockHub('Finance'),
      ];

      final systemPrompt = _llmService.buildSystemPrompt(hubsList, []); // Empty feedback list
      final result = await _extractor.extractFromText(_controller.text, systemPrompt);

      setState(() {
        _parsedResult = result.toJson();
        _rawJson = const JsonEncoder.withIndent('  ').convert(_parsedResult);
      });
    } catch (e) {
      setState(() {
        if (e.toString().contains('not initialized') || e.toString().contains('Model not initialized')) {
          _error = 'Local LLM not initialized. Please download and install a model from Settings > Models & AI first.';
        } else {
          _error = e.toString();
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug LLM Extraction'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      backgroundColor: const Color(0xFF0B1220),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Model Status Indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isCheckingModel 
                    ? const Color(0xFF1E293B)
                    : (_llmService.isInitialized 
                        ? const Color(0x1A10B981) 
                        : const Color(0x1AEF4444)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isCheckingModel
                      ? const Color(0xFF3B82F6)
                      : (_llmService.isInitialized 
                          ? const Color(0xFF10B981) 
                          : const Color(0xFFEF4444)),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  if (_isCheckingModel)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                    )
                  else
                    Icon(
                      _llmService.isInitialized ? Icons.check_circle : Icons.error,
                      color: _llmService.isInitialized ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _modelStatus,
                      style: TextStyle(
                        color: _llmService.isInitialized ? const Color(0xFF10B981) : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Paste notification text here...',
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Process with LLM', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0x33EF4444),
                        child: Text('Error: $_error', style: const TextStyle(color: Color(0xFFEF4444))),
                      ),
                    
                    if (_parsedResult != null) ...[
                      const Text('Parsed Result:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildResultCard('Importance', _parsedResult!['importance']),
                      _buildResultCard('Should Show', _parsedResult!['should_show'].toString()),
                      _buildResultCard('In Priority Spotlight', _parsedResult!['in_priority_spotlight'].toString()),
                      _buildResultCard('Summary', _parsedResult!['summary']),
                      
                      if ((_parsedResult!['assigned_hubs'] as List?)?.isNotEmpty ?? false)
                        _buildSection('Assigned Hubs', _parsedResult!['assigned_hubs']),
                        
                      if ((_parsedResult!['todo_items'] as List?)?.isNotEmpty ?? false)
                        _buildSection('Todo Items', _parsedResult!['todo_items']),
                        
                      if ((_parsedResult!['events'] as List?)?.isNotEmpty ?? false)
                        _buildSection('Events', _parsedResult!['events']),

                      const SizedBox(height: 24),
                      const Text('Raw JSON:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _rawJson ?? '',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Color(0xFFC084FC), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(item.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
        )),
      ],
    );
  }
}

