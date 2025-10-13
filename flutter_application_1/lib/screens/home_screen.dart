import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      if (!mounted) return;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Your Day"),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(PhosphorIconsBold.gear),
            tooltip: 'Settings',
          ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => feedProvider.loadFeed(),
        child: _buildDashboard(feedProvider),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTaskExtractionDialog,
        icon: const Icon(PhosphorIconsBold.magicWand),
        label: const Text('Extract Tasks'),
        tooltip: 'Extract Tasks',
      ).animate().moveY(begin: 20, end: 0, duration: 400.ms, curve: Curves.easeOut).fadeIn(duration: 400.ms),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
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
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.white70,
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
            icon: Icon(PhosphorIconsLight.house),
            activeIcon: Icon(PhosphorIconsBold.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsLight.calendarDots),
            activeIcon: Icon(PhosphorIconsBold.calendarDots),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsLight.listMagnifyingGlass),
            activeIcon: Icon(PhosphorIconsBold.listMagnifyingGlass),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsLight.checks),
            activeIcon: Icon(PhosphorIconsBold.checks),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsLight.gearSix),
            activeIcon: Icon(PhosphorIconsBold.gearSix),
            label: 'Setup',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(FeedProvider feedProvider) {
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Hero Header
        _HeroHeader().animate().fadeIn(duration: 400.ms).moveY(begin: 12, end: 0, curve: Curves.easeOut),
        const SizedBox(height: 16),

        // Quick Actions
        _QuickActions(onExtract: _showTaskExtractionDialog).animate().fadeIn(duration: 450.ms).moveY(begin: 12, end: 0),
        const SizedBox(height: 16),

        // Highlights Grid
        _HighlightsGrid(feedProvider: feedProvider).animate().fadeIn(duration: 500.ms).moveY(begin: 12, end: 0),
        const SizedBox(height: 16),

        // Recent Feed section
        Text('Recent Feed', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...feedProvider.feed.take(5).toList().asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return FeedCard(
            feedItem: item,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tapped: ${item.title}')),
              );
            },
            showPriority: true,
            showRelevance: true,
          ).animate().fadeIn(delay: (100 * i).ms, duration: 350.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
        }),
      ],
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

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            child: const Icon(PhosphorIconsBold.sparkle, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  'Your personalized AI feed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onExtract;
  const _QuickActions({required this.onExtract});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onExtract,
            icon: const Icon(PhosphorIconsBold.magicWand),
            label: const Text('Extract Tasks'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/feed'),
            icon: const Icon(PhosphorIconsBold.listMagnifyingGlass),
            label: const Text('Open Feed'),
          ),
        ),
      ],
    );
  }
}

class _HighlightsGrid extends StatelessWidget {
  final FeedProvider feedProvider;
  const _HighlightsGrid({required this.feedProvider});

  @override
  Widget build(BuildContext context) {
    final items = feedProvider.feed;
    final high = items.where((i) => i.priority >= 0.7).length;
    final today = items.take(20).length;
    final sources = items.map((e) => e.source).toSet().length;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _StatTile(icon: PhosphorIconsBold.fire, label: 'High', value: '$high'),
        _StatTile(icon: PhosphorIconsBold.clock, label: 'Recent', value: '$today'),
        _StatTile(icon: PhosphorIconsBold.squaresFour, label: 'Sources', value: '$sources'),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}