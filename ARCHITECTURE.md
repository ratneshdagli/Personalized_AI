### Technical Architecture and Data Flow Guide for Personalized AI Companion

## Part 1: High-Level System Architecture

### Component Diagram (Mermaid)
```mermaid
flowchart LR
    subgraph Mobile
        A[Flutter Mobile App (UI)]
        B[Android Native Layer (Services)]
        A <--> |MethodChannel & EventChannel| B
    end

    subgraph Backend
        C[Python Backend (FastAPI)]
        D[(SQLite Database)]
        C <--> |SQLAlchemy| D
    end

    E[[Future LLM/ML Services]]

    B --> |HTTP POST /api/whatsapp/add & /api/ingest/context_event| C
    A --> |HTTP GET /api/feed & health| C
    C --> |ranking/summarization, embeddings| E
```

### Core Concept
- The project captures on-device context (starting with WhatsApp notifications), filters and forwards relevant events to a backend, stores them as unified feed items, optionally processes them with LLM/ML, and displays a personalized, searchable feed in the Flutter app.

- Live mobile UX:
  - Android services listen for notifications and optionally accessibility events, sanitize and deduplicate content, broadcast events to Flutter for live UI updates, and optionally forward to the backend over HTTP.
  - Flutter fetches stored feed items from the backend and renders them with filtering, sorting, and rich UI.


## Part 2: End-to-End Data Flow: The Journey of a WhatsApp Notification

1) Capture
- A WhatsApp notification appears on the device.

2) Listening
- `NotificationCaptureService` listens via `NotificationListenerService`.
```1:9:flutter_application_1/android/app/src/main/kotlin/com/yourorg/personalizedai/NotificationCaptureService.kt
package com.yourorg.personalizedai
...
class NotificationCaptureService : NotificationListenerService() {
```

3) Filtering & Extraction
- `onNotificationPosted` extracts `title`, `text`, dedupes, checks `pkg == "com.whatsapp"`, and filters out system messages using `isActualWhatsAppMessage`.
```52:66:flutter_application_1/android/app/src/main/kotlin/com/yourorg/personalizedai/NotificationCaptureService.kt
override fun onNotificationPosted(sbn: StatusBarNotification?) {
    ...
    val pkg = sbn.packageName ?: return
    ...
    val title = extras?.getCharSequence("android.title")?.toString() ?: ""
    var text = extras?.getCharSequence("android.text")?.toString() ?: ""
```
```98:106:flutter_application_1/android/app/src/main/kotlin/com/yourorg/personalizedai/NotificationCaptureService.kt
if (pkg == "com.whatsapp" && text.isNotEmpty()) {
    ...
    if (isActualWhatsAppMessage(title, text)) {
        handleWhatsAppNotification(title, text, timestamp)
```
```151:210:flutter_application_1/android/app/src/main/kotlin/com/yourorg/personalizedai/NotificationCaptureService.kt
private fun isActualWhatsAppMessage(title: String, text: String): Boolean {
    // Filters "new messages", short/empty, punctuation-only, etc.
    ...
    return true
}
```

4) Forwarding
- A JSON payload is built and sent via `OkHttpClient` in `handleWhatsAppNotification`.
```241:279:flutter_application_1/android/app/src/main/kotlin/com/yourorg/personalizedai/NotificationCaptureService.kt
private fun handleWhatsAppNotification(title: String, text: String, timestamp: Long) {
    ...
    val whatsappData = JSONObject().apply {
        put("sender", sender)
        put("message", text)
        put("timestamp", timestamp)
        put("user_id", userId)
    }
    ...
    val url = if (backendUrl.endsWith("/")) backendUrl + "api/whatsapp/add" else backendUrl + "/api/whatsapp/add"
```

- Independently, all notifications (not just WhatsApp) are broadcast to Flutter for real-time UI via `sendLocalBroadcast`, consumed by `MainActivity` and surfaced over `EventChannel`.
```142:149:flutter_application_1/android/app/src/main/kotlin/com/yourorg/personalizedai/NotificationCaptureService.kt
private fun sendLocalBroadcast(context: Context, event: JSONObject) {
    val intent = Intent(ACTION_CONTEXT_EVENT)
    intent.putExtra(EXTRA_EVENT_JSON, event.toString())
    context.sendBroadcast(intent)
}
```
```38:55:flutter_application_1/android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt
EventChannel(...).setStreamHandler(object : EventChannel.StreamHandler { ... })
```

