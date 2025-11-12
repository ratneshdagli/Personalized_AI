# Auto-Extraction Feature Documentation

## Overview

This feature automatically extracts **todos** and **calendar events** from WhatsApp notifications (and other notifications) using **Groq LLM**. The extracted items are stored in the backend and displayed in the Flutter frontend.

## How It Works

### Data Flow

```
WhatsApp Message/Notification
    ↓
Backend receives via /api/whatsapp/add
    ↓
1. Creates feed_item (shows in Recent Activity)
    ↓
2. Notification Processor Service
    ├→ Extract Tasks using Groq LLM
    │   └→ Save to NoSQL tasks collection
    └→ Extract Events using Groq LLM
        └→ Save to NoSQL events collection
    ↓
Frontend polls/refreshes
    ↓
Displays in:
- Home Screen > Recent Activity (feed items)
- Todo Screen (AI-extracted tasks)
- Calendar Screen (AI-extracted events)
```

## Backend Components

### 1. LLM Adapter (`ml/llm_adapter.py`)

**New Methods Added:**
- `extract_events(text)` - Extracts calendar events from text using Groq
- `_extract_events_groq(text)` - Uses Groq API with structured JSON output
- `_extract_events_rules(text)` - Fallback rule-based event extraction

**Event Extraction Prompt:**
```json
{
  "summary": "One-line summary",
  "events": [
    {
      "title": "event title",
      "start_time": "YYYY-MM-DD HH:MM or null",
      "duration_minutes": 60,
      "location": "location or null",
      "description": "brief description"
    }
  ]
}
```

### 2. Notification Processor Service (`services/notification_processor.py`)

**Purpose:** Orchestrates automatic extraction from notifications

**Key Method:**
```python
def process_notification(
    text: str,
    user_id: int,
    source: str,
    source_id: str
) -> Tuple[List[Dict], List[Dict]]
```

**Process:**
1. Extracts tasks using `llm_adapter.extract_tasks()`
2. Converts to todo format with priority detection
3. Saves to `store.tasks` collection
4. Extracts events using `llm_adapter.extract_events()`
5. Converts to event format
6. Saves to `store.events` collection

**Priority Detection:**
- High priority verbs: submit, pay, register, apply → Priority 3
- Urgent keywords: urgent, asap, deadline, today → Priority 2
- Default → Priority 1

### 3. NoSQL Store (`app/core/nosql.py`)

**New Collection Added:**
- `events` - Stores AI-extracted calendar events

**Collections:**
- `users` - User data
- `feed_items` - Feed/notification items (shown in Recent Activity)
- `tasks` - AI-extracted todos
- `connectors` - Connector configurations
- `vector_meta` - Vector embeddings metadata
- **`events`** - AI-extracted calendar events

### 4. API Routes

#### Todos API (`routes/todos.py`)

**Endpoints:**
- `GET /api/todos?user_id=1&completed=false` - Get all todos
- `POST /api/todos` - Create new todo
- `PUT /api/todos/{todo_id}` - Update todo
- `DELETE /api/todos/{todo_id}` - Soft delete todo
- `POST /api/todos/{todo_id}/complete` - Mark as completed

**Todo Model:**
```json
{
  "id": 1,
  "title": "Submit assignment",
  "verb": "submit",
  "due_date": "2025-11-05",
  "description": "Submit the project assignment by November 5th",
  "priority": 3,
  "completed": false,
  "source": "whatsapp",
  "source_id": "123",
  "user_id": 1,
  "created_at": 1730400000.0
}
```

#### Events API (`routes/events.py`)

**Endpoints:**
- `GET /api/events?user_id=1&start_date=2025-11-01` - Get events
- `POST /api/events` - Create new event
- `PUT /api/events/{event_id}` - Update event
- `DELETE /api/events/{event_id}` - Soft delete event

**Event Model:**
```json
{
  "id": 1,
  "title": "Team meeting",
  "start_time": "2025-11-05 14:00",
  "duration_minutes": 60,
  "location": "Conference Room A",
  "description": "Q4 review meeting",
  "source": "whatsapp",
  "source_id": "123",
  "user_id": 1,
  "is_ai_detected": true,
  "created_at": 1730400000.0
}
```

### 5. WhatsApp Processing (`routes/whatsapp.py`)

**Updated Function:** `_process_whatsapp_message_background()`

