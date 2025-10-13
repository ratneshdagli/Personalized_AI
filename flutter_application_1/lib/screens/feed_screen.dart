import 'package:flutter/material.dart';
import '../models/feed_item.dart';
import '../services/api_service.dart';
import '../widgets/feed_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/filter_chip.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<FeedItem> _feedItems = [];
  List<FeedItem> _filteredItems = [];
  bool _isLoading = true;
  String? _error;
  
  // Filter states
  Set<String> _selectedSources = {};
  Set<String> _selectedPriorities = {};
  String _sortBy = 'published_at';
  String _sortOrder = 'desc';
  
  // Available filters
  final List<String> _availableSources = ['gmail', 'whatsapp', 'news', 'reddit'];
  final List<String> _availablePriorities = ['high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _loadFeedItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeedItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final feedItems = await _apiService.getFeedItems(
        limit: 100,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );
      
      setState(() {
        _feedItems = feedItems;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<FeedItem> filtered = List.from(_feedItems);

    // Apply source filter
    if (_selectedSources.isNotEmpty) {
      filtered = filtered.where((item) => 
        _selectedSources.contains(item.source)
      ).toList();
    }

    // Apply priority filter
    if (_selectedPriorities.isNotEmpty) {
      filtered = filtered.where((item) {
        String priorityLevel;
        if (item.priority >= 0.7) {
          priorityLevel = 'high';
        } else if (item.priority >= 0.4) {
          priorityLevel = 'medium';
        } else {
          priorityLevel = 'low';
        }
        return _selectedPriorities.contains(priorityLevel);
      }).toList();
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((item) =>
        item.title.toLowerCase().contains(searchQuery) ||
        item.summary.toLowerCase().contains(searchQuery) ||
        item.content.toLowerCase().contains(searchQuery)
      ).toList();
    }

    setState(() {
      _filteredItems = filtered;
    });
  }

  void _onSearchChanged(String query) {
    _applyFilters();
  }

  void _toggleSourceFilter(String source) {
    setState(() {
      if (_selectedSources.contains(source)) {
        _selectedSources.remove(source);
      } else {
        _selectedSources.add(source);
      }
      _applyFilters();
    });
  }

  void _togglePriorityFilter(String priority) {
    setState(() {
      if (_selectedPriorities.contains(priority)) {
        _selectedPriorities.remove(priority);
      } else {
        _selectedPriorities.add(priority);
      }
      _applyFilters();
    });
  }

  void _changeSorting(String sortBy, String sortOrder) {
    setState(() {
      _sortBy = sortBy;
      _sortOrder = sortOrder;
    });
    _loadFeedItems();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedSources.clear();
      _selectedPriorities.clear();
      _searchController.clear();
      _sortBy = 'published_at';
      _sortOrder = 'desc';
    });
    _loadFeedItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _loadFeedItems,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'sort_date_desc':
                  _changeSorting('published_at', 'desc');
                  break;
                case 'sort_date_asc':
                  _changeSorting('published_at', 'asc');
                  break;
                case 'sort_priority_desc':
                  _changeSorting('priority', 'desc');
                  break;
                case 'sort_priority_asc':
                  _changeSorting('priority', 'asc');
                  break;
                case 'sort_relevance_desc':
                  _changeSorting('relevance', 'desc');
                  break;
                case 'sort_relevance_asc':
                  _changeSorting('relevance', 'asc');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sort_date_desc',
                child: Text('Sort by Date (Newest)'),
              ),
              const PopupMenuItem(
                value: 'sort_date_asc',
                child: Text('Sort by Date (Oldest)'),
              ),
              const PopupMenuItem(
                value: 'sort_priority_desc',
                child: Text('Sort by Priority (High)'),
              ),
              const PopupMenuItem(
                value: 'sort_priority_asc',
                child: Text('Sort by Priority (Low)'),
              ),
              const PopupMenuItem(
                value: 'sort_relevance_desc',
                child: Text('Sort by Relevance (High)'),
              ),
              const PopupMenuItem(
                value: 'sort_relevance_asc',
                child: Text('Sort by Relevance (Low)'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search feed items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          
          // Filter Chips
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Source filters
                      ..._availableSources.map((source) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(source.toUpperCase()),
                          selected: _selectedSources.contains(source),
                          onSelected: (_) => _toggleSourceFilter(source),
                          selectedColor: Colors.blue[100],
                        ),
                      )),
                      
                      // Priority filters
                      ..._availablePriorities.map((priority) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(priority.toUpperCase()),
                          selected: _selectedPriorities.contains(priority),
                          onSelected: (_) => _togglePriorityFilter(priority),
                          selectedColor: _getPriorityColor(priority),
                        ),
                      )),
                      
                      // Clear filters
                      if (_selectedSources.isNotEmpty || _selectedPriorities.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('CLEAR ALL'),
                            onSelected: (_) => _clearAllFilters(),
                            selectedColor: Colors.red[100],
                            selected: false,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_filteredItems.length} items',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (_selectedSources.isNotEmpty || _selectedPriorities.isNotEmpty)
                  Text(
                    'Filtered from ${_feedItems.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // Feed Items
          Expanded(
            child: _buildFeedList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5, // Show 5 skeleton cards
        itemBuilder: (context, index) {
          return const SkeletonCard();
        },
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading feed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFeedItems,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredItems.isEmpty) {
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
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _feedItems.isEmpty ? 'No feed items' : 'No items match your filters',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _feedItems.isEmpty 
                  ? 'Connect your data sources to see personalized content'
                  : 'Try adjusting your search or filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_feedItems.isEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                icon: const Icon(Icons.settings),
                label: const Text('Setup Connectors'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeedItems,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredItems.length,
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FeedCard(
              feedItem: item,
              onTap: () {
                // TODO: Navigate to detail view
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tapped: ${item.title}'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              showPriority: true,
              showRelevance: true,
            ),
          );
        },
      ),
    );
  }

  Color? _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red[100];
      case 'medium':
        return Colors.orange[100];
      case 'low':
        return Colors.green[100];
      default:
        return null;
    }
  }
}
