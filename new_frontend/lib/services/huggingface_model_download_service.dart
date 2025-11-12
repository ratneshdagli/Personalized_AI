import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';  // For AccumulatorSink
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'local_llm_service.dart';

/// A streaming hash sink that computes SHA256 incrementally without buffering all data.
class HashSink implements Sink<List<int>> {
  // Accumulator that receives final Digest when the hasher is closed.
  final _acc = AccumulatorSink<Digest>();
  // The chunked conversion sink that we feed bytes to.
  late final ByteConversionSink _hasherSink;
  String? _cachedHash;
  bool _closed = false;

  HashSink() {
    // Create the chunked conversion sink that writes Digests into _acc.
    _hasherSink = sha256.startChunkedConversion(_acc);
  }

  @override
  void add(List<int> data) {
    if (_closed) return;
    _hasherSink.add(data);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _hasherSink.close(); // finish the hash
    // _acc.events will contain a single Digest
    if (_acc.events.isNotEmpty) {
      _cachedHash = _acc.events.single.toString();
    } else {
      _cachedHash = '';
    }
  }

  /// Get the computed hash as a hex string. Calling this will ensure the sink is closed.
  String get hash {
    if (!_closed) close();
    return _cachedHash ?? '';
  }
}

enum HFModelDownloadStatus {
  notInstalled,
  downloading,
  installed,
  failed,
  cancelled,
  preparing,
  verifying,
}

class HFModelInfo {
  final String id;
  final String displayName;
  final String hfRepoId;
  final String fileName;
  final int sizeInBytes;
  final String? description;
  final String? version;

  const HFModelInfo({
    required this.id,
    required this.displayName,
    required this.hfRepoId,
    required this.fileName,
    required this.sizeInBytes,
    this.description,
    this.version,
  });

  // Getters for backward compatibility
  String get name => displayName;
  String get modelId => id;
  String get modelFile => fileName;

  factory HFModelInfo.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('Parsing model info from JSON: ${json.toString()}');
      
      // Extract fields with fallbacks
      final id = (json['id'] ?? '').toString().trim();
      final displayName = (json['displayName'] ?? json['name'] ?? 'Unknown Model').toString();
      final hfRepoId = (json['hfRepoId'] ?? '').toString().trim();
      final fileName = (json['fileName'] ?? json['modelFile'] ?? 'model.bin').toString().trim();
      
      // Parse size in bytes
      int sizeInBytes = 0;
      if (json['sizeInBytes'] is int) {
        sizeInBytes = json['sizeInBytes'];
      } else if (json['sizeInBytes'] is String) {
        sizeInBytes = int.tryParse(json['sizeInBytes']) ?? 0;
      }
      
      debugPrint('''
      [HFModelInfo] Parsed model:
        ID: $id
        Name: $displayName
        Repo: $hfRepoId
        File: $fileName
        Size: $sizeInBytes bytes
      ''');
      
      return HFModelInfo(
        id: id,
        displayName: displayName,
        hfRepoId: hfRepoId,
        fileName: fileName,
        sizeInBytes: sizeInBytes,
        description: json['description']?.toString(),
        version: json['version']?.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('ERROR in HFModelInfo.fromJson: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Problematic JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'hfRepoId': hfRepoId,
    'fileName': fileName,
    'sizeInBytes': sizeInBytes,
    if (description != null) 'description': description,
    if (version != null) 'version': version,
  };
}

class HFModelDownloadState {
  final HFModelDownloadStatus status;
  final double progress;
  final int bytesDownloaded;
  final int? totalBytes;
  final String? modelPath;
  final HFModelInfo? modelInfo;
  final String? sha256;
  final DateTime? installedAt;
  final String? errorMessage;

  const HFModelDownloadState({
    this.status = HFModelDownloadStatus.notInstalled,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes,
    this.modelPath,
    this.modelInfo,
    this.sha256,
    this.installedAt,
    this.errorMessage,
  });

