import 'dart:async';
import 'dart:io';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter_gemma/flutter_gemma.dart';

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
  Map<String, dynamic> _generationParams = {};
  
  // Store conversation history
  final List<Map<String, dynamic>> _conversationHistory = [];
  
  // System prompt to provide context to the model
  static const String _systemPrompt = "You are a helpful AI assistant. Keep your responses concise and to the point.";
  
  // Singleton instance
  static final LocalLLMService _instance = LocalLLMService._internal();
  
  // Factory constructor to return the same instance
  factory LocalLLMService() => _instance;
  
  // Private constructor
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
  Future<void> initialize({String? modelPath, String? modelName}) async {
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
        
        // Set generation parameters when actually generating text
        _generationParams = {
          'temperature': 0.7,  // More creative responses
          'topP': 0.9,         // Better response quality
          'topK': 50,          // More diverse outputs
        };
        debugPrint('⚙️ Using generation parameters: $_generationParams');
      } catch (e) {
        debugPrint('⚠️ Failed to initialize with optimized settings, falling back to defaults: $e');
        _model = await FlutterGemma.getActiveModel(
          maxTokens: 1024,
          preferredBackend: PreferredBackend.cpu,
        );
        _generationParams = {};  // Use default generation parameters
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

  /// Clears the conversation history
  void clearConversation() {
    _conversationHistory.clear();
    _currentChat = null; // Reset chat session
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    await cancelGeneration();
    await _model?.dispose();
    _model = null;
    _conversationHistory.clear();
  }

  /// Generates a response for the given prompt using the loaded model.
  /// Returns a stream of tokens as they are generated.
  Stream<String> generateResponse(String prompt) async* {
    if (!_isInitialized || _model == null) {
      throw Exception('Model not initialized');
    }
    
    debugPrint('🔄 Starting response generation...');
    final stopwatch = Stopwatch()..start();
    
    // Create or reuse chat session
    final chat = _currentChat ?? await _model.createChat();
    
    try {
      _isGenerating = true;
      _currentChat = chat;
      
      // Add system prompt if this is the first message
      if (_conversationHistory.isEmpty) {
        await chat.addQueryChunk(Message.text(
          text: _systemPrompt,
          isUser: false,
        ));
      }
      
      // Add user message to conversation history
      _conversationHistory.add({
        'role': 'user',
        'content': prompt,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Add the user's message to the chat
      await chat.addQueryChunk(Message.text(
        text: prompt,
        isUser: true,
      ));
      
      // Generate the response with parameters
      debugPrint(' Generating response with params: $_generationParams');
      
      // Start listening to the response stream
      final responseStream = chat.generateChatResponseAsync();
      
      // Process the response stream
      String fullResponse = '';
      
      // Yield initial empty string to clear any previous content
      yield '';
      
      try {
        await for (final response in responseStream) {
          if (response is TextResponse) {
            // Replace escaped newlines with actual newlines and update the full response
            final processedToken = response.token.replaceAll(r'\n', '\n');
            fullResponse += processedToken;
            yield fullResponse;
          } else if (response is FunctionCallResponse) {
            debugPrint('Function call detected: ${response.name}');
            debugPrint('Arguments: ${response.args}');
            // You can implement function calling logic here
          } else if (response is ThinkingResponse) {
            debugPrint('Thinking: ${response.content}');
          }
        }
        
        debugPrint('✅ Response generated in ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('Full response: $fullResponse');
      } catch (e) {
        if (e.toString().contains('cancelled')) {
          debugPrint('Response generation was cancelled');
          yield fullResponse; // Return whatever we have so far
        } else {
          debugPrint('Error during response generation: $e');
          rethrow;
        }
      } finally {
        stopwatch.stop();
        _isGenerating = false;
        _currentChat = null;
        debugPrint('Total processing time: ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Error in chat session: $e';
      debugPrint(errorMsg);
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    } finally {
      // Some chat implementations might not have a close method
      try {
        if (chat is Closable) {
          await (chat as Closable).close();
        }
      } catch (e) {
        debugPrint('Warning: Failed to close chat session: $e');
      }
    }
  }
  
}
