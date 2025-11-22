import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/repositories/feed_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/schema/feed_item.dart';
import '../data/schema/task.dart';
import '../data/schema/calendar_event.dart';
import '../data/repositories/hub_repository.dart';
import '../data/schema/hub.dart';
import '../data/repositories/user_feedback_repository.dart';
import 'task_extractor.dart';
import 'ranking_service.dart';
import 'local_llm_service.dart';
import '../models/extraction_result.dart';
import 'package:isar/isar.dart';

class FeedService {
  final FeedRepository _feedRepository;
  final TaskRepository _taskRepository;
  final HubRepository _hubRepository;
  final UserFeedbackRepository _userFeedbackRepository;
  final TaskExtractor _taskExtractor;
  final RankingService _rankingService;
  final Isar _isar;

  FeedService(
    this._feedRepository,
    this._taskRepository,
    this._hubRepository,
    this._userFeedbackRepository,
    this._taskExtractor,
    this._rankingService,
    this._isar,
  );

  Future<void> processIncomingNotification(
    String notificationText, {
    String source = 'Unknown',
    String appName = 'System',
  }) async {
    try {
      debugPrint('[FeedService] Processing incoming notification from $appName');
      debugPrint('[FeedService] Text: ${notificationText.substring(0, notificationText.length > 100 ? 100 : notificationText.length)}...');

      if (notificationText.isEmpty) {
        debugPrint('[FeedService] Empty notification text, skipping.');
        return;
      }

      final recentItems = await _feedRepository.getFeed(limit: 10);
      if (recentItems.any((item) => item.content == notificationText && item.source == appName)) {
        debugPrint('[FeedService] Duplicate notification detected, skipping.');
        return;
      }
      debugPrint('[FeedService] ✅ Notification passed deduplication.');

      final hubs = await _hubRepository.getAllHubs();
      final feedback = await _userFeedbackRepository.getRecentFeedback(limit: 15);
      
      final systemPrompt = LocalLLMService().buildSystemPrompt(hubs, feedback);

      ExtractionResult result;
      try {
        result = await _taskExtractor.extractFromText(notificationText, systemPrompt);
      } catch (e) {
        debugPrint('[FeedService] ❌ LLM Extraction failed: $e');
        return;
      }

      debugPrint('[FeedService] 📥 LLM Extraction Result:');
      debugPrint('  - Should Show: ${result.shouldShow}');
      debugPrint('  - Importance: ${result.importance}');
      debugPrint('  - Spotlight: ${result.inPrioritySpotlight}');
      debugPrint('  - Hubs: ${result.assignedHubs.map((h) => h.hubName).toList()}');
      debugPrint('  - Todos: ${result.todoItems.length}');
      debugPrint('  - Events: ${result.events.length}');

      if (!result.shouldShow) {
        debugPrint('[FeedService] 🚫 LLM decided not to show this notification.');
        return;
      }

      int? primaryHubId;
      List<int> secondaryHubIds = [];
      
      // 1. Try to find assigned hubs
      for (final eHub in result.assignedHubs) {
        // Try case-insensitive match first
        var matchedHub = await _hubRepository.findByName(eHub.hubName);
        
        // If not found, check if it's a known alias
        if (matchedHub == null) {
           if (eHub.hubName.toLowerCase().contains('work') || eHub.hubName.toLowerCase().contains('email')) {
             matchedHub = await _hubRepository.findByName('Work & Email');
           } else if (eHub.hubName.toLowerCase().contains('news')) {
             matchedHub = await _hubRepository.findByName('News & Trends');
           } else if (eHub.hubName.toLowerCase().contains('urgent')) {
             matchedHub = await _hubRepository.findByName('Urgent & Priority');
           } else if (eHub.hubName.toLowerCase().contains('conversation')) {
             matchedHub = await _hubRepository.findByName('Conversations');
           }
        }

        // If still not found and confidence is high, create it
        if (matchedHub == null && eHub.confidence >= 0.8) { 
          debugPrint('[FeedService] 🆕 Creating new hub from LLM: ${eHub.hubName}');
          matchedHub = await _hubRepository.createHub(eHub.hubName);
        }

        if (matchedHub != null) {
          if (primaryHubId == null) {
            primaryHubId = matchedHub.id;
          } else {
            secondaryHubIds.add(matchedHub.id);
          }
        }
      }

      // 2. Fallback logic
      if (primaryHubId == null) {
        // If LLM said "should_show: true" but gave no hubs, put in General
        debugPrint('[FeedService] ⚠️ No valid hubs assigned by LLM, falling back to General');
        final defaultHub = await _hubRepository.getDefaultHub();
        primaryHubId = defaultHub.id;
      }

      final priority = _mapImportanceToPriority(result.importance);
      final inSpotlight = result.importance.toLowerCase() == 'high' && result.shouldShow;

      await _isar.writeTxn(() async {
        final feedItem = FeedItem()
          ..source = appName
          ..content = notificationText
          ..summary = result.summary
          ..timestamp = DateTime.now()
          ..priority = priority
          ..isRead = false
          ..hubId = primaryHubId!
          ..secondaryHubIds = secondaryHubIds
          ..inPrioritySpotlight = inSpotlight
          ..metadataJson = json.encode(result.toJson());

        final feedItemId = await _isar.feedItems.put(feedItem);

        for (final todoData in result.todoItems) {
          final task = Task()
            ..feedItemId = feedItemId
            ..title = todoData.title
            ..verb = ''
            ..text = todoData.title
            ..dueDate = todoData.dueDate
            ..priority = _mapImportanceToPriority(todoData.priority)
            ..completed = false;
          
          await _isar.tasks.put(task);
          debugPrint('[FeedService] Created Todo: ${task.title}');
          await _isar.tasks.put(task);
          debugPrint('[FeedService] Created Todo: ${task.title}');
        }

        for (final evt in result.events) {
          final event = CalendarEvent()
            ..feedItemId = feedItemId
            ..title = evt.title
            ..start = evt.date ?? DateTime.now()
            ..end = (evt.date ?? DateTime.now()).add(const Duration(hours: 1))
            ..allDay = evt.allDay;
            
          await _isar.calendarEvents.put(event);
        }
      });

      debugPrint('[FeedService] ✅ Notification saved to feed (spotlight: $inSpotlight, hub: $primaryHubId)');
    } catch (e, stackTrace) {
      debugPrint('[FeedService] ❌ Error processing notification: $e');
      debugPrint('[FeedService] Stack trace: $stackTrace');
    }
  }

  int _mapImportanceToPriority(String importance) {
    switch (importance.toLowerCase()) {
      case 'high': return 9;
      case 'medium': return 5;
      case 'low': return 2;
      default: return 5;
    }
  }
  
  int _mapPriorityStringToInt(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return 3;
      case 'medium': return 2;
      case 'low': return 1;
      default: return 1;
    }
  }

  Future<void> handleUserFeedback(int feedItemId, String reason) async {
    try {
      final item = await _feedRepository.getFeedItemById(feedItemId);
      if (item != null) {
        await _userFeedbackRepository.addFeedback(item.content, item.source, reason);
        await _feedRepository.deleteFeedItem(feedItemId);
      }
    } catch (e) {
      debugPrint('[FeedService] ❌ Error handling user feedback: $e');
    }
  }
}
