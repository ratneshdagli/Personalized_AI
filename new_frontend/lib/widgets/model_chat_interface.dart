import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_llm_service.dart';
import '../models/task_types.dart';

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
  StreamSubscription<PerformanceMetrics>? _metricsSubscription;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _error;
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();
  final Stopwatch _stopwatch = Stopwatch(); // Add stopwatch for timing
  
  // Task and performance tracking
  TaskConfig? _currentTask;
  PerformanceMetrics? _currentMetrics;
  bool _showMetrics = false;

  @override
  void initState() {
    super.initState();
    
    // Set default task to AI Chat
    _currentTask = BuiltInTasks.getTaskByType(TaskType.llmChat);
    _llmService.setCurrentTask(_currentTask!);
    
    // Listen to performance metrics
    _metricsSubscription = _llmService.performanceMetrics.listen((metrics) {
      setState(() {
        _currentMetrics = metrics;
      });
    });
    
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
        // Check if the model supports images based on the model name or other criteria
        final bool supportsImage = widget.modelName.toLowerCase().contains('vision') || 
                                 widget.modelName.toLowerCase().contains('multimodal');
        
        await _llmService.initialize(
          modelPath: modelPath,
          modelName: modelName,
          llmSupportImage: supportsImage,
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
    _messageController.dispose();
    _scrollController.dispose();
    _responseSubscription?.cancel();
    _metricsSubscription?.cancel();
    _llmService.dispose();
    super.dispose();
  }

  // Helper method to get task icons
  IconData _getTaskIcon(TaskType taskType) {
    switch (taskType) {
      case TaskType.llmChat:
        return Icons.chat;
      case TaskType.llmPromptLab:
        return Icons.science;
      case TaskType.llmAskImage:
        return Icons.image;
      case TaskType.llmAskAudio:
        return Icons.mic;
    }
  }

  // Build performance metrics widget
  Widget _buildPerformanceMetrics() {
    if (_currentMetrics == null || !_showMetrics) return const SizedBox.shrink();
    
    final metrics = _currentMetrics!;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Performance Metrics',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem('TTFT', '${metrics.timeToFirstToken.toStringAsFixed(2)}s'),
              ),
              Expanded(
                child: _buildMetricItem('Prefill', '${metrics.prefillSpeed.toStringAsFixed(0)} t/s'),
              ),
              Expanded(
                child: _buildMetricItem('Decode', '${metrics.decodeSpeed.toStringAsFixed(0)} t/s'),
              ),
              Expanded(
                child: _buildMetricItem('Latency', '${metrics.latency.toStringAsFixed(2)}s'),
              ),
            ],
          ),
          if (metrics.totalTokens > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Total tokens: ${metrics.totalTokens}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.grey[800],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
    });
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
    if (message.isEmpty && _selectedImageBytes == null) return;

    setState(() {
      _messages.add(ChatMessage(
        text: message,
        isUser: true,
        imageBytes: _selectedImageBytes,
      ));
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      _responseSubscription?.cancel();
      
      // Start timing the response generation
      _stopwatch.reset();
      _stopwatch.start();
      
      // Add an empty assistant message that will be updated
      setState(() {
        _messages.add(ChatMessage(
          text: '',
          isUser: false,
        ));
      });
      
      final stream = _selectedImageBytes != null
          ? _llmService.generateResponseWithPrompt(
              message,
              systemPrompt: LocalLLMService.chatSystemPrompt,
              imageBytes: _selectedImageBytes,
            )
          : _llmService.generateResponseWithPrompt(
              message,
              systemPrompt: LocalLLMService.chatSystemPrompt,
            );
          
      _responseSubscription = stream.listen(
        (response) {
          setState(() {
            if (_messages.isNotEmpty) {
              _messages.last = _messages.last.copyWith(text: response);
            }
          });
          _scrollToBottom();
        },
        onError: (error) {
          _stopwatch.stop();
          setState(() {
            _error = error.toString();
            _isLoading = false;
            if (_messages.isNotEmpty) {
              _messages.last = _messages.last.copyWith(
                text: 'Error: ${error.toString()}',
                generationTime: _stopwatch.elapsed,
              );
            }
          });
        },
        onDone: () {
          _stopwatch.stop();
          _responseSubscription = null;
          setState(() {
            _isLoading = false;
            _selectedImageBytes = null; // Clear the selected image after sending
            if (_messages.isNotEmpty) {
              _messages.last = _messages.last.copyWith(
                generationTime: _stopwatch.elapsed,
              );
            }
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
            Text('${_currentTask?.displayName ?? 'AI Chat'}'),
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
          // Performance metrics toggle
          if (_currentMetrics != null)
            IconButton(
              icon: Icon(_showMetrics ? Icons.speed : Icons.speed_outlined),
              tooltip: 'Show performance metrics',
              onPressed: () {
                setState(() {
                  _showMetrics = !_showMetrics;
                });
              },
            ),
          // Task selection dropdown
          PopupMenuButton<TaskType>(
            icon: const Icon(Icons.task_alt),
            tooltip: 'Select task type',
            onSelected: (TaskType taskType) {
              final newTask = BuiltInTasks.getTaskByType(taskType);
              if (newTask != null) {
                setState(() {
                  _currentTask = newTask;
                });
                _llmService.setCurrentTask(newTask);
                _llmService.resetConversation(
                  supportImage: taskType == TaskType.llmAskImage,
                  supportAudio: taskType == TaskType.llmAskAudio,
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return TaskType.values.map((TaskType taskType) {
                return PopupMenuItem<TaskType>(
                  value: taskType,
                  child: Row(
                    children: [
                      Icon(_getTaskIcon(taskType)),
                      const SizedBox(width: 8),
                      Text(taskType.displayName),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear conversation',
            onPressed: _clearConversation,
          ),
        ],
      ),
        
      body: Column(
        children: [
          // Performance metrics display
          _buildPerformanceMetrics(),
          
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
                            message: message.text,
                            isUser: message.isUser,
                            generationTime: message.generationTime,
                            imageBytes: message.imageBytes,
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
            child: _buildInputField(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image preview
          if (_selectedImageBytes != null)
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.error_outline, color: Colors.red),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                    onPressed: _removeImage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          // Input row
          Row(
            children: [
              // Image picker button (only show if model supports images)
              if (_isInitialized && _llmService.modelSupportsImage)
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, size: 24),
                  onPressed: _pickImage,
                  tooltip: 'Attach image',
                ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _currentTask?.inputPlaceholder ?? 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 28),
                onPressed: _sendMessage,
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.all(12),
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final Duration? generationTime;
  final Uint8List? imageBytes;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.generationTime,
    this.imageBytes,
  });

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    Duration? generationTime,
    Uint8List? imageBytes,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      generationTime: generationTime ?? this.generationTime,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final Duration? generationTime;
  final Uint8List? imageBytes;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.generationTime,
    this.imageBytes,
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (imageBytes != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                      maxHeight: 200,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imageBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          padding: const EdgeInsets.all(16),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isUser
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (generationTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.clock,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(generationTime!.inMilliseconds / 1000).toStringAsFixed(1)}s',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (isUser)
            Container(
              margin: const EdgeInsets.only(left: 12),
              child: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}