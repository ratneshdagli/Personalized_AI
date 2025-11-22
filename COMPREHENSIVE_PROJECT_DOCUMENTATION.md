# Personalized AI - Comprehensive Project Documentation

**Version**: 2.0  
**Last Updated**: 2025-11-22  
**Status**: Production-Ready

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Features](#features)
5. [Setup & Installation](#setup--installation)
6. [Notification Processing Pipeline](#notification-processing-pipeline)
7. [Data Models & Schema](#data-models--schema)
8. [Services & Components](#services--components)
9. [UI/UX Implementation](#uiux-implementation)
10. [Configuration](#configuration)
11. [Testing](#testing)
12. [Known Issues](#known-issues)
13. [API Reference](#api-reference)
14. [Deployment](#deployment)
15. [Contributing](#contributing)

---

## Project Overview

Personalized AI is an offline-first, privacy-focused mobile application that uses on-device AI to intelligently organize notifications, tasks, and events. The app runs entirely locally using TensorFlow Lite models, ensuring complete data privacy.

### Key Principles

1. **Offline-First**: All processing happens on-device
2. **Privacy-First**: No data leaves the device
3. **Smart Organization**: AI-powered hub categorization
4. **Real-Time Updates**: Reactive UI with Isar database
5. **Beautiful UI**: Modern design with glassmorphism and animations

### Core Capabilities

- **Notification Analysis**: Automatically classify and extract actionable items
- **Smart Filtering**: Casual vs actionable message detection
- **Task Extraction**: Identify tasks, deadlines, and priorities
- **Event Detection**: Extract meetings, appointments, and schedules
- **Hub Organization**: Automatic categorization (College, Work, Personal, etc.)
- **Real-Time Sync**: Instant UI updates via Isar watchers

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Android System                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          NotificationListenerService                  │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │ BroadcastReceiver                   │
│                       ↓                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              MainActivity (Kotlin)                   │   │
│  │  - Receives broadcasts                               │   │
│  │  - Forwards via MethodChannel                        │   │
│  └────────────────────┬────────────────────────────────┘   │
└─────────────────────────┼──────────────────────────────────┘
                          │ MethodChannel
                          │ "com.personalized_ai.app/notifications"
┌─────────────────────────┼──────────────────────────────────┐
│                 Flutter Application                          │
│  ┌──────────────────────┴─────────────────────────────┐    │
│  │         NotificationDispatcher                      │    │
│  │  - Receives from MethodChannel                      │    │
│  │  - Routes to FeedService                            │    │
│  └────────────────────┬────────────────────────────────┘   │
│                       ↓                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              FeedService                              │  │
│  │  1. Deduplication check                               │  │
│  │  2. Build system prompt with hubs                     │  │
│  │  3. Call TaskExtractor                                │  │
│  │  4. Resolve hubs                                      │  │
│  │  5. Create FeedItem/Task/Event in Isar               │  │
│  └────────────────────┬────────────────────────────────┘   │
│                       ↓                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          TaskExtractor + LocalLLMService              │  │
│  │  - Loads model (auto-init if needed)                  │  │
│  │  - Generates response via flutter_gemma               │  │
│  │  - Cleans & validates JSON                            │  │
│  │  - Returns ExtractionResult                           │  │
│  └────────────────────┬────────────────────────────────┘   │
│                       ↓                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                 Isar Database                         │  │
│  │  - FeedItems (notifications)                          │  │
│  │  - Tasks (todos)                                      │  │
│  │  - CalendarEvents (appointments)                      │  │
│  │  - Hubs (categories)                                  │  │
│  │  - ModelRecords (downloaded models)                   │  │
│  └────────────────────┬────────────────────────────────┘   │
│                       ↓                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Isar Watchers (AppState)                 │  │
│  │  - Watch FeedItems → notifyListeners()                │  │
│  │  - Watch Tasks → notifyListeners()                    │  │
│  │  - Watch Events → notifyListeners()                   │  │
│  └────────────────────┬────────────────────────────────┘   │
│                       ↓                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                 UI Layer (Widgets)                    │  │
│  │  - HomeScreen (feed display)                          │  │
│  │  - TodoScreen (task management)                       │  │
│  │  - CalendarScreen (event view)                        │  │
│  │  - SettingsScreen (model selection)                   │  │
│  └──────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Notification Arrives
    ↓
Android NotificationListener catches it
    ↓
Broadcast to MainActivity
    ↓
MethodChannel → Flutter (NotificationDispatcher)
    ↓
FeedService.processIncomingNotification()
    ↓
┌─────────────────────────────────────┐
│ 1. Deduplication Check               │
│    - Query last 10 items             │
│    - Skip if duplicate               │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 2. Build System Prompt               │
│    - Load available hubs             │
│    - Include classification rules    │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 3. LLM Extraction                    │
│    - Auto-init if not loaded         │
│    - Generate response (60s timeout) │
│    - Clean & validate JSON           │
│    - Parse to ExtractionResult       │
└─────────────────────────────────────┘
    ↓
Check: should_show == true?
    ↓ (yes)           ↓ (no)
    ↓                Stop (ignore)
    ↓
┌─────────────────────────────────────┐
│ 4. Resolve Hubs                      │
│    - Match by name                   │
│    - Create new if confidence > 0.6  │
│    - Fallback to "General"           │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 5. Persist to Isar                   │
│    - Create FeedItem                 │
│    - Create Tasks (if any)           │
│    - Create Events (if any)          │
│    - All in one transaction          │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 6. Isar Watchers Fire                │
│    - FeedItems changed → notify      │
│    - Tasks changed → notify          │
│    - Events changed → notify         │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 7. UI Updates Automatically          │
│    - AppState.notifyListeners()      │
│    - Widgets rebuild                 │
│    - New data appears instantly      │
└─────────────────────────────────────┘
```

---

## Technology Stack

### Frontend (Flutter)

| Component | Technology | Purpose |
|-----------|------------|---------|
| Framework | Flutter 3.x | Cross-platform UI |
| State Management | Provider | Reactive state |
| Database | Isar 3.x | Local NoSQL database |
| LLM Runtime | flutter_gemma | On-device AI inference |
| Model Format | TensorFlow Lite | Optimized models |
| HTTP | http package | Model downloads |
| Storage | shared_preferences | Settings persistence |
| Paths | path_provider | File system access |
| Hashing | crypto | SHA256 verification |

### Backend (Optional - Model Server)

| Component | Technology | Purpose |
|-----------|------------|---------|
| Framework | FastAPI (Python) | Model metadata API |
| Server | Uvicorn | ASGI server |
| Status | Optional | Can work fully offline |

### Native (Android)

| Component | Technology | Purpose |
|-----------|------------|---------|
| Language | Kotlin | Native integration |
| Listener | NotificationListenerService | Notification access |
| Channel | MethodChannel | Flutter communication |

---

## Features

### 1. Smart Notification Processing

**Automatic Classification**
- Distinguishes casual from actionable messages
- Examples of **excluded** (should_show=false):
  - "what are you doing today"
  - "hi", "ok", "nice", emojis
  - "WhatsApp - 12 messages from 2 chats"
  - Weather alerts
  - Generic summaries

- Examples of **included** (should_show=true):
  - "python exp 12 hain kispe?" → College hub, creates task
  - "Meeting at 5 tomorrow" → Work hub, creates event
  - "Submit report by Friday" → Work hub, creates task with deadline

**Metadata Extraction**
- Summary generation
- Importance level (low/medium/high)
- Hub assignment with confidence scores
- Task detection with deadlines
- Event detection with times

### 2. Hub-Based Organization

**Default Hubs**
- General (fallback)
- College (assignments, classes, homework)
- Work (meetings, projects, deadlines)
- Personal (family, friends)
- System (alerts, notifications)

**Dynamic Hub Creation**
- Auto-created when LLM suggests with confidence ≥ 0.6
- Persisted to database
- Available for future categorization

**Hub Assignment Logic**
```
Keywords → Hub Mapping:
- "assignment", "exp", "code", "class", "lab" → College
- "meeting", "work", "project", "client" → Work
- Personal names, "family", "friend" → Personal
- "weather", "system" → System
```

### 3. Task Management

**Automatic Task Extraction**
- Verb identification (Submit, Complete, Answer, etc.)
- Text content
- Due date parsing (ISO8601 format)
- Priority assignment (1-3 scale)
- Confidence scoring

**Task Linking**
- Each task linked to originating FeedItem via `feedItemId`
- Navigate from task → original notification
- Maintain context and source

**Task Display**
- Todo screen shows all uncompleted tasks
- Sorted by priority
- Due date labels
- Completion tracking

### 4. Calendar Integration

**Event Detection**
- Title extraction
- Start/end time parsing
- Location detection
- All-day event support
- Recurring event patterns (future enhancement)

**Event Linking**
- Linked to FeedItem via `feedItemId`
- Preserve notification context
- AI-detected flag for transparency

**Calendar Views**
- Day/Week/Month views
- Event creation
- Editing and deletion
- Source attribution

### 5. On-Device AI

**Model Management**
- Download from Hugging Face
- Local caching with SHA256 verification
- Multiple model support
- Active model selection
- Auto-initialization on startup

**Supported Models**
- Gemma 3 (270M, 1B, 2B variants)
- Qwen 2.5 (1.5B)
- TinyLlama (1.1B)
- Llama 3.2 (1B)
- Phi-4 Mini (4B)
- DeepSeek R1 Distill

**Model Selection**
- Settings → Active Model
- Radio button selection
- Initialize on selection
- Persist choice
- Display current status

### 6. Real-Time Updates

**Isar Watchers**
```dart
// AppState automatically watches for changes
_isar.feedItems.watchLazy().listen((_) {
  notifyListeners(); // Triggers UI rebuild
});

_isar.tasks.watchLazy().listen((_) {
  notifyListeners();
});

_isar.calendarEvents.watchLazy().listen((_) {
  notifyListeners();
});
```

**Reactive Getters**
```dart
List<FeedItemVM> get filteredFeed {
  return _isar.feedItems
    .where()
    .sortByTimestampDesc()
    .findAllSync()
    .map((item) => _convertLocalToUIFeedItem(item))
    .toList();
}
```

**Auto-Refresh Flow**
1. Notification processed → Data saved to Isar
2. Isar watcher detects change
3. `notifyListeners()` called
4. All listening widgets rebuild
5. Getters re-run, fetching fresh data
6. UI updates instantly

---

## Setup & Installation

### Prerequisites

- Flutter SDK 3.10+
- Android SDK (API 24+)
- Android Studio / VS Code
- Git

### Installation Steps

#### 1. Clone Repository
```bash
git clone https://github.com/yourusername/Personalized_AI.git
cd Personalized_AI/new_frontend
```

#### 2. Install Dependencies
```bash
flutter pub get
```

#### 3. Generate Isar Files
```bash
dart run build_runner build --delete-conflicting-outputs
```

#### 4. Configure Android
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<!-- Add notification listener permission -->
<uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"/>

<!-- Add notification listener service -->
<service
    android:name=".NotificationService"
    android:label="Personalized AI Notification Listener"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

#### 5. Run Application
```bash
flutter run
```

#### 6. Grant Permissions
On first launch:
1. App requests notification access
2. Go to Settings → Notification Access
3. Enable "Personalized AI"
4. Return to app

#### 7. Download Model
1. Go to Settings → Model Management
2. Select a model (recommended: Gemma 3 1B)
3. Download (~1.2 GB)
4. Wait for completion
5. Select as Active Model

---

## Notification Processing Pipeline

### Complete Flow Diagram

```
┌─────────────────────────────────────────────────────┐
│ 1. Android Notification Received                    │
│    Example: "WhatsApp - Anish: python exp 12?"      │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ 2. NotificationListenerService (Android)            │
│    - Extract: packageName, sender, text, timestamp  │
│    - Broadcast via Intent                           │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ 3. MainActivity Receives Broadcast                  │
│    - Build payload map                              │
│    ```kotlin                                        │
│    val payload = mapOf(                             │
│      "app" to "com.whatsapp",                       │
│      "sender" to "Anish",                           │
│      "text" to "python exp 12 hain kispe?",         │
│      "timestamp" to 1763663210384                   │
│    )                                                │
│   ```                                               │
│    - Invoke MethodChannel                           │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ 4. NotificationDispatcher (Flutter)                 │
│    ```dart                                          │
│    _channel.setMethodCallHandler((call) {           │
│      if (call.method == 'onNotificationPosted') {   │
│        _feedService.processNotification(payload);   │
│      }                                              │
│    });                                              │
│    ```                                              │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│ 5. FeedService.processNotification()                │
│    Step 1: Deduplication                            │
│    ```dart                                          │
│    final recent = await _feedRepo.getFeed(limit:10);│
│    if (recent.any((i) => i.content == text)) {      │
│      return; // Skip duplicate                      │
│    }                                                │
│    ```                                              │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│    Step 2: Build System Prompt                      │
│    ```dart                                          │
│    final hubs = await _hubRepo.getAllHubs();        │
│    final prompt = LocalLLMService()                 │
│      .buildSystemPrompt(hubs);                      │
│    ```                                              │
│    Prompt includes:                                 │
│    - Classification rules                           │
│    - Available hubs                                 │
│    - Output schema                                  │
│    - Examples                                       │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│    Step 3: Extract with LLM                         │
│    ```dart                                          │
│    final result = await _taskExtractor              │
│      .extractFromText(text, systemPrompt);          │
│    ```                                              │
│                                                     │
│    TaskExtractor:                                   │
│    1. Auto-init LLM if needed                       │
│    2. Generate response (60s timeout)               │
│    3. Collect cumulative chunks                     │
│    4. Extract JSON from response                    │
│    5. Clean markdown/backticks                      │
│    6. Validate brace balance                        │
│    7. Repair if incomplete                          │
│    8. Parse to ExtractionResult                     │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│    Step 4: Check should_show                        │
│    ```dart                                          │
│    if (!result.shouldShow) {                        │
│      return; // Ignore casual message               │
│    }                                                │
│    ```                                              │
│                                                     │
│    Example LLM Output for our notification:         │
│    ```json                                          │
│    {                                                │
│      "should_show": true,                           │
│      "importance": "medium",                        │
│      "summary": "Question about Python exp 12",     │
│      "tasks": [{                                    │
│        "verb": "Answer",                            │
│        "text": "Respond to Python exp 12 query",   │
│        "due_date": null,                            │
│        "priority": 2,                               │
│        "confidence": 0.7                            │
│      }],                                            │
│      "events": [],                                  │
│      "hubs": [{                                     │
│        "hub_id": null,                              │
│        "hub_name": "College",                       │
│        "confidence": 0.9                            │
│      }]                                             │
│    }                                                │
│    ```                                              │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│    Step 5: Resolve Hubs                             │
│    ```dart                                          │
│    for (hub in result.hubs) {                       │
│      var matched = await hubRepo.findByName(        │
│        hub.hubName                                  │
│      );                                             │
│      if (matched == null && hub.confidence >= 0.6) {│
│        matched = await hubRepo.createHub(           │
│          hub.hubName                                │
│        );                                           │
│      }                                              │
│      primaryHubId = matched?.id;                    │
│    }                                                │
│    ```                                              │
│    Result: primaryHubId = 2 (College hub)           │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│    Step 6: Create Database Records                  │
│    ```dart                                          │
│    await _isar.writeTxn(() async {                  │
│      // Create FeedItem                             │
│      final feedItem = FeedItem()                    │
│        ..source = "WhatsApp"                        │
│        ..content = "python exp 12 hain kispe?"      │
│        ..summary = "Question about Python exp 12"   │
│        ..priority = 6 // medium = 6                 │
│        ..hubId = 2 // College                       │
│        ..metadataJson = jsonEncode(result);         │
│      final feedItemId = await _isar.feedItems       │
│        .put(feedItem);                              │
│                                                     │
│      // Create Task                                 │
│      final task = Task()                            │
│        ..feedItemId = feedItemId                    │
│        ..title = "Respond to Python exp 12 query"   │
│        ..verb = "Answer"                            │
│        ..priority = 2                               │
│        ..completed = false;                         │
│      await _isar.tasks.put(task);                   │
│    });                                              │
│    ```                                              │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│    Step 7: Isar Watchers Triggered                  │
│    ```dart                                          │
│    // AppState watchers fire                        │
│    _isar.feedItems.watchLazy().listen((_) {         │
│      notifyListeners();                             │
│    });                                              │
│    _isar.tasks.watchLazy().listen((_) {             │
│      notifyListeners();                             │
│    });                                              │
│    ```                                              │
└──────────────────┬──────────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────────┐
│    Step 8: UI Updates                               │
│    Widgets using AppState rebuild:                  │
│    - HomeScreen sees new feed item                  │
│    - TodoScreen sees new task                       │
│    - College hub shows updated count                │
│    All happen automatically, no manual refresh!     │
└─────────────────────────────────────────────────────┘
```

### Key Components

#### NotificationDispatcher
```dart
class NotificationDispatcher {
  final FeedService _feedService;
  static const MethodChannel _channel = 
    MethodChannel('com.personalized_ai.app/notifications');

  NotificationDispatcher(this._feedService) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNotificationPosted') {
      final payload = Map<String, dynamic>.from(call.arguments);
      await _feedService.processNotification(payload);
    }
  }
}
```

#### FeedService
```dart
class FeedService {
  Future<void> processIncomingNotification(
    String notificationText, {
    String source = 'Unknown',
    String appName = 'System',
  }) async {
    // 1. Deduplication
    // 2. Build system prompt
    // 3. Extract with LLM
    // 4. Check should_show
    // 5. Resolve hubs
    // 6. Persist to Isar
  }
}
```

#### TaskExtractor
```dart
class TaskExtractor {
  Future<ExtractionResult> extractFromText(
    String text,
    String systemPrompt,
  ) async {
    // 1. Auto-init LLM if needed
    // 2. Generate response
    // 3. Clean JSON
    // 4. Validate & repair
    // 5. Parse to model
    // 6. Return result
  }
}
```

---

## Data Models & Schema

### Isar Collections

#### 1. FeedItem
```dart
@collection
class FeedItem {
  Id id = Isar.autoIncrement;
  
  late String source;        // "WhatsApp", "Gmail", etc.
  late String content;        // Original notification text
  String? summary;            // LLM-generated summary
  late DateTime timestamp;
  
  int priority = 5;          // 1-10 (low to high)
  bool isRead = false;
  
  int? hubId;                // Primary hub
  List<int> secondaryHubIds = [];
  
  String? metadataJson;      // Full ExtractionResult
}
```

#### 2. Task
```dart
@collection
class Task {
  Id id = Isar.autoIncrement;
  
  int? feedItemId;           // Link to FeedItem
  
  late String title;
  late String verb;          // "Submit", "Complete", etc.
  late String text;
  
  DateTime? dueDate;
  int priority = 1;          // 1-3
  bool completed = false;
  DateTime? createdAt;
}
```

#### 3. CalendarEvent
```dart
@collection
class CalendarEvent {
  Id id = Isar.autoIncrement;
  
  int? feedItemId;           // Link to FeedItem
  
  late String title;
  late DateTime start;
  DateTime? end;
  String? location;
  bool allDay = false;
}
```

#### 4. Hub
```dart
@collection
class Hub {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true)
  late String name;          // "College", "Work", etc.
  
  String? description;
  int? color;                // ARGB color value
  String? icon;              // Icon identifier
  
  bool isDefault = false;    // System hubs
  DateTime? createdAt;
}
```

#### 5. ModelRecord
```dart
@collection
class ModelRecord {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true)
  late String modelId;       // "litert-community/Gemma3-1B-IT"
  
  late String path;          // Local file path
  late String checksum;      // SHA256 hash
  late String runtime;       // "gemmaIt", "qwen", etc.
  
  DateTime downloadedAt = DateTime.now();
}
```

### View Models (UI Layer)

#### FeedItemVM
```dart
class FeedItemVM {
  final String id;
  final FeedType type;       // email, message, news
  final List<String> categories;
  final String sender;
  final String title;
  final String summary;
  final String? fullContent;
  final List<String> tags;
  final String time;         // "2h ago"
  final int? priority;
}
```

#### TodoItemVM
```dart
class TodoItemVM {
  final String id;
  final String title;
  final String desc;
  final Priority priority;   // low, medium, high
  final String? dueLabel;    // "Dec 21"
  final DateTime? due;
  final bool completed;
  final List<String> tags;
}
```

#### CalendarEventVM
```dart
class CalendarEventVM {
  final String id;
  String title;
  DateTime date;
  TimeOfDay start;
  Duration duration;
  List<Color> gradient;
  String? location;
  EventSource source;        // email, messages, phone, manual
  bool isAIDetected;
}
```

### Extraction Models

#### ExtractionResult
```dart
class ExtractionResult {
  final String importance;      // "low" | "medium" | "high"
  final bool shouldShow;
  final List<ExtractedHub> hubs;
  final List<ExtractedTask> tasks;
  final List<ExtractedEvent> events;
  final String summary;
  final Map<String, dynamic> meta;
  
  factory ExtractionResult.fromJson(Map<String, dynamic> json) {
    // Defensive parsing with fallbacks
  }
}
```

#### ExtractedTask
```dart
class ExtractedTask {
  final String verb;
  final String text;
  final DateTime? dueDate;
  final int priority;         // 1-3
  final double confidence;    // 0.0-1.0
}
```

#### ExtractedEvent
```dart
class ExtractedEvent {
  final String title;
  final DateTime start;
  final DateTime? end;
  final String? location;
  final bool allDay;
  final double confidence;
}
```

#### ExtractedHub
```dart
class ExtractedHub {
  final String? hubId;
  final String hubName;
  final double confidence;
}
```

---

## Services & Components

### Core Services

#### 1. LocalLLMService
**Purpose**: Manages on-device LLM inference using flutter_gemma

**Key Methods**:
```dart
class LocalLLMService {
  // Singleton instance
  static LocalLLMService() => _instance;
  
  // Initialize with model
  Future<void> initialize({
    String? modelPath,
    String? modelName,
    bool llmSupportImage = false,
  });
  
  // Build system prompt with hubs
  String buildSystemPrompt(List<Map<String, String>> hubs);
  
  // Generate response (streaming)
  Stream<String> generateResponse(
    String prompt, 
    {List<int>? imageBytes}
  );
  
  // Check if initialized
  bool get isInitialized;
  
  // Get/save model path
  static Future<String?> getDownloadedModelPath();
  static Future<void> saveModelPath(String path, String modelName);
}
```

**Features**:
- Auto-detects model type from filename
- Streaming token generation
- Performance metrics (TTFT, decode speed)
- Image support for multimodal models
- Conversation history management
- Model caching

#### 2. TaskExtractor
**Purpose**: Extracts structured data from notification text using LLM

**Key Methods**:
```dart
class TaskExtractor {
  Future<ExtractionResult> extractFromText(
    String text,
    String systemPrompt,
  ) async {
    // 1. Auto-initialize LLM if needed
    // 2. Generate response with timeout
    // 3. Extract JSON from response
    // 4. Clean markdown/backticks
    // 5. Validate and repair JSON
    // 6. Parse to ExtractionResult
    // 7. Return with error handling
  }
}
```

**Features**:
- Auto-initialization if LLM not ready
- JSON cleaning (removes ```json fences)
- Brace balancing for incomplete JSON
- MediaPipe error handling
- Timeout protection (60s)
- Fallback responses

#### 3. FeedService
**Purpose**: Orchestrates the notification processing pipeline

**Key Methods**:
```dart
class FeedService {
  // Main entry point
  Future<void> processIncomingNotification(
    String notificationText, {
    String source = 'Unknown',
    String appName = 'System',
  });
  
  // Legacy entry point
  Future<void> processNotification(
    Map<String, dynamic> payload
  );
}
```

**Processing Steps**:
1. Deduplication check
2. Hub loading
3. System prompt building
4. LLM extraction
5. should_show check
6. Hub resolution
7. Isar persistence (FeedItem + Tasks + Events)

#### 4. HuggingFaceModelDownloadService
**Purpose**: Manages model downloads from Hugging Face

**Key Methods**:
```dart
class HuggingFaceModelDownloadService extends ChangeNotifier {
  // Load available models from API
  Future<void> loadAvailableModels();
  
  // Install model from HF
  Future<void> installModel(HFModelInfo model);
  
  // Check locally installed models
  Future<void> checkInstalledModel({bool force = false});
  
  // Get download progress
  Stream<double> get downloadProgress;
  
  // Current state
  HFModelDownloadState get state;
}
```

**Features**:
- Fetches model list from backend API
- Downloads from Hugging Face Hub
- Progress tracking
- SHA256 verification
- Auto-detection of existing models
- Model caching in `/models` directory
- Registers models in Isar

### Repositories

#### 1. FeedRepository
```dart
class FeedRepository {
  final Isar _isar;
  
  Future<List<FeedItem>> getFeed({int limit = 50});
  Future<FeedItem?> getFeedItemById(int id);
  Future<void> createFeedItem(FeedItem item);
  Future<void> markAsRead(int id);
  Future<void> deleteFeedItem(int id);
}
```

#### 2. TaskRepository
```dart
class TaskRepository {
  Future<List<Task>> getTasks({bool completed = false});
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> toggleCompleted(int id);
  Future<void> deleteTask(int id);
}
```

#### 3. HubRepository
```dart
class HubRepository {
  Future<List<Hub>> getAllHubs();
  Future<Hub?> getHubById(int id);
  Future<Hub?> findByName(String name);
  Future<Hub> createHub(String name, {String? description});
  Future<Hub> getDefaultHub();
  Future<void> ensureDefaultHubs();
}
```

#### 4. ModelRepository
```dart
class ModelRepository {
  Future<List<ModelRecord>> getInstalledModels();
  Future<ModelRecord?> getModelById(String modelId);
  Future<void> registerModel(ModelRecord model);
  Future<void> deleteModel(String modelId);
}
```

### State Management (AppState)

**Purpose**: Central state management using Provider

**Key Features**:
- Initializes all services
- Sets up Isar watchers
- Provides reactive getters
- Manages UI state

**Reactive Getters**:
```dart
class AppState extends ChangeNotifier {
  // Real-time data from Isar
  List<FeedItemVM> get filteredFeed {
    return _isar.feedItems
      .where()
      .sortByTimestampDesc()
      .findAllSync()
      .map(_convertLocalToUIFeedItem)
      .toList();
  }
  
  List<TodoItemVM> get filteredTodos {
    return _isar.tasks
      .where()
      .filter()
      .completedEqualTo(false)
      .sortByPriorityDesc()
      .findAllSync()
      .map(_convertToTodoVM)
      .toList();
  }
  
  List<CalendarEventVM> get events {
    return _isar.calendarEvents
      .where()
      .sortByStart()
      .findAllSync()
      .map(_convertToEventVM)
      .toList();
  }
}
```

**Isar Watchers**:
```dart
void _setupIsarWatchers() {
  _isar.feedItems.watchLazy().listen((_) {
    notifyListeners(); // Triggers UI rebuild
  });
  
  _isar.tasks.watchLazy().listen((_) {
    notifyListeners();
  });
  
  _isar.calendarEvents.watchLazy().listen((_) {
    notifyListeners();
  });
}
```

---

## UI/UX Implementation

### Screens

#### 1. HomeScreen
**Purpose**: Main feed display with hub navigation

**Features**:
- Pull-to-refresh
- Feed item list
- Hub grid (3 columns)
- Search bar
- Filter options

**Data Source**:
```dart
final appState = context.watch<AppState>();
final items = appState.filteredFeed; // Reads from Isar
```

#### 2. TodoScreen
**Purpose**: Task management

**Features**:
- Uncompleted tasks
- Priority filtering
- Due date display
- Completion toggle
- Task creation

**Data Source**:
```dart
final todos = context.watch<AppState>().filteredTodos;
```

#### 3. CalendarScreen
**Purpose**: Event visualization

**Features**:
- Day/Week/Month views
- Event creation
- Time slot display
- AI-detected badge
- Event editing

**Data Source**:
```dart
final events = context.watch<AppState>().events;
```

#### 4. SettingsScreen
**Purpose**: Configuration and model management

**Sections**:
1. **Active Model Selector**
   - Radio buttons for installed models
   - Initialization on selection
   - Loading indicator
   - Status feedback

2. **Model Management**
   - HFModelManagerCard widget
   - Model download
   - Installation progress
   - Installed model list

3. **Developer Tools**
   - Debug LLM Screen link
   - Test extraction

**Key Components**:
```dart
// Model selection
RadioListTile<String>(
  title: Text(model.displayName),
  value: model.path,
  groupValue: _selectedModelId,
  onChanged: (value) => _selectModel(value),
);

// Model initialization
Future<void> _selectModel(String? modelPath) async {
  if (modelPath == null) return;
  
  setState(() => _isInitializing = true);
  
  try {
    await LocalLLMService().initialize(
      modelPath: modelPath,
    );
    // Show success
  } catch (e) {
    // Show error
  } finally {
    setState(() => _isInitializing = false);
  }
}
```

#### 5. DebugLLMScreen
**Purpose**: Test LLM extraction

**Features**:
- Text input
- "Extract" button
- JSON output display
- Parsed result view
- Model status indicator

**Status States**:
- 🔵 Blue: Checking/Initializing
- 🟢 Green: Model ready
- 🔴 Red: Error/Not initialized

**Auto-Check**:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _checkModelStatus();
  });
}

Future<void> _checkModelStatus() async {
  final llm = LocalLLMService();
  
  if (!llm.isInitialized) {
    final modelPath = await LocalLLMService.getDownloadedModelPath();
    if (modelPath != null) {
      await llm.initialize(modelPath: modelPath);
    }
  }
}
```

### Widget Components

#### HFModelManagerCard
**Purpose**: Displays and manages model downloads

**Features**:
- Available models grid
- Download button
- Progress bar
- Installed badge
- Model info display

**State Management**:
```dart
ChangeNotifierProvider<HuggingFaceModelDownloadService>(
  create: (context) {
    final service = HuggingFaceModelDownloadService();
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      service.init(appState.modelRepository);
    } catch (e) {
      // Handle if AppState not ready
    }
    return service;
  },
  child: _HFModelManagerCardContent(),
);
```

#### GlassCard
**Purpose**: Glassmorphism effect container

**Usage**:
```dart
GlassCard(
  padding: EdgeInsets.all(16),
  child: Column(children: [...]),
);
```

**Effect**:
- Frosted glass appearance
- Blur backdrop
- Subtle border
- Shadow

#### LavishBackground
**Purpose**: Animated gradient background

**Usage**:
```dart
LavishBackground(
  dark: true,
  child: SafeArea(child: content),
);
```

**Features**:
- Multiple gradient layers
- Animation support
- Dark/light mode
- Customizable colors

---

## Configuration

### System Prompt Tuning

Edit `LocalLLMService.buildSystemPrompt()` to adjust:

**Classification Rules**:
```dart
Classification Rules:
1. Casual messages (greetings, small-talk, questions with no commitment): 
   should_show=false, importance="low"
2. Actionable content (tasks, deadlines, meetings, commitments): 
   should_show=true, importance based on urgency
3. If no tasks/events/commitments: tasks=[], events=[], hubs=[]
```

**Hub Assignment**:
```dart
5. HUB ASSIGNMENT
Hubs are determined by message content:
- "assignment", "exp", "code", "class", "lab" → hub_name: "College"
- "meeting", "work", "project", "client" → hub_name: "Work"
- personal names, "family", "friend" → hub_name: "Personal"
```

**Add Custom Rules**:
```dart
// Add to hub assignment section
- "gym", "workout", "exercise" → hub_name: "Health"
- "shopping", "grocery", "mall" → hub_name: "Shopping"
```

### Model Configuration

**Available Models API**:
Edit `HuggingFaceModelDownloadService._availableModelsApi`:
```dart
static const String _availableModelsApi = 
  'https://your-backend.com/models/available';
```

**Model Storage**:
Models are stored at: `/data/data/com.example.figma/files/models/`

**Verification**:
SHA256 checksums are verified on:
- Initial download
- Cache initialization
- Model registration

### Timeout Settings

**LLM Generation**:
```dart
// TaskExtractor
const Duration(seconds: 60)
```

**HTTP Requests**:
```dart
// HuggingFaceModelDownloadService
timeout: Duration(seconds: 300) // 5 minutes for downloads
```

### Notification Settings

**Deduplication Window**:
```dart
// FeedService.processNotification
final recentItems = await _feedRepository.getFeed(limit: 10);
```

**Hub Confidence Threshold**:
```dart
// FeedService - hub creation threshold
if (matchedHub == null && eHub.confidence >= 0.6) {
  matchedHub = await hubRepo.createHub(eHub.hubName);
}
```

---

## Testing

### Manual Testing

#### Test Notification Pipeline

1. **Send Test Notification**:
   ```bash
   adb shell service call notification 1
   ```

2. **Example Notifications**:
   - "what are you doing today" → should_show=false
   - "python exp 12 hain kispe?" → should_show=true, College hub, task created
   - "Meeting at 5 tomorrow" → should_show=true, event created

3. **Check Logs**:
   ```
   [NotificationDispatcher] Received payload from Native: ...
   [FeedService] ✅ Notification passed deduplication.
   [TaskExtractor] 📥 Receiving first chunk...
   [FeedService] 📥 LLM Extraction Result:
     - Should Show: true
     - Tasks: 1
   [FeedService] ✅ FeedItem saved with ID: 5
   [AppState] 🔄 FeedItems changed, notifying listeners...
   ```

4. **Verify UI**:
   - Home screen shows new item
   - Todo screen shows task (if any)
   - Calendar shows event (if any)
   - Hub counts updated

#### Test Model Management

1. Go to Settings → Model Management
2. Select a model
3. Click Download
4. Wait for completion
5. Go to Settings → Active Model
6. Select downloaded model
7. Wait for initialization
8. Check status in Debug LLM Screen

#### Test Extraction

1. Go to Settings → Developer Tools → Debug LLM
2. Enter test text: "Submit report by Friday 5pm"
3. Click "Extract"
4. Verify JSON output:
   ```json
   {
     "should_show": true,
     "importance": "high",
     "summary": "Report submission deadline",
     "tasks": [{
       "verb": "Submit",
       "text": "Submit report",
       "due_date": "2025-11-22T17:00:00Z",
       "priority": 1,
       "confidence": 0.9
     }],
     "hubs": [{"hub_name": "Work", "confidence": 0.8}]
   }
   ```

### Unit Tests

#### TaskExtractor Test
```dart
void main() {
  group('TaskExtractor', () {
    late TaskExtractor extractor;
    late MockLocalLLMService mockLLM;
    
    setUp(() {
      mockLLM = MockLocalLLMService();
      extractor = TaskExtractor(mockLLM);
    });
    
    test('extracts tasks from actionable message', () async {
      // Mock LLM response
      when(mockLLM.generateResponse(any)).thenAnswer(
        (_) => Stream.value('{"should_show":true,...}')
      );
      
      final result = await extractor.extractFromText(
        'Submit report by Friday',
        'system prompt',
      );
      
      expect(result.shouldShow, true);
      expect(result.tasks.length, 1);
      expect(result.tasks[0].verb, 'Submit');
    });
    
    test('ignores casual messages', () async {
      when(mockLLM.generateResponse(any)).thenAnswer(
        (_) => Stream.value('{"should_show":false,...}')
      );
      
      final result = await extractor.extractFromText(
        'what are you doing',
        'system prompt',
      );
      
      expect(result.shouldShow, false);
      expect(result.tasks.length, 0);
    });
  });
}
```

### Integration Tests

#### End-to-End Flow
```dart
void main() {
  testWidgets('notification creates feed item', (tester) async {
    // Initialize app
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    
    // Simulate notification
    await simulateNotification('Meeting at 5pm tomorrow');
    await tester.pumpAndSettle();
    
    // Verify feed item appears
    expect(find.text('Meeting at 5pm tomorrow'), findsOneWidget);
    
    // Verify event created
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    expect(find.text('Meeting'), findsOneWidget);
  });
}
```

---

## Known Issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for detailed information.

### Summary

1. **MediaPipe Timestamp Errors**: Non-fatal noise from flutter_gemma (handled gracefully)
2. **LLM Hanging**: Auto-initialization and timeout prevent infinite waiting
3. **JSON Parsing Errors**: Automatic repair and fallback responses
4. **UI Not Updating**: Fixed with Isar watchers and reactive getters

### Workarounds

- MediaPipe errors are caught and logged once
- LLM auto-initializes on first use
- JSON is automatically cleaned and repaired
- UI updates happen automatically via Isar watchers

---

## API Reference

### FeedService

```dart
class FeedService {
  /// Main entry point for processing incoming notifications
  Future<void> processIncomingNotification(
    String notificationText, {
    String source = 'Unknown',
    String appName = 'System',
  });
  
  /// Legacy entry point (calls processIncomingNotification)
  Future<void> processNotification(
    Map<String, dynamic> payload,
  );
}
```

### LocalLLMService

```dart
class LocalLLMService {
  /// Singleton instance
  factory LocalLLMService();
  
  /// Initialize with model
  Future<void> initialize({
    String? modelPath,
    String? modelName,
    bool llmSupportImage = false,
  });
  
  /// Build system prompt
  String buildSystemPrompt(
    List<Map<String, String>> hubs,
  );
  
  /// Generate response (streaming)
  Stream<String> generateResponse(
    String prompt, {
    List<int>? imageBytes,
  });
  
  /// Check initialization status
  bool get isInitialized;
  
  /// Get saved model path
  static Future<String?> getDownloadedModelPath();
  
  /// Save model path
  static Future<void> saveModelPath(
    String path,
    String modelName,
  );
}
```

### TaskExtractor

```dart
class TaskExtractor {
  /// Extract structured data from text
  Future<ExtractionResult> extractFromText(
    String text,
    String systemPrompt,
  );
}
```

### HuggingFaceModelDownloadService

```dart
class HuggingFaceModelDownloadService extends ChangeNotifier {
  /// Initialize with model repository
  void init(ModelRepository repository);
  
  /// Load available models from API
  Future<void> loadAvailableModels();
  
  /// Install model
  Future<void> installModel(HFModelInfo model);
  
  /// Check installed models
  Future<void> checkInstalledModel({bool force = false});
  
  /// Current state
  HFModelDownloadState get state;
  
  /// Available models
  List<HFModelInfo> get availableModels;
}
```

### AppState

```dart
class AppState extends ChangeNotifier {
  /// Initialize all services
  Future<void> init();
  
  /// Real-time feed from Isar
  List<FeedItemVM> get filteredFeed;
  
  /// Real-time todos from Isar
  List<TodoItemVM> get filteredTodos;
  
  /// Real-time events from Isar
  List<CalendarEventVM> get events;
  
  /// Refresh from backend (optional)
  Future<void> refreshFeed();
}
```

---

## Deployment

### Build for Production

#### Android APK
```bash
flutter build apk --release
```

#### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

### Pre-Release Checklist

- [ ] Run build_runner to generate Isar files
- [ ] Test on physical device
- [ ] Verify notification access permissions
- [ ] Test model download and initialization
- [ ] Test notification processing end-to-end
- [ ] Check UI updates in all screens
- [ ] Verify data persistence after restart
- [ ] Test with different message types
- [ ] Review logs for errors
- [ ] Test offline functionality

### Environment Variables

Create `.env` file (optional):
```
BACKEND_URL=https://your-backend.com
MODEL_API_URL=https://your-backend.com/models/available
```

### Release Configuration

Edit `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        minSdkVersion 24  // Minimum for notification listener
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.debug
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt')
        }
    }
}
```

---

## Contributing

### Development Setup

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Make changes
4. Run tests: `flutter test`
5. Commit: `git commit -m 'Add amazing feature'`
6. Push: `git push origin feature/amazing-feature`
7. Open Pull Request

### Code Style

- Follow Dart style guide
- Use meaningful variable names
- Add comments for complex logic
- Write tests for new features
- Update documentation

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- feat: New feature
- fix: Bug fix
- docs: Documentation
- style: Formatting
- refactor: Code restructuring
- test: Tests
- chore: Maintenance

**Example**:
```
feat(extraction): Add JSON repair logic

- Implements brace balancing
- Handles incomplete JSON
- Adds validation step

Closes #123
```

### Pull Request Guidelines

- Link related issues
- Describe changes clearly
- Include screenshots for UI changes
- Ensure tests pass
- Update documentation
- Request review from maintainers

---

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Isar Documentation](https://isar.dev)
- [flutter_gemma GitHub](https://github.com/google/flutter-mediapipe/tree/main/packages/mediapipe-task-genai)
- [Hugging Face Models](https://huggingface.co/models?library=transformers&sort=trending)
- [NOTIFICATION_PROCESSING_PIPELINE.md](NOTIFICATION_PROCESSING_PIPELINE.md)
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)

---

## License

MIT License - See LICENSE file for details

---

## Support

For issues, questions, or contributions:
- GitHub Issues: [Report a bug](https://github.com/yourusername/Personalized_AI/issues)
- Discussions: [Ask questions](https://github.com/yourusername/Personalized_AI/discussions)
- Email: support@personalizedai.dev

---

**Last Updated**: 2025-11-22  
**Version**: 2.0  
**Maintained By**: Personalized AI Team
