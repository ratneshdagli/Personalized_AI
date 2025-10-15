import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

class NotificationForwarderService {
  static const EventChannel _events = EventChannel('com.yourorg.personalizedai/context_events');
  static const MethodChannel _methods = MethodChannel('com.yourorg.personalizedai/settings');

  static Stream<Map<String, dynamic>>? _cachedStream;

  static Stream<Map<String, dynamic>> get contextEvents {
    _cachedStream ??= _events.receiveBroadcastStream().map((dynamic data) {
      try {
        final map = json.decode(data as String) as Map<String, dynamic>;
        return map;
      } catch (_) {
        return <String, dynamic>{'raw': data};
      }
    });
    return _cachedStream!;
  }

  static Future<bool> setServerForwarding(bool enabled) async {
    final res = await _methods.invokeMethod('setServerForwarding', {'enabled': enabled});
    return res == true;
  }

  static Future<bool> setBackendUrl(String url) async {
    final res = await _methods.invokeMethod('setBackendUrl', {'url': url});
    return res == true;
  }

  static Future<bool> setUserId(String userId) async {
    final res = await _methods.invokeMethod('setUserId', {'userId': userId});
    return res == true;
  }

  static Future<bool> enableAccessibilityAdvancedMode(bool enabled) async {
    final res = await _methods.invokeMethod('setAdvancedAccessibility', {'enabled': enabled});
    return res == true;
  }

  static Future<Map<String, dynamic>> getCaptureStatus() async {
    final res = await _methods.invokeMethod('getStatus');
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> openNotificationSettings() async {
    await _methods.invokeMethod('openNotificationListenerSettings');
  }

  static Future<void> openAccessibilitySettings() async {
    await _methods.invokeMethod('openAccessibilitySettings');
  }
}


