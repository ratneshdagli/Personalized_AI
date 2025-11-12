import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/feed_item.dart' as backend;
import '../models/task.dart' as backend;
import '../llm/llm_service.dart';

// Lightweight in-memory UI state (Provider/ChangeNotifier)
// Data models (visual-only)
enum FeedType { email, message, news, whatsapp }

class FeedItem {
  final String id;
  final FeedType type;
  final List<String> categories; // e.g., ['urgent','work']
  final String sender;
  final String title;
  final String summary;
  final String? fullContent;
  final List<String> tags;
  final String time; // e.g., '2h ago'
  final int? priority; // optional 1..10
  FeedItem({
    required this.id,
    required this.type,
    required this.categories,
    required this.sender,
    required this.title,
    required this.summary,
    this.fullContent,
    required this.tags,
    required this.time,
    this.priority,
  });
}

class CategoryConfig {
  final String id;
  final String name;
  final String shortName;
  final List<Color> gradient;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final Color ringColor;
  const CategoryConfig({
    required this.id,
    required this.name,
    required this.shortName,
    required this.gradient,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.ringColor,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortName': shortName,
        'gradient': gradient.map((c) => c.value).toList(),
        'bg': bgColor.value,
        'text': textColor.value,
        'border': borderColor.value,
        'ring': ringColor.value,
      };
  static CategoryConfig fromJson(Map<String, dynamic> j) => CategoryConfig(
        id: j['id'],
        name: j['name'],
        shortName: j['shortName'],
        gradient: ((j['gradient'] as List).cast<int>()).map((v) => Color(v)).toList(),
        bgColor: Color(j['bg']),
        textColor: Color(j['text']),
        borderColor: Color(j['border']),
        ringColor: Color(j['ring']),
      );
}
class HubItem {
  final String id;
  final String hub; // e.g., "Urgent & Priority"
  final String title;
  final String meta; // description/source
  final List<Color> gradient;
  final IconData icon;
  HubItem(this.id, this.hub, this.title, this.meta, this.gradient, this.icon);
}

enum Priority { low, medium, high }

class TodoItem {
  final String id;
  String title;
  String? desc; // source/description
  Priority priority;
  String? dueLabel; // React uses labels like 'Oct 18'
  DateTime? due; // optional actual date if used elsewhere
  bool completed;
  List<String> tags;
  TodoItem({
    required this.id,
    required this.title,
    this.desc,
    required this.priority,
    this.dueLabel,
    this.due,
    this.completed = false,
    this.tags = const [],
  });
}

enum EventSource { email, whatsapp, messages, phone, manual }

class CalendarEventVM {
  final String id;
  String title;
  DateTime date;
  TimeOfDay start;
  Duration duration;
  List<Color> gradient;
  String? location;
  EventSource source;
  bool isAIDetected;
  CalendarEventVM({
    required this.id,
    required this.title,
    required this.date,
    required this.start,
    required this.duration,
    required this.gradient,
    this.location,
    this.source = EventSource.manual,
    this.isAIDetected = false,
  });
}

class AppState extends ChangeNotifier {
  // API service
  final ApiService _apiService = ApiService();
  
  // Loading states
  bool _isLoadingFeed = false;
  bool _isLoadingTasks = false;
  String? _errorMessage;
  
  // Polling timer for auto-refresh
  Timer? _pollingTimer;
  
  bool get isLoadingFeed => _isLoadingFeed;
  bool get isLoadingTasks => _isLoadingTasks;
  String? get errorMessage => _errorMessage;
  
  // Search/filter state
  String _search = '';
  final TextEditingController searchController = TextEditingController();
  // Theme state
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
  AppState() {
    searchController.addListener(() {
      final v = searchController.text;
      if (v != _search) {
        _search = v;
        notifyListeners();
      }
    });
  }

  Future<void> init() async {
    await _loadFeedFromBackend();
    await _loadTodosFromBackend();
    await _loadEventsFromBackend();
    
    // Start automatic polling every 30 seconds
    startPolling();
  }
  
