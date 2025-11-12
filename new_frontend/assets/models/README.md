# Model Manifest Configuration

This directory contains the model manifest that tells the app where to download the on-device AI model.

## Quick Start

1. **Get a TFLite model** (see conversion guide in `docs/LOCAL_MODEL.md`)
2. **Upload to CDN** (HTTPS required)
3. **Compute SHA256**:
   ```bash
   sha256sum your_model.tflite
   ```
4. **Edit `model_manifest.json`**:
   ```json
   {
     "default": {
       "name": "your_model.tflite",
       "url": "https://your-cdn.com/path/to/your_model.tflite",
       "sha256": "computed_hash_here",
       "size": 554661246
     }
   }
   ```
5. **Rebuild app**: `flutter run`

## Example Manifest

```json
{
  "default": {
    "name": "gemma3-1b-it-q4.tflite",
    "url": "https://huggingface.co/your-org/your-model/resolve/main/model.tflite",
    "sha256": "a1b2c3d4e5f6789abcdef0123456789abcdef0123456789abcdef0123456789",
    "size": 554661246
  }
}
```

## Field Descriptions

- **name**: Display name (will be sanitized for filename)
- **url**: Direct HTTPS download URL
- **sha256**: SHA256 checksum (64-char hex, lowercase)
- **size**: File size in bytes (optional but recommended)

## Hosting Options

### GitHub Releases (Free)
```
https://github.com/your-org/your-repo/releases/download/v1.0.0/model.tflite
```

### Hugging Face (Free)
```
https://huggingface.co/your-org/your-model/resolve/main/model.tflite
```

### Google Cloud Storage
```
https://storage.googleapis.com/your-bucket/models/model.tflite
```

### AWS S3
```
https://your-bucket.s3.amazonaws.com/models/model.tflite
```

## Security Notes

- ✅ Only HTTPS URLs are accepted
- ✅ SHA256 is verified before use
- ✅ Only `.tflite` files are loaded
- ⚠️ Ensure your CDN allows public downloads
- ⚠️ Set proper CORS headers if needed

## Testing

Leave URL empty to test without model:
```json
{
  "default": {
    "name": "test-model",
    "url": "",
    "sha256": "",
    "size": 0
  }
}
```

App will show "Not installed" and use cloud fallback.

## Troubleshooting

**"No model URL configured"**
→ Add a valid HTTPS URL to the manifest

**"Download failed with status 403"**
→ Check CDN permissions (must allow public downloads)

**"SHA256 mismatch"**
→ Recompute hash and update manifest

For detailed docs, see: `docs/LOCAL_MODEL.md`
