import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart';

class NotificationForwarderService {
  static const EventChannel _events = EventChannel('com.yourorg.personalizedai/context_events');
  static const MethodChannel _methods = MethodChannel('com.yourorg.personalizedai/settings');

  // Broadcast streams
  static final StreamController<Map<String, dynamic>> _eventCtrl = StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<List<Map<String, dynamic>>> _eventListCtrl = StreamController<List<Map<String, dynamic>>>.broadcast();

  // Internal state for dedupe/throttle and list buffer
  static final Set<String> _recentKeys = <String>{};
  static final ListQueue<Map<String, dynamic>> _buffer = ListQueue<Map<String, dynamic>>();
  static const int _bufferMax = 50; // keep last 50
  static int _eventsThisSecond = 0;
  static int _currentSecond = 0;

  static StreamSubscription? _nativeSub;
  static bool _initialized = false;

  static Stream<Map<String, dynamic>> get contextEvents {
    _ensureInitialized();
    return _eventCtrl.stream;
  }

  static Stream<List<Map<String, dynamic>>> get contextEventList {
    _ensureInitialized();
    return _eventListCtrl.stream;
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    print('=== NOTIFICATION_FORWARDER: Initializing native event subscription ===');
    _subscribeNative();
  }

  static void _subscribeNative() {
    _nativeSub?.cancel();
    _nativeSub = _events.receiveBroadcastStream().listen((dynamic data) {
      try {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final sec = nowMs ~/ 1000;
        if (_currentSecond != sec) {
          _currentSecond = sec;
          _eventsThisSecond = 0;
        }
        if (_eventsThisSecond >= 10) {
          // throttle to 10 events/sec
          return;
        }
        _eventsThisSecond++;

        final map = json.decode(data as String) as Map<String, dynamic>;
        final pkg = (map['package'] ?? '').toString();
        final sender = (map['sender'] ?? '').toString();
        final text = (map['text'] ?? '').toString();
        final eventId = (map['event_id'] ?? '').toString();
        final rawKey = '${pkg}|${sender}|${text}';
        final maxLen = 128;
        final truncated = rawKey.substring(0, rawKey.length > maxLen ? maxLen : rawKey.length);
        final key = eventId.isNotEmpty ? eventId : truncated;
        final now = DateTime.now().millisecondsSinceEpoch;

        // dedupe within 5s window
        if (_recentKeys.contains(key)) {
          return;
        }
        _recentKeys.add(key);
        // schedule removal after 5s
        Future<void>.delayed(const Duration(seconds: 5), () { _recentKeys.remove(key); });

        _pushEvent(map);
      } catch (e) {
        print('=== NOTIFICATION_FORWARDER: Error parsing data ===');
        print('Error: $e');
        print('Raw data: $data');
      }
    }, onError: (error) {
      print('=== NOTIFICATION_FORWARDER: Native stream error, will resubscribe ===');
      print('Error: $error');
      Future<void>.delayed(const Duration(milliseconds: 400), _subscribeNative);
    }, onDone: () {
      print('=== NOTIFICATION_FORWARDER: Native stream closed, will resubscribe ===');
      Future<void>.delayed(const Duration(milliseconds: 400), _subscribeNative);
    });
  }

  static void _pushEvent(Map<String, dynamic> map) {
    try {
      _eventCtrl.add(map);
      _buffer.addFirst(map);
      while (_buffer.length > _bufferMax) {
        _buffer.removeLast();
      }
      _eventListCtrl.add(List<Map<String, dynamic>>.unmodifiable(_buffer));
    } catch (e) {
      // ignore
    }
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

  // Debug: inject a simulated event into the stream
  static void simulateEvent(Map<String, dynamic> event) {
    final enriched = <String, dynamic>{
      'source': event['source'] ?? 'simulation',
      'package': event['package'] ?? 'com.example.sim',
      'sender': event['sender'] ?? 'Tester',
      'text': event['text'] ?? 'Hello from simulateEvent',
      'timestamp': event['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      'event_id': event['event_id'] ?? 'sim-${DateTime.now().microsecondsSinceEpoch}',
    };
    _pushEvent(enriched);
  }
}