  /// Start automatic polling for live updates
  void startPolling() {
    _pollingTimer?.cancel(); // Cancel existing timer if any
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      // Silently refresh in background without showing loading indicator
      try {
        final backendItems = await _apiService.fetchFeed();
        if (backendItems.isNotEmpty) {
          _feedItems.clear();
          for (final item in backendItems) {
            _feedItems.add(_convertBackendToUIFeedItem(item));
          }
          _hubItems.clear();
          notifyListeners();
        }
      } catch (e) {
        // Silently fail, don't interrupt user experience
        print('Background poll failed: $e');
      }
    });
  }
  
  /// Stop automatic polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
  
  @override
  void dispose() {
    stopPolling();
    searchController.dispose();
    super.dispose();
  }
  String get search => _search;
  set search(String v) {
    _search = v;
    if (searchController.text != v) {
      searchController.text = v;
      searchController.selection = TextSelection.fromPosition(TextPosition(offset: v.length));
    }
    notifyListeners();
  }

  void clearSearch() {
    if (_search.isNotEmpty || searchController.text.isNotEmpty) {
      _search = '';
      searchController.clear();
      notifyListeners();
    }
  }

  // Home hubs and items
  final List<String> hubs = const [
    'Urgent & Priority',
    'Conversations',
    'Work & Email',
    'Reminders',
    'Finance',
    'News & Trends',
    'Personal',
  ];
  // New: feed items mirroring HomeFeed.tsx mockData
  final List<FeedItem> _feedItems = [
    FeedItem(
      id: '1',
      type: FeedType.email,
      categories: ['urgent', 'work', 'reminders'],
      sender: 'Sarah Chen',
      title: 'Project Update: Q4 Review',
      summary: 'Team meeting scheduled for Thursday. Please review the quarterly metrics...',
      fullContent:
          'Team meeting scheduled for Thursday at 2 PM. Please review the quarterly metrics before the call. We\'ll be discussing the progress on all major initiatives and planning for Q1 next year.',
      tags: ['Work', 'Important'],
      time: '2h ago',
      priority: 9,
    ),
    FeedItem(
      id: '2',
      type: FeedType.whatsapp,
      categories: ['personal', 'conversations'],
      sender: 'Alex Rivera',
      title: 'Dinner plans this weekend?',
      summary: 'Hey! Want to try that new restaurant downtown? I heard great reviews.',
      fullContent:
          'Hey! Want to try that new restaurant downtown? I heard great reviews. They have amazing Italian food and the atmosphere looks perfect for catching up. Let me know if Saturday works for you!',
      tags: ['Personal', 'Social'],
      time: '1h ago',
      priority: 5,
    ),
    FeedItem(
      id: '2b',
      type: FeedType.message,
      categories: ['work', 'conversations'],
      sender: 'Jordan Smith',
      title: 'Meeting notes shared',
      summary: 'Attached the notes from today\'s brainstorming session...',
      fullContent:
          'Attached the notes from today\'s brainstorming session. Please review and add your thoughts. We have some great ideas to explore for the next sprint.',
      tags: ['Work', 'Notes'],
      time: '4h ago',
      priority: 6,
    ),
    FeedItem(
      id: '3',
      type: FeedType.news,
      categories: ['news', 'trends'],
      sender: 'Tech Daily',
      title: 'AI Advances in Healthcare',
      summary: 'New research shows AI models can detect early signs of diseases...',
      fullContent:
          'New research shows AI models can detect early signs of diseases with 95% accuracy. Scientists at leading institutions have developed breakthrough algorithms that analyze medical imaging data to identify potential health issues before traditional methods.',
      tags: ['Technology', 'Health'],
      time: '6h ago',
      priority: 4,
    ),
    FeedItem(
      id: '4',
      type: FeedType.email,
      categories: ['work', 'news'],
      sender: 'Marketing Team',
      title: 'Campaign Performance Report',
      summary: 'Last month\'s campaign exceeded expectations with 40% increase...',
      fullContent:
          'Last month\'s campaign exceeded expectations with 40% increase in engagement. Our social media strategy paid off significantly, with Instagram showing the highest ROI. We should continue this approach into next quarter.',
      tags: ['Work', 'Marketing'],
      time: '1d ago',
      priority: 3,
    ),
    FeedItem(
      id: '5b',
      type: FeedType.whatsapp,
      categories: ['reminders', 'personal'],
      sender: 'Study Group',
      title: 'Quiz prep tonight',
      summary: 'Meeting at the library at 7 PM for quiz preparation',
      fullContent:
          'Meeting at the library at 7 PM for quiz preparation. Don\'t forget to bring your notes on chapters 5-8. Sarah is bringing snacks!',
      tags: ['Study', 'Group'],
      time: '5h ago',
      priority: 8,
    ),
    FeedItem(
      id: '6',
      type: FeedType.email,
      categories: ['urgent', 'work', 'reminders'],
      sender: 'HR Department',
      title: 'Benefits Enrollment Reminder',
      summary: 'Annual benefits enrollment period closes this Friday...',
      fullContent:
          'Annual benefits enrollment period closes this Friday at 5 PM. Please review your health insurance options and update your selections in the portal. Don\'t miss the deadline!',
      tags: ['Work', 'Important'],
      time: '2d ago',
      priority: 10,
    ),
    FeedItem(
      id: '7',
      type: FeedType.news,
      categories: ['news', 'trends'],
      sender: 'Design Weekly',
      title: 'Top UI Trends for 2025',
      summary: 'Explore the latest design patterns shaping modern interfaces...',
      fullContent:
          'Explore the latest design patterns shaping modern interfaces. From glassmorphism to ambient computing, these trends are revolutionizing how we interact with digital products.',
      tags: ['Design', 'Technology'],
      time: '2d ago',
      priority: 2,
    ),
    FeedItem(
      id: '8',
      type: FeedType.message,
      categories: ['personal', 'reminders'],
      sender: 'Mom',
      title: 'Family dinner next Sunday',
      summary: 'Hi sweetie! Would you be free for dinner next Sunday?',
      fullContent:
          'Hi sweetie! Would you be free for dinner next Sunday? Dad and I were thinking of making your favorite lasagna. Your sister will be in town too, so it would be great to have everyone together.',
      tags: ['Family', 'Personal'],
      time: '3d ago',
      priority: 7,
    ),
    FeedItem(
      id: '10',
      type: FeedType.email,
      categories: ['finance'],
      sender: 'Chase Bank',
      title: 'Your Monthly Statement is Ready',
      summary: 'View your account activity and spending summary for October...',
      fullContent:
          'View your account activity and spending summary for October. You spent \$2,450 this month, which is 10% less than last month. Great job staying on budget!',
      tags: ['Finance', 'Banking'],
      time: '1d ago',
      priority: 6,
    ),
  ];

  // Saved/custom filters state
  String _customFilter = '';
  final List<String> _savedFilters = [];
  // Custom hubs
  final List<CategoryConfig> _customHubs = [];
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _customFilter = prefs.getString('customFilter') ?? '';
    _savedFilters
      ..clear()
      ..addAll(prefs.getStringList('savedFilters') ?? const []);
    // NOTE: Hubs persistence omitted for brevity; will load when stored as JSON.
    _customHubs.clear();
    notifyListeners();
  }
  String _selectedHubTab = 'Hubs'; // 'Hubs' or 'All' or hub name
  String get selectedHubTab => _selectedHubTab;
  void setHubTab(String v) {
    _selectedHubTab = v;
    notifyListeners();
  }

  final List<HubItem> _hubItems = [];
  List<HubItem> get hubFeed {
    // Backward-compat via projecting FeedItem -> HubItem
    if (_hubItems.isEmpty) {
      for (final f in _feedItems) {
        // map feed categories to one of default hubs for demo
        String hub = 'Personal';
        if (f.categories.contains('urgent')) hub = 'Urgent & Priority';
        else if (f.categories.contains('conversations')) hub = 'Conversations';
        else if (f.categories.contains('work')) hub = 'Work & Email';
        else if (f.categories.contains('reminders')) hub = 'Reminders';
        else if (f.categories.contains('finance')) hub = 'Finance';
        else if (f.categories.contains('news') || f.categories.contains('trends')) hub = 'News & Trends';
        _hubItems.add(HubItem(
          f.id,
          hub,
          f.title,
          '${f.sender} • ${f.time}',
          const [Color(0xFFA855F7), Color(0xFFEC4899)],
          Icons.forum,
        ));
      }
    }
    final q = _search.toLowerCase();
    Iterable<HubItem> list = _hubItems;
    if (_selectedHubTab != 'All' && _selectedHubTab != 'Hubs') {
      list = list.where((e) => e.hub == _selectedHubTab);
    }
    if (q.isNotEmpty) list = list.where((e) => e.title.toLowerCase().contains(q) || e.meta.toLowerCase().contains(q));
    return list.toList();
  }

  // New filtered feed applying search and custom filter (simple contains for demo)
  List<FeedItem> get filteredFeed {
    Iterable<FeedItem> list = _feedItems;
    final q = _search.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((f) => f.title.toLowerCase().contains(q) || f.summary.toLowerCase().contains(q) || (f.fullContent ?? '').toLowerCase().contains(q));
    }
    final cf = _customFilter.trim().toLowerCase();
    if (cf.isNotEmpty) {
      list = list.where((f) => f.title.toLowerCase().contains(cf) || f.summary.toLowerCase().contains(cf) || f.tags.any((t) => t.toLowerCase().contains(cf)));
    }
    return list.toList();
  }

  // Priority feed - high priority items from backend
  List<FeedItem> get priorityFeed {
    return _feedItems.where((f) => (f.priority ?? 0) >= 8).toList()
      ..sort((a, b) => (b.priority ?? 0).compareTo(a.priority ?? 0));
  }

  // Unread count
  int get unreadCount => _feedItems.where((f) => f.tags.contains('unread')).length;

  List<FeedItem> getHubItems(CategoryConfig hub) {
    // filter by category id
    return filteredFeed.where((f) => f.categories.contains(hub.id)).toList();
  }

  /// Load feed items from backend and convert to UI models
  Future<void> _loadFeedFromBackend() async {
    _isLoadingFeed = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check backend health first
      final isHealthy = await _apiService.checkHealth();
      if (!isHealthy) {
        print('Backend is not healthy, using mock data');
        _isLoadingFeed = false;
        notifyListeners();
        return;
      }

      // Fetch feed from backend
      final backendItems = await _apiService.fetchFeed();
      print('Loaded ${backendItems.length} items from backend');

      // Convert backend items to UI feed items
      _feedItems.clear();
      for (final item in backendItems) {
        _feedItems.add(_convertBackendToUIFeedItem(item));
      }

      // Rebuild hub items
      _hubItems.clear();

      print('Successfully loaded ${_feedItems.length} feed items from backend');
    } catch (e) {
      _errorMessage = 'Failed to load feed: $e';
      print('Error loading feed from backend: $e');
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  /// Convert backend feed item to UI feed item
  FeedItem _convertBackendToUIFeedItem(backend.BackendFeedItem item) {
    // Determine feed type based on source
    FeedType type = FeedType.message;
    if (item.source.toLowerCase().contains('email')) {
      type = FeedType.email;
    } else if (item.source.toLowerCase().contains('whatsapp')) {
      type = FeedType.whatsapp;
    } else if (item.source.toLowerCase().contains('news')) {
      type = FeedType.news;
    }

    // Map priority to categories
    List<String> categories = [];
    if (item.priority >= 8) {
      categories.add('urgent');
    }
    if (item.source.toLowerCase().contains('email') || item.source.toLowerCase().contains('work')) {
      categories.add('work');
    }
    if (item.source.toLowerCase().contains('whatsapp') || item.source.toLowerCase().contains('message')) {
      categories.add('conversations');
    }
    if (item.source.toLowerCase().contains('news')) {
      categories.add('news');
      categories.add('trends');
    }
    if (categories.isEmpty) {
      categories.add('personal');
    }

    // Extract sender from metadata or use source
    String sender = item.metaData?['sender'] ?? item.source;

    // Format time ago
    String timeAgo = _formatTimeAgo(item.date);

    // Extract tags from metadata
    List<String> tags = [];
    if (item.metaData?['tags'] != null) {
      tags = List<String>.from(item.metaData!['tags']);
    }

    return FeedItem(
      id: item.id,
      type: type,
      categories: categories,
      sender: sender,
      title: item.title,
      summary: item.summary,
      fullContent: item.fullText,
      tags: tags,
      time: timeAgo,
      priority: item.priority,
    );
  }

  /// Format date as time ago (e.g., "2h ago")
  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Refresh feed from backend
  Future<void> refreshFeed() async {
    await _loadFeedFromBackend();
    await _loadTodosFromBackend();
    await _loadEventsFromBackend();
  }

  /// Load AI-extracted todos from backend
  Future<void> _loadTodosFromBackend() async {
    try {
      final backendTodos = await _apiService.fetchTodos(completed: false);
      print('Loaded ${backendTodos.length} todos from backend');

      // Convert backend todos to UI todos
      for (final todoData in backendTodos) {
        _addBackendTaskToTodos(backend.BackendTask.fromJson({
          'id': todoData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'title': todoData['title'] ?? '',
          'verb': todoData['verb'] ?? '',
          'due_date': todoData['due_date'],
          'text': todoData['description'] ?? todoData['title'] ?? '',
          'priority': todoData['priority'] ?? 1,
          'isCompleted': todoData['completed'] ?? false,
          'completedAt': todoData['completed_at'],
          'createdAt': todoData['created_at'],
        }));
      }

      print('Successfully loaded ${backendTodos.length} todos from backend');
    } catch (e) {
      print('Error loading todos from backend: $e');
    }
  }

  /// Load AI-extracted events from backend
  Future<void> _loadEventsFromBackend() async {
    try {
      final backendEvents = await _apiService.fetchEvents();
      print('Loaded ${backendEvents.length} events from backend');

      // Convert backend events to UI calendar events
      for (final eventData in backendEvents) {
        if (eventData['start_time'] == null) continue;

        try {
          final startTime = DateTime.parse(eventData['start_time']);
          final duration = Duration(minutes: eventData['duration_minutes'] ?? 60);

          // Determine gradient based on source
          List<Color> gradient = const [Color(0xFFA855F7), Color(0xFF7C3AED)];
          if (eventData['source'] == 'whatsapp') {
            gradient = const [Color(0xFF22C55E), Color(0xFF16A34A)];
          } else if (eventData['source'] == 'email') {
            gradient = const [Color(0xFF3B82F6), Color(0xFF2563EB)];
          }

          final calendarEvent = CalendarEventVM(
            id: eventData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: eventData['title'] ?? 'Event',
            date: startTime,
            start: TimeOfDay(hour: startTime.hour, minute: startTime.minute),
            duration: duration,
            gradient: gradient,
            location: eventData['location'],
            source: _mapEventSource(eventData['source']),
            isAIDetected: eventData['is_ai_detected'] ?? true,
          );

          _events.add(calendarEvent);
        } catch (e) {
          print('Error parsing event: $e');
        }
      }

      print('Successfully loaded ${backendEvents.length} events from backend');
      notifyListeners();
    } catch (e) {
      print('Error loading events from backend: $e');
    }
  }

  EventSource _mapEventSource(String? source) {
    switch (source?.toLowerCase()) {
      case 'whatsapp':
        return EventSource.whatsapp;
      case 'email':
        return EventSource.email;
      case 'phone':
        return EventSource.phone;
      default:
        return EventSource.manual;
    }
  }

  /// Extract tasks from text using local on-device LLM with backend fallback
  Future<backend.TaskExtractionResult?> extractTasksFromText(String text) async {
    _isLoadingTasks = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Prefer local LLM
      final llm = LlmService();
      final res = await llm.extractTasks(text);
      final result = backend.TaskExtractionResult.fromJson(res);
      print('Extracted ${result.tasks.length} tasks from text (local-first)');
      
      // Convert backend tasks to UI todos
      for (final task in result.tasks) {
        _addBackendTaskToTodos(task);
      }
      
      return result;
    } catch (e) {
      _errorMessage = 'Failed to extract tasks: $e';
      print('Error extracting tasks: $e');
      return null;
    } finally {
      _isLoadingTasks = false;
      notifyListeners();
    }
  }

  /// Convert backend task to UI todo item
  void _addBackendTaskToTodos(backend.BackendTask task) {
    // Determine priority based on backend priority
    Priority priority = Priority.medium;
    if (task.priority >= 8) {
      priority = Priority.high;
    } else if (task.priority <= 3) {
      priority = Priority.low;
    }

    // Format due date label
    String? dueLabel;
    if (task.dueDate != null) {
      final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][task.dueDate!.month - 1];
      dueLabel = '$month ${task.dueDate!.day}';
    }

    final todoItem = TodoItem(
      id: task.id,
      title: task.title,
      desc: task.text,
      priority: priority,
      dueLabel: dueLabel,
      due: task.dueDate,
      completed: task.isCompleted,
    );

    addTodo(todoItem);
  }

  // Custom filter methods
  String get customFilter => _customFilter;
  List<String> get savedFilters => List.unmodifiable(_savedFilters);
  Future<void> setCustomFilter(String v) async {
    _customFilter = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customFilter', v);
    notifyListeners();
  }
  Future<void> saveCurrentFilter() async {
    if (_customFilter.trim().isEmpty) return;
    _savedFilters.add(_customFilter.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('savedFilters', _savedFilters);
    notifyListeners();
  }
  Future<void> applySavedFilter(String filter) async {
    await setCustomFilter(filter);
  }
  Future<void> removeSavedFilter(int index) async {
    if (index < 0 || index >= _savedFilters.length) return;
    _savedFilters.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('savedFilters', _savedFilters);
    notifyListeners();
  }

  // Custom hubs management
  List<CategoryConfig> get customHubs => List.unmodifiable(_customHubs);
  Future<void> addCustomHub(CategoryConfig hub) async {
    _customHubs.add(hub);
    await _persistHubs();
    notifyListeners();
  }
  Future<void> updateCustomHub(CategoryConfig hub) async {
    final i = _customHubs.indexWhere((h) => h.id == hub.id);
    if (i != -1) _customHubs[i] = hub;
    await _persistHubs();
    notifyListeners();
  }
  Future<void> removeCustomHub(String hubId) async {
    _customHubs.removeWhere((h) => h.id == hubId);
    await _persistHubs();
    notifyListeners();
  }
  Future<void> _persistHubs() async {
    final prefs = await SharedPreferences.getInstance();
    // For brevity, store only count (full JSON encode omitted). Real impl would use jsonEncode.
    await prefs.setStringList('customHubs', _customHubs.map((h) => h.toJson().toString()).toList());
  }

  // Count items per hub (for hub tiles badges)
  int hubCount(String hubName) => _hubItems.where((e) => e.hub == hubName).length;

  void addHubItem(HubItem item) {
    _hubItems.insert(0, item);
    notifyListeners();
  }

  // ToDo state
  Priority _todoFilter = Priority.high; // used with segmented chips; 'All' handled by nullable
  Priority? _todoFilterNullable; // null => All
  Priority? get todoFilter => _todoFilterNullable;
  void setTodoFilter(Priority? p) {
    _todoFilterNullable = p;
    notifyListeners();
  }

  // Seeded from React mockTasks (TodoScreen.tsx)
  final List<TodoItem> _todos = [
    TodoItem(id: '1', title: 'Review Q4 metrics before Thursday meeting', desc: 'Email from Sarah', priority: Priority.high, dueLabel: 'Oct 18', completed: false),
    TodoItem(id: '2', title: 'Respond to Alex about weekend dinner', desc: 'Message from Alex', priority: Priority.medium, completed: false),
    TodoItem(id: '3', title: 'Check campaign performance report', desc: 'Email from Marketing', priority: Priority.medium, dueLabel: 'Oct 20', completed: false),
    TodoItem(id: '4', title: 'Get book recommendation from Jamie', desc: 'Message from Jamie', priority: Priority.low, completed: false),
    TodoItem(id: '5', title: 'Complete benefits enrollment', desc: 'Email from HR', priority: Priority.high, dueLabel: 'Oct 19', completed: false),
    TodoItem(id: '6', title: 'Confirm family dinner attendance', desc: 'Message from Mom', priority: Priority.medium, dueLabel: 'Oct 21', completed: false),
    TodoItem(id: '7', title: 'Review design trends article', desc: 'Design Weekly', priority: Priority.low, completed: false),
    TodoItem(id: '8', title: 'Prepare presentation slides', desc: 'Email from Sarah', priority: Priority.high, dueLabel: 'Oct 18', completed: false),
  ];
  List<TodoItem> get todos {
    Iterable<TodoItem> list = _todos;
    if (_todoFilterNullable != null) {
      list = list.where((t) => t.priority == _todoFilterNullable);
    }
    final q = _search.toLowerCase();
    if (q.isNotEmpty) list = list.where((t) => t.title.toLowerCase().contains(q) || (t.desc ?? '').toLowerCase().contains(q));
    return list.toList();
  }
  // Grouping parity with React: today = labels 'Oct 18' or 'Oct 19'; upcoming = other labels; backlog = no label
  List<TodoItem> get today => todos.where((t) => (t.dueLabel == 'Oct 18' || t.dueLabel == 'Oct 19') && !t.completed).toList();
  List<TodoItem> get upcoming => todos.where((t) => t.dueLabel != null && !(t.dueLabel == 'Oct 18' || t.dueLabel == 'Oct 19') && !t.completed).toList();
  List<TodoItem> get backlog => todos.where((t) => t.dueLabel == null && !t.completed).toList();
  List<TodoItem> get completed => _todos.where((t) => t.completed).toList();

  void toggleTodo(String id) async {
    final i = _todos.indexWhere((t) => t.id == id);
    if (i != -1) {
      _todos[i].completed = !_todos[i].completed;
      notifyListeners();
      
      // Sync to backend
      try {
        final success = await _apiService.completeTodo(int.parse(id));
        if (!success) {
          // Revert on failure
          _todos[i].completed = !_todos[i].completed;
          notifyListeners();
        }
      } catch (e) {
        print('Error syncing todo completion: $e');
        // Revert on error
        _todos[i].completed = !_todos[i].completed;
        notifyListeners();
      }
    }
  }

  void addTodo(TodoItem item) async {
    _todos.insert(0, item);
    notifyListeners();
    
    // Sync to backend
    try {
      // Create backend todo
      final response = await _apiService.createTodo({
        'title': item.title,
        'verb': '',
        'due_date': item.due?.toIso8601String(),
        'description': item.desc ?? '',
        'priority': item.priority == Priority.high ? 3 : (item.priority == Priority.medium ? 2 : 1),
        'completed': item.completed,
        'user_id': 1,
      });
      print('Todo created on backend: $response');
    } catch (e) {
      print('Error creating todo on backend: $e');
      _errorMessage = 'Failed to save todo';
      notifyListeners();
    }
  }

  void removeTodo(String id) async {
    // Store item in case we need to restore
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    
    final removedItem = _todos[index];
    _todos.removeAt(index);
    notifyListeners();
    
    // Sync to backend
    try {
      final success = await _apiService.deleteTodo(int.parse(id));
      if (!success) {
        // Restore on failure
        _todos.insert(index, removedItem);
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting todo on backend: $e');
      // Restore on error
      _todos.insert(index, removedItem);
      notifyListeners();
    }
  }

  // Calendar state
  DateTime _selectedDay = DateTime(2025, 10, 18);
  DateTime get selectedDay => _selectedDay;
  void selectDay(DateTime d) {
    _selectedDay = d;
    notifyListeners();
  }

  String _calendarView = 'day';
  String get calendarView => _calendarView;
  void setCalendarView(String v) {
    _calendarView = v;
    notifyListeners();
  }

  // Seeded from React initialMockEvents (CalendarScreen.tsx)
  final List<CalendarEventVM> _events = [
    CalendarEventVM(
      id: '1',
      title: 'Q4 Review Meeting',
      date: DateTime(2025, 10, 18),
      start: const TimeOfDay(hour: 14, minute: 0),
      duration: const Duration(minutes: 90),
      gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
      location: 'Conference Room A',
      source: EventSource.email,
      isAIDetected: true,
    ),
    CalendarEventVM(
      id: '2',
      title: 'Dinner with Alex',
      date: DateTime(2025, 10, 20),
      start: const TimeOfDay(hour: 19, minute: 0),
      duration: const Duration(minutes: 120),
      gradient: const [Color(0xFFA855F7), Color(0xFF7C3AED)],
      location: 'Downtown Restaurant',
      source: EventSource.whatsapp,
      isAIDetected: true,
    ),
    CalendarEventVM(
      id: '3',
      title: 'Team Sync',
      date: DateTime(2025, 10, 22),
      start: const TimeOfDay(hour: 10, minute: 0),
      duration: const Duration(minutes: 30),
      gradient: const [Color(0xFF22C55E), Color(0xFF16A34A)],
      source: EventSource.messages,
      isAIDetected: false,
    ),
    CalendarEventVM(
      id: '4',
      title: 'Marketing Review',
      date: DateTime(2025, 10, 22),
      start: const TimeOfDay(hour: 15, minute: 0),
      duration: const Duration(minutes: 60),
      gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      location: 'Virtual',
      source: EventSource.email,
      isAIDetected: false,
    ),
    CalendarEventVM(
      id: '5',
      title: 'Family Dinner',
      date: DateTime(2025, 10, 21),
      start: const TimeOfDay(hour: 18, minute: 0),
      duration: const Duration(minutes: 90),
      gradient: const [Color(0xFFEC4899), Color(0xFFE11D48)],
      location: 'Home',
      source: EventSource.whatsapp,
      isAIDetected: true,
    ),
    CalendarEventVM(
      id: '6',
      title: 'Presentation Prep',
      date: DateTime(2025, 10, 18),
      start: const TimeOfDay(hour: 9, minute: 0),
      duration: const Duration(minutes: 120),
      gradient: const [Color(0xFF06B6D4), Color(0xFF0D9488)],
      source: EventSource.manual,
      isAIDetected: false,
    ),
    CalendarEventVM(
      id: '7',
      title: 'Coffee Break',
      date: DateTime(2025, 10, 18),
      start: const TimeOfDay(hour: 11, minute: 15),
      duration: const Duration(minutes: 30),
      gradient: const [Color(0xFFF59E0B), Color(0xFFCA8A04)],
      source: EventSource.messages,
      isAIDetected: false,
    ),
  ];

  List<CalendarEventVM> eventsForDay(DateTime d) =>
      _events.where((e) => _isSameDay(e.date, d)).toList()..sort((a, b) => _toMinutes(a.start).compareTo(_toMinutes(b.start)));

  List<CalendarEventVM> get events => List.unmodifiable(_events);

  void addEvent(CalendarEventVM e) async {
    _events.add(e);
    notifyListeners();
    
    // Sync to backend
    try {
      final response = await _apiService.createEvent({
        'title': e.title,
        'start_time': '${e.date.toIso8601String().split('T')[0]} ${e.start.hour.toString().padLeft(2, '0')}:${e.start.minute.toString().padLeft(2, '0')}',
        'duration_minutes': e.duration.inMinutes,
        'location': e.location,
        'description': '',
        'source': 'manual',
        'user_id': 1,
        'is_ai_detected': false,
      });
      print('Event created on backend: $response');
    } catch (e) {
      print('Error creating event on backend: $e');
      _errorMessage = 'Failed to save event';
      notifyListeners();
    }
  }

  CalendarEventVM? getEvent(String id) {
    try {
      return _events.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  void updateEvent(String id, {String? title, TimeOfDay? start, Duration? duration, List<Color>? gradient, String? location}) async {
    final i = _events.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final e = _events[i];
    // FIX: defensive clamps – prevent negative durations
    final dur = (duration ?? e.duration).inMinutes.clamp(15, 24 * 60);
    final oldEvent = _events[i];
    _events[i] = CalendarEventVM(
      id: e.id,
      title: title ?? e.title,
      date: e.date,
      start: start ?? e.start,
      duration: Duration(minutes: dur),
      gradient: gradient ?? e.gradient,
      location: location ?? e.location,
      source: e.source,
      isAIDetected: e.isAIDetected,
    );
    notifyListeners();
    
    // Sync to backend
    try {
      final success = await _apiService.updateEvent(int.parse(id), {
        'title': _events[i].title,
        'start_time': '${_events[i].date.toIso8601String().split('T')[0]} ${_events[i].start.hour.toString().padLeft(2, '0')}:${_events[i].start.minute.toString().padLeft(2, '0')}',
        'duration_minutes': _events[i].duration.inMinutes,
        'location': _events[i].location,
        'source': 'manual',
        'user_id': 1,
      });
      if (!success) {
        // Revert on failure
        _events[i] = oldEvent;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating event on backend: $e');
      // Revert on error
      _events[i] = oldEvent;
      notifyListeners();
    }
  }

  void removeEvent(String id) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index == -1) return;
    
    final removedEvent = _events[index];
    _events.removeAt(index);
    notifyListeners();
    
    // Sync to backend
    try {
      final success = await _apiService.deleteEvent(int.parse(id));
      if (!success) {
        // Restore on failure
        _events.insert(index, removedEvent);
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting event on backend: $e');
      // Restore on error
      _events.insert(index, removedEvent);
      notifyListeners();
    }
  }

  // Helpers
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
}
