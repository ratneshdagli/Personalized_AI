# Personalized AI - New Flutter Frontend

A modern, beautiful Flutter UI for the Personalized AI productivity app with full FastAPI backend integration.

## ✨ Features

- **Modern Glassmorphism UI** - Beautiful gradient backgrounds with frosted glass effects
- **Real-time Backend Integration** - Connects to FastAPI backend for all data
- **AI-Powered Task Extraction** - Uses backend LLM to extract tasks from text
- **Pull-to-Refresh** - Easily refresh feed data with a gesture
- **Smart Categorization** - Organizes content into Urgent, Work, Personal, News, etc.
- **Dark/Light Theme** - Full theme support with smooth transitions
- **Responsive Design** - Optimized for all screen sizes

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.9 or higher
- Running FastAPI backend (see `../flutter_backend/`)
- Device/Emulator on same network as backend

### Installation

```bash
# Navigate to frontend directory
cd new_frontend

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Backend Configuration

Update the backend IP address in `lib/config/api_config.dart`:

```dart
static const String lanDefaultUrl = 'http://YOUR_IP:8000/api';
```

**Or** use command line override:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000/api
```

## 📱 Screens

- **Home** - Feed items from backend organized by hubs
- **Todo** - AI-extracted tasks with priority organization
- **Calendar** - Events with AI-detection from messages
- **Settings** - Theme and app configuration

## 🔌 Backend Integration

### API Endpoints Used

- `GET /api/feed` - Fetch all feed items
- `POST /api/extract_tasks` - Extract tasks using LLM
- `GET /health` - Backend health check
- `POST /ingest/context_event` - Post context events
- `POST /api/whatsapp/add` - Post WhatsApp messages

### Data Flow

```
User Action → Screen → AppState → ApiService → Backend → NoSQL Store
```

## 📖 Documentation

- **Architecture**: See `../new_frontend_architecture.md`
- **Migration**: See `../MIGRATION_NOTES.md`
- **Backend**: See `../backend_architecture.md`

## 🐛 Troubleshooting

### Backend Connection Issues

1. Check backend is running: `http://YOUR_IP:8000/health`
2. Verify IP address in `api_config.dart`
3. Check firewall allows port 8000
4. Ensure same network

### Build Errors

```bash
flutter clean && flutter pub get
flutter doctor
```

## 📄 Status

✅ **Production Ready**  
**Version**: 1.0.0  
**Last Updated**: October 2025
