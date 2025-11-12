# Personalized AI Feed

A privacy-first mobile application that consolidates data from multiple sources (Gmail, WhatsApp, News, Reddit, Instagram, Telegram) and uses AI to extract actionable tasks, rank content by priority, and present a personalized "Today's Top Priorities" dashboard.

## 🚀 Features

### Data Sources
- **Gmail**: OAuth2 integration for email processing
- **WhatsApp**: Chat export parsing and notification forwarding
- **News**: RSS feeds, NewsAPI, and GNews integration
- **Reddit**: Subreddit monitoring with PRAW
- **Instagram**: Basic Display API integration
- **Telegram**: Bot API for message processing

### AI-Powered Processing
- **Task Extraction**: LLM-powered identification of actionable items
- **Content Summarization**: Intelligent summarization of long-form content
- **Priority Ranking**: Weighted scoring based on relevance and urgency
- **Personalization**: Learning from user feedback and behavior

### Privacy-First Design
- **Local Processing**: On-device processing when possible
- **Encrypted Storage**: Sensitive data encrypted at rest
- **User Control**: Granular privacy controls and data export
- **Transparent AI**: Explainable ranking and recommendations

## 🏗️ Architecture

### Backend (FastAPI)
- **API Layer**: RESTful endpoints for all operations
- **Storage**: PostgreSQL with SQLAlchemy ORM
- **Vector Search**: FAISS for semantic similarity
- **Background Jobs**: Async processing with job queue
- **LLM Integration**: Groq (primary), Hugging Face (fallback)

### Frontend (Flutter)
- **Cross-Platform**: iOS and Android support
- **Modern UI**: Material Design 3 with dark mode
- **Offline Support**: Local caching and offline viewing
- **Notifications**: Local notifications for tasks and priorities

## 📋 Prerequisites

- Python 3.11+
- Flutter 3.16+
- PostgreSQL 15+
- Redis 7+
- Docker & Docker Compose (optional)

## 🚀 Quick Start

### Using Docker Compose (Recommended)

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd personalized-ai-feed
   ```

2. **Set up environment:**
   ```bash
   cp flutter_backend/env.example .env
   # Edit .env with your API keys
   ```

3. **Start the application:**
   ```bash
   docker-compose up -d
   ```

4. **Initialize database:**
   ```bash
   docker-compose exec backend python -c "from storage.db import init_db; init_db()"
   ```

5. **Access the application:**
   - Frontend: http://localhost
   - Backend API: http://localhost:8000
   - API Docs: http://localhost:8000/docs

### Manual Setup

#### Backend Setup

1. **Install dependencies:**
   ```bash
   cd flutter_backend
   pip install -r requirements.txt
   ```

2. **Configure database:**
   ```bash
   createdb personalized_ai_feed
   python -c "from storage.db import init_db; init_db()"
   ```

3. **Run the backend:**
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

#### Frontend Setup

1. **Install Flutter dependencies:**
   ```bash
   cd flutter_application_1
   flutter pub get
   ```

2. **Run the app:**
   ```bash
   flutter run
   ```

## 🔧 Configuration

### Required API Keys

| Service | Environment Variable | Description |
|---------|---------------------|-------------|
| Groq | `GROQ_API_KEY` | Primary LLM provider |
| Hugging Face | `HF_API_KEY` | Fallback LLM provider |
| Gmail | `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET` | OAuth credentials |
| Instagram | `INSTAGRAM_CLIENT_ID`, `INSTAGRAM_CLIENT_SECRET` | OAuth credentials |
| Google Calendar | `GOOGLE_CALENDAR_CLIENT_ID`, `GOOGLE_CALENDAR_CLIENT_SECRET` | OAuth credentials |
| NewsAPI | `NEWSAPI_KEY` | News aggregation |
| GNews | `GNEWS_API_KEY` | Alternative news source |
| Reddit | `REDDIT_CLIENT_ID`, `REDDIT_CLIENT_SECRET` | Reddit API |
| Telegram | `TELEGRAM_BOT_TOKEN` | Bot API token |

### Database Configuration

```bash
# SQLite (development)
DATABASE_URL=sqlite:///./personalized_ai_feed.db

