import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feed_item.dart';
import '../models/task.dart';
import '../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Health check method
  Future<bool> checkHealth() async {
    try {
      print('Checking backend health...');
      // Use root of backend (without /api) to hit a simple health/root endpoint
      final response = await http
          .get(
            Uri.parse('${baseUrl.replaceAll('/api', '')}/'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        print('Backend is healthy! Body: ${response.body}');
        return true;
      } else {
        print('Backend health check failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Backend health check error: $e');
      return false;
    }
  }

  Future<List<FeedItem>> fetchFeed() async {
    try {
      // Print debug info
      ApiConfig.printConfig();
      print('Fetching feed from: $baseUrl/feed');
      
      final response = await http
          .get(
            Uri.parse('$baseUrl/feed'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.timeout);

      print('Response status: ${response.statusCode}');
      print('Response body length: ${response.body.length}');
      print('Raw JSON response: ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        print('Successfully fetched ${data.length} feed items');
        
        // Log WhatsApp items specifically
        final whatsappItems = data.where((item) => 
          item['source'] == 'whatsapp' || item['source'] == 'whatsapp_notification'
        ).toList();
        print('Found ${whatsappItems.length} WhatsApp items in response');
        
        for (var item in whatsappItems) {
          print('WhatsApp item: ${item['title']} - ${item['source']}');
        }
        
        return data.map((item) => FeedItem.fromJson(item)).toList();
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load feed: ${response.statusCode}');
      }
    } catch (e) {
      print('Network Error: $e');
      throw Exception('Network error: $e');
    }
  }

  Future<List<FeedItem>> getFeedItems({
    int limit = 20,
    int offset = 0,
    String? category,
    String? source,
    String? sortBy,
    String? sortOrder,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    
    if (category != null) queryParams['category'] = category;
    if (source != null) queryParams['source'] = source;
    if (sortBy != null) queryParams['sortBy'] = sortBy;
    if (sortOrder != null) queryParams['sortOrder'] = sortOrder;
    
    final uri = Uri.parse('$baseUrl/feed').replace(queryParameters: queryParams);
    final response = await http
        .get(uri, headers: ApiConfig.defaultHeaders)
        .timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) => FeedItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load feed items');
    }
  }

  Future<TaskExtractionResult> extractTasks(String text) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/extract_tasks'),
          headers: ApiConfig.defaultHeaders,
          body: json.encode({'text': text}),
        )
        .timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return TaskExtractionResult.fromJson(data);
    } else {
      throw Exception('Failed to extract tasks: ${response.statusCode}');
    }
  }

  Future<bool> postContextEvent(Map<String, dynamic> event) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/ingest/context_event'),
          headers: ApiConfig.defaultHeaders,
          body: json.encode(event),
        )
        .timeout(ApiConfig.timeout);
    return response.statusCode == 200 || response.statusCode == 202;
  }

  Future<bool> postWhatsAppMessage(Map<String, dynamic> messageData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/whatsapp/add'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode(messageData),
          )
          .timeout(ApiConfig.timeout);
      
      return response.statusCode == 200 || response.statusCode == 202;
    } catch (e) {
      print('Error posting WhatsApp message: $e');
      return false;
    }
  }
}
