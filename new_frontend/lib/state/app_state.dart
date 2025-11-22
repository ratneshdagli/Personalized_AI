import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart'; // Keep for now, but will be deprecated
import '../services/feed_service.dart';
import '../services/task_extractor.dart';
import '../services/ranking_service.dart';
import '../services/local_llm_service.dart';
import '../services/notification_dispatcher.dart';
import '../services/search_service.dart';

import '../data/repositories/feed_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/model_repository.dart';
import '../data/repositories/calendar_event_repository.dart';
import '../data/repositories/hub_repository.dart';
import '../data/repositories/user_feedback_repository.dart';

import '../data/schema/feed_item.dart' as schema;
import '../data/schema/task.dart' as schema;
import '../data/schema/model_record.dart' as schema;
import '../data/schema/calendar_event.dart' as schema;
import '../data/schema/hub.dart' as schema;
import '../data/schema/user_feedback.dart' as schema;

import '../models/task.dart' as backend;

import '../llm/llm_service.dart'; // Old LLM service, might need to check usage

// Lightweight in-memory UI state (Provider/ChangeNotifier)
// Data models (visual-only)
enum FeedType { email, message, news }

class FeedItemVM {
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
  FeedItemVM({
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

class TodoItemVM {
  final String id;
  String title;
  String? desc; // source/description
  Priority priority;
  String? dueLabel; // React uses labels like 'Oct 18'
  DateTime? due; // optional actual date if used elsewhere
  bool completed;
  List<String> tags;
  TodoItemVM({
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

enum EventSource { email, messages, phone, manual }

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
  // API service (Deprecated for main logic, kept for model server if needed)
  final ApiService _apiService = ApiService();
  
  // Local Services & Repositories
  late Isar _isar;
  late FeedRepository _feedRepository;
  late TaskRepository _taskRepository;
  ModelRepository? _modelRepository;
  late CalendarEventRepository _calendarEventRepository;
  HubRepository? _hubRepository;
  late UserFeedbackRepository _userFeedbackRepository;
  
  late FeedService _feedService;
  late TaskExtractor _taskExtractor;
  late RankingService _rankingService;
  late SearchService _searchService;
  late NotificationDispatcher _notificationDispatcher;
  
  bool _isInitialized = false;

  // Getters for services/repos
  ModelRepository get modelRepository {
    if (_modelRepository == null) {
      throw StateError('ModelRepository not initialized. Call init() first.');
    }
    return _modelRepository!;
  }
  
  HubRepository get hubRepository {
    if (_hubRepository == null) {
      throw StateError('HubRepository not initialized. Call init() first.');
    }
    return _hubRepository!;
  }

  // Getters that read from Isar for real-time UI
  List<FeedItemVM> get filteredFeed {
    if (!_isInitialized) return [];
    
    try {
      final items = _isar.feedItems
          .where()
          .sortByTimestampDesc()
          .findAllSync()
          .map((item) => _convertLocalToUIFeedItem(item))
          .toList();
      
      debugPrint('[AppState] filteredFeed: returning ${items.length} items');
      return items;
    } catch (e) {
      debugPrint('[AppState] Error in filteredFeed: $e');
      return [];
    }
  }
  
  List<TodoItemVM> get filteredTodos {
    if (!_isInitialized) return [];
    
    try {
      final tasks = _isar.tasks
          .where()
          .filter()
          .completedEqualTo(false)
          .sortByPriorityDesc()
          .findAllSync()
          .map((task) => TodoItemVM(
                id: task.id.toString(),
                title: task.title,
                desc: task.text,
                priority: _mapPriority(task.priority),
                dueLabel: task.dueDate != null ? _formatDate(task.dueDate!) : null,
                due: task.dueDate,
                completed: task.completed,
                tags: [],
              ))
          .toList();
      
      debugPrint('[AppState] filteredTodos: returning ${tasks.length} items');
      return tasks;
    } catch (e) {
      debugPrint('[AppState] Error in filteredTodos: $e');
      return [];
    }
  }
  
  List<CalendarEventVM> get events {
    if (!_isInitialized) return [];
    
    try {
      final events = _isar.calendarEvents
          .where()
          .sortByStart()
          .findAllSync();
      
      // Convert to CalendarEventVM (simplified - adjust as needed)
      return events.map((e) => CalendarEventVM(
            id: e.id.toString(),
            title: e.title,
            date: e.start,
            start: TimeOfDay.fromDateTime(e.start),
            duration: e.end != null ? e.end!.difference(e.start) : const Duration(hours: 1),
            gradient: [const Color(0xFFA855F7), const Color(0xFF8B5CF6)],
            location: e.location,
            source: EventSource.manual,
            isAIDetected: true,
          )).toList();
    } catch (e) {
      debugPrint('[AppState] Error in events: $e');
      return [];
    }
  }

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
    await _initIsar();
    await _loadFeedFromLocal();
    await _loadTodosFromLocal();
    await _loadEventsFromLocal();
    await _loadHubsFromLocal();
    
    // Start automatic polling (now just refreshing from local DB if needed, or relying on streams)
    // startPolling(); // Polling might not be needed if we use streams, but for now keep it to refresh UI
  }

  Future<void> _initIsar() async {
    if (_isInitialized) return;

    final dir = await getApplicationDocumentsDirectory();
    
    _isar = await Isar.open(
      [
        schema.FeedItemSchema,
        schema.TaskSchema,
        schema.ModelRecordSchema,
        schema.CalendarEventSchema,
        schema.HubSchema,
        schema.UserFeedbackSchema,
      ],
      directory: dir.path,
    );

    _feedRepository = FeedRepository(_isar);
    _taskRepository = TaskRepository(_isar);
    _modelRepository = ModelRepository(_isar);
    _calendarEventRepository = CalendarEventRepository(_isar);
    _hubRepository = HubRepository(_isar);
    _userFeedbackRepository = UserFeedbackRepository(_isar);

    _rankingService = RankingService();
    // LocalLLMService is a singleton, so we just use the instance
    _taskExtractor = TaskExtractor(LocalLLMService());
    
    _feedService = FeedService(
      _feedRepository,
      _taskRepository,
      _hubRepository!,
      _userFeedbackRepository, // Now using in-memory version
      _taskExtractor,
      _rankingService,
      _isar,
    );
    
    _searchService = SearchService(_feedRepository);
    
    debugPrint('[AppState] Creating NotificationDispatcher...');
    _notificationDispatcher = NotificationDispatcher(_feedService);
    
    // Set up Isar watchers for real-time UI updates
    _setupIsarWatchers();
    
    _isInitialized = true;
    debugPrint('[AppState] ✅ Initialization complete!');
  }
  
  /// Sets up Isar watchers to automatically update UI when data changes
  void _setupIsarWatchers() {
    debugPrint('[AppState] Setting up Isar watchers for real-time updates...');
    
    // Watch for FeedItem changes
    _isar.feedItems.watchLazy().listen((_) {
      debugPrint('[AppState] 🔄 FeedItems changed, notifying listeners...');
      notifyListeners();
    });
    
    // Watch for Task changes
    _isar.tasks.watchLazy().listen((_) {
      debugPrint('[AppState] 🔄 Tasks changed, notifying listeners...');
      notifyListeners();
    });
    
    // Watch for CalendarEvent changes
    _isar.calendarEvents.watchLazy().listen((_) {
      debugPrint('[AppState] 🔄 CalendarEvents changed, notifying listeners...');
      notifyListeners();
    });
    
    debugPrint('[AppState] ✅ Isar watchers set up successfully!');
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

  // Dynamic hubs from DB
  List<schema.Hub> _hubs = [];
  List<schema.Hub> get hubs => _hubs;

  Future<void> _loadHubsFromLocal() async {
    try {
      await _hubRepository!.ensureDefaultHubs();
      _hubs = await _hubRepository!.getAllHubs();
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] Error loading hubs: $e');
    }
  }

  Future<void> deleteHub(int id) async {
    try {
      await _hubRepository!.deleteHub(id);
      await _loadHubsFromLocal();
      // Reset tab if deleted hub was selected
      if (_selectedHubTab != 'Hubs' && _selectedHubTab != 'All') {
        // Check if selected hub still exists
        if (!_hubs.any((h) => h.name == _selectedHubTab)) {
          _selectedHubTab = 'Hubs';
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState] Error deleting hub: $e');
    }
  }

  // Data Lists
  final List<TodoItemVM> _todoItems = [];
  final List<CalendarEventVM> _events = [];

  List<TodoItemVM> get todoItems => _todoItems;
  // events getter now reads from Isar - see line 244

  // New: feed items mirroring HomeFeed.tsx mockData
  final List<FeedItemVM> _feedItems = [
    FeedItemVM(
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
    FeedItemVM(
      id: '2',
      type: FeedType.message,
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
    FeedItemVM(
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
    FeedItemVM(
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
    FeedItemVM(
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
    FeedItemVM(
      id: '5b',
      type: FeedType.message,
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
    FeedItemVM(
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
    FeedItemVM(
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
    FeedItemVM(
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
    FeedItemVM(
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

  // feedItems and filteredFeed now read from Isar - see line 195
  // Keeping this for backward compatibility - redirects to Isar-based getter
  List<FeedItemVM> get feedItems => filteredFeed;

  // Priority feed - high priority items from backend
  List<FeedItemVM> get priorityFeed {
    return filteredFeed.where((f) => (f.priority ?? 0) >= 8).toList()
      ..sort((a, b) => (b.priority ?? 0).compareTo(a.priority ?? 0));
  }

  // Unread count
  int get unreadCount => _feedItems.where((f) => f.tags.contains('unread')).length;

  List<FeedItemVM> getHubItems(CategoryConfig hub) {
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

      // TODO: implement actual backend feed loading when ready.
      // For now, just rely on local DB / mock data.
      print('Backend is healthy, but _loadFeedFromBackend is not implemented yet.');
    } catch (e) {
      _errorMessage = 'Failed to load feed from backend: $e';
      print('Error loading feed from backend: $e');
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> _loadFeedFromLocal() async {
    try {
      _isLoadingFeed = true;
      notifyListeners();
      
      final items = await _feedRepository.getFeed();
      _feedItems.clear();
      for (final item in items) {
        _feedItems.add(_convertLocalToUIFeedItem(item));
      }
    } catch (e) {
      _errorMessage = 'Failed to load feed: $e';
      print('Error loading feed from local DB: $e');
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  /// Convert local schema feed item to UI feed item
  FeedItemVM _convertLocalToUIFeedItem(schema.FeedItem item) {
    // Determine feed type based on source
    FeedType type = FeedType.message;
    final source = item.source.toLowerCase();
    if (source.contains('email')) {
      type = FeedType.email;
    } else if (source.contains('message')) {
      type = FeedType.message;
    } else if (source.contains('news')) {
      type = FeedType.news;
    }

    // Map priority to categories
    List<String> categories = [];
    if (item.priority >= 8) {
      categories.add('urgent');
    }
    if (source.contains('email') || source.contains('work')) {
      categories.add('work');
    }
    if (source.contains('message')) {
      categories.add('conversations');
    }
    if (source.contains('news')) {
      categories.add('news');
      categories.add('trends');
    }
    if (categories.isEmpty) {
      categories.add('personal');
    }

    // Extract metadata if available
    Map<String, dynamic> meta = {};
    if (item.metadataJson != null) {
      try {
        meta = json.decode(item.metadataJson!);
      } catch (e) {
        print('Error parsing metadata JSON: $e');
      }
    }

    // Extract sender from metadata or use source
    String sender = meta['sender'] ?? item.source;

    // Format time ago
    String timeAgo = _formatTimeAgo(item.timestamp);

    // Extract tags from metadata
    List<String> tags = [];
    if (meta['tags'] != null) {
      tags = List<String>.from(meta['tags']);
    }

    return FeedItemVM(
      id: item.id.toString(),
      type: type,
      categories: categories,
      sender: sender,
      title: item.summary, // Use summary as title for now, or extract title from content
      summary: item.summary,
      fullContent: item.content,
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

  FeedItemVM _convertBackendToUIFeedItem(dynamic item) {
    // TODO: Implement actual conversion from backend model to FeedItemVM
    // For now returning a dummy item to satisfy compilation
    return FeedItemVM(
      id: 'backend_${DateTime.now().millisecondsSinceEpoch}',
      type: FeedType.news,
      categories: ['news'],
      sender: 'Backend',
      title: 'Backend Item',
      summary: 'Item from backend',
      tags: [],
      time: 'Just now',
    );
  }

  Future<void> _loadEventsFromBackend() async {
     // TODO: Implement backend event loading
     // Stub implementation
  }

  /// Refresh feed from backend
  Future<void> refreshFeed() async {
    await _loadFeedFromBackend();
    await _loadTodosFromBackend();
    await _loadEventsFromBackend();
  }

  /// Load AI-extracted todos from backend (deprecated - using offline-first now)
  Future<void> _loadTodosFromBackend() async {
    // Offline-first mode - not loading from backend
    return;
    /* 
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
    */
  }



  Future<void> _loadTodosFromLocal() async {
    try {
      _isLoadingTasks = true;
      notifyListeners();
      
      final tasks = await _taskRepository.getTasks();
      _todoItems.clear();
      for (final task in tasks) {
        _todoItems.add(TodoItemVM(
          id: task.id.toString(),
          title: task.title,
          desc: task.text,
          priority: _mapPriority(task.priority),
          dueLabel: task.dueDate != null ? _formatDate(task.dueDate!) : null,
          due: task.dueDate,
          completed: task.completed,
          tags: [], // TODO: Add tags to Task schema if needed
        ));
      }
    } catch (e) {
      print('Error loading tasks from local DB: $e');
    } finally {
      _isLoadingTasks = false;
      notifyListeners();
    }
  }

  Priority _mapPriority(int p) {
    if (p >= 8) return Priority.high;
    if (p >= 5) return Priority.medium;
    return Priority.low;
  }

  String _formatDate(DateTime d) {
    return '${d.month}/${d.day}';
  }

  Future<void> _loadEventsFromLocal() async {
    try {
      final events = await _calendarEventRepository.getEvents();
      _events.clear();
      for (final event in events) {
        _events.add(CalendarEventVM(
          id: event.id.toString(),
          title: event.title,
          date: event.start,
          start: TimeOfDay.fromDateTime(event.start),
          duration: event.end != null ? event.end!.difference(event.start) : const Duration(hours: 1),
          gradient: [Colors.blue, Colors.purple], // Default gradient
          location: event.location,
          source: EventSource.manual, // Or infer from metadata
          isAIDetected: true, // Assuming mostly AI generated for now
        ));
      }
      notifyListeners();
    } catch (e) {
      print('Error loading events from local DB: $e');
    }
  }

  EventSource _mapEventSource(String? source) {
    switch (source?.toLowerCase()) {
      case 'message':
        return EventSource.messages;
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

    final todoItem = TodoItemVM(
      id: task.id.toString(),
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
  final List<TodoItemVM> _todos = [
    TodoItemVM(id: '7', title: 'Review design trends article', desc: 'Design Weekly', priority: Priority.low, completed: false),
    TodoItemVM(id: '8', title: 'Prepare presentation slides', desc: 'Email from Sarah', priority: Priority.high, dueLabel: 'Oct 18', completed: false),
  ];
  List<TodoItemVM> get todos {
    Iterable<TodoItemVM> list = _todos;
    if (_todoFilterNullable != null) {
      list = list.where((t) => t.priority == _todoFilterNullable);
    }
    final q = _search.toLowerCase();
    if (q.isNotEmpty) list = list.where((t) => t.title.toLowerCase().contains(q) || (t.desc ?? '').toLowerCase().contains(q));
    return list.toList();
  }
  // Grouping parity with React: today = labels 'Oct 18' or 'Oct 19'; upcoming = other labels; backlog = no label
  List<TodoItemVM> get today => todos.where((t) => (t.dueLabel == 'Oct 18' || t.dueLabel == 'Oct 19') && !t.completed).toList();
  List<TodoItemVM> get upcoming => todos.where((t) => t.dueLabel != null && !(t.dueLabel == 'Oct 18' || t.dueLabel == 'Oct 19') && !t.completed).toList();
  List<TodoItemVM> get backlog => todos.where((t) => t.dueLabel == null && !t.completed).toList();
  List<TodoItemVM> get completed => _todos.where((t) => t.completed).toList();

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

  void addTodo(TodoItemVM item) async {
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

  List<CalendarEventVM> eventsForDay(DateTime d) =>
      _events.where((e) => _isSameDay(e.date, d)).toList()..sort((a, b) => _toMinutes(a.start).compareTo(_toMinutes(b.start)));

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

  // Handle user feedback (Swipe to Hide)
  Future<void> handleUserFeedback(String feedItemId, String reason) async {
    try {
      final id = int.tryParse(feedItemId);
      if (id != null) {
        await _feedService.handleUserFeedback(id, reason);
        // Optimistically remove from UI lists
        _feedItems.removeWhere((i) => i.id.toString() == feedItemId);
        // _priorityFeedItems.removeWhere((i) => i.id.toString() == feedItemId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppState] Error handling user feedback: $e');
    }
  }

  // Helpers
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
}
