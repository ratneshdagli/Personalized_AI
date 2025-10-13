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
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // First check if backend is healthy
      _backendHealthy = await _apiService.checkHealth();
      
      if (_backendHealthy) {
        _feed = await _apiService.fetchFeed();
        print('Feed loaded successfully with ${_feed.length} items');
      } else {
        _errorMessage = 'Backend is not responding. Please check if the server is running.';
        print(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'Error fetching feed: $e';
      print(_errorMessage);
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> refreshFeed() async {
    await loadFeed();
  }
}
