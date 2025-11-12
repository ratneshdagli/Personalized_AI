import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class ModelInfo {
  final String name;
  final String? url;
  final String? sha256;
  final int? size;
  const ModelInfo({required this.name, this.url, this.sha256, this.size});
}

class DownloadProgress {
  final int received;
  final int? total;
  const DownloadProgress(this.received, this.total);
}

class ModelManager {
  static const _prefsKeyPath = 'local_llm_model_path';
  static const _prefsKeyName = 'local_llm_model_name';
  static const _prefsKeySha = 'local_llm_model_sha256';
  static const _prefsKeySize = 'local_llm_model_size';
  static const _prefsKeyDownloadedAt = 'local_llm_model_downloaded_at';

  static Future<Directory> _modelsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
    }

  static Future<ModelInfo?> loadDefaultManifest() async {
    try {
      final data = await rootBundle.loadString('assets/models/model_manifest.json');
      final j = json.decode(data);
      final def = (j['default'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      return ModelInfo(
        name: (def['name'] as String?) ?? 'Local LLM',
        url: def['url'] as String?,
        sha256: def['sha256'] as String?,
        size: (def['size'] is int) ? def['size'] as int : null,
      );
    } catch (_) {
      return const ModelInfo(name: 'Local LLM');
    }
  }

  static Future<String?> getCachedModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKeyPath);
    if (path == null) return null;
    if (!await File(path).exists()) return null;
    return path;
  }

  static Future<Map<String, dynamic>> getCachedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'path': prefs.getString(_prefsKeyPath),
      'name': prefs.getString(_prefsKeyName),
      'sha256': prefs.getString(_prefsKeySha),
      'size': prefs.getInt(_prefsKeySize),
      'downloadedAt': prefs.getInt(_prefsKeyDownloadedAt),
    };
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyPath);
    await prefs.remove(_prefsKeyName);
    await prefs.remove(_prefsKeySha);
    await prefs.remove(_prefsKeySize);
    await prefs.remove(_prefsKeyDownloadedAt);
  }

  static Future<String?> ensureModelAvailable({
    ModelInfo? info,
    void Function(DownloadProgress p)? onProgress,
  }) async {
    final cached = await getCachedModelPath();
    if (cached != null) return cached;

    final manifest = info ?? await loadDefaultManifest();
    final url = manifest?.url ?? '';
    if (url.isEmpty) {
      // No URL configured; caller should fall back to cloud.
      return null;
    }

    final dir = await _modelsDir();
    final fileName = (manifest?.name ?? 'model.tflite').replaceAll(' ', '_');
    final filePath = '${dir.path}/$fileName';

    final ok = await _downloadWithChecksum(
      url,
      File(filePath),
      expectedSha256: manifest?.sha256,
      expectedSize: manifest?.size,
      onProgress: onProgress,
    );

    if (!ok) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPath, filePath);
    await prefs.setString(_prefsKeyName, manifest?.name ?? 'Local LLM');
    final sha = manifest?.sha256;
    if (sha != null && sha.isNotEmpty) await prefs.setString(_prefsKeySha, sha);
    final sz = manifest?.size;
    if (sz != null) await prefs.setInt(_prefsKeySize, sz);
    await prefs.setInt(_prefsKeyDownloadedAt, DateTime.now().millisecondsSinceEpoch);

    return filePath;
  }

  static Future<bool> _downloadWithChecksum(
    String url,
    File outFile, {
    String? expectedSha256,
    int? expectedSize,
    void Function(DownloadProgress p)? onProgress,
  }) async {
    final req = http.Request('GET', Uri.parse(url));
    final resp = await req.send();
    if (resp.statusCode != 200) return false;

    final sink = outFile.openWrite();
    int received = 0;
    final total = resp.contentLength;

    final bytesBuilder = BytesBuilder();
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      bytesBuilder.add(chunk);
      received += chunk.length;
      if (onProgress != null) onProgress(DownloadProgress(received, total));
    }
    await sink.flush();
    await sink.close();

    final bytes = bytesBuilder.takeBytes();
    if (expectedSize != null && expectedSize != bytes.length) return false;
    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final hash = sha256.convert(bytes).toString();
      if (hash.toLowerCase() != expectedSha256.toLowerCase()) return false;
    }
    return true;
  }

  /// Load local model with CPU-only interpreter (no GPU/NNAPI delegates)
  static Future<tfl.Interpreter?> loadLocalModel(String modelPath) async {
    try {
      debugPrint('[ModelManager] Loading model from: $modelPath');
      
      final file = File(modelPath);
      if (!await file.exists()) {
        debugPrint('[ModelManager] Model file not found: $modelPath');
        return null;
      }

      // Create interpreter options with CPU-only configuration
      final options = tfl.InterpreterOptions();
      
      // Explicitly set number of threads for CPU inference
      options.threads = 4; // Use 4 threads for better performance
      
      // DO NOT add GPU or NNAPI delegates - CPU only
      debugPrint('[ModelManager] Creating CPU-only interpreter with 4 threads');
      
      // Create interpreter from file
      final interpreter = tfl.Interpreter.fromFile(file, options: options);
      
      debugPrint('[ModelManager] Interpreter created successfully');
      debugPrint('[ModelManager] Input tensors: ${interpreter.getInputTensors().length}');
      debugPrint('[ModelManager] Output tensors: ${interpreter.getOutputTensors().length}');
      
      return interpreter;
    } catch (e, stackTrace) {
      debugPrint('[ModelManager] Failed to load model: $e');
      debugPrint('[ModelManager] Stack trace: $stackTrace');
      return null;
    }
  }
}
