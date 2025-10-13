import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/feed_card.dart';
import '../widgets/loading_widget.dart';
import '../services/api_service.dart';
import '../models/task.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch data when the screen is first loaded, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FeedProvider>(context, listen: false).loadFeed();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          "Today's Priorities",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => feedProvider.loadFeed(),
        child: _buildBody(feedProvider),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTaskExtractionDialog,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Extract Tasks'),
        tooltip: 'Extract Tasks',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on home screen
              break;
            case 1:
              Navigator.pushNamed(context, '/today');
              break;
            case 2:
              Navigator.pushNamed(context, '/feed');
              break;
            case 3:
              Navigator.pushNamed(context, '/tasks');
              break;
            case 4:
              Navigator.pushNamed(context, '/login');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            activeIcon: Icon(Icons.today),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed_outlined),
            activeIcon: Icon(Icons.feed),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            activeIcon: Icon(Icons.task),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Setup',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(FeedProvider feedProvider) {
    if (feedProvider.loading && feedProvider.feed.isEmpty) {
      return Center(
        child: LoadingWidget(
          message: 'Loading your personalized feed...',
          size: 60,
        ),
      );
    }

    if (feedProvider.feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "All caught up!",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Pull down to refresh your feed.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.settings),
              label: const Text('Setup Connectors'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Space for FAB
      itemCount: feedProvider.feed.length,
      itemBuilder: (context, index) {
        return FeedCard(
          feedItem: feedProvider.feed[index],
          onTap: () {
            // TODO: Navigate to detail view
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tapped: ${feedProvider.feed[index].title}'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          showPriority: true,
          showRelevance: true,
        );
      },
    );
  }

  void _showTaskExtractionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Extract Tasks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter text to extract tasks from:'),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'e.g., Please submit your assignment by October 15th. Also, attend the meeting tomorrow at 2 PM.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _textController.clear();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_textController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  await _extractTasks(_textController.text);
                  _textController.clear();
                }
              },
              child: const Text('Extract'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _extractTasks(String text) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Extracting tasks...'),
              ],
            ),
          );
        },
      );

      final result = await _apiService.extractTasks(text);

      // Hide loading dialog
      Navigator.of(context).pop();

      // Show results
      _showTaskResults(result);
    } catch (e) {
      // Hide loading dialog
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error extracting tasks: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTaskResults(TaskExtractionResult result) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Extracted Tasks'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary: ${result.summary}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tasks Found:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (result.tasks.isEmpty)
                  const Text('No tasks found in the text.')
                else
                  ...result.tasks.map((task) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${task.verb.toUpperCase()}: ${task.text}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (task.dueDate != null)
                            Text(
                              'Due: ${task.dueDate}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}