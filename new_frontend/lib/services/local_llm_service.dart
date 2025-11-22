import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../models/task_types.dart';

// Helper mixin for closable objects
abstract class Closable {
  Future<void> close();
}

class LocalLLMService {
  static const String _prefsKeyPath = 'local_llm_model_path';
  static const String _prefsKeyName = 'local_llm_model_name';
  
  bool _isInitialized = false;
  bool _isInitializing = false;
  dynamic _model;
  dynamic _session;
  dynamic _currentChat;
  bool _isGenerating = false;
  bool _modelSupportsImage = false;
  Map<String, dynamic> _generationParams = {};
  
  // Mutex to prevent concurrent generation
  final List<Completer<void>> _generationQueue = [];
  bool _isProcessing = false;
  
  // Store conversation history
  final List<Map<String, dynamic>> _conversationHistory = [];
  
  // Performance metrics tracking
  PerformanceMetrics? _currentMetrics;
  final StreamController<PerformanceMetrics> _metricsController = 
      StreamController<PerformanceMetrics>.broadcast();
  
  // Current task configuration
  TaskConfig? _currentTask;
  
  // System prompts for different tasks
  static const Map<String, String> _systemPrompts = {
    'llm_chat': "You are a helpful AI assistant. Engage in natural conversation and provide helpful, concise responses.",
    'llm_prompt_lab': "You are a helpful AI assistant focused on single-turn tasks. Follow the user's instruction precisely and provide direct, actionable results.",
    'llm_ask_image': "You are a helpful AI assistant with vision capabilities. Analyze the provided image and answer questions about it accurately and concisely.",
    'llm_ask_audio': "You are a helpful AI assistant with audio processing capabilities. Transcribe or translate the provided audio content accurately.",
  };

  String buildSystemPrompt(List<dynamic> hubs, List<dynamic> feedback) {
    // Note: hubs are List<Hub>, feedback is List<UserFeedback>
    
    // Safely extract hub names
    final hubsList = hubs
        .where((h) => h != null)
        .map((h) {
          try {
            return h.name ?? 'Unknown';
          } catch (e) {
            return 'Unknown';
          }
        })
        .where((name) => name != 'Unknown')
        .join(', ');
    
    String feedbackSection = '';
    if (feedback.isNotEmpty) {
      final feedbackTexts = feedback
          .where((f) => f != null)
          .take(10) // Reduced to 10 to save tokens
          .map((f) {
            try {
              final content = f.messageContent ?? '';
              return content.isNotEmpty ? '"$content"' : null;
            } catch (e) {
              return null;
            }
          })
          .where((text) => text != null)
          .join(', ');
      
      if (feedbackTexts.isNotEmpty) {
        feedbackSection = '''
NEGATIVE EXAMPLES (User Hidden):
[$feedbackTexts]
(If similar, set should_show: false)
''';
      }
    }

    return '''
You are a strict JSON-only AI. You analyze notifications and output raw JSON.
DO NOT say "Okay", "Here is the JSON", or anything else. Just the JSON object.

Rules:
- Casual chit-chat ("hi", "ok", "thanks"), group summaries ("X messages from Y chats"), and generic service/promo/chatbot notifications -> should_show: false, all lists empty, importance: "low".
- If should_show is false -> assigned_hubs, todo_items, events must all be empty arrays.
- Only create todo_items if there is a clear action for the user (call, pay, submit, buy, etc.).
- Only create events if there is a real date/time (meeting, birthday, flight, etc.).
- If no explicit date/time -> set due_date/date to null.

AVAILABLE HUBS: $hubsList

Output JSON with exactly these fields:
{
  "should_show": <bool>,
  "in_priority_spotlight": <bool>,
  "assigned_hubs": [{"hub_name": "<string>", "confidence": <0.0-1.0>}],
  "todo_items": [{"title": "<string>", "due_date": "<ISO8601|null>", "priority": "<low|medium|high>"}],
  "events": [{"title": "<string>", "date": "<ISO8601|null>", "all_day": <bool>, "priority": "<low|medium|high>"}],
  "importance": "<low|medium|high>",
  "summary": "<short string>"
}
''';
  }

  
  
  // Singleton instance
  static final LocalLLMService _instance = LocalLLMService._internal();
  
  // Factory constructor to return the same instance
  factory LocalLLMService() => _instance;
  
  LocalLLMService._internal();