5) Ingestion
- The FastAPI backend receives POST `/api/whatsapp/add` in `routes/whatsapp.py`.
```114:122:flutter_backend/routes/whatsapp.py
@router.post("/whatsapp/add")
async def add_whatsapp_message(..., message_data: WhatsAppMessageData):
    ...
```

6) Processing
- A background task `_process_whatsapp_message_background` creates `notification_data` and uses `WhatsAppConnector.process_notification_data` to construct a `FeedItem`.
```172:205:flutter_backend/routes/whatsapp.py
async def _process_whatsapp_message_background(message_data: Dict[str, Any]):
    ...
    notification_data = {
        'title': f"WhatsApp: {message_data.get('sender', 'Unknown')}",
        'content': message_data.get('message', ''),
        'sender': message_data.get('sender', 'Unknown'),
        'timestamp': timestamp_dt.isoformat(),
        'user_id': int(message_data.get('user_id', '1'))
    }
    feed_item = connector.process_notification_data(notification_data, notification_data['user_id'])
```
```275:339:flutter_backend/services/whatsapp_connector.py
def process_notification_data(...)-> Optional[FeedItem]:
    ...
    feed_item = FeedItem(
        user_id=user_id,
        title=f"WhatsApp: {sender}",
        content=cleaned_content,
        summary=summary,
        source="whatsapp_notification",
        origin_id=f"whatsapp_notif_{sender}_{parsed_time.timestamp()}",
        priority=priority,
        relevance=relevance,
        date=parsed_time,
        meta_data={...}
    )
```

7) Storage
- `save_feed_items_with_embeddings` persists to SQLite via SQLAlchemy and updates embeddings.
```345:388:flutter_backend/services/whatsapp_connector.py
def save_feed_items_with_embeddings(self, feed_items: List[FeedItem]) -> List[FeedItem]:
    db = get_db_session()
    ...
    db.add(feed_item); db.commit(); db.refresh(feed_item)
    ...
    self.vector_store.add_embedding(feed_item.id, embedding, feed_item.user_id)
```
- DB setup and models:
```15:26:flutter_backend/storage/db.py
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./personalized_ai_feed.db")
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False}, poolclass=StaticPool, ...)
```
```73:96:flutter_backend/storage/models.py
class FeedItem(Base):
    __tablename__ = "feed_items"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    source = Column(Enum(SourceType), nullable=False)
    origin_id = Column(String(255), nullable=False)
    title = Column(String(500), nullable=False)
    summary = Column(Text)
    text = Column(Text)
    date = Column(DateTime(timezone=True), nullable=False)
    priority = Column(Enum(PriorityLevel), default=PriorityLevel.MEDIUM)
    relevance_score = Column(Float, default=0.5)
    entities = Column(JSON, default=list)
    meta_data = Column("metadata", JSON, default=dict)
```

8) Retrieval
- User opens Flutter; `HomeScreen` triggers `FeedProvider.loadFeed()` after first frame.
```31:35:flutter_application_1/lib/screens/home_screen.dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  Provider.of<FeedProvider>(context, listen: false).loadFeed();
});
```

9) API Call
- `FeedProvider.loadFeed` checks health and fetches feed via `ApiService`.
```28:36:flutter_application_1/lib/providers/feed_provider.dart
_backendHealthy = await _apiService.checkHealth();
if (_backendHealthy) {
  _feed = await _apiService.fetchFeed();
}
```
- `ApiService.fetchFeed` calls GET `/api/feed`.
```41:47:flutter_application_1/lib/services/api_service.dart
final response = await http.get(Uri.parse('$baseUrl/feed'), headers: ApiConfig.defaultHeaders)...
```

10) Data Serving
- `/api/feed` queries DB, transforms ORM to API `FeedItem` model and returns combined items.
```12:24:flutter_backend/routes/feed.py
@router.get("/feed", response_model=List[FeedItem])
async def get_feed():
    db_items = db.query(DBFeedItem).order_by(DBFeedItem.date.desc()).limit(50).all()
```

