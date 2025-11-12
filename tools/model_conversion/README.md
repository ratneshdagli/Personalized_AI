# Model Conversion Guide (Edge LLM → Mobile)

This project prefers on-device inference. If your chosen model isn't mobile-ready, use these steps to convert and package it for CPU-only mobile runtime.

## Options

- TensorFlow Lite (preferred for Flutter via `tflite_flutter`)
- ONNX Runtime Mobile (alternative)
- MediaPipe .task (Google AI Edge formats; Android-first)

## 1) Convert to TFLite (generic guidance)

> NOTE: Exact commands depend on your source model (PyTorch/TF/ONNX). Below is a scaffold.

```bash
# Create a virtual env
python -m venv .venv && . .venv/Scripts/activate  # Windows PowerShell use: .venv\Scripts\Activate.ps1
pip install torch torchvision torchaudio tensorflow onnx onnxconverter-common tf-onnx

# Example: Export PyTorch → ONNX
python export_to_onnx.py --model your_model.ckpt --out model.onnx --seq_len 512

# Convert ONNX → TFLite
python onnx_to_tflite.py --in model.onnx --out model_fp16.tflite --fp16

# (Optional) Post-training quantization (int8)
python tflite_quantize.py --in model_fp16.tflite --out model_int8.tflite
```

Then place the resulting file in `assets/models/` and set `assets/models/model_manifest.json`:

```json
{
  "default": {
    "name": "your_model_int8.tflite",
    "url": "https://your-host/your_model_int8.tflite",
    "sha256": "<SHA256_OF_FILE>",
    "size": 123456789
  }
}
```

## 2) ONNX Runtime Mobile

- Add `onnxruntime` mobile for Flutter via a suitable plugin (or use a platform channel)
- Convert your model to `.onnx`
- Bundle or download with SHA256 verification using the same manifest pattern

## 3) MediaPipe / LiteRT `.task` packaging (Android)

- The Edge Gallery shows `.task` packs. If you use MediaPipe LLM Inference API on Android, download the `.task` and load via Android-specific APIs.
- For this Flutter app, we currently integrate `tflite_flutter` for portability; `.task` usage would require custom platform integration.

## Measuring Latency

- Use the Debug screen (Debug → LLM Diagnostics) to run a sample and view latency
- For emulator and device, record the latency shown and save it in the deployment report

## Notes

- Complex LLMs are heavy; consider 1B–2B variants with int8/int4 quantization for CPU-only
- Always verify SHA256 to ensure integrity
- Keep model under ~300 MB for practical OTA download
