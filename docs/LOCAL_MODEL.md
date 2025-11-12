# Local On-Device AI Model

This document describes how to configure, download, and use on-device AI models in the Personalized AI app.

## Overview

The app supports running AI inference locally on your device for:
- Text summarization
- Task extraction from messages
- Event detection

This provides:
- **Privacy**: Your data never leaves your device
- **Speed**: No network latency
- **Offline capability**: Works without internet connection
- **Cost savings**: No API calls to cloud services

## Architecture

```
┌─────────────────────────────────────────────────┐
│  UI Layer (ModelManagerCard)                    │
│  - Download button & progress                   │
│  - Status display                                │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  Service Layer (ModelDownloadService)           │
│  - HTTP streaming download                      │
│  - SHA256 verification                          │
│  - State management                              │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  Model Layer (ModelManager)                     │
│  - Manifest parsing                              │
│  - File storage                                  │
│  - Metadata persistence                          │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│  Inference Layer (LocalLlmAdapter)              │
│  - TFLite interpreter                            │
│  - Heuristic fallbacks                           │
└─────────────────────────────────────────────────┘
```

## Configuration

### 1. Model Manifest

Edit `new_frontend/assets/models/model_manifest.json`:

```json
{
  "default": {
    "name": "gemma3-1b-it-q4.tflite",
    "url": "https://your-cdn.com/models/gemma3-1b-it-q4.tflite",
    "sha256": "a1b2c3d4e5f6...",
    "size": 554661246
  }
}
```

**Fields:**
- `name`: Display name and filename (will be sanitized)
- `url`: Direct download URL (must be HTTPS)
- `sha256`: SHA256 checksum (lowercase hex, 64 characters)
- `size`: File size in bytes (optional but recommended)

### 2. Compute SHA256

```bash
# Linux/Mac
sha256sum model.tflite

# Windows PowerShell
Get-FileHash model.tflite -Algorithm SHA256

# Python
python -c "import hashlib; print(hashlib.sha256(open('model.tflite','rb').read()).hexdigest())"
```

### 3. Host the Model

Upload your `.tflite` file to a CDN or static file server:
- **GitHub Releases**: Good for open-source projects
- **Google Cloud Storage**: Set CORS and public read access
- **AWS S3**: Configure bucket policy for public downloads
- **Your own server**: Ensure HTTPS and CORS headers

**Important**: The URL must support:
- HTTPS (required for security)
- Range requests (optional but improves resume capability)
- CORS headers if hosting on different domain

## User Flow

### Download Flow

1. User opens app → Home screen shows ModelManagerCard
2. Status: "Not installed • Using cloud fallback"
3. User taps "Download Model"
4. Service:
   - Reads manifest from assets
   - Validates URL and metadata
   - Downloads file with streaming (shows progress %)
   - Computes SHA256 while downloading
   - Verifies size and checksum
   - Saves to app-private storage
   - Initializes TFLite interpreter
5. Status: "Installed • Ready for use"

### Error Handling

| Error | Cause | User Action |
|-------|-------|-------------|
| "No model URL configured" | Empty URL in manifest | Add valid URL and rebuild app |
| "Download failed with status 404" | URL not accessible | Check URL and network |
| "Size mismatch" | Incomplete download or wrong file | Retry download |
| "SHA256 mismatch" | Corrupted download or wrong file | Retry download |
| "Download cancelled" | User cancelled | Retry when ready |

### Fallback Behavior

If model download fails or is not installed:
- App uses **heuristic rules** for task/event extraction
- Cloud API fallback (if enabled in settings)
- User can retry download anytime

## File Locations

- **Manifest**: `new_frontend/assets/models/model_manifest.json` (bundled with app)
- **Downloaded model**: `{AppDocumentsDirectory}/models/{sanitized_name}.tflite`
- **Metadata**: SharedPreferences keys:
  - `local_llm_model_path`
  - `local_llm_model_name`
  - `local_llm_model_sha256`
  - `local_llm_model_size`
  - `local_llm_model_downloaded_at`

## Security

### Verification Steps

