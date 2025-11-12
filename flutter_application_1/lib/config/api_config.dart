import 'dart:io';

// API URLs and constants
class ApiConfig {
  // Optional: override via --dart-define=API_BASE_URL=http://LAN_IP:8000/api
  static const String _defineBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  // Optional: set your PC LAN IP here to test on physical devices (same Wi‑Fi)
  // Example: '192.168.1.42'
  static const String lanIp = String.fromEnvironment('LAN_IP', defaultValue: '');

  // Platform-aware base URL selection with sensible fallbacks
  // - Android emulator uses 10.0.2.2 to reach host (your PC) localhost
  // - Physical devices need your PC's LAN IP, not 127.0.0.1
  static String get baseUrl {
    if (_defineBase.isNotEmpty) return _defineBase; // highest priority
    if (lanIp.isNotEmpty) return 'http://$lanIp:8000/api';
    // Default LAN URL works for emulator and physical device when backend is on same network
    return lanDefaultUrl;
  }
  
  // Alternative URLs for different environments
  static const String localUrl = 'http://192.168.29.143:8000/api';
  static const String androidEmulatorUrl = 'http://192.168.29.143:8000/api';
  static const String lanDefaultUrl = 'http://192.168.29.143:8000/api';
  static const String productionUrl = 'https://your-production-domain.com/api';
  
  // Timeout settings (enforced across all requests)
  static const Duration timeout = Duration(seconds: 10);
  
  // Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Debug info
  static void printConfig() {
    print('API Config - Platform: ${Platform.operatingSystem}');
    print('API Config - Base URL: $baseUrl');
  }
}
