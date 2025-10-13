import 'dart:io';

// API URLs and constants
class ApiConfig {
  // Platform-aware base URL
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      return 'http://10.0.2.2:8000/api';
    } else if (Platform.isIOS) {
      // iOS simulator uses localhost
      return 'http://localhost:8000/api';
    } else {
      // Web and desktop use localhost
      return 'http://localhost:8000/api';
    }
  }
  
  // Alternative URLs for different environments
  static const String localUrl = 'http://localhost:8000/api';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8000/api'; // Android emulator
  static const String productionUrl = 'https://your-production-domain.com/api';
  
  // Timeout settings
  static const Duration timeout = Duration(seconds: 30);
  
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