**New Logic:**
```python
# After creating feed_item...
from services.notification_processor import get_notification_processor
processor = get_notification_processor()

todos, events = processor.process_notification(
    text=message_text,
    user_id=user_id,
    source="whatsapp",
    source_id=feed_item_id
)
```

**What Happens:**
1. WhatsApp message arrives at `/api/whatsapp/add`
2. Creates feed item (visible in Recent Activity)
3. **Automatically extracts todos and events**
4. Stores in NoSQL database
5. Frontend can fetch and display them

## Frontend Components

### 1. API Service (`lib/services/api_service.dart`)

**New Methods:**
- `fetchTodos({userId, completed})` - Fetch AI-extracted todos
- `fetchEvents({userId, startDate, endDate})` - Fetch AI-extracted events
- `completeTodo(todoId)` - Mark todo as completed

### 2. App State (`lib/state/app_state.dart`)

**New Methods:**
- `_loadTodosFromBackend()` - Loads todos from API and converts to UI format
- `_loadEventsFromBackend()` - Loads events from API and converts to UI format
- `refreshFeed()` - Now also refreshes todos and events

**Updated Constructor:**
```dart
AppState() {
  _loadFeedFromBackend();     // Loads feed items
  _loadTodosFromBackend();    // NEW: Loads AI todos
  _loadEventsFromBackend();   // NEW: Loads AI events
}
```

### 3. Screens

**Home Screen** (`screens/home_screen.dart`)
- Recent Activity section shows feed items from WhatsApp/notifications
- Pull-to-refresh reloads feed, todos, and events

**Todo Screen** (`screens/todo_screen.dart`)
- Displays AI-extracted todos organized by:
  - Today & Urgent
  - Upcoming
  - Backlog
  - Completed
- Backend todos automatically appear here

**Calendar Screen** (`screens/calendar_screen.dart`)
- Displays AI-extracted events with:
  - AI-detected badge
  - Source indicator (WhatsApp, Email, etc.)
  - Color-coded by source

## Example Flow

### Scenario: WhatsApp Message

**Message Received:**
```
"Hi! Meeting scheduled for tomorrow at 2 PM. 
Don't forget to submit the report by Friday."
```

**Backend Processing:**

1. **Feed Item Created** (Recent Activity):
```json
{
  "id": "456",
  "title": "WhatsApp: John Doe",
  "summary": "Meeting scheduled tomorrow...",
  "source": "whatsapp",
  "date": "2025-10-31T22:48:34"
}
```

2. **Todo Extracted**:
```json
{
  "title": "Submit the report by Friday",
  "verb": "submit",
  "due_date": "2025-11-01",
  "priority": 3,
  "source": "whatsapp",
  "source_id": "456"
}
```

3. **Event Extracted**:
```json
{
  "title": "Meeting",
  "start_time": "2025-11-01 14:00",
  "duration_minutes": 60,
  "source": "whatsapp",
  "source_id": "456",
  "is_ai_detected": true
}
```

**Frontend Display:**

- **Home > Recent Activity**: Shows the WhatsApp message
- **Todo Screen**: Shows "Submit the report by Friday" in Today & Urgent
- **Calendar Screen**: Shows "Meeting" on Nov 1 at 2 PM with AI badge

## Configuration

### Backend Requirements

**Environment Variables:**
```bash
GROQ_API_KEY=your_groq_api_key_here
```

**Python Dependencies:**
- `groq` - For LLM API access
- `fastapi` - API framework
- `tinydb` - NoSQL database

### Frontend Configuration

**API Base URL** (`lib/config/api_config.dart`):
```dart
static const String lanDefaultUrl = 'http://YOUR_IP:8000/api';
```

## Testing

### Backend Testing

**1. Test Todo Extraction:**
```bash
curl -X POST http://localhost:8000/api/extract_tasks \
  -H "Content-Type: application/json" \
  -d '{"text": "Submit report by Friday and attend meeting tomorrow at 2 PM"}'
```

**2. Test WhatsApp Message:**
```bash
curl -X POST http://localhost:8000/api/whatsapp/add \
  -H "Content-Type: application/json" \
  -d '{
    "sender": "Test User",
    "message": "Meeting tomorrow at 2 PM. Submit report by Friday.",
    "timestamp": 1730400000000,
    "user_id": "1"
  }'
```

**3. Check Extracted Todos:**
```bash
curl http://localhost:8000/api/todos?user_id=1
```