  // Get the path to the downloaded model
  static Future<String?> getDownloadedModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKeyPath);
  }

  // Get the model name
  static Future<String?> getDownloadedModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKeyName);
  }

  // Save the model path after download
  static Future<void> saveModelPath(String path, String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPath, path);
    await prefs.setString(_prefsKeyName, modelName);
  }

  /// Updates the current model with a new one
  Future<void> updateModel(String modelPath, String modelName) async {
    debugPrint('🔄 Updating model to: $modelName ($modelPath)');
    
    // Clear the existing model
    _model = null;
    _isInitialized = false;
    
    // Save the new model path
    await saveModelPath(modelPath, modelName);
    
    // Re-initialize with the new model
    await initialize(modelPath: modelPath, modelName: modelName);
    
    debugPrint('✅ Successfully updated model to: $modelName');
  }

  /// Detects the appropriate model type based on file name and model metadata
  /// Supports various model architectures including Gemma, Qwen, and others
  Future<ModelType> _getModelTypeFromPath(String modelPath) async {
    final fileName = path.basename(modelPath).toLowerCase();
    
    // First try to determine from file name patterns with more specific checks
    if (fileName.contains('gemma-3') || fileName.contains('gemma3')) {
      debugPrint('🔍 Detected Gemma 3 model from filename');
      return ModelType.gemmaIt; // Gemma 3 uses the same interface as Gemma 2
    } else if (fileName.contains('gemma')) {
      debugPrint('🔍 Detected Gemma model from filename');
      return ModelType.gemmaIt;
    } else if (fileName.contains('qwen')) {
      debugPrint('🔍 Detected Qwen model from filename');
      // Qwen models use the same interface as Gemma for inference
      return ModelType.gemmaIt;
    }
    
    // If we can't determine from filename, try to infer from model metadata
    try {
      // Check if the model has metadata that indicates its type
      final modelFile = File(modelPath);
      if (modelFile.existsSync()) {
        // Read first 10KB of the file to check for model type
        final bytes = await modelFile.openRead(0, 10240).toList();
        final buffer = StringBuffer();
        for (var chunk in bytes) {
          buffer.write(String.fromCharCodes(chunk));
        }
        final content = buffer.toString();
        
        if (content.contains('gemma-3') || content.contains('gemma3')) {
          debugPrint('🔍 Detected Gemma 3 model from metadata');
          return ModelType.gemmaIt;
        } else if (content.contains('gemma')) {
          debugPrint('🔍 Detected Gemma model from metadata');
          return ModelType.gemmaIt;
        } else if (content.contains('qwen') || content.contains('Qwen')) {
          debugPrint('🔍 Detected Qwen model from metadata');
          return ModelType.gemmaIt;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking model metadata: $e');
    }
    
    // If we still can't determine, log a warning and default to Gemma
    debugPrint('⚠️ Could not determine model type from path or metadata, defaulting to Gemma interface');
    return ModelType.gemmaIt;
  }

  /// Initializes the LLM service with the specified model
  /// If no model path is provided, it will try to find one in the default location
  Future<void> initialize({String? modelPath, String? modelName, bool llmSupportImage = false}) async {
    _modelSupportsImage = llmSupportImage;
    if (_isInitialized || _isInitializing) return;
    
    _isInitializing = true;
    debugPrint('🔄 Initializing LLM service...');
    
    try {
      // If no model path is provided, try to find one in the default location
      if (modelPath == null) {
        final prefs = await SharedPreferences.getInstance();
        modelPath = prefs.getString(_prefsKeyPath);
        modelName = prefs.getString(_prefsKeyName);
      }
      
      if (modelPath != null && modelName != null) {
        await saveModelPath(modelPath, modelName);
        debugPrint('💾 Saved new model path: $modelPath');
      }
      
      // Get the model path from preferences
      final prefs = await SharedPreferences.getInstance();
      String? actualModelPath = prefs.getString(_prefsKeyPath);
      final String? actualModelName = prefs.getString(_prefsKeyName);
      
      debugPrint('🔍 Retrieved model path from prefs: $actualModelPath');
      
      // If no model is found, throw an error
      if (actualModelPath == null || actualModelName == null) {
        final error = '❌ No model path provided and no saved model found';
        debugPrint(error);
        throw Exception(error);
      }
      
      // If the model path was overridden, update the saved path
      if (modelPath != null && modelPath != actualModelPath) {
        debugPrint('🔄 Updating model path to: $modelPath');
        actualModelPath = modelPath;
        await saveModelPath(modelPath, modelName!);
      }
      
      debugPrint('📂 Using model path: $actualModelPath');
      
      // Verify the model file exists
      final modelFile = File(actualModelPath);
      if (!await modelFile.exists()) {
        final error = '❌ Model file not found at: $actualModelPath';
        debugPrint(error);
        throw Exception(error);
      }
      
      final fileSize = (await modelFile.length()) / (1024 * 1024);
      final fileName = path.basename(actualModelPath);
      debugPrint('📊 Model details - Name: $fileName, Size: ${fileSize.toStringAsFixed(2)} MB');
      
      // Determine model type from file name and content
      final modelType = await _getModelTypeFromPath(actualModelPath);
      debugPrint('🔧 Detected model type: $modelType');
      
      // Install the model using FlutterGemma
      debugPrint('⚙️ Installing model...');
      debugPrint('📝 Model file: $actualModelPath');
      debugPrint('📝 Model type: $modelType');
      
      try {
        // First try with the detected model type
        await FlutterGemma.installModel(
          modelType: modelType,
        ).fromFile(actualModelPath).install();
        debugPrint('✅ Model installed successfully with type: $modelType');
      } catch (e) {
        debugPrint('⚠️ Standard model installation failed, trying fallback method: $e');
        // Try alternative installation method
        await FlutterGemma.installModel(
          modelType: ModelType.gemmaIt, // Fallback to Gemma interface
        ).fromFile(actualModelPath).install();
        debugPrint('✅ Model installed using fallback method');
      }
      
      debugPrint('🔄 Initializing model...');
      
      // Try to get the active model with optimized settings
      debugPrint('🔄 Getting active model...');
      try {
        _model = await FlutterGemma.getActiveModel(
          maxTokens: 2048,  // Increased context window
          preferredBackend: PreferredBackend.cpu,
        );
        
        // Log model info
        debugPrint('✅ Active model: $_model');
        debugPrint('📊 Model details:');
        debugPrint('   - Max tokens: ${_model.maxTokens}');
        debugPrint('   - Backend: ${_model.preferredBackend}');
        debugPrint('   - Model type: ${_model.modelType}');
        
        // Set generation parameters when actually generating text
        _generationParams = {
          'temperature': 0.7,  // More creative responses
          'topP': 0.9,         // Better response quality
          'topK': 50,          // More diverse outputs
        };
        debugPrint('⚙️ Using generation parameters: $_generationParams');
        
        // Model is ready - no need to test chat creation as it will be created on demand
      } catch (e) {
        debugPrint('⚠️ Failed to initialize with optimized settings, falling back to defaults: $e');
        try {
          _model = await FlutterGemma.getActiveModel(
            maxTokens: 1024,
            preferredBackend: PreferredBackend.cpu,
          );
          _generationParams = {};  // Use default generation parameters
          debugPrint('✅ Model initialized with fallback settings');
        } catch (e2) {
          debugPrint('❌ Failed to initialize model even with fallback settings: $e2');
          throw Exception('Failed to initialize model: $e2');
        }
      }
      
      _isInitialized = true;
      _isInitializing = false;
      debugPrint('✅ LLM service initialized successfully');
    } catch (e, stackTrace) {
      _isInitializing = false;
      debugPrint('❌ Error initializing LLM service: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;
  
  // Performance metrics stream
  Stream<PerformanceMetrics> get performanceMetrics => _metricsController.stream;
  
  // Current performance metrics
  PerformanceMetrics? get currentMetrics => _currentMetrics;
  
  // Current task configuration
  TaskConfig? get currentTask => _currentTask;
  
  // Set current task configuration
  void setCurrentTask(TaskConfig task) {
    _currentTask = task;
    debugPrint('🎯 Current task set to: ${task.type.displayName}');
  }
  
  // Get system prompt for current task
  String get _systemPrompt {
    if (_currentTask != null) {
      return _systemPrompts[_currentTask!.type.id] ?? _systemPrompts['llm_chat']!;
    }
    return _systemPrompts['llm_chat']!;
  }
  
  /// Cancels the current response generation
  Future<void> cancelGeneration() async {
    if (_isGenerating && _currentChat != null) {
      try {
        await _currentChat.cancel();
        debugPrint('🛑 Response generation cancelled');
      } catch (e) {
        debugPrint('Error cancelling generation: $e');
      } finally {
        _isGenerating = false;
        _currentChat = null;
      }
    }
  }

  bool get isGenerating => _isGenerating;
  
  /// Returns whether the current model supports image inputs
  bool get modelSupportsImage => _modelSupportsImage;

  /// Clears the conversation history
  void clearConversation() {
    _conversationHistory.clear();
    _currentChat = null; // Reset chat session
  }

  /// Clears the current model and resets the service
  Future<void> clearModel() async {
    debugPrint('🔄 Clearing model from LLM service...');
    
    // Dispose of the current model
    await _model?.dispose();
    _model = null;
    
    // Clear initialization state
    _isInitialized = false;
    _isInitializing = false;
    
    // Clear conversation history
    _conversationHistory.clear();
    _currentChat = null;
    
    // Clear shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyPath);
    await prefs.remove(_prefsKeyName);
    
    debugPrint('✅ Model cleared from LLM service');
  }

  /// Cancels the current response generation
  Future<void> cancelResponse() async {
    if (_isGenerating && _currentChat != null) {
      try {
        _isGenerating = false;
        debugPrint('🛑 Cancelling response generation...');
        // Some implementations might support cancellation
        // For now, we'll just set the flag and clean up
        _currentChat = null;
        debugPrint('✅ Response generation cancelled');
      } catch (e) {
        debugPrint('⚠️ Error cancelling response: $e');
      }
    }
  }

  /// Resets the conversation context, inspired by Edge Gallery's resetConversation
  Future<void> resetConversation({bool supportImage = false, bool supportAudio = false}) async {
    debugPrint('🔄 Resetting conversation...');
    
    try {
      // Cancel any ongoing generation
      await cancelGeneration();
      
      // Clear conversation history
      _conversationHistory.clear();
      
      // Reset current chat to force recreation
      _currentChat = null;
      
      // Update model capabilities if needed
      _modelSupportsImage = supportImage;
      
      // Reset performance metrics
      _currentMetrics = null;
      
      debugPrint('✅ Conversation reset completed');
    } catch (e) {
      debugPrint('❌ Error resetting conversation: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    await cancelGeneration();
    await _model?.dispose();
    _model = null;
    _conversationHistory.clear();
    _metricsController.close();
  }

  /// Generates a response for the given prompt using the loaded model.
  /// If imageBytes is provided, it will be used as a multimodal input.
  /// Returns a stream of tokens as they are generated.
  Stream<String> generateResponse(String prompt, {List<int>? imageBytes}) async* {
    if (imageBytes != null && !_modelSupportsImage) {
      throw Exception('The current model does not support image inputs');
    }
    if (!_isInitialized || _model == null) {
      throw Exception('Model not initialized');
    }
    
    debugPrint('[LLM] Generating response (${prompt.length} chars)...');
    
    // Performance tracking variables
    final stopwatch = Stopwatch()..start();
    final startTime = DateTime.now().millisecondsSinceEpoch;
    var firstRun = true;
    var timeToFirstToken = 0.0;
    var firstTokenTs = 0;
    var decodeTokens = 0;
    var prefillTokens = 0; // Will be calculated below
    var prefillSpeed = 0.0;
    var decodeSpeed = 0.0;
    
    // Safety limits to prevent infinite loops
    const maxTokens = 2000; // Maximum tokens to process
    const maxProcessingTime = Duration(seconds: 60); // Maximum processing time
    int tokenCount = 0;
    
    // Calculate prefill tokens (input prompt + image tokens)
    // Estimate input tokens (rough approximation: 1 token per 4 characters)
    final inputTokens = (prompt.length / 4).ceil();
    final imageTokens = (imageBytes != null ? 257 : 0); // Edge Gallery uses 257 tokens per image
    prefillTokens = inputTokens + imageTokens;
    
    // Ensure minimum prefill tokens for meaningful calculation
    if (prefillTokens < 10) {
      prefillTokens = 10; // Minimum baseline for system prompt and basic processing
    }
    
    debugPrint('📊 Prefill calculation: $inputTokens input tokens + $imageTokens image tokens = $prefillTokens total');
    
    // Initialize metrics
    _currentMetrics = PerformanceMetrics(
      timeToFirstToken: 0.0,
      prefillSpeed: 0.0,
      decodeSpeed: 0.0,
      latency: 0.0,
      totalTokens: 0,
      isRunning: true,
    );
    _metricsController.add(_currentMetrics!);
    
    // Acquire lock to prevent concurrent generation
    await _acquireLock();
    
    // Create or reuse chat session
    dynamic chat;
    try {
      // Always create a fresh chat to avoid state conflicts
      _currentChat = null;
      chat = await _model.createChat();
      debugPrint('✅ Chat session created successfully');
    } catch (e) {
      debugPrint('❌ Failed to create chat session: $e');
      rethrow;
    }
    
    try {
      _isGenerating = true;
      _currentChat = chat;
      
      // No automatic system prompt injection
      // System prompts must be explicitly provided in the user's prompt
      
      // Add user message to conversation history
      _conversationHistory.add({
        'role': 'user',
        'content': prompt,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Add the user's message to the chat
      if (imageBytes != null) {
        await chat.addQueryChunk(Message.withImage(
          text: prompt,
          imageBytes: Uint8List.fromList(imageBytes),
          isUser: true,
        ));
      } else {
        await chat.addQueryChunk(Message.text(
          text: prompt,
          isUser: true,
        ));
      }
      
      // Generate the response
      final responseStream = chat.generateChatResponseAsync();
      
      // Process the response stream
      String fullResponse = '';
      
      // Yield initial empty string to clear any previous content
      yield '';
      
      try {
        await for (final response in responseStream.timeout(maxProcessingTime)) {
          // Safety checks to prevent infinite loops
          if (tokenCount >= maxTokens) {
            debugPrint('⚠️ Maximum token limit ($maxTokens) reached. Stopping processing.');
            break;
          }
          
          if (stopwatch.elapsed > maxProcessingTime) {
            debugPrint('⚠️ Maximum processing time (${maxProcessingTime.inSeconds}s) reached. Stopping processing.');
            break;
          }
          
          if (response is TextResponse) {
            final curTs = DateTime.now().millisecondsSinceEpoch;
            
            if (firstRun) {
              firstTokenTs = DateTime.now().millisecondsSinceEpoch;
              timeToFirstToken = (firstTokenTs - startTime) / 1000.0;
              
              // Calculate prefill speed (tokens per second)
              if (timeToFirstToken > 0) {
                prefillSpeed = prefillTokens / timeToFirstToken;
              } else {
                prefillSpeed = 0.0; // Avoid division by zero
              }
              
              firstRun = false;
              debugPrint('⚡ First token received in ${timeToFirstToken.toStringAsFixed(2)}s');
              debugPrint('📊 Prefill speed: ${prefillSpeed.toStringAsFixed(1)} tokens/s (from $prefillTokens tokens)');
            } else {
              decodeTokens++;
            }
            
            tokenCount++;
            // Replace escaped newlines with actual newlines and update the full response
            final processedToken = response.token.replaceAll(r'\n', '\n');
            fullResponse += processedToken;
            
            // Verbose logging disabled to reduce console spam
            // debugPrint('📝 Token $tokenCount: "$processedToken"');
            // debugPrint('📝 Full response so far: "$fullResponse"');
            
            yield fullResponse;
          } else if (response is FunctionCallResponse) {
            debugPrint('🔧 Function call detected: ${response.name}');
            debugPrint('🔧 Arguments: ${response.args}');
            // You can implement function calling logic here
          } else if (response is ThinkingResponse) {
            debugPrint('🤔 Thinking: ${response.content}');
          }
        }
        
        // Calculate final metrics
        final totalTime = stopwatch.elapsedMilliseconds / 1000.0;
        final decodeTime = totalTime - timeToFirstToken;
        decodeSpeed = decodeTime > 0 ? decodeTokens / decodeTime : 0.0;
        
        // Update final metrics
        _currentMetrics = PerformanceMetrics(
          timeToFirstToken: timeToFirstToken,
          prefillSpeed: prefillSpeed,
          decodeSpeed: decodeSpeed.isNaN ? 0.0 : decodeSpeed,
          latency: totalTime,
          totalTokens: tokenCount,
          isRunning: false,
        );
        _metricsController.add(_currentMetrics!);
        
        debugPrint('[LLM] ✅ Done in ${totalTime.toStringAsFixed(1)}s ($tokenCount tokens, ${decodeSpeed.toStringAsFixed(0)} t/s)');
        if (fullResponse.isEmpty) {
          debugPrint('[LLM] ⚠️ Warning: Received empty response');
        }
      } catch (e) {
        if (e.toString().contains('cancelled')) {
          debugPrint('⚠️ Response generation was cancelled');
          yield fullResponse; // Return whatever we have so far
        } else if (e.toString().contains('timeout')) {
          debugPrint('⚠️ Response generation timed out after ${maxProcessingTime.inSeconds}s');
          debugPrint('📝 Partial response: "$fullResponse"');
          yield fullResponse; // Return whatever we have so far
        } else if (tokenCount >= maxTokens) {
          debugPrint('⚠️ Response generation stopped at token limit ($maxTokens)');
          debugPrint('📝 Partial response: "$fullResponse"');
          yield fullResponse; // Return whatever we have so far
        } else {
          debugPrint('❌ Error during response generation: $e');
          rethrow;
        }
      } finally {
        stopwatch.stop();
        _isGenerating = false;
        _currentChat = null;
        debugPrint('⏱️ Total processing time: ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Error in chat session: $e';
      debugPrint('❌ $errorMsg');
      debugPrint('📚 Stack trace: $stackTrace');
      rethrow;
    } finally {
      // Some chat implementations might not have a close method
      try {
        await chat?.close();
      } catch (e) {
        // Known flutter_gemma limitation - close() method doesn't exist
        // This is non-fatal and can be safely ignored
        debugPrint('[LLM] Note: Chat session cleanup skipped (flutter_gemma limitation)');
      }
      
      // Release lock
      _releaseLock();
    }
  }

  /// Generates response WITHOUT any default system prompt
  /// Used by TaskExtractor for classification with custom system prompts
  Stream<String> generateResponseWithoutDefaultPrompt(String prompt) async* {
    // 1. Do NOT touch _conversationHistory or _currentChat here to avoid side effects
    // The classification should be completely isolated
    
    // 2. Set deterministic parameters for classification
    final originalParams = Map<String, dynamic>.from(_generationParams);
    _generationParams = {
      'temperature': 0.0,  // Zero temperature for maximum determinism
      'topP': 1.0,         // Standard sampling
      'topK': 40,
      'maxTokens': 512,    // Strict limit for JSON output
    };
    debugPrint('[LLM] Using deterministic params for classification: $_generationParams');
    
    // 3. Acquire lock to prevent concurrent generation
    await _acquireLock();
    
    dynamic chat;
    try {
      // 4. Create a FRESH chat session specifically for this classification
      // This ensures no history is reused
      chat = await _model.createChat();
      debugPrint('[LLM] Created fresh chat session for classification');
      
      // 5. Add the prompt directly
      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));
      
      // 6. Generate response
      final responseStream = chat.generateChatResponseAsync();
      
      // 7. Yield results
      await for (final response in responseStream) {
        if (response is TextResponse) {
           // Yield each token as it comes
           yield response.token;
        }
      }
      
    } catch (e) {
      debugPrint('[LLM] Error in classification: $e');
      rethrow;
    } finally {
      // 8. Clean up - CRITICAL: Try to close/dispose the session if possible
      // Note: flutter_gemma might not expose a close() method on InferenceChat yet,
      // but creating a new one next time effectively resets the "current" session for this method.
      try {
        // await chat?.close(); // Uncomment if available
      } catch (_) {}
      
      _releaseLock();
      
      // Restore original parameters
      _generationParams = originalParams;
    }
  }

  /// Generates response WITH a custom system prompt for playground/chat
  Stream<String> generateResponseWithPrompt(String prompt, {String? systemPrompt, List<int>? imageBytes}) async* {
    final fullPrompt = systemPrompt != null 
        ? '$systemPrompt\n\n$prompt'
        : prompt;
    
    yield* generateResponse(fullPrompt, imageBytes: imageBytes);
  }

  /// Get the default chat system prompt
  static String get chatSystemPrompt => _systemPrompts['llm_chat'] ?? 
      "You are a helpful AI assistant. Engage in natural conversation and provide helpful, concise responses.";

  /// Acquire lock for exclusive generation access
  Future<void> _acquireLock() async {
    if (_isProcessing) {
      debugPrint('[LLM] ⏳ Waiting for previous generation to complete...');
      final completer = Completer<void>();
      _generationQueue.add(completer);
      await completer.future;
    }
    _isProcessing = true;
    debugPrint('[LLM] 🔒 Lock acquired');
  }

  /// Release lock and process next in queue
  void _releaseLock() {
    _isProcessing = false;
    debugPrint('[LLM] 🔓 Lock released');
    
    if (_generationQueue.isNotEmpty) {
      final next = _generationQueue.removeAt(0);
      next.complete();
    }
  }
}
