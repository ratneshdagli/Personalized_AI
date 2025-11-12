import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_llm_service.dart';

class ModelChatInterface extends StatefulWidget {
  final String modelName;
  final String modelId;
  
  const ModelChatInterface({
    super.key,
    required this.modelName,
    required this.modelId,
  });

  @override
  State<ModelChatInterface> createState() => _ModelChatInterfaceState();
}

class _ModelChatInterfaceState extends State<ModelChatInterface> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final LocalLLMService _llmService = LocalLLMService();
  StreamSubscription<String>? _responseSubscription;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeModel();
    });
  }

  Future<void> _initializeModel() async {
    if (_isInitialized || _isInitializing) return;
    
    _isInitializing = true;
    
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final prefs = await SharedPreferences.getInstance();
      String? modelPath = prefs.getString('local_llm_model_path');
      String? modelName = prefs.getString('local_llm_model_name');
      
      // Check if the model file exists
      bool modelExists = modelPath != null && await File(modelPath).exists();
      
      // If model doesn't exist in the saved path, try to find it in the models directory
      if (!modelExists) {
        debugPrint('No valid model path in preferences, searching for downloaded model...');
        
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final modelsDir = Directory('${appDir.path}/models');
          
          if (await modelsDir.exists()) {
            final entities = await modelsDir.list().toList();
            final files = entities.whereType<File>().where((file) {
              return file.path.endsWith('.task');
            }).toList();
            
            if (files.isNotEmpty) {
              modelPath = files.first.path;
              modelName = path.basenameWithoutExtension(modelPath);
              debugPrint('Found model file at: $modelPath');
              
              // Save the found model to preferences
              await prefs.setString('local_llm_model_path', modelPath);
              if (modelName != null) {
                await prefs.setString('local_llm_model_name', modelName);
              }
              
              modelExists = true;
            }
          }
        } catch (e) {
          debugPrint('Error searching for model files: $e');
        }
      }
      
      if (modelExists) {
        debugPrint('Initializing model from: $modelPath');
        await _llmService.initialize(
          modelPath: modelPath,
          modelName: modelName,
        );
        setState(() => _isInitialized = true);
      } else {
        throw Exception('No local model found. Please download and select a model first.');
      }
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to initialize model: $e';
      debugPrint(errorMsg);
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _error = errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _llmService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading || !_isInitialized || _error != null) return;

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
      _messages.add(ChatMessage(text: '...', isUser: false));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();
    final responseIndex = _messages.length - 1;
    final stopwatch = Stopwatch()..start();
    
    try {
      final responseStream = _llmService.generateResponse(message);
      _responseSubscription = responseStream.listen(
        (token) {
          if (!mounted) return;
          final elapsed = stopwatch.elapsed;
          setState(() {
            // Trim any trailing newlines from the response
            final trimmedToken = token.trimRight();
            _messages[responseIndex] = _messages[responseIndex].copyWith(
              text: trimmedToken,
              generationTime: elapsed,
            );
          });
          _scrollToBottom();
        },
        onError: (error) {
          debugPrint('Error in response stream: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
              if (!error.toString().contains('cancelled')) {
                _messages[responseIndex] = ChatMessage(
                  text: 'Error: ${error.toString()}',
                  isUser: false,
                );
              }
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        cancelOnError: true,
      );
      
      // Wait for the subscription to complete or be cancelled
      await _responseSubscription?.asFuture();
    } catch (e, stackTrace) {
      debugPrint('Error generating response: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _messages[responseIndex] = ChatMessage(
          text: 'Error generating response. Please try again.\n$e',
          isUser: false,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    
    _scrollToBottom();
  }

  void _clearConversation() {
    if (_isLoading) {
      _responseSubscription?.cancel();
      setState(() => _isLoading = false);
    }
    _llmService.clearConversation();
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('AI Chat'),
            if (widget.modelName.isNotEmpty)
              Text(
                widget.modelName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear conversation',
            onPressed: _clearConversation,
          ),
        ],
      ),
        
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.alertTriangle, size: 48, color: Colors.orange),
                          const SizedBox(height: 16),
                          Text(
                            'Error Initializing Model',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _initializeModel,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.messageSquare, size: 48, color: Color(0xFF3B82F6)),
                            const SizedBox(height: 16),
                            Column(
                              children: [
                                Text(
                                  'Start chatting with ${widget.modelName}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF94A3B8)),
                                ),
                                const Text(
                                  'Ask a question or give it a prompt!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return MessageBubble(
                            text: message.text,
                            isUser: message.isUser,
                            generationTime: message.generationTime,
                          );
                        },
                      ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              border: Border(
                top: BorderSide(color: Colors.grey.shade800),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    onSubmitted: _isLoading ? null : (_) => _sendMessage(),
                  ),
                ),
                if (_isLoading)
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.red),
                    tooltip: 'Stop generation',
                    onPressed: () {
                      _llmService.cancelGeneration();
                      _responseSubscription?.cancel();
                      setState(() => _isLoading = false);
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(LucideIcons.send),
                    onPressed: _sendMessage,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Duration? generationTime;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.generationTime,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    Duration? generationTime,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp,
      generationTime: generationTime ?? this.generationTime,
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final Duration? generationTime;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.generationTime,
  });

  List<Widget> _buildGenerationTime(Duration duration) {
    return [
      const SizedBox(height: 4),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.clock,
            size: 12,
            color: Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0x1A3B82F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(LucideIcons.bot, size: 16, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.replaceAll(r'\n', '\n').trimRight(),
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFE2E8F0),
                      fontSize: 14,
                    ),
                  ),
                  if (!isUser && generationTime != null) ..._buildGenerationTime(generationTime!),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0x1A3B82F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(LucideIcons.user, size: 16, color: Color(0xFF3B82F6)),
            ),
          ],
        ],
      ),
    );
  }
}