**4. Check Extracted Events:**
```bash
curl http://localhost:8000/api/events?user_id=1
```

### Frontend Testing

1. **Send WhatsApp message** from your device
2. **Pull down to refresh** on Home screen
3. **Check Todo screen** - AI-extracted tasks should appear
4. **Check Calendar screen** - AI-detected events should appear
5. **Check Recent Activity** - Message should appear in feed

## Logs & Debugging

### Backend Logs

**Look for:**
```
Extracted 2 tasks from notification
Created todo: Submit the report by Friday
Extracted 1 events from notification
Created event: Meeting
Auto-extracted 2 todos and 1 events from WhatsApp message
```

### Frontend Logs

**Look for:**
```
Loaded 2 todos from backend
Successfully loaded 2 todos from backend
Loaded 1 events from backend
Successfully loaded 1 events from backend
```

## Limitations & Future Enhancements

### Current Limitations
- Events without clear date/time may not be extracted
- LLM depends on Groq API availability
- Priority detection is rule-based (can be improved)
- No conflict detection for events

### Future Enhancements
1. **Smart Deduplication** - Avoid duplicate todos/events
2. **Confidence Scoring** - Show AI confidence level
3. **User Feedback Loop** - Learn from user corrections
4. **Batch Processing** - Process multiple messages at once
5. **Context Awareness** - Use previous conversations for better extraction
6. **Calendar Integration** - Sync with Google Calendar
7. **Reminders** - Send notifications for upcoming todos/events
8. **Natural Language Queries** - "Show me todos for this week"

## Troubleshooting

### Todos/Events Not Appearing

**Check:**
1. Backend logs show extraction happening
2. Groq API key is set correctly
3. Frontend is calling `refreshFeed()`
4. NoSQL database file has `tasks` and `events` collections
5. API endpoints are accessible from frontend

### Extraction Not Working

**Check:**
1. Groq API key is valid: `echo $GROQ_API_KEY`
2. Backend logs show "Groq client initialized successfully"
3. Message text contains actionable content
4. Check `/api/extract_tasks` endpoint directly

### Events Missing Dates

**Issue:** LLM couldn't parse date/time from text

**Solution:**
- Include clear date/time in messages: "tomorrow at 2 PM" instead of "later"
- Check backend logs for parsing errors
- Improve prompts in `llm_adapter.py`

## API Summary

### Backend Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/whatsapp/add` | POST | Receive WhatsApp message |
| `/api/todos` | GET | Get all todos |
| `/api/todos` | POST | Create todo |
| `/api/todos/{id}` | PUT | Update todo |
| `/api/todos/{id}` | DELETE | Delete todo |
| `/api/todos/{id}/complete` | POST | Complete todo |
| `/api/events` | GET | Get all events |
| `/api/events` | POST | Create event |
| `/api/events/{id}` | PUT | Update event |
| `/api/events/{id}` | DELETE | Delete event |
| `/api/extract_tasks` | POST | Extract tasks from text |
| `/api/feed` | GET | Get feed items (Recent Activity) |

### Frontend Methods

| Method | Purpose |
|--------|---------|
| `apiService.fetchFeed()` | Get Recent Activity items |
| `apiService.fetchTodos()` | Get AI-extracted todos |
| `apiService.fetchEvents()` | Get AI-extracted events |
| `appState.refreshFeed()` | Refresh all data |
| `appState._loadFeedFromBackend()` | Load feed items |
| `appState._loadTodosFromBackend()` | Load todos |
| `appState._loadEventsFromBackend()` | Load events |

## Success Criteria

✅ **Feature is working if:**
1. WhatsApp messages appear in Home > Recent Activity
2. Actionable items are extracted as todos
3. Todos appear in Todo Screen with correct priorities
4. Meetings/events are extracted as calendar events
5. Events appear in Calendar Screen with AI badge
6. Backend logs show successful extraction
7. Pull-to-refresh updates all screens

## Implementation Summary

- ✅ LLM adapter extended with event extraction
- ✅ Notification processor service created
- ✅ NoSQL store updated with events collection
- ✅ API routes for todos and events
- ✅ WhatsApp processing triggers auto-extraction
- ✅ Frontend API service methods added
- ✅ Frontend state management updated
- ✅ Complete end-to-end data flow

**Your notifications now automatically become actionable todos and calendar events powered by Groq LLM!** 🚀
