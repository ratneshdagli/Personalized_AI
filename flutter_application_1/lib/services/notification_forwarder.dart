import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

class NotificationForwarderService {
  static const EventChannel _events = EventChannel('com.yourorg.personalizedai/context_events');
  static const MethodChannel _methods = MethodChannel('com.yourorg.personalizedai/settings');

  static Stream<Map<String, dynamic>>? _cachedStream;

  static Stream<Map<String, dynamic>> get contextEvents {
    print('=== NOTIFICATION_FORWARDER: Getting context events stream ===');
    _cachedStream ??= _events.receiveBroadcastStream().map((dynamic data) {
      try {
        print('=== NOTIFICATION_FORWARDER: Received raw data ===');
        print('Raw data: $data');
        final map = json.decode(data as String) as Map<String, dynamic>;
        print('=== NOTIFICATION_FORWARDER: Parsed data ===');
        print('Parsed map: $map');
        return map;
      } catch (e) {
        print('=== NOTIFICATION_FORWARDER: Error parsing data ===');
        print('Error: $e');
        print('Raw data: $data');
        return <String, dynamic>{'raw': data, 'error': e.toString()};
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
    print('=== NOTIFICATION_FORWARDER: Getting capture status ===');
    try {
      final res = await _methods.invokeMethod('getStatus');
      print('=== NOTIFICATION_FORWARDER: Status received ===');
      print('Status: $res');
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      print('=== NOTIFICATION_FORWARDER: Error getting status ===');
      print('Error: $e');
      return <String, dynamic>{'error': e.toString()};
    }
  }

  static Future<void> openNotificationSettings() async {
    await _methods.invokeMethod('openNotificationListenerSettings');
  }

  static Future<void> openAccessibilitySettings() async {
    await _methods.invokeMethod('openAccessibilitySettings');
  }

  static Future<bool> sendTestNotification() async {
    print('=== NOTIFICATION_FORWARDER: Sending test notification ===');
    try {
      final res = await _methods.invokeMethod('testNotification');
      print('=== NOTIFICATION_FORWARDER: Test notification sent ===');
      return res == true;
    } catch (e) {
      print('=== NOTIFICATION_FORWARDER: Error sending test notification ===');
      print('Error: $e');
      return false;
    }
  }
}


