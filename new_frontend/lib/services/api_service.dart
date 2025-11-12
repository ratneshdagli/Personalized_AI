import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/feed_item.dart';
import '../models/task.dart';
import '../config/api_config.dart';

/// API service for communicating with the FastAPI backend
class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  /// Health check to verify backend connectivity
  Future<bool> checkHealth() async {
    try {
      print('Checking backend health...');
      final response = await http
          .get(
            Uri.parse('${baseUrl.replaceAll('/api', '')}/health'),
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

  /// Fetch all feed items from the backend
  Future<List<BackendFeedItem>> fetchFeed() async {
    try {
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

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        print('Successfully fetched ${data.length} feed items');

        // Log WhatsApp items specifically
        final whatsappItems = data.where((item) =>
            item['source'] == 'whatsapp' ||
            item['source'] == 'whatsapp_notification').toList();
        print('Found ${whatsappItems.length} WhatsApp items in response');

        return data.map((item) => BackendFeedItem.fromJson(item)).toList();
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load feed: ${response.statusCode}');
      }
    } catch (e) {
      print('Network Error: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Fetch feed items with optional filters
  Future<List<BackendFeedItem>> getFeedItems({
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
      return data.map((item) => BackendFeedItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load feed items');
    }
  }

  /// Extract tasks from text using LLM
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

  /// Post context event to the backend for ingestion
  Future<bool> postContextEvent(Map<String, dynamic> event) async {
    try {
      final response = await http
          .post(
            Uri.parse('${baseUrl.replaceAll('/api', '')}/ingest/context_event'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode(event),
          )
          .timeout(ApiConfig.timeout);
      return response.statusCode == 200 || response.statusCode == 202;
    } catch (e) {
      print('Error posting context event: $e');
      return false;
    }
  }

  /// Post WhatsApp message data to the backend
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

  /// Search across feed items
  Future<List<BackendFeedItem>> searchFeed(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/search').replace(
        queryParameters: {'query': query},
      );
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => BackendFeedItem.fromJson(item)).toList();
      } else {
        throw Exception('Failed to search: ${response.statusCode}');
      }
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  /// Provide feedback on a feed item
  Future<bool> submitFeedback({
    required String itemId,
    required String feedbackType,
    String? comment,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/feedback'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode({
              'item_id': itemId,
              'feedback_type': feedbackType,
              'comment': comment,
            }),
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }

  /// Fetch AI-extracted todos from backend
  Future<List<Map<String, dynamic>>> fetchTodos({int userId = 1, bool? completed}) async {
    try {
      final queryParams = <String, String>{
        'user_id': userId.toString(),
      };
      if (completed != null) {
        queryParams['completed'] = completed.toString();
      }

      final uri = Uri.parse('$baseUrl/todos').replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['todos'] ?? []);
      } else {
        throw Exception('Failed to fetch todos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching todos: $e');
      return [];
    }
  }

  /// Fetch AI-extracted events from backend
  Future<List<Map<String, dynamic>>> fetchEvents({
    int userId = 1,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'user_id': userId.toString(),
      };
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrl/events').replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: ApiConfig.defaultHeaders)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['events'] ?? []);
      } else {
        throw Exception('Failed to fetch events: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  /// Mark todo as completed
  Future<bool> completeTodo(int todoId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/todos/$todoId/complete'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error completing todo: $e');
      return false;
    }
  }

  /// Create a new todo
  Future<Map<String, dynamic>?> createTodo(Map<String, dynamic> todoData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/todos'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode(todoData),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create todo: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating todo: $e');
      return null;
    }
  }

  /// Delete a todo
  Future<bool> deleteTodo(int todoId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/todos/$todoId'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting todo: $e');
      return false;
    }
  }

  /// Update a todo
  Future<bool> updateTodo(int todoId, Map<String, dynamic> todoData) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/todos/$todoId'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode(todoData),
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating todo: $e');
      return false;
    }
  }

  /// Create a new event
  Future<Map<String, dynamic>?> createEvent(Map<String, dynamic> eventData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/events'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode(eventData),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create event: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating event: $e');
      return null;
    }
  }

  /// Delete an event
  Future<bool> deleteEvent(int eventId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/events/$eventId'),
            headers: ApiConfig.defaultHeaders,
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  /// Update an event
  Future<bool> updateEvent(int eventId, Map<String, dynamic> eventData) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/events/$eventId'),
            headers: ApiConfig.defaultHeaders,
            body: json.encode(eventData),
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating event: $e');
      return false;
    }
  }
}
