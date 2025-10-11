import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feed_item.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.29.143:8000/api'; // Android emulator

  Future<List<FeedItem>> fetchFeed() async {
    final response = await http.get(Uri.parse('$baseUrl/feed'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => FeedItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load feed');
    }
  }
}
