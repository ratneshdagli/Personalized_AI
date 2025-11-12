# Personalized AI Feed Backend Setup

This document provides setup instructions for the backend LLM adapter and task extraction functionality.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd flutter_backend
pip install -r requirements.txt
```

### 2. Set Environment Variables

Create a `.env` file or set environment variables:

```bash
# Optional: Groq API Key (for primary LLM)
export GROQ_API_KEY="your_groq_api_key_here"

# Optional: Hugging Face API Key (for fallback)
export HF_API_KEY="your_hf_api_key_here"

# Optional: News API Key (for live news)
export GNEWS_API_KEY="your_gnews_api_key_here"
```

**Note**: The system works without API keys using rule-based fallbacks, but LLM features will be limited.

### 3. Run the Backend

```bash
# Development mode
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Or using Python directly
python main.py
```

### 4. Test the API

```bash
# Test all endpoints
python test_api.py

# Test LLM adapter specifically
python test_llm_adapter.py
```

## 🔧 API Endpoints

### Task Extraction
```bash
POST /api/extract_tasks
Content-Type: application/json

{
  "text": "Please submit your assignment by October 15th. Also, attend the meeting tomorrow at 2 PM."
}
```

**Response:**
```json
{
  "summary": "Assignment submission due October 15th and meeting tomorrow",
  "tasks": [
    {
      "verb": "submit",
      "due_date": "2025-10-15",
      "text": "assignment by October 15th"
    },
    {
      "verb": "attend",
      "due_date": "2025-01-XX",
      "text": "meeting tomorrow at 2 PM"
    }
  ]
}
```

### Health Check
```bash
GET /api/health
```

### Feed
```bash
GET /api/feed
```

## 🧠 LLM Configuration

### Groq (Primary)
1. Sign up at [console.groq.com](https://console.groq.com)
2. Get your API key
3. Set `GROQ_API_KEY` environment variable

### Hugging Face (Fallback)
1. Sign up at [huggingface.co](https://huggingface.co)
2. Get your API key from settings
3. Set `HF_API_KEY` environment variable

### Local Processing
If no API keys are provided, the system uses rule-based extraction as fallback.

## 📱 Flutter Integration

The Flutter app includes a floating action button (✨) on the home screen to test task extraction:

1. Tap the floating action button
2. Enter text with tasks/deadlines
3. View extracted tasks with due dates

## 🧪 Testing

### Backend Tests
```bash
# Test LLM adapter
python test_llm_adapter.py

# Test API endpoints
python test_api.py
```

### Flutter Tests
1. Run the Flutter app
2. Use the task extraction feature
3. Check console for any errors

## 🔍 Troubleshooting

### Common Issues

1. **Import Errors**: Make sure all dependencies are installed
   ```bash
   pip install -r requirements.txt
   ```

2. **API Key Issues**: Check environment variables
   ```bash
   echo $GROQ_API_KEY
   echo $HF_API_KEY
   ```

3. **Network Issues**: Ensure backend is running on correct port
   ```bash
   curl http://localhost:8000/api/health
   ```

4. **Flutter Connection**: Update IP address in `api_service.dart` if needed

### Logs
Check console output for detailed error messages and LLM adapter status.

## 📋 Features Implemented

✅ **LLM Adapter** with Groq primary + HF fallback  
✅ **Task Extraction** endpoint with structured JSON output  
✅ **Rule-based Fallback** when LLMs unavailable  
✅ **Flutter Integration** with test UI  
✅ **Comprehensive Testing** suite  
✅ **Error Handling** and graceful degradation  

## 🚧 Next Steps

- [ ] Add Gmail connector
- [ ] Add Reddit connector  
- [ ] Implement ranking service
- [ ] Add vector database for semantic search
- [ ] Add user authentication
- [ ] Add WhatsApp notification capture