  HFModelDownloadState copyWith({
    HFModelDownloadStatus? status,
    double? progress,
    int? bytesDownloaded,
    int? totalBytes,
    String? modelPath,
    HFModelInfo? modelInfo,
    String? sha256,
    DateTime? installedAt,
    String? errorMessage,
  }) {
    return HFModelDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      modelPath: modelPath ?? this.modelPath,
      modelInfo: modelInfo ?? this.modelInfo,
      sha256: sha256 ?? this.sha256,
      installedAt: installedAt ?? this.installedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class HuggingFaceModelDownloadService with ChangeNotifier {
  // Singleton instance
  static final HuggingFaceModelDownloadService _instance = HuggingFaceModelDownloadService._internal();
  
  // Factory constructor to return the same instance
  factory HuggingFaceModelDownloadService() => _instance;
  
  // Private constructor
  HuggingFaceModelDownloadService._internal() {
    // Initialize cache when the service is first created
    _initializeCache();
  }

  // SharedPreferences keys
  static const String _prefsKeyInstalledModelId = 'installed_model_id';
  static const String _prefsKeyInstalledModelFile = 'installed_model_file';
  static const String _prefsKeyInstalledModelPath = 'installed_model_path';
  static const String _prefsKeyInstalledModelSha = 'installed_model_sha';
  static const String _prefsKeyInstalledAt = 'installed_at';
  
  // State management
  HFModelDownloadState _state = const HFModelDownloadState(status: HFModelDownloadStatus.notInstalled);
  
  // Model loading state
  bool _isLoadingModels = false;
  DateTime? _lastModelCheck;
  DateTime? _lastModelLoad;
  
  // Model download cache
  final Map<String, bool> _modelDownloadCache = {};
  
  // HTTP client for downloads
  http.Client? _httpClient;
  bool _cancelRequested = false;

  // Update state and notify listeners
  void _updateState(HFModelDownloadState newState) {
    _state = newState;
    notifyListeners();
  }
  
  // Backend base URL
  final String _backendBaseUrl = 'http://192.168.29.143:8000';
  
  // Available models list
  List<HFModelInfo> _availableModels = [];
  
  // In-memory cache of installed model filenames
  final Set<String> _installedModelFileNames = {};
  bool _isCacheInitialized = false;
  
  // Getters
  HFModelDownloadState get state => _state;
  List<HFModelInfo> get availableModels => _availableModels;
  
  // Initialize the cache of installed model filenames
  Future<void> _initializeCache() async {
    if (_isCacheInitialized) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      
      if (await modelsDir.exists()) {
        await for (final entity in modelsDir.list()) {
          if (entity is File) {
            _installedModelFileNames.add(entity.uri.pathSegments.last);
          }
        }
      }
      _isCacheInitialized = true;
      debugPrint('[HFModelDownload] Initialized model file cache with ${_installedModelFileNames.length} files');
    } catch (e) {
      debugPrint('[HFModelDownload] Error initializing model file cache: $e');
    }
  }
  
  // Add a file to the cache
  void _addToCache(String fileName) {
    _installedModelFileNames.add(fileName);
  }
  
  // Remove a file from the cache
  void _removeFromCache(String fileName) {
    _installedModelFileNames.remove(fileName);
  }

  // Check if a model with the given ID is downloaded
  Future<bool> isModelDownloaded(String modelId) async {
    try {
      // Check in-memory cache first
      if (_modelDownloadCache.containsKey(modelId)) {
        return _modelDownloadCache[modelId]!;
      }
      
      // Get the model info from available models
      final model = availableModels.firstWhere(
        (m) => m.id == modelId,
        orElse: () => HFModelInfo(
          id: modelId,
          displayName: modelId.split('/').last,
          hfRepoId: modelId,
          fileName: 'model.bin',
          sizeInBytes: 0,
        ),
      );
      
      final safeRepoId = model.hfRepoId.replaceAll('/', '--');
      final modelName = model.id.split('/').last;
      
      final possibleFilenames = [
        // Format used in the logs: {hfRepoId}--{modelName}--{fileName}
        '$safeRepoId--$modelName--${model.fileName}',
        // Current format: {hfRepoId}--{fileName}
        '$safeRepoId--${model.fileName}',
        // Format used in some downloads: {id}--{fileName}
        '${model.id.replaceAll('/', '--')}--${model.fileName}',
        // Original format: just the filename
        model.fileName,
        // Another possible format: {id}--{fileName}
        '${model.id}--${model.fileName}',
      ];
      
      // Check if any of the possible filenames exist in our cache
      final isDownloaded = possibleFilenames.any((name) => 
        _installedModelFileNames.any((f) => f.endsWith(name)) || 
        _installedModelFileNames.any((f) => f.contains(name))
      );
      
      // Cache the result
      _modelDownloadCache[modelId] = isDownloaded;
      
      if (isDownloaded) {
        debugPrint('[HFModelDownload] Model found in cache: $modelId');
        return true;
      }
      
      // If not found in cache, do a full check and update cache if needed
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      
      if (!await modelsDir.exists()) {
        return false;
      }
      
      for (final name in possibleFilenames) {
        final path = '${modelsDir.path}/$name';
        final file = File(path);
        if (await file.exists()) {
          // Add to cache for future checks
          _addToCache(name);
          final fileSize = await file.length();
          debugPrint('[HFModelDownload] Found model file at: $path (${fileSize} bytes)');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[HFModelDownload] Error checking if model is downloaded: $e');
    }
    
    return false;
  }

  /// Install an already downloaded model without re-downloading
  Future<void> installModel(HFModelInfo modelInfo) async {
    try {
      _updateState(_state.copyWith(status: HFModelDownloadStatus.preparing));
      debugPrint('[HFModelDownload] Installing model: ${modelInfo.id}');
      
      // Find the model in available models to get the full info
      final model = _availableModels.firstWhere(
        (m) => m.id == modelInfo.id,
        orElse: () => modelInfo,
      );
      
      // Get the model file path - handle all possible filename patterns
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      
      if (!await modelsDir.exists()) {
        throw Exception('Models directory does not exist');
      }
      
      // Try multiple filename patterns that could have been used during download
      final fileName = model.fileName;
      final safeRepoId = model.hfRepoId.replaceAll('/', '--');
      final safeId = model.id.replaceAll('/', '--');
      final modelName = model.id.split('/').last;
      
      final possibleFilenames = [
        // Format used in the logs: {hfRepoId}--{modelName}--{fileName}
        '$safeRepoId--$modelName--$fileName',
        // Current format: {hfRepoId}--{fileName}
        '$safeRepoId--$fileName',
        // Format used in some downloads: {id}--{fileName}
        '$safeId--$fileName',
        // Original format: just the filename
        fileName,
        // Another possible format: {id}--{fileName}
        '${model.id}--$fileName',
      ];
      
      debugPrint('[HFModelDownload] Looking for model file with patterns: ${possibleFilenames.join(', ')}');
      
      File? modelFile;
      String? foundPath;
      
      // Check each possible filename
      for (final name in possibleFilenames) {
        final path = '${modelsDir.path}/$name';
        final file = File(path);
        if (await file.exists()) {
          modelFile = file;
          foundPath = path;
          debugPrint('[HFModelDownload] Found model file at: $path');
          break;
        } else {
          debugPrint('[HFModelDownload] File not found: $path');
        }
      }
      
      // If file still not found, try to find any file that contains the model name
      if (modelFile == null) {
        debugPrint('[HFModelDownload] Model file not found with standard patterns, searching for matching files...');
        
        final files = await modelsDir.list().where((entity) => entity is File).toList();
        
        for (final file in files) {
          if (file.path.contains(model.id.split('/').last) || 
              file.path.contains(modelName) ||
              file.path.contains(model.hfRepoId.split('/').last)) {
            modelFile = file as File;
            foundPath = file.path;
            debugPrint('[HFModelDownload] Found matching model file: ${file.path}');
            break;
          }
        }
      }
      
      if (modelFile == null || foundPath == null) {
        throw Exception('Could not find model file for ${model.id}');
      }
      
      // Get file size and verify it's not empty
      final fileSize = await modelFile.length();
      if (fileSize == 0) {
        throw Exception('Model file is empty (0 bytes)');
      }
      
      debugPrint('[HFModelDownload] Model file size: $fileSize bytes');
      
      // Immediately update state to show as installed
      _updateState(HFModelDownloadState(
        status: HFModelDownloadStatus.installed,
        progress: 1.0,
        bytesDownloaded: fileSize,
        totalBytes: fileSize,
        modelPath: foundPath!,
        modelInfo: model,
        installedAt: DateTime.now(),
      ));
      
      // Save to shared preferences immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyInstalledModelId, model.id);
      await prefs.setString(_prefsKeyInstalledModelFile, model.fileName);
      await prefs.setString(_prefsKeyInstalledModelPath, foundPath!);
      await prefs.setInt(_prefsKeyInstalledAt, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('[HFModelDownload] Model installation started: ${model.id}');
      
      // Initialize the model in the background
      _initializeModelInBackground(foundPath!, model);
      
    } catch (e, stackTrace) {
      debugPrint('[HFModelDownload] Failed to install model: $e');
      debugPrint('Stack trace: $stackTrace');
      _updateState(HFModelDownloadState(
        status: HFModelDownloadStatus.failed,
        errorMessage: 'Failed to install model: $e',
      ));
      rethrow;
    }
  }
  
  // Initialize the model in the background
  Future<void> _initializeModelInBackground(String modelPath, HFModelInfo model) async {
    try {
      debugPrint('[HFModelDownload] Initializing model in background: ${model.id}');
      
      // Update LocalLLMService with the new model in the background
      try {
        debugPrint('[HFModelDownload] Updating LocalLLMService with new model...');
        final localLLMService = LocalLLMService();
        await localLLMService.updateModel(modelPath, model.id);
        debugPrint('[HFModelDownload] Successfully updated LocalLLMService with model: ${model.id}');
      } catch (e) {
        debugPrint('[HFModelDownload] Error updating LocalLLMService: $e');
        // Don't fail the installation, just log the error
      }
    } catch (e, stackTrace) {
      debugPrint('[HFModelDownload] Failed to install model: $e');
      debugPrint('Stack trace: $stackTrace');
      _updateState(HFModelDownloadState(
        status: HFModelDownloadStatus.failed,
        errorMessage: 'Failed to install model: $e',
      ));
      rethrow;
    }
  }

  /// Load available models from our backend
  Future<void> loadAvailableModels({bool force = false}) async {
    // If we've already loaded models and not forcing a refresh, return cached result
    if (!force && _availableModels.isNotEmpty && 
        _lastModelLoad != null && 
        DateTime.now().difference(_lastModelLoad!) < const Duration(minutes: 30)) {
      return;
    }
    
    if (_isLoadingModels) return;
    _isLoadingModels = true;
    
    try {
      final response = await http.get(
        Uri.parse('$_backendBaseUrl/api/v1/models'),
      );

      if (response.statusCode == 200) {
        final models = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        _availableModels.clear();
        _availableModels.addAll(models.map((model) => HFModelInfo.fromJson(model)));
        _lastModelLoad = DateTime.now();
        notifyListeners(); // Notify listeners that available models have been updated
        return;
      } else {
        throw Exception('Failed to load models: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[HFModelDownload] Failed to load manifest: $e');
    } finally {
      _isLoadingModels = false;
    }
  }

  /// Check for installed model
  Future<void> checkInstalledModel({bool force = false}) async {
    // If we've already checked recently and not forcing a refresh, return cached result
    if (!force && _lastModelCheck != null && 
        DateTime.now().difference(_lastModelCheck!) < const Duration(minutes: 5)) {
      return;
    }
    
    _lastModelCheck = DateTime.now();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final modelId = prefs.getString(_prefsKeyInstalledModelId);
      
      // If no model ID is stored, ensure we're in a clean state
      if (modelId == null || modelId.isEmpty) {
        // Clear any partial or invalid state
        await prefs.remove(_prefsKeyInstalledModelId);
        await prefs.remove(_prefsKeyInstalledModelFile);
        await prefs.remove(_prefsKeyInstalledModelPath);
        await prefs.remove(_prefsKeyInstalledModelSha);
        await prefs.remove(_prefsKeyInstalledAt);
        
        _updateState(const HFModelDownloadState(status: HFModelDownloadStatus.notInstalled));
        return;
      }
      
      final modelPath = prefs.getString(_prefsKeyInstalledModelPath);
      
      // Verify the model file exists and is valid
      if (modelPath == null || modelPath.isEmpty) {
        await _clearModelState(prefs);
        return;
      }
      
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        debugPrint('[HFModelDownload] Model file not found at path: $modelPath');
        await _clearModelState(prefs);
        return;
      }
      
      // Verify the model is in our available models
      HFModelInfo? foundModel;
      try {
        foundModel = _availableModels.firstWhere(
          (m) => m.id == modelId || m.hfRepoId == modelId,
        );
      } catch (e) {
        debugPrint('[HFModelDownload] Model $modelId not found in available models: $e');
        await _clearModelState(prefs);
        return;
      }
      
      if (foundModel == null) {
        debugPrint('[HFModelDownload] No model found with ID: $modelId');
        await _clearModelState(prefs);
        return;
      }
      
      // Add to cache if not already present
      final fileName = modelPath.split('/').last;
      _addToCache(fileName);
      
      _updateState(HFModelDownloadState(
        status: HFModelDownloadStatus.installed,
        modelInfo: foundModel,
        modelPath: modelPath,
        sha256: prefs.getString(_prefsKeyInstalledModelSha),
        installedAt: DateTime.fromMillisecondsSinceEpoch(
          prefs.getInt(_prefsKeyInstalledAt) ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ));
      
      debugPrint('[HFModelDownload] Found installed model: ${foundModel.id} at $modelPath');
    } catch (e, stackTrace) {
      debugPrint('[HFModelDownload] Error checking installed model: $e');
      debugPrint('Stack trace: $stackTrace');
      // On any error, ensure we don't show an invalid model as installed
      final prefs = await SharedPreferences.getInstance();
      await _clearModelState(prefs);
    }
  }

  /// Download model by calling the backend
  Future<void> downloadModel(HFModelInfo modelInfo) async {
    if (_state.status == HFModelDownloadStatus.downloading || _state.status == HFModelDownloadStatus.preparing) {
      debugPrint('[HFModelDownload] Download already in progress');
      return;
    }

    _cancelRequested = false;
    debugPrint('[HFModelDownload] Starting download: ${modelInfo.displayName}');

    _updateState(_state.copyWith(
      status: HFModelDownloadStatus.preparing,
      modelInfo: modelInfo,
      errorMessage: null,
    ));

    File? tempFile;
    try {
      // 1. Call backend to prepare file
      debugPrint('[HFModelDownload] Calling backend to prepare file...');
      final prepareUrl = Uri.parse("$_backendBaseUrl/api/v1/models/prepare");
      
      final prepareResponse = await http.post(
        prepareUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'hfRepoId': modelInfo.hfRepoId,
          'fileName': modelInfo.fileName,
        }),
      );

      if (prepareResponse.statusCode != 200) {
        throw Exception('Backend prepare failed: ${prepareResponse.statusCode} ${prepareResponse.body}');
      }

      // 2. Parse backend response
      final prepData = json.decode(utf8.decode(prepareResponse.bodyBytes));
      final String downloadUrl = "$_backendBaseUrl${prepData['downloadUrl']}";
      final String expectedSha256 = prepData['sha256'];
      final int expectedSize = prepData['sizeBytes'];
      
      debugPrint('[HFModelDownload] Backend prepared file. Starting download from: $downloadUrl');
      debugPrint('[HFModelDownload] Expected Size: $expectedSize, SHA256: $expectedSha256');

      // 3. Start downloading the file
      _updateState(_state.copyWith(
        status: HFModelDownloadStatus.downloading,
        progress: 0.0,
        bytesDownloaded: 0,
      ));

      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }
      
      // Use a consistent file naming pattern for downloaded files
      // Format: {hfRepoId}--{fileName}
      final safeRepoId = modelInfo.hfRepoId.replaceAll('/', '--');
      final fileName = '${safeRepoId}--${modelInfo.fileName}';
      final filePath = '${modelsDir.path}/$fileName';
      final tempPath = '$filePath.tmp';
      tempFile = File(tempPath);

      debugPrint('[HFModelDownload] Downloading to temporary file: $tempPath');
      debugPrint('[HFModelDownload] Final file will be: $filePath');

      // Clean up any existing files
      if (await tempFile.exists()) {
        debugPrint('[HFModelDownload] Removing existing temporary file');
        await tempFile.delete();
      }
      
      // Also clean up any existing file with the same name
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        debugPrint('[HFModelDownload] Removing existing model file');
        await existingFile.delete();
      }

       _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      
      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? expectedSize;
      debugPrint('[HFModelDownload] Download started, total bytes: $totalBytes');

      final sink = tempFile.openWrite();
      final hashSink = HashSink();
      int bytesDownloaded = 0;
      
      debugPrint('[HFModelDownload] Starting download...');

      try {
        await for (final chunk in response.stream) {
          if (_cancelRequested) {
            debugPrint('[HFModelDownload] Download cancelled by user');
            await sink.close();
            if (await tempFile.exists()) await tempFile.delete();
            _updateState(const HFModelDownloadState(
              status: HFModelDownloadStatus.cancelled,
              errorMessage: 'Download cancelled by user',
            ));
            return;
          }

          // Write chunk to file and update hash
          sink.add(chunk);
          hashSink.add(chunk);
          
          bytesDownloaded = bytesDownloaded + chunk.length;

          // Update progress every 1MB or when download is complete
          if (bytesDownloaded % (1024 * 1024) == 0 || bytesDownloaded == totalBytes) {
            final progress = (totalBytes > 0) ? bytesDownloaded / totalBytes : 0.0;
            _updateState(_state.copyWith(
              progress: progress,
              bytesDownloaded: bytesDownloaded,
              totalBytes: totalBytes,
            ));
            
            // Force garbage collection periodically
            if (bytesDownloaded % (10 * 1024 * 1024) == 0) {
              debugPrint('[HFModelDownload] Processed $bytesDownloaded/$totalBytes bytes (${(progress * 100).toStringAsFixed(1)}%)');
              await Future.delayed(Duration.zero); // Allow UI to update
            }
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
        hashSink.close();
      }

      debugPrint('[HFModelDownload] Download complete, verifying...');
      _updateState(_state.copyWith(status: HFModelDownloadStatus.verifying));

      // Verify size
      if (bytesDownloaded != totalBytes) {
        await tempFile.delete();
        throw Exception('Size mismatch: expected $totalBytes bytes, got $bytesDownloaded bytes');
      }

      // Get the final hash
      final computedHash = hashSink.hash;
      debugPrint('[HFModelDownload] SHA256 computed successfully: $computedHash');

      // Move the temporary file to the final location
      final finalFile = File(filePath);
      try {
        await tempFile.rename(filePath);
        debugPrint('[HFModelDownload] Model successfully moved to: $filePath');
      } catch (e) {
        // If rename fails (e.g., across different filesystems), copy instead
        debugPrint('[HFModelDownload] Rename failed, trying copy: $e');
        await tempFile.copy(filePath);
        await tempFile.delete();
        debugPrint('[HFModelDownload] Model successfully copied to: $filePath');
      }

      // Try to verify the file exists and has the correct size
      final downloadedFile = File(filePath);
      if (!await downloadedFile.exists()) {
        throw Exception('Downloaded file not found at expected location: $filePath');
      }
      
      final fileSize = await downloadedFile.length();
      debugPrint('[HFModelDownload] Downloaded file size: $fileSize bytes');
      
      if (fileSize == 0) {
        throw Exception('Downloaded file is empty');
      }

      await _saveModelMetadata(modelInfo, filePath, computedHash);

      final now = DateTime.now();
      _updateState(HFModelDownloadState(
        status: HFModelDownloadStatus.installed,
        progress: 1.0,
        bytesDownloaded: bytesDownloaded,
        totalBytes: totalBytes,
        modelPath: filePath,
        modelInfo: modelInfo,
        sha256: computedHash,
        installedAt: now,
      ));

      debugPrint('[HFModelDownload] Model installed successfully: $filePath');
    } catch (e, stackTrace) {
      debugPrint('[HFModelDownload] Download failed: $e');
      debugPrint('[HFModelDownload] Stack trace: $stackTrace');
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
      _updateState(HFModelDownloadState(
        status: HFModelDownloadStatus.failed,
        errorMessage: e.toString(),
        modelInfo: modelInfo,
      ));
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Computes the SHA-256 hash of a file
  Future<String> _computeFileHash(File file) async {
    final hashSink = HashSink();
    final stream = file.openRead();
    
    await for (final chunk in stream) {
      hashSink.add(chunk);
    }
    hashSink.close();
    
    return hashSink.hash;
  }

  Future<void> _saveModelMetadata(HFModelInfo modelInfo, String path, String sha) async {
    final prefs = await SharedPreferences.getInstance();
    // Save both the full ID and the filename for better compatibility
    await prefs.setString(_prefsKeyInstalledModelId, modelInfo.id);
    await prefs.setString(_prefsKeyInstalledModelFile, modelInfo.fileName);
    await prefs.setString(_prefsKeyInstalledModelPath, path);
    await prefs.setString(_prefsKeyInstalledModelSha, sha);
    await prefs.setInt(_prefsKeyInstalledAt, DateTime.now().millisecondsSinceEpoch);
    
    // Find the model in available models to ensure we have all the metadata
    final fullModelInfo = _availableModels.firstWhere(
      (m) => m.id == modelInfo.id || m.fileName == modelInfo.fileName,
      orElse: () => modelInfo,
    );
    
    _updateState(HFModelDownloadState(
      status: HFModelDownloadStatus.installed,
      progress: 1.0,
      bytesDownloaded: await File(path).length(),
      totalBytes: await File(path).length(),
      modelPath: path,
      modelInfo: fullModelInfo,
      sha256: sha,
      installedAt: DateTime.now(),
    ));
    
    debugPrint('[HFModelDownload] Saved model metadata for ${modelInfo.id}');
  }

  // This method is no longer needed as we've moved the logic to _initializeModelInBackground

  void cancelDownload() {
    if (_state.status == HFModelDownloadStatus.downloading) {
      debugPrint('[HFModelDownload] Requesting download cancellation...');
      _cancelRequested = true;
    }
  }

  Future<void> removeModel() async {
    if (_state.status != HFModelDownloadStatus.installed) {
      return;
    }
    
    try {
      _updateState(_state.copyWith(status: HFModelDownloadStatus.preparing));
      
      // Get the model file
      final modelPath = _state.modelPath;
      if (modelPath == null) {
        throw Exception('No model path found');
      }
      
      final modelFile = File(modelPath);
      if (await modelFile.exists()) {
        // Remove from cache before deleting
        final fileName = modelPath.split('/').last;
        _removeFromCache(fileName);
        
        await modelFile.delete();
        debugPrint('[HFModelDownload] Deleted model file: $modelPath');
      }
      
      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyInstalledModelId);
      await prefs.remove(_prefsKeyInstalledModelFile);
      await prefs.remove(_prefsKeyInstalledModelPath);
      await prefs.remove(_prefsKeyInstalledModelSha);
      await prefs.remove(_prefsKeyInstalledAt);
      
      // Reset state
      _updateState(const HFModelDownloadState(status: HFModelDownloadStatus.notInstalled));
      
      debugPrint('[HFModelDownload] Model removed successfully');
    } catch (e) {
      debugPrint('[HFModelDownload] Failed to remove model: $e');
      _updateState(_state.copyWith(
        status: HFModelDownloadStatus.failed,
        errorMessage: 'Failed to remove model: $e',
      ));
      rethrow;
    }
  }

  // Clear all model-related state
  Future<void> _clearModelState(SharedPreferences prefs) async {
    await prefs.remove(_prefsKeyInstalledModelId);
    await prefs.remove(_prefsKeyInstalledModelFile);
    await prefs.remove(_prefsKeyInstalledModelPath);
    await prefs.remove(_prefsKeyInstalledModelSha);
    await prefs.remove(_prefsKeyInstalledAt);
    
    _updateState(const HFModelDownloadState(status: HFModelDownloadStatus.notInstalled));
    debugPrint('[HFModelDownload] Cleared model state');
  }

  @override
  void dispose() {
    _httpClient?.close();
  }
}