1. **HTTPS only**: Downloads only from HTTPS URLs
2. **File extension check**: Only `.tflite` files accepted
3. **SHA256 verification**: Computed hash must match manifest
4. **Size check**: Downloaded bytes must match expected size
5. **Isolated storage**: Model saved to app-private directory

### Threat Model

- ✅ **Man-in-the-middle**: Prevented by HTTPS + SHA256
- ✅ **Corrupted downloads**: Detected by checksum mismatch
- ✅ **Malicious models**: User must trust the manifest source (bundled with app)
- ⚠️ **Compromised manifest**: If attacker modifies app bundle, they can change URL/SHA256

**Recommendation**: Sign your app releases and distribute through official stores.

## Testing

### Unit Tests

```bash
cd new_frontend
flutter test test/model_download_service_test.dart
```

Tests cover:
- State transitions (notInstalled → downloading → installed)
- Error handling (empty URL, failed download)
- Cancel functionality

### Manual Testing

1. **Happy path**:
   - Set valid URL in manifest
   - Tap "Download Model"
   - Verify progress bar updates
   - Verify "Installed" status after completion

2. **Error cases**:
   - Empty URL → Should show error message
   - Invalid URL → Should fail with network error
   - Wrong SHA256 → Should fail with "SHA256 mismatch"

3. **Cancel**:
   - Start download
   - Tap "Cancel"
   - Verify status changes to "Cancelled"
   - Verify temp file is deleted

4. **Remove**:
   - Install model
   - Tap "Remove Model"
   - Confirm dialog
   - Verify model file deleted
   - Verify status returns to "Not installed"

## Troubleshooting

### "Download failed with status 403"

- **Cause**: Server requires authentication or blocks user agent
- **Fix**: Configure server to allow public downloads or add auth headers

### "SHA256 mismatch"

- **Cause**: File corrupted during download or wrong file on server
- **Fix**: 
  1. Verify SHA256 of file on server matches manifest
  2. Retry download
  3. Check network stability

### "Interpreter initialization failed"

- **Cause**: Model file incompatible with TFLite runtime
- **Fix**:
  1. Ensure model is TFLite format (not PyTorch/ONNX)
  2. Check TFLite version compatibility
  3. Verify model uses supported ops

### Model downloaded but inference still uses heuristics

- **Cause**: Interpreter not properly initialized
- **Check**:
  1. Open Debug screen (Settings → LLM Diagnostics in debug builds)
  2. Verify "modelLoaded: true"
  3. Check logs for initialization errors

## Performance

### Model Size Recommendations

| Model Size | Download Time (10 Mbps) | RAM Usage | Inference Speed |
|------------|-------------------------|-----------|-----------------|
| 100-300 MB | 1-3 minutes | ~500 MB | Fast (CPU) |
| 300-500 MB | 3-5 minutes | ~800 MB | Medium |
| 500 MB+ | 5+ minutes | 1+ GB | Slow on mobile |

**Recommendation**: Use quantized models (int8/int4) under 300 MB for best mobile experience.

### Inference Latency

- **Summarization** (100 tokens): ~200-500ms on modern devices
- **Task extraction**: ~100-300ms (mostly regex-based)
- **Event detection**: ~100-300ms (mostly regex-based)

## Model Conversion

If you have a PyTorch/ONNX model, convert to TFLite:

```bash
# See tools/model_conversion/README.md for detailed steps

# Example: PyTorch → ONNX → TFLite
python export_to_onnx.py --model model.pt --out model.onnx
python onnx_to_tflite.py --in model.onnx --out model.tflite --quantize int8
```

## Future Enhancements

- [ ] Resume interrupted downloads
- [ ] Multiple model support (user can choose)
- [ ] Model updates (check for new versions)
- [ ] Background download
- [ ] GPU acceleration (Android)
- [ ] iOS support (CoreML conversion)

## References

- [TensorFlow Lite](https://www.tensorflow.org/lite)
- [MediaPipe LLM Inference](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference)
- [Google AI Edge Gallery](https://github.com/google-ai-edge/ai-edge-model-explorer)
