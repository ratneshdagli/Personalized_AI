# Notification Processing Pipeline - Complete Flow

## Overview
This document describes the complete end-to-end notification processing pipeline from Android notification to feed items, tasks, and calendar events.

## Architecture Flow

```
Android Notification
    ↓
NotificationListener (Android)
    ↓
MethodChannel: onNotificationPosted
    ↓
NotificationDispatcher (Flutter)
    ↓
FeedService.processIncomingNotification() or processNotification()
    ↓
├─> TaskExtractor (with LocalLLMService)
│   └─> ExtractionResult (JSON)
│       ├─> should_show (true/false)
│       ├─> importance (low/medium/high)
│       ├─> summary (string)
│       ├─> hubs (array)
│       ├─> tasks (array)
│       └─> events (array)
    ↓
├─> If should_show == false → STOP (don't create anything)
│
└─> If should_show == true:
    ├─> Resolve Hubs (match to existing or create new)
    ├─> Create FeedItem in Isar
    ├─> Create Task(s) linked to FeedItem
    └─> Create CalendarEvent(s) linked to FeedItem
```

## Component Breakdown

### 1. Android Side (NotificationListener)
- **Location**: `android/app/src/main/kotlin/.../NotificationService.kt`
- **Function**: Listens to all system notifications
- **Output**: Sends to Flutter via MethodChannel with payload:
  ```kotlin
  {
    "text": "notification content",
    "app": "WhatsApp",
    "sender": "Contact Name"
  }
  ```

### 2. NotificationDispatcher
- **Location**: `lib/services/notification_dispatcher.dart`
- **Function**: Receives MethodChannel calls from Android
- **Method**: `_handleMethodCall(MethodCall call)`
- **Action**: Calls `FeedService.processNotification(payload)`

### 3. FeedService - Main Processing Hub
- **Location**: `lib/services/feed_service.dart`
- **Entry Points**:
  - `processIncomingNotification(String text, {String source, String appName})` - Simple API
  - `processNotification(Map<String, dynamic> payload)` - Full implementation

#### Processing Steps:

**Step 1: Deduplication**
```dart
final recentItems = await _feedRepository.getFeed(limit: 10);
if (recentItems.any((item) => item.content == text && item.source == appName)) {
  return; // Ignore duplicates
}
```

**Step 2: Load Hubs for Context**
```dart
final hubRepo = HubRepository(_isar);
await hubRepo.ensureDefaultHubs();
final hubs = await hubRepo.getAllHubs();
final hubsMap = hubs.map((h) => {'id': h.id.toString(), 'name': h.name}).toList();
```

**Step 3: Build System Prompt**
```dart
final systemPrompt = LocalLLMService().buildSystemPrompt(hubsMap);
```

**Step 4: Extract with LLM**
```dart
final extractionResult = await _taskExtractor.extractFromText(text, systemPrompt);
```

**Step 5: Check should_show**
```dart
if (!extractionResult.shouldShow) {
  debugPrint('Notification ignored by LLM: ${extractionResult.summary}');
  return; // Don't create any records
}
```

**Step 6: Resolve Hubs**
```dart
// Match extracted hubs to existing hubs or create new ones
// Prioritize by confidence score
// Assign primary hub and secondary hubs
```

**Step 7: Create FeedItem**
```dart
final feedItem = FeedItem()
  ..source = appName
  ..content = text
  ..summary = extractionResult.summary
  ..timestamp = DateTime.now()
  ..priority = _mapImportanceToPriority(extractionResult.importance)
  ..isRead = false
  ..hubId = primaryHubId
  ..secondaryHubIds = secondaryHubIds
  ..metadataJson = json.encode(extractionResult.toJson());
```

**Step 8: Create Tasks & Events in Transaction**
```dart
await _isar.writeTxn(() async {
  final feedItemId = await _isar.feedItems.put(feedItem);

  // Create tasks
  for (final taskData in extractionResult.tasks) {
    final task = Task()
      ..feedItemId = feedItemId
      ..title = taskData.text
      ..verb = taskData.verb
      // ... other fields
    await _isar.tasks.put(task);
  }

  // Create events
  for (final eventData in extractionResult.events) {
    final event = CalendarEvent()
      ..feedItemId = feedItemId
      ..title = eventData.title
      // ... other fields
    await _isar.calendarEvents.put(event);
  }
});
```

### 4. TaskExtractor & LocalLLMService
- **Location**: `lib/services/task_extractor.dart`, `lib/services/local_llm_service.dart`
- **Function**: Analyzes text using local LLM (flutter_gemma)
- **System Prompt**: Comprehensive rules for classification (see LocalLLMService.buildSystemPrompt)

#### Key Classification Rules:
1. **Casual messages** → `should_show = false`
   - Examples: "what are you doing today", "hi", "ok", emojis, weather alerts
   
2. **Actionable messages** → `should_show = true`
   - Contains: questions, plans, meetings, dates/times, instructions, requests
   
3. **Hub Assignment**:
   - "assignment", "exp", "code", "class" → College
   - "meeting", "work", "project" → Work
   - Personal names → Personal

### 5. Data Models (Isar)

