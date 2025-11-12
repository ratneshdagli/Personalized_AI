import 'package:flutter/material.dart';
import '../models/feed_item.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';

class FeedProvider with ChangeNotifier {
  List<FeedItem> _feed = [];
  bool _loading = false;
  bool _backendHealthy = false;
  String? _errorMessage;

  List<FeedItem> get feed => _feed;
  bool get loading => _loading;
  bool get backendHealthy => _backendHealthy;
  String? get errorMessage => _errorMessage;

  final ApiService _apiService = ApiService();

  FeedProvider() {
    _loadFromHive();
  }

  void _loadFromHive() {
    try {
      final box = LocalStorage.feedItems;
      final List<dynamic> raw = (box.get('items') as List?) ?? [];
      _feed = raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return FeedItem(
          id: (m['id'] ?? '').toString(),
          title: (m['title'] ?? '').toString(),
          summary: (m['summary'] ?? '').toString(),
          content: (m['content'] ?? m['summary'] ?? '').toString(),
          date: DateTime.tryParse((m['date'] ?? '') as String) ?? DateTime.now(),
          source: (m['source'] ?? '').toString(),
          priority: int.tryParse('${m['priority'] ?? 1}') ?? 1,
          relevance: (m['relevance'] is num) ? (m['relevance'] as num).toDouble() : 0.0,
          metaData: (m['metaData'] is Map) ? Map<String, dynamic>.from(m['metaData'] as Map) : null,
        );
      }).toList();
      notifyListeners();
    } catch (_) {}
  }

  void _saveToHive() {
    try {
      final box = LocalStorage.feedItems;
      final list = _feed.map((i) => {
        'id': i.id,
        'title': i.title,
        'summary': i.summary,
        'content': i.content,
        'date': i.date.toIso8601String(),
        'source': i.source,
        'priority': i.priority,
        'relevance': i.relevance,
        'metaData': i.metaData,
      }).toList();
      box.put('items', list);
    } catch (_) {}
  }

  Future<void> loadFeed() async {
    print("=" * 50);
    print("FeedProvider: Starting to load feed");
    print("=" * 50);
    
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First check if backend is healthy
      print("FeedProvider: Checking backend health...");
      _backendHealthy = await _apiService.checkHealth();
      print("FeedProvider: Backend health check result: $_backendHealthy");
      
      if (_backendHealthy) {
        print("FeedProvider: Backend is healthy, fetching feed...");
        _feed = await _apiService.fetchFeed();
        print("FeedProvider: Feed loaded successfully with ${_feed.length} items");
        _saveToHive();
        
        // Log details about WhatsApp messages
        final whatsappMessages = _feed.where((item) => 
          item.source == 'whatsapp' || item.source == 'whatsapp_notification'
        ).toList();
        print("FeedProvider: Found ${whatsappMessages.length} WhatsApp messages in feed");
        
        for (var msg in whatsappMessages) {
          print("FeedProvider: WhatsApp message - Title: '${msg.title}', Source: '${msg.source}'");
        }
        
      } else {
        _errorMessage = 'Backend is not responding. Please check if the server is running.';
        print("FeedProvider: $_errorMessage");
      }
    } catch (e) {
      _errorMessage = 'Error fetching feed: $e';
      print("FeedProvider: ERROR - $_errorMessage");
    }

    _loading = false;
    notifyListeners();
    
    print("FeedProvider: Feed loading completed");
    print("=" * 50);
  }

  Future<void> refreshFeed() async {
    await loadFeed();
  }

  // Optional: allow app to merge a live event into feed when user opts in
  void addLiveEventToFeed(FeedItem item) {
    _feed = [item, ..._feed];
    notifyListeners();
    _saveToHive();
  }

  void addLiveEventMapToFeed(Map<String, dynamic> event) {
    final DateTime ts = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse('${event['timestamp']}') ?? DateTime.now().millisecondsSinceEpoch,
      isUtc: false,
    );
    final item = FeedItem(
      id: 'live-${event['event_id'] ?? ts.microsecondsSinceEpoch}',
      title: (event['sender'] ?? event['package'] ?? 'Notification').toString(),
      summary: (event['text'] ?? '').toString(),
      content: (event['text'] ?? '').toString(),
      date: ts,
      source: (event['package'] ?? 'notification').toString(),
      priority: 1,
      relevance: 0.0,
      metaData: {
        'source': event['source'],
        'event_id': event['event_id'],
        'package': event['package'],
      },
    );
    addLiveEventToFeed(item);
  }
}