11) Display
- Flutter parses JSON to `FeedItem` model and renders in UI.
```24:35:flutter_application_1/lib/models/feed_item.dart
factory FeedItem.fromJson(Map<String, dynamic> json) {
  return FeedItem(
    id: json['id'],
    title: json['title'],
    summary: json['summary'],
    content: json['content'] ?? json['summary'],
    date: DateTime.parse(json['date']),
    source: json['source'],
    priority: json['priority'],
    relevance: (json['relevance'] ?? 0.0).toDouble(),
    metaData: json['metaData'],
  );
}
```
```453:482:flutter_application_1/lib/screens/feed_screen.dart
return RefreshIndicator(
  onRefresh: _loadFeedItems,
  child: ListView.builder(
    ... itemBuilder: (context, index) { return FeedCard(feedItem: item, ...); }
  ),
);
```


## Part 3: Component Deep Dive

### A. Flutter Application (`flutter_application_1`)

- Screens
  - `main.dart`: Entry point; sets up `MultiProvider` and routes.
```13:26:flutter_application_1/lib/main.dart
void main() {
  runApp(const RootApp());
}
...
ChangeNotifierProvider(create: (_) => FeedProvider()),
```
  - `home_screen.dart`: Main shell with `BottomNavigationBar`; on load triggers `FeedProvider.loadFeed`; subscribes to live context events via `NotificationForwarderService.contextEvents`; includes quick actions and recent feed highlights.
```37:50:flutter_application_1/lib/screens/home_screen.dart
_eventsSub = NotificationForwarderService.contextEvents.listen((event) { ... });
```
  - `feed_screen.dart`: Primary feed UI with search, filters, sorting, `RefreshIndicator`, and `ListView.builder`. Data comes from `ApiService.getFeedItems`.
```48:66:flutter_application_1/lib/screens/feed_screen.dart
final feedItems = await _apiService.getFeedItems(limit: 100, sortBy: _sortBy, sortOrder: _sortOrder);
```
  - `settings_screen.dart`: Control Center for general app settings using `SharedPreferences`. Toggles for notifications, local-only mode, theme, sync interval, data management actions.
  - `settings_capture.dart`: Capture/Privacy settings controlling native services via `MethodChannel`. Toggles:
    - Forward to Server (enables backend forwarding in native prefs).
    - Local-only Mode.
    - WhatsApp Notification Capture (prompts Notification Access).
    - Advanced Capture (enables `AccessibilityService` and navigates user to settings).
```60:71:flutter_application_1/lib/screens/settings_capture.dart
await NotificationForwarderService.setServerForwarding(value);
await NotificationForwarderService.enableAccessibilityAdvancedMode(value);
```

- State Management (`providers/`)
  - `feed_provider.dart`: Manages `_feed`, `_loading`, `_backendHealthy`, `_errorMessage`. Orchestrates `checkHealth` then `fetchFeed`; notifies listeners.
```18:36:flutter_application_1/lib/providers/feed_provider.dart
_loading = true; ... _backendHealthy = await _apiService.checkHealth(); ... _feed = await _apiService.fetchFeed();
```

- Services (`services/`)
  - `api_service.dart`: HTTP client for backend:
    - `checkHealth()`: GET backend root `/` (uses `ApiConfig`).
    - `fetchFeed()`: GET `/api/feed` returning `List<FeedItem>`.
    - `getFeedItems(...)`: GET `/api/feed` with query params (client-side sorting/filtering UX).
    - `extractTasks(text)`: POST `/api/extract_tasks` (future/planned).
    - `postContextEvent(event)`: POST `/api/ingest/context_event`.
    - `postWhatsAppMessage(messageData)`: POST `/api/whatsapp/add`.
  - `notification_forwarder.dart`: Bridges to Android using:
    - `EventChannel('com.yourorg.personalizedai/context_events')` for live events.
    - `MethodChannel('com.yourorg.personalizedai/settings')` for settings operations and permission navigation.
  - `local_storage.dart`: Placeholder for local persistence.