**FeedItem** (`lib/data/schema/feed_item.dart`)
```dart
class FeedItem {
  Id id = Isar.autoIncrement;
  late String source;         // "WhatsApp", "Gmail", etc.
  late String content;         // Original notification text
  String? summary;             // LLM-generated summary
  late DateTime timestamp;
  int priority = 5;           // Mapped from importance
  bool isRead = false;
  int? hubId;                 // Primary hub
  List<int> secondaryHubIds = [];
  String? metadataJson;       // Full ExtractionResult
}
```

**Task** (`lib/data/schema/task.dart`)
```dart
class Task {
  Id id = Isar.autoIncrement;
  int? feedItemId;            // Links back to FeedItem
  late String title;
  late String verb;           // "Submit", "Complete", "Answer"
  late String text;
  DateTime? dueDate;
  int priority = 1;
  bool completed = false;
  DateTime? createdAt;
}
```

**CalendarEvent** (`lib/data/schema/calendar_event.dart`)
```dart
class CalendarEvent {
  Id id = Isar.autoIncrement;
  int? feedItemId;            // Links back to FeedItem
  late String title;
  late DateTime start;
  DateTime? end;
  String? location;
  bool allDay = false;
}
```

## Example Scenarios

### Scenario 1: Casual Message (No Show)
**Input**: `"what are you doing today abby"`

**LLM Output**:
```json
{
  "should_show": false,
  "importance": "low",
  "summary": "Casual question to Abby about today's plans",
  "tasks": [],
  "events": [],
  "hubs": []
}
```

**Result**: Nothing created in Isar. Notification ignored.

---

### Scenario 2: Academic Question (Show + Task)
**Input**: `"C1-1 (10 messages): Anish Dj Ce1 - python exp 12 hain kispe?"`

**LLM Output**:
```json
{
  "should_show": true,
  "importance": "medium",
  "summary": "Question about Python experiment 12",
  "tasks": [{
    "verb": "Answer",
    "text": "Respond to query about Python experiment 12",
    "due_date": null,
    "priority": 2,
    "confidence": 0.7
  }],
  "events": [],
  "hubs": [{
    "hub_id": null,
    "hub_name": "College",
    "confidence": 0.9
  }]
}
```

**Result**:
- ✅ **FeedItem** created with summary, content, priority=6, hubId=College
- ✅ **Task** created: "Respond to query about Python experiment 12"
- ✅ Appears in Feed list
- ✅ Appears in College hub
- ✅ Appears in Todo list (uncompleted task)

---

### Scenario 3: Meeting Notification (Show + Event)
**Input**: `"Meeting at 5 tomorrow"`

**LLM Output**:
```json
{
  "should_show": true,
  "importance": "high",
  "summary": "Meeting scheduled for tomorrow at 5pm",
  "tasks": [],
  "events": [{
    "title": "Meeting",
    "start": "2025-11-21T17:00:00Z",
    "end": null,
    "location": null,
    "all_day": false,
    "confidence": 0.8
  }],
  "hubs": [{
    "hub_id": null,
    "hub_name": "Work",
    "confidence": 0.7
  }]
}
```

**Result**:
- ✅ **FeedItem** created with summary, content, priority=9, hubId=Work
- ✅ **CalendarEvent** created for tomorrow 5pm
- ✅ Appears in Feed list
- ✅ Appears in Work hub
- ✅ Appears in Calendar view

---

### Scenario 4: Generic WhatsApp Summary (No Show)
**Input**: `"WhatsApp - 12 messages from 2 chats"`

**LLM Output**:
```json
{
  "should_show": false,
  "importance": "low",
  "summary": "Generic WhatsApp activity summary",
  "tasks": [],
  "events": [],
  "hubs": []
}
```

**Result**: Nothing created. Too generic/non-actionable.

## How to Use

### For Testing
Use the **Debug LLM Screen** (Settings → Developer Tools → Open LLM Diagnostics):
1. Enter notification text
2. Click "Extract"
3. See the JSON output and parsed results

### For Production
The pipeline runs automatically:
1. Android NotificationListener catches all notifications
2. Sends to Flutter via MethodChannel
3. FeedService processes automatically
4. Results appear in:
   - Main Feed (`home_screen.dart`)
   - Hub views
   - Todo list (`todo_screen.dart`)
   - Calendar views

## Configuration

### Adjust Hub Assignment
Edit `LocalLLMService.buildSystemPrompt()` hub assignment rules:
```dart
5. HUB ASSIGNMENT
Hubs are determined by message content:
- "assignment", "exp" → hub_name: "College"
- "meeting", "work" → hub_name: "Work"
// Add your custom rules here
```

### Adjust Classification Threshold
Change what counts as "actionable" by editing the system prompt logic rules section.

### Adjust Deduplication Window
Change the limit in FeedService:
```dart
final recentItems = await _feedRepository.getFeed(limit: 10); // Increase for longer window
```

## Debugging

Enable verbose logging to see the full pipeline:
```dart
debugPrint('[FeedService] Processing incoming notification from $appName');
debugPrint('[FeedService] Text: ...');
debugPrint('[TaskExtractor] Starting extraction...');
debugPrint('[TaskExtractor] Full response received...');
debugPrint('[TaskExtractor] Extracted JSON...');
```

All logs are prefixed with component names for easy filtering.
