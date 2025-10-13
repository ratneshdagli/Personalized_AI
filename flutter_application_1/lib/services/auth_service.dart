import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AuthService {
  static String get _baseUrl => ApiConfig.baseUrl;
  static const String _prefsKey = 'auth_tokens';
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Get Gmail OAuth URL for user
  Future<String?> getGmailAuthUrl(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/gmail/url?user_id=$userId'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['auth_url'];
      }
      return null;
    } catch (e) {
      print('Error getting Gmail auth URL: $e');
      return null;
    }
  }

  /// Complete Gmail OAuth flow
  Future<bool> completeGmailAuth(String code, String state) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/gmail/callback'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'code': code,
          'state': state,
        }),
      );
      
      if (response.statusCode == 200) {
        // Store auth success
        await _storeAuthSuccess('gmail');
        return true;
      }
      return false;
    } catch (e) {
      print('Error completing Gmail auth: $e');
      return false;
    }
  }

  /// Launch OAuth URL in browser
  Future<bool> launchOAuthUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      print('Error launching OAuth URL: $e');
      return false;
    }
  }

  /// Check if connector is authenticated
  Future<bool> isConnectorAuthenticated(String connectorType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authData = prefs.getString(_prefsKey);
      
      if (authData != null) {
        final Map<String, dynamic> tokens = json.decode(authData);
        return tokens.containsKey(connectorType);
      }
      return false;
    } catch (e) {
      print('Error checking auth status: $e');
      return false;
    }
  }

  /// Get connector status
  Future<Map<String, dynamic>?> getConnectorStatus(String connectorType) async {
    try {
      String endpoint;
      switch (connectorType) {
        case 'gmail':
          endpoint = '/gmail/status';
          break;
        case 'whatsapp':
          endpoint = '/whatsapp/status';
          break;
        case 'news':
          endpoint = '/news/status';
          break;
        case 'reddit':
          endpoint = '/reddit/status';
          break;
        default:
          return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting connector status: $e');
      return null;
    }
  }

  /// Enable connector
  Future<bool> enableConnector(String connectorType, int userId) async {
    try {
      String endpoint;
      switch (connectorType) {
        case 'gmail':
          endpoint = '/gmail/enable';
          break;
        case 'whatsapp':
          endpoint = '/whatsapp/enable';
          break;
        case 'news':
          endpoint = '/news/enable';
          break;
        case 'reddit':
          endpoint = '/reddit/enable';
          break;
        default:
          return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );
      
      if (response.statusCode == 200) {
        await _storeAuthSuccess(connectorType);
        return true;
      }
      return false;
    } catch (e) {
      print('Error enabling connector: $e');
      return false;
    }
  }

  /// Disable connector
  Future<bool> disableConnector(String connectorType, int userId) async {
    try {
      String endpoint;
      switch (connectorType) {
        case 'gmail':
          endpoint = '/gmail/disable';
          break;
        case 'whatsapp':
          endpoint = '/whatsapp/disable';
          break;
        case 'news':
          endpoint = '/news/disable';
          break;
        case 'reddit':
          endpoint = '/reddit/disable';
          break;
        default:
          return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );
      
      if (response.statusCode == 200) {
        await _removeAuthSuccess(connectorType);
        return true;
      }
      return false;
    } catch (e) {
      print('Error disabling connector: $e');
      return false;
    }
  }

  /// Store auth success
  Future<void> _storeAuthSuccess(String connectorType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authData = prefs.getString(_prefsKey) ?? '{}';
      final Map<String, dynamic> tokens = json.decode(authData);
      
      tokens[connectorType] = {
        'authenticated': true,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_prefsKey, json.encode(tokens));
    } catch (e) {
      print('Error storing auth success: $e');
    }
  }

  /// Remove auth success
  Future<void> _removeAuthSuccess(String connectorType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authData = prefs.getString(_prefsKey) ?? '{}';
      final Map<String, dynamic> tokens = json.decode(authData);
      
      tokens.remove(connectorType);
      
      await prefs.setString(_prefsKey, json.encode(tokens));
    } catch (e) {
      print('Error removing auth success: $e');
    }
  }

  /// Clear all auth data
  Future<void> clearAllAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      print('Error clearing auth data: $e');
    }
  }
}
