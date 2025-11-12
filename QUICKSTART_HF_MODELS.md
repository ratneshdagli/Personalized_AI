# Quick Start: Hugging Face Model Download

## 🚀 Get Started in 3 Steps

### Step 1: Build the App

```bash
cd D:\flutter_apps\Personalized_AI\new_frontend
flutter clean
flutter pub get
flutter run
```

### Step 2: Download a Model

1. Open the app
2. Scroll to "Hugging Face Model" card on Home screen
3. Choose a model:
   - **Gemma3-1B-IT q4** (529 MB, faster)
   - **Qwen2.5-1.5B-Instruct q8** (1.5 GB, better quality)
4. Tap the model to start download
5. **First time**: Authorize Hugging Face in browser
6. Wait for download (~2-7 minutes depending on speed)
7. ✅ Model installed!

### Step 3: Use the Model

The model is now ready for CPU-only inference. The LocalLlmAdapter will automatically use it for:
- Text summarization
- Task extraction
- Event detection

## 📋 What You'll See

### 1. Model Selection
```
Available Models (CPU-only):
┌─────────────────────────────────┐
│ 📥 Gemma3-1B-IT q4              │
│    529 MB • 20250514            │
└─────────────────────────────────┘
```

### 2. OAuth Authorization
- Browser opens to huggingface.co
- Click "Authorize"
- Automatically returns to app

### 3. Download Progress
```
Downloading from Hub...
████████████░░░░░░░░░░░░░░░░░░░░
45% • 237.5 MB / 529 MB
```

### 4. Verification
```
Verifying integrity...
[Progress spinner]
```

### 5. Installed
```
✅ Installed • CPU-only inference ready
Model: Gemma3-1B-IT q4
Size: 529 MB
SHA256: a1b2c3d4...
```

## 🔍 Check Logs

Look for these log messages:

### Authentication
```
I/flutter: [HFAuth] Starting OAuth flow...
I/flutter: [HFAuth] Authentication successful
```

### Download
```
I/flutter: [HFModelDownload] Starting download: Gemma3-1B-IT q4
I/flutter: [HFModelDownload] Downloaded: 100.0 MB
I/flutter: [HFModelDownload] Downloaded: 200.0 MB
I/flutter: [HFModelDownload] Download complete, verifying...
I/flutter: [HFModelDownload] SHA256 verification passed
I/flutter: [HFModelDownload] Model installed successfully
```

### Model Loading
```
I/flutter: [LocalLlmAdapter] Loading model from: /data/user/0/.../models/...
I/flutter: [ModelManager] Creating CPU-only interpreter with 4 threads
I/flutter: [ModelManager] Interpreter created successfully
I/flutter: [LocalLlmAdapter] CPU-only interpreter initialized successfully
```

## ❓ Troubleshooting

### "Authentication failed"
- Check internet connection
- Try again (OAuth can be flaky)
- Verify ProjectConfig.kt has correct credentials

### "Download failed"
- Check internet connection
- Verify Hugging Face Hub is accessible
- Try a different model

### "Size mismatch"
- Network interrupted download
- Tap "Retry Download"

### "Failed to load model"
- Remove model and re-download
- Check logs for specific error
- Verify model is TFLite format

## 📊 Performance

### Download Time (Gemma3-1B, 529 MB)
- **10 Mbps**: ~7 minutes
- **50 Mbps**: ~1.5 minutes
- **100 Mbps**: ~45 seconds

### Inference Speed (CPU-only, 4 threads)
- **Summarization**: ~500-800ms per token
- **Task extraction**: ~100-300ms (mostly regex)

## 🎯 Next Steps

After installing a model:

1. **Test summarization**:
   - Add a long message to the feed
   - Check if it gets summarized

2. **Test task extraction**:
   - Add a message with tasks (e.g., "Submit report by Friday")
   - Check if tasks are extracted

3. **Monitor performance**:
   - Check logs for latency
   - Verify CPU usage is reasonable

4. **Try different models**:
   - Remove current model
   - Download the other model
   - Compare quality and speed

## 🔐 Security Note

⚠️ **IMPORTANT**: The OAuth credentials in `ProjectConfig.kt` are **gitignored** and should **never be committed**.

If you need to share the project:
1. Share credentials via secure channel (1Password, etc.)
2. Each developer creates their own `ProjectConfig.kt` locally
3. Verify `.gitignore` includes the file

## 📚 Full Documentation

For complete details, see:
- `docs/HUGGINGFACE_INTEGRATION.md` - Complete guide
- `HUGGINGFACE_IMPLEMENTATION_SUMMARY.md` - Implementation details

## 🎉 That's It!

You now have a fully functional Hugging Face model download system with:
- ✅ OAuth authentication
- ✅ Hub model download
- ✅ SHA256 verification
- ✅ CPU-only inference
- ✅ Beautiful UI

**Enjoy your on-device AI! 🚀**