- Models (`models/`)
  - `feed_item.dart`: Fields: `id`, `title`, `summary`, `content`, `date`, `source`, `priority`, `relevance`, `metaData`. `fromJson` handles `date` parsing and default `content`.

- Widgets
  - `feed_card.dart`: Visual card showing source icon/color, title, summary, time, and optional priority/relevance badges.

- Config
  - `config/api_config.dart`: Determines `baseUrl` using `--dart-define` or static LAN IP defaults; headers and timeouts.


### B. Android Native Layer (`flutter_application_1/android/`)

- Core Services (`app/src/main/kotlin/com/yourorg/personalizedai/`)
  - `NotificationCaptureService.kt`: Responsibilities:
    - Receive notifications via `onNotificationPosted`.
    - Extract title/text from standard and extended fields (bigText, textLines, subText).
    - Deduplicate using `LruCache` with TTL.
    - Filter only WhatsApp actual messages using `isActualWhatsAppMessage`.
    - Broadcast all notifications to Flutter via `Intent(ACTION_CONTEXT_EVENT)`.
    - Conditionally forward sanitized JSON to backend using `OkHttpClient` (`handleWhatsAppNotification`) and general events via `forwardToBackendAsync` when enabled in shared prefs.
    - Uses shared prefs keys: `KEY_SERVER_FORWARDING_ENABLED`, `KEY_BACKEND_URL`, `KEY_USER_ID`.
```333:343:flutter_application_1/android/app/src/main/kotlin/com/yourorg/personalizedai/NotificationCaptureService.kt
companion object {
    const val ACTION_CONTEXT_EVENT: String = "com.yourorg.personalizedai.CONTEXT_EVENT"
    const val EXTRA_EVENT_JSON: String = "event_json"
    const val PREFS_NAME: String = "personalized_ai_prefs"
    ...
}
```
  - `ScreenAccessibilityService.kt`: Intentional scaffold for advanced capture:
    - Listens for `TYPE_WINDOW_STATE_CHANGED` and `TYPE_VIEW_TEXT_CHANGED`.
    - Enforces whitelist/blacklist and rate limits.
    - Aggregates visible text nodes; if WhatsApp, forwards a synthesized message to `/api/whatsapp/add`.
    - Broadcasts sanitized events locally to Flutter.

- Flutter bridge (`app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt`)
  - Registers `EventChannel` and `MethodChannel`.
  - Receives native broadcast intents and forwards JSON to Flutter stream.
  - Exposes methods to read/write shared prefs and open OS settings screens.

- Configuration (`app/src/main/`)
  - `AndroidManifest.xml`:
    - Declares permissions:
      - `BIND_NOTIFICATION_LISTENER_SERVICE`
      - `BIND_ACCESSIBILITY_SERVICE`
      - `INTERNET`
      - `ACCESS_NETWORK_STATE`
      - `POST_NOTIFICATIONS`
    - Registers services:
      - `com.yourorg.personalizedai.NotificationCaptureService`
      - `com.yourorg.personalizedai.ScreenAccessibilityService` (+ `@xml/accessibility_service_config`)
    - Allows cleartext for LAN development and includes `@xml/network_security_config`.
```48:57:flutter_application_1/android/app/src/main/AndroidManifest.xml
<service
    android:name="com.yourorg.personalizedai.NotificationCaptureService"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" ... />
```
  - `res/xml/network_security_config.xml`: Permits HTTP cleartext to LAN IP for local backend testing.

  - `res/xml/accessibility_service_config.xml`: Configures event types and capability flags for the accessibility service.
```1:8:flutter_application_1/android/app/src/main/res/xml/accessibility_service_config.xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged|typeViewTextChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="300"
    android:canRetrieveWindowContent="true"
    android:description="@string/accessibility_description"
    android:settingsActivity=""/>
```

### C. Python Backend (`flutter_backend`)

- Main Application (`main.py`)
  - Initializes FastAPI, loads CORS, includes routers, sets up DB on startup (`init_db()`), and starts background worker. Exposes `/` root and `/health`.
