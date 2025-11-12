import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'model_manager.dart';

Future<void> maybePromptModelDownload(BuildContext context) async {
  if (!kDebugMode) {
    // In release too, but keep same UI
  }
  final existing = await ModelManager.getCachedModelPath();
  if (existing != null) return; // already present

  final info = await ModelManager.loadDefaultManifest();
  final url = info?.url ?? '';
  if (url.isEmpty) {
    // No URL configured; skip silently.
    return;
  }

  if (!context.mounted) return;

  int received = 0;
  int? total;
  bool downloading = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final double progress = (total != null && total! > 0) ? (received / total!) : 0.0;
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Enable On-Device AI', style: TextStyle(color: Colors.white)),
          content: downloading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Downloading model...', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: total != null ? progress : null, color: const Color(0xFFA855F7)),
                    const SizedBox(height: 8),
                    Text(
                      total != null ? '${(received / (1024*1024)).toStringAsFixed(1)} / ${(total! / (1024*1024)).toStringAsFixed(1)} MB' : '${(received / (1024*1024)).toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('To enable on-device summarization, a model (~100–300 MB) will be downloaded once and stored securely on your device.', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Text('Model: ${info?.name ?? "none"}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
          actions: [
            if (!downloading)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Use Cloud', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            TextButton(
              onPressed: () async {
                if (!downloading) {
                  setState(() => downloading = true);
                  await ModelManager.ensureModelAvailable(onProgress: (p) {
                    setState(() {
                      received = p.received;
                      total = p.total;
                    });
                  });
                } else {
                  Navigator.of(ctx).pop();
                }
              },
              child: Text(downloading ? 'Close' : 'Download', style: const TextStyle(color: Color(0xFFC084FC))),
            )
          ],
        );
      });
    },
  );
}
