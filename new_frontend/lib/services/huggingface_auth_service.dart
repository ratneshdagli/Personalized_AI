import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Hugging Face OAuth authentication service
class HuggingFaceAuthService {
  // OAuth configuration (from ProjectConfig.kt)
  static const String _clientId = '71df7d87-f83c-4dc3-97ad-1e7ec29493d3';
  static const String _clientSecret = '824654a5-a73f-4328-8a1e-11cb9dd35307';
  static const String _callbackScheme = 'com.example.figma';
  static const String _redirectPath = 'auth';
  static String get _redirectUri => '$_callbackScheme://$_redirectPath';
  
  // Add a flag to track if we're currently authenticating
  static bool _isAuthenticating = false;
  
  static const String _authEndpoint = 'https://huggingface.co/oauth/authorize';
  static const String _tokenEndpoint = 'https://huggingface.co/oauth/token';
  static const String _scope = 'read-repos';
  
  static const String _prefsKeyAccessToken = 'hf_access_token';
  static const String _prefsKeyRefreshToken = 'hf_refresh_token';
  static const String _prefsKeyTokenExpiry = 'hf_token_expiry';

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Get current access token (refreshes if expired)
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefsKeyAccessToken);
    final expiry = prefs.getInt(_prefsKeyTokenExpiry);
    
    if (token == null || token.isEmpty) {
      return null;
    }
    
    // Check if token is expired (with 5 minute buffer)
    if (expiry != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiry);
      final now = DateTime.now();
      if (now.isAfter(expiryDate.subtract(const Duration(minutes: 5)))) {
        debugPrint('[HFAuth] Token expired, attempting refresh...');
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return prefs.getString(_prefsKeyAccessToken);
        }
        return null;
      }
    }
    
    return token;
  }

  /// Authenticate with Hugging Face OAuth
  static Future<bool> authenticate() async {
    // Prevent multiple authentication attempts
    if (_isAuthenticating) {
      debugPrint('[HFAuth] Authentication already in progress');
      return false;
    }
    
    _isAuthenticating = true;
    
    try {
      debugPrint('[HFAuth] Starting OAuth flow...');
      
      // Generate state for CSRF protection
      final state = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Build authorization URL using Uri for proper encoding
      final authUri = Uri(
        scheme: 'https',
        host: 'huggingface.co',
        path: '/oauth/authorize',
        queryParameters: {
          'client_id': _clientId,
          'redirect_uri': _redirectUri,
          'scope': _scope,
          'state': state,
          'response_type': 'code',
        },
      );
      
      debugPrint('[HFAuth] Auth URL: ${authUri.toString()}');
      
      String result;
      try {
        debugPrint('[HFAuth] Opening browser for authentication...');
        debugPrint('[HFAuth] Using callback scheme: $_callbackScheme');
        
        result = await FlutterWebAuth2.authenticate(
          url: authUri.toString(),
          callbackUrlScheme: 'com.example.figma', // Exact scheme without ://
        );
        
        debugPrint('[HFAuth] Authentication completed successfully');
        debugPrint('[HFAuth] Callback result: $result');
      } catch (e, stackTrace) {
        debugPrint('[HFAuth] Authentication failed: $e');
        debugPrint('[HFAuth] Stack trace: $stackTrace');
        _isAuthenticating = false;
        rethrow;
      } finally {
        _isAuthenticating = false;
      }
      
      debugPrint('[HFAuth] Received callback: $result');
      
      if (result == null || result.isEmpty) {
        debugPrint('[HFAuth] Empty result from authentication');
        return false;
      }
      
      // Parse callback URL
      final callbackUri = Uri.tryParse(result);
      if (callbackUri == null) {
        debugPrint('[HFAuth] Failed to parse callback URI: $result');
        return false;
      }
      final code = callbackUri.queryParameters['code'];
      final returnedState = callbackUri.queryParameters['state'];
      final error = callbackUri.queryParameters['error'];
      
      if (error != null) {
        debugPrint('[HFAuth] OAuth error: $error');
        debugPrint('[HFAuth] Error description: ${callbackUri.queryParameters['error_description']}');
        return false;
      }
      
      if (code == null || code.isEmpty) {
        debugPrint('[HFAuth] No authorization code received');
        debugPrint('[HFAuth] Full callback URI: $callbackUri');
        return false;
      }
      
      if (returnedState != state) {
        debugPrint('[HFAuth] State mismatch - possible CSRF attack');
        return false;
      }
      
      debugPrint('[HFAuth] Authorization code received, exchanging for token...');
      
      // Exchange code for access token
      final tokenResponse = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'code': code,
          'redirect_uri': _redirectUri,
          'grant_type': 'authorization_code',
        },
      );
      
      if (tokenResponse.statusCode != 200) {
        debugPrint('[HFAuth] Token exchange failed: ${tokenResponse.statusCode} ${tokenResponse.body}');
        return false;
      }
      
      final tokenData = json.decode(tokenResponse.body);
      final accessToken = tokenData['access_token'] as String?;
      final refreshToken = tokenData['refresh_token'] as String?;
      final expiresIn = tokenData['expires_in'] as int?;
      
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[HFAuth] No access token in response');
        return false;
      }
      
      debugPrint('[HFAuth] Access token received, expires in: $expiresIn seconds');
      
      // Save tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyAccessToken, accessToken);
      if (refreshToken != null) {
        await prefs.setString(_prefsKeyRefreshToken, refreshToken);
      }
      if (expiresIn != null) {
        final expiry = DateTime.now().add(Duration(seconds: expiresIn));
        await prefs.setInt(_prefsKeyTokenExpiry, expiry.millisecondsSinceEpoch);
      }
      
      debugPrint('[HFAuth] Authentication successful');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[HFAuth] Authentication failed: $e');
      debugPrint('[HFAuth] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Refresh access token using refresh token
  static Future<bool> _refreshAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_prefsKeyRefreshToken);
      
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('[HFAuth] No refresh token available');
        return false;
      }
      
      debugPrint('[HFAuth] Refreshing access token...');
      
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );
      
      if (response.statusCode != 200) {
        debugPrint('[HFAuth] Token refresh failed: ${response.statusCode}');
        return false;
      }
      
      final tokenData = json.decode(response.body);
      final accessToken = tokenData['access_token'] as String?;
      final newRefreshToken = tokenData['refresh_token'] as String?;
      final expiresIn = tokenData['expires_in'] as int?;
      
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }
      
      // Save new tokens
      await prefs.setString(_prefsKeyAccessToken, accessToken);
      if (newRefreshToken != null) {
        await prefs.setString(_prefsKeyRefreshToken, newRefreshToken);
      }
      if (expiresIn != null) {
        final expiry = DateTime.now().add(Duration(seconds: expiresIn));
        await prefs.setInt(_prefsKeyTokenExpiry, expiry.millisecondsSinceEpoch);
      }
      
      debugPrint('[HFAuth] Token refreshed successfully');
      return true;
    } catch (e) {
      debugPrint('[HFAuth] Token refresh error: $e');
      return false;
    }
  }

  /// Sign out and clear tokens
  static Future<void> signOut() async {
    debugPrint('[HFAuth] Signing out...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyAccessToken);
    await prefs.remove(_prefsKeyRefreshToken);
    await prefs.remove(_prefsKeyTokenExpiry);
    debugPrint('[HFAuth] Signed out successfully');
  }
}
