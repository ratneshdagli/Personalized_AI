import 'package:flutter/material.dart';
import '../models/feed_item.dart';
import '../services/api_service.dart';

class FeedProvider with ChangeNotifier {
  List<FeedItem> _feed = [];
  bool _loading = false;

  List<FeedItem> get feed => _feed;
  bool get loading => _loading;

  final ApiService _apiService = ApiService();

  Future<void> loadFeed() async {
    _loading = true;
    notifyListeners();

    try {
      _feed = await _apiService.fetchFeed();
    } catch (e) {
      print('Error fetching feed: $e');
    }

    _loading = false;
    notifyListeners();
  }
}