```33:41:flutter_backend/main.py
@app.on_event("startup")
async def startup_event():
    init_db()
    from services.background_jobs import start_background_worker
    await start_background_worker()
```
  - Routers included under `/api`: `feed`, `tasks`, `search`, `feedback`, `gmail`, `news`, `reddit`, `context_ingest`, `jobs`, `instagram`, `telegram`, `calendar`, and `whatsapp` if importable.

- API Endpoints (`routes/`)
  - GET `/api/` (root route in `main.py` at `/`) serves health welcome; `/health` returns OK.
  - POST `/api/whatsapp/add` (`routes/whatsapp.py`): Ingest WhatsApp message data from mobile. Request model `WhatsAppMessageData` with fields `sender`, `message`, `timestamp` (ms), `user_id` (string, coerced to int).
  - POST `/api/whatsapp/notification`: Alternative path for notification-like data (`NotificationData`).
  - GET `/api/feed` (`routes/feed.py`): Query `FeedItem` from DB, map ORM to API model, and merge with mock and live news.
  - Other placeholder/connector routes exist: `gmail.py`, `reddit.py`, `news.py`, `instagram.py`, `telegram.py`, `calendar.py`, `context_ingest.py`, `feedback.py`, `search.py`, `tasks.py`, `jobs.py`—intended to manage ingestion, retrieval, and background sync for various sources.

- Business Logic (`services/`)
  - `whatsapp_connector.py`:
    - `process_notification_data(notification_data, user_id)`: Maps raw notification into a unified `FeedItem` (source `whatsapp_notification`), computes summary, priority, relevance, extracts tasks, and sets `date`.
    - `process_and_store_message(message_data, user_id)`: Simpler utility to build a `FeedItem` (source `whatsapp`) from sender/message/timestamp.
    - `save_feed_items_with_embeddings(feed_items)`: Persist items, create embeddings with `EmbeddingsPipeline`, and index into `vector_store`.
    - Chat export parsing is also available for bulk ingestion.
  - `ranking.py` & `summarizer.py` (and `ml/`): Planned/auxiliary functions for scoring and summarization beyond the immediate WhatsApp path; integrated via `llm_adapter`, embeddings, and vector store.

- Data Storage (`storage/`)
  - `db.py`:
    - `DATABASE_URL` defaults to `sqlite:///./personalized_ai_feed.db`.
    - Configures SQLAlchemy `engine`, `SessionLocal`, `Base`, `init_db()` creates tables and a default admin user.
  - `models.py`:
    - `FeedItem` schema:
      - `id: Integer (PK)`, `user_id: Integer (FK)`
      - `source: Enum(SourceType)`
      - `origin_id: String`
      - `title: String`
      - `summary: Text`
      - `text: Text`
      - `date: DateTime(tz)`
      - `priority: Enum(PriorityLevel)`
      - `relevance_score: Float`
      - `entities: JSON`
      - `meta_data: JSON` (stored in DB as `metadata` column)
      - `has_tasks: Boolean`, `extracted_tasks: JSON`
      - `embedding: JSON`
      - `is_encrypted: Boolean`, `processed_locally: Boolean`
      - Audit timestamps and relationships.


### Notes and Subtleties

- Flutter model vs API model:
  - Flutter `FeedItem` expects JSON fields: `id`, `title`, `summary`, `content`, `date`, `source`, `priority`, `relevance`, `metaData`.
  - Backend `/api/feed` maps ORM to those keys and fills `content` from `text or summary`.

- Live events vs stored feed:
  - Live notifications are shown immediately in the Flutter `HomeScreen` via the `EventChannel`, independently from the stored feed fetched from `/api/feed`.

- Permissions and Settings UX:
  - Permission prompts and toggles are in `settings_capture.dart` and `home_screen.dart`, invoking `MethodChannel` methods in `MainActivity` to set prefs and open OS settings.

- Development networking:
  - `AndroidManifest.xml` uses `@xml/network_security_config` and `usesCleartextTraffic="true"` for local testing against a LAN IP (`config/api_config.dart` defaults to `192.168.29.143:8000`).

- Backend startup and health:
  - Flutter `ApiService.checkHealth()` calls backend root `/` (not `/api`) to verify availability before loading the feed.

- Future LLM/ML:
  - `ml/` and `services/` include hooks for summarization, ranking, and embeddings (Groq API key loading noted in `main.py`).


