import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'feed_service.dart';

class NotificationDispatcher {
  final FeedService _feedService;
  static const MethodChannel _channel = MethodChannel('com.personalized_ai.app/notifications');

  NotificationDispatcher(this._feedService) {
    _channel.setMethodCallHandler(_handleMethodCall);
    debugPrint('[NotificationDispatcher] ✅ Initialized and listening on channel: com.personalized_ai.app/notifications');
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationPosted':
        try {
          final Map<dynamic, dynamic> args = call.arguments;
          final Map<String, dynamic> payload = Map<String, dynamic>.from(args);
          debugPrint('----------------------------------------------------------------');
          debugPrint('[NotificationDispatcher] Received payload from Native: $payload');
          
          // Extract notification details
          final text = payload['text'] ?? '';
          final source = payload['sender'] ?? payload['app'] ?? 'Unknown';
          final appName = payload['app'] ?? 'System';
          
          await _feedService.processIncomingNotification(text, source: source, appName: appName);
        } catch (e) {
          debugPrint('Error processing notification: $e');
        }
        break;
      default:
        debugPrint('Unknown method ${call.method}');
    }
  }
}
