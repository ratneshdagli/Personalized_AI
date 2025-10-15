import 'package:flutter/material.dart';
import '../models/feed_item.dart';
import '../services/api_service.dart';

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
}
