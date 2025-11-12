import 'dart:async';
import 'dart:io';
import 'dart:convert' as dc;
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:convert/convert.dart' as convert;
import '../llm/model_manager.dart';

enum ModelDownloadStatus {
  notInstalled,
  downloading,
  verifying,
  installed,
  failed,
  cancelled,
}

class ModelDownloadState {
  final ModelDownloadStatus status;
  final double progress; // 0.0 to 1.0
  final int bytesDownloaded;
  final int? totalBytes;
  final String? modelPath;
  final String? modelName;
  final String? sha256;
  final DateTime? installedAt;
  final String? errorMessage;

  const ModelDownloadState({
    required this.status,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes,
    this.modelPath,
    this.modelName,
    this.sha256,
    this.installedAt,
    this.errorMessage,
  });

  ModelDownloadState copyWith({
    ModelDownloadStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? modelPath,
    String? modelName,
    String? sha256,
    DateTime? installedAt,
    String? errorMessage,
  }) {
    return ModelDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      modelPath: modelPath ?? this.modelPath,
      modelName: modelName ?? this.modelName,
      sha256: sha256 ?? this.sha256,
      installedAt: installedAt ?? this.installedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ModelDownloadService extends ChangeNotifier {
  ModelDownloadState _state = const ModelDownloadState(status: ModelDownloadStatus.notInstalled);
  http.Client? _httpClient;
  bool _cancelRequested = false;

  ModelDownloadState get state => _state;

  void _updateState(ModelDownloadState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> checkInstalledModel() async {
    debugPrint('[ModelDownloadService] Checking for installed model...');

    final cachedPath = await ModelManager.getCachedModelPath();
    final cachedStatus = await ModelManager.getCachedStatus();

    if (cachedPath != null && await File(cachedPath).exists()) {
      final ts = cachedStatus['downloadedAt'] as int?;
      _updateState(ModelDownloadState(
        status: ModelDownloadStatus.installed,
        progress: 1.0,
        modelPath: cachedPath,
        modelName: cachedStatus['name'] as String?,
        sha256: cachedStatus['sha256'] as String?,
        installedAt: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
      ));
      debugPrint('[ModelDownloadService] Model already installed: $cachedPath');
    } else {
      _updateState(const ModelDownloadState(status: ModelDownloadStatus.notInstalled));
      debugPrint('[ModelDownloadService] No model installed');
    }
  }

  Future<void> downloadModel() async {
    if (_state.status == ModelDownloadStatus.downloading) {
      debugPrint('[ModelDownloadService] Download already in progress');
      return;
    }

    _cancelRequested = false;
    debugPrint('[ModelDownloadService] Starting model download...');

    try {
      // Load manifest
      _updateState(_state.copyWith(
        status: ModelDownloadStatus.downloading,
        progress: 0.0,
        bytesDownloaded: 0,
        errorMessage: null,
      ));

      final manifest = await ModelManager.loadDefaultManifest();
      final url = manifest?.url ?? '';
      final expectedSha = manifest?.sha256;
      final expectedSize = manifest?.size;
      final modelName = manifest?.name ?? 'model.tflite';

      if (url.isEmpty) {
        throw Exception('No model URL configured in manifest. Please add a valid URL to assets/models/model_manifest.json');
      }

      debugPrint('[ModelDownloadService] Manifest loaded: $modelName from $url');
      debugPrint('[ModelDownloadService] Expected SHA256: $expectedSha');
      debugPrint('[ModelDownloadService] Expected size: $expectedSize bytes');

      // Prepare download location
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      final fileName = modelName.replaceAll(' ', '_');
      final filePath = '${modelsDir.path}/$fileName';
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);

      // Delete temp file if exists
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Download with streaming
      debugPrint('[ModelDownloadService] Downloading to: $tempPath');
      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      debugPrint('[ModelDownloadService] Download started, total bytes: $totalBytes');

      final sink = tempFile.openWrite();
      int bytesDownloaded = 0;

      // SHA256 hashing (chunked)
      debugPrint('[ModelDownloadService] SHA256 computation started');
      final digests = <crypto.Digest>[];
      // CORRECT
      final digestSink = dc.ChunkedConversionSink<crypto.Digest>.withCallback((values) {
        if (values.isNotEmpty) digests.addAll(values);
      });
      final hashSink = crypto.sha256.startChunkedConversion(digestSink);

      try {
        await for (final chunk in response.stream) {
          if (_cancelRequested) {
            debugPrint('[ModelDownloadService] Download cancelled by user');
            await sink.close();
            if (await tempFile.exists()) await tempFile.delete();
            _updateState(const ModelDownloadState(
              status: ModelDownloadStatus.cancelled,
              errorMessage: 'Download cancelled by user',
            ));
            return;
          }

          sink.add(chunk);
          hashSink.add(chunk);
          bytesDownloaded += chunk.length;

          final progress = totalBytes != null ? bytesDownloaded / totalBytes : 0.0;
          _updateState(_state.copyWith(
            progress: progress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
          ));

          if (bytesDownloaded % (1024 * 1024) == 0 || bytesDownloaded == totalBytes) {
            debugPrint('[ModelDownloadService] Downloaded: ${(bytesDownloaded / (1024 * 1024)).toStringAsFixed(1)} MB');
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      debugPrint('[ModelDownloadService] Download complete, verifying...');
      _updateState(_state.copyWith(status: ModelDownloadStatus.verifying));

      // Verify size
      if (expectedSize != null && bytesDownloaded != expectedSize) {
        await tempFile.delete();
        throw Exception('Size mismatch: expected $expectedSize bytes, got $bytesDownloaded bytes');
      }

      // Finalize SHA256
      hashSink.close();
      final digest = digests.isNotEmpty ? digests.single : null; // crypto.Digest
      final computedSha256 = digest == null ? '' : convert.hex.encode(digest.bytes);
      debugPrint('[ModelDownloadService] SHA256 computed successfully: $computedSha256');

      // Verify SHA256 (if expected provided)
      if (expectedSha != null && expectedSha.isNotEmpty) {
        if (computedSha256.toLowerCase() != expectedSha.toLowerCase()) {
          await tempFile.delete();
          throw Exception('SHA256 mismatch: expected $expectedSha, got $computedSha256');
        }
        debugPrint('[ModelDownloadService] SHA256 verification passed');
      }

      // Move temp file to final location
      final finalFile = File(filePath);
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(filePath);

      // Save metadata
      await ModelManager.clearCache();
      await _saveModelMetadata(filePath, modelName, (expectedSha != null && expectedSha.isNotEmpty) ? expectedSha : computedSha256, bytesDownloaded);

      final now = DateTime.now();
      _updateState(ModelDownloadState(
        status: ModelDownloadStatus.installed,
        progress: 1.0,
        bytesDownloaded: bytesDownloaded,
        totalBytes: totalBytes,
        modelPath: filePath,
        modelName: modelName,
        sha256: (expectedSha != null && expectedSha.isNotEmpty) ? expectedSha : computedSha256,
        installedAt: now,
      ));

      debugPrint('[ModelDownloadService] Model installed successfully: $filePath');
    } catch (e, stackTrace) {
      debugPrint('[ModelDownloadService] Download failed: $e');
      debugPrint('[ModelDownloadService] Stack trace: $stackTrace');
      _updateState(ModelDownloadState(
        status: ModelDownloadStatus.failed,
        errorMessage: e.toString(),
      ));
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  Future<void> _saveModelMetadata(String path, String name, String? sha, int size) async {
    await ModelManager.clearCache();
    // Directly use SharedPreferences to save metadata
    final sp = await SharedPreferences.getInstance();
    await sp.setString('local_llm_model_path', path);
    await sp.setString('local_llm_model_name', name);
    if (sha != null && sha.isNotEmpty) await sp.setString('local_llm_model_sha256', sha);
    await sp.setInt('local_llm_model_size', size);
    await sp.setInt('local_llm_model_downloaded_at', DateTime.now().millisecondsSinceEpoch);
  }

  void cancelDownload() {
    if (_state.status == ModelDownloadStatus.downloading) {
      debugPrint('[ModelDownloadService] Requesting download cancellation...');
      _cancelRequested = true;
    }
  }

  Future<void> removeModel() async {
    debugPrint('[ModelDownloadService] Removing installed model...');

    final path = _state.modelPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[ModelDownloadService] Deleted model file: $path');
      }
    }

    await ModelManager.clearCache();
    _updateState(const ModelDownloadState(status: ModelDownloadStatus.notInstalled));
    debugPrint('[ModelDownloadService] Model removed successfully');
  }

  @override
  void dispose() {
    _httpClient?.close();
    super.dispose();
  }
}