# PostgreSQL (production)
DATABASE_URL=postgresql://user:password@host:port/dbname
```

## 📱 Usage

### Setting Up Data Sources

1. **Open the app** and navigate to Settings
2. **Connect your accounts**:
   - Gmail: OAuth2 authentication
   - Instagram: OAuth2 authentication
   - Telegram: Bot token configuration
   - News: Automatic RSS feed discovery
   - Reddit: Subreddit subscription

### Using the App

1. **Today Screen**: View your top 5 priorities with explanations
2. **Feed Screen**: Browse all content with filtering and search
3. **Tasks Screen**: Manage extracted tasks with due dates
4. **Settings Screen**: Configure privacy and notification preferences

### Task Management

- **Automatic Extraction**: AI identifies tasks from your data
- **Manual Addition**: Add tasks directly in the app
- **Calendar Sync**: Sync tasks to Google Calendar
- **Notifications**: Get reminded before due dates

## 🧪 Testing

### Backend Tests

```bash
cd flutter_backend
python run_tests.py
```

### Frontend Tests

```bash
cd flutter_application_1
flutter test
```

### Integration Tests

```bash
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Run integration tests
python test_integration.py
```

## 📊 Monitoring

### Health Checks

- Backend: `GET /health`
- Frontend: `GET /health`
- Database: Connection status
- Redis: Connection status

### Metrics

The backend exposes Prometheus metrics at `/metrics`:

- HTTP request metrics
- Database connection metrics
- Background job metrics
- LLM API usage metrics

### Logging

Structured logging with different levels:
- `INFO`: General application flow
- `WARNING`: Non-critical issues
- `ERROR`: Application errors
- `DEBUG`: Detailed debugging information

## 🔒 Security

### Data Protection

- **Encryption**: Sensitive data encrypted with AES-256
- **OAuth2**: Secure authentication flows
- **HTTPS**: All communications encrypted in transit
- **Input Validation**: All inputs sanitized and validated

### Privacy Controls

- **Local Processing**: Process data on-device when possible
- **Data Export**: Export all your data in JSON format
- **Data Deletion**: Complete data removal on request
- **Transparency**: Clear data usage policies

## 🚀 Deployment

### Production Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

### Environment-Specific Configurations

- **Development**: SQLite, debug logging, hot reload
- **Staging**: PostgreSQL, structured logging, monitoring
- **Production**: PostgreSQL, minimal logging, full monitoring

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow PEP 8 for Python code
- Use Flutter's official style guide
- Write tests for new features
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [FastAPI](https://fastapi.tiangolo.com/) for the excellent web framework
- [Flutter](https://flutter.dev/) for cross-platform mobile development
- [Groq](https://groq.com/) for fast LLM inference
- [Hugging Face](https://huggingface.co/) for open-source AI models
- [PostgreSQL](https://postgresql.org/) for reliable data storage

## 📞 Support

- **Documentation**: Check this README and [DEPLOYMENT.md](DEPLOYMENT.md)
- **Issues**: Create an issue in the repository
- **Discussions**: Use GitHub Discussions for questions
- **Email**: Contact the development team

## 🔮 Roadmap

### Phase 1 (Completed)
- ✅ Core backend infrastructure
- ✅ Basic connectors (Gmail, News, Reddit)
- ✅ AI-powered task extraction
- ✅ Flutter frontend with OAuth flows

### Phase 2 (Completed)
- ✅ WhatsApp integration
- ✅ Instagram and Telegram connectors
- ✅ Calendar synchronization
- ✅ Local notifications

### Phase 3 (Future)
- 🔄 Advanced personalization
- 🔄 Multi-language support
- 🔄 Advanced analytics
- 🔄 Enterprise features

---

**Built with ❤️ for privacy-conscious users who want to stay organized and productive.**


