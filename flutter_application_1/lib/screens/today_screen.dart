import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/feed_item.dart';
import '../services/api_service.dart';
import '../widgets/feed_card.dart';
import '../widgets/loading_widget.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final ApiService _apiService = ApiService();
  List<FeedItem> _topPriorities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTopPriorities();
  }

  Future<void> _loadTopPriorities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final feedItems = await _apiService.getFeedItems(
        limit: 5,
        sortBy: 'priority',
        sortOrder: 'desc',
      );
      
      setState(() {
        _topPriorities = feedItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSwipeAction(FeedItem item, String action) async {
    try {
      switch (action) {
        case 'snooze':
          await _snoozeItem(item);
          break;
        case 'complete':
          await _completeItem(item);
          break;
        case 'dismiss':
          await _dismissItem(item);
          break;
      }
      
      // Reload priorities after action
      await _loadTopPriorities();
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _snoozeItem(FeedItem item) async {
    // TODO: Implement snooze functionality
    _showSuccessSnackBar('Item snoozed until tomorrow');
  }

  Future<void> _completeItem(FeedItem item) async {
    // TODO: Implement completion functionality
    _showSuccessSnackBar('Item marked as complete');
  }

  Future<void> _dismissItem(FeedItem item) async {
    // TODO: Implement dismiss functionality
    _showSuccessSnackBar('Item dismissed');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showExplainabilityDialog(FeedItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Why is this important?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildExplainabilityItem('Priority Score', item.priority.toDouble(), Colors.red),
            _buildExplainabilityItem('Relevance Score', item.relevance, Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Source: ${item.source.toUpperCase()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (item.metaData != null) ...[
              const SizedBox(height: 8),
              Text(
                'Additional Info:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatMetaData(item.metaData!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildExplainabilityItem(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            width: 60,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(value * 100).toInt()}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMetaData(Map<String, dynamic> metaData) {
    final List<String> items = [];
    
    if (metaData.containsKey('sender')) {
      items.add('From: ${metaData['sender']}');
    }
    if (metaData.containsKey('extracted_tasks')) {
      final tasks = metaData['extracted_tasks'] as List?;
      if (tasks != null && tasks.isNotEmpty) {
        items.add('Tasks: ${tasks.length}');
      }
    }
    if (metaData.containsKey('message_count')) {
      items.add('Messages: ${metaData['message_count']}');
    }
    
    return items.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Top Priorities'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _loadTopPriorities,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: LoadingWidget(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading priorities',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTopPriorities,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_topPriorities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No priorities today',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your data sources to see personalized priorities',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Setup Connectors'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTopPriorities,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _topPriorities.length,
        itemBuilder: (context, index) {
          final item = _topPriorities[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: Key(item.id.toString()),
              background: Container(
                color: Colors.green,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              secondaryBackground: Container(
                color: Colors.orange,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(
                  Icons.snooze,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  await _handleSwipeAction(item, 'complete');
                  return false; // Don't actually dismiss
                } else if (direction == DismissDirection.endToStart) {
                  await _handleSwipeAction(item, 'snooze');
                  return false; // Don't actually dismiss
                }
                return false;
              },
              child: FeedCard(
                feedItem: item,
                onTap: () => _showExplainabilityDialog(item),
                showPriority: true,
                showRelevance: true,
              ),
            ),
          );
        },
      ),
    );
  }
}


