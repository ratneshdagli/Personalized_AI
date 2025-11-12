import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/local_llm_service.dart';

class LocalModelChatInterface extends StatefulWidget {
  final String modelPath;
  final String modelName;
  
  const LocalModelChatInterface({
    super.key,
    required this.modelPath,
    required this.modelName,
  });

  @override
  State<LocalModelChatInterface> createState() => _LocalModelChatInterfaceState();
}

class _LocalModelChatInterfaceState extends State<LocalModelChatInterface> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late final LocalLLMService _llmService;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _llmService = LocalLLMService();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      setState(() => _isLoading = true);
      await _llmService.initialize(
        modelPath: widget.modelPath,
        modelName: widget.modelName,
      );
      setState(() => _isInitialized = true);
    } catch (e, stackTrace) {
      debugPrint('Error initializing model: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _error = 'Failed to load model: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  void _sendMessage() async {
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
    
    try {
          final stopwatch = Stopwatch()..start();
      final responseStream = _llmService.generateResponse(message);
      await for (final token in responseStream) {
        if (!mounted) return;
        final elapsed = stopwatch.elapsed;
        setState(() {
          _messages[responseIndex] = _messages[responseIndex].copyWith(
            text: token,
            generationTime: elapsed,
          );
        });
        _scrollToBottom();
      }
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
  }

  @override
  void dispose() {
    _llmService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.modelName}'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _isLoading && _messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return MessageBubble(
                            message: _messages[index],
                            isLast: index == _messages.length - 1,
                          );
                        },
                      ),
          ),
          if (_isLoading && _messages.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          Container(
            padding: const EdgeInsets.all(8),
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
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]!.withOpacity(0.5)
                            : Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading && _isInitialized && _error == null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(LucideIcons.send, color: Colors.white),
                      onPressed: _sendMessage,
                      disabledColor: Colors.grey,
                    ),
                  ),
                ],
              ),
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
  final ChatMessage message;
  final bool isLast;

  const MessageBubble({
    super.key,
    required this.message,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: message.isUser 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!message.isUser && message.generationTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.clock,
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(message.generationTime!.inMilliseconds / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
