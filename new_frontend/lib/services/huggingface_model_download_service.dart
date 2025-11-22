import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';  // For AccumulatorSink
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'local_llm_service.dart';
import '../data/repositories/model_repository.dart';
import '../data/schema/model_record.dart';

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
  final bool llmSupportImage;
  final List<String> taskTypes;

  const HFModelInfo({
    required this.id,
    required this.displayName,
    required this.hfRepoId,
    required this.fileName,
    required this.sizeInBytes,
    this.description,
    this.version,
    this.llmSupportImage = false,
    this.taskTypes = const [],
  });

  // Getters for backward compatibility
  String get name => displayName;
  String get modelId => id;
  String get modelFile => fileName;

  factory HFModelInfo.fromJson(Map<String, dynamic> json) {
    try {
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
      
      // Parse taskTypes if available
      final taskTypes = json['taskTypes'] is List 
          ? List<String>.from(json['taskTypes'])
          : <String>[];
          
      return HFModelInfo(
        id: id,
        displayName: displayName,
        hfRepoId: hfRepoId,
        fileName: fileName,
        sizeInBytes: sizeInBytes,
        description: json['description']?.toString(),
        version: json['version']?.toString(),
        llmSupportImage: json['llmSupportImage'] == true,
        taskTypes: taskTypes,
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
    'llmSupportImage': llmSupportImage,
    'taskTypes': taskTypes,
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
  
  ModelRepository? _modelRepository;

  void init(ModelRepository repo) {
    _modelRepository = repo;
    _initializeCache();
  }

  // Backend base URL
  final String _backendBaseUrl = 'http://192.168.29.143:8000';
  
  // Available models list
  List<HFModelInfo> _availableModels = [];
  
  // In-memory cache of installed model filenames
  final Set<String> _installedModelIds = {};
  final Set<String> _installedModelFileNames = {};
  bool _isCacheInitialized = false;
  
  // Getters
  HFModelDownloadState get state => _state;
  List<HFModelInfo> get availableModels => _availableModels;
  
  // Initialize the cache of installed model filenames
  Future<void> _initializeCache() async {
    if (_modelRepository == null) return;
    
    try {
      final installed = await _modelRepository!.getInstalledModels();
      _installedModelIds.clear();
      _installedModelIds.addAll(installed.map((m) => m.modelId));
      
      _installedModelFileNames.clear();
      _installedModelFileNames.addAll(installed.map((m) => path.basename(m.path)));
      
      // Scan the models directory for any files not in database
      await _scanAndRegisterExistingModels();
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing model cache: $e');
    }
  }

  /// Scans the models directory and registers any existing model files not in the database
  Future<void> _scanAndRegisterExistingModels() async {
    if (_modelRepository == null) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      
      if (!await modelsDir.exists()) {
        debugPrint('[HFModelDownload] Models directory does not exist yet');
        return;
      }
      
      debugPrint('[HFModelDownload] Scanning models directory for existing files...');
      final files = await modelsDir.list().toList();
      
      for (final fileEntity in files) {
        if (fileEntity is! File) continue;
        
        final file = fileEntity as File;
        final fileName = path.basename(file.path);
        
        // Skip if already in cache
        if (_installedModelFileNames.contains(fileName)) {
          continue;
        }
        
        // Try to match the file to a known model from available models
        HFModelInfo? matchedModel;
        for (final model in _availableModels) {
          if (fileName.contains(model.id.replaceAll('/', '--')) ||
              fileName.contains(model.fileName) ||
              fileName == model.fileName) {
            matchedModel = model;
            break;
          }
        }
        
        // If no match, create a basic model info from the file
        if (matchedModel == null) {
          debugPrint('[HFModelDownload] Found unknown model file: $fileName, skipping registration');
          continue;
        }
        
        final fileStat = await file.stat();
        final fileSize = fileStat.size;
        
        debugPrint('[HFModelDownload] Found existing model: $fileName (${fileSize} bytes)');
        
        // Compute SHA256 if file size matches expected size (to avoid re-hashing huge files unnecessarily)
        String? sha256Hash;
        if (fileSize == matchedModel.sizeInBytes || matchedModel.sizeInBytes == 0) {
          debugPrint('[HFModelDownload] Computing SHA256 for: $fileName');
          sha256Hash = await _computeFileHash(file);
          debugPrint('[HFModelDownload] SHA256: ${sha256Hash.substring(0, 12)}...');
        }
        
        // Register the model in the database
        final modelRecord = ModelRecord()
          ..modelId = matchedModel.id
          ..name = matchedModel.displayName
          ..path = file.path
          ..sizeBytes = fileSize
          ..version = matchedModel.version
          ..runtime = 'gemma' // Default to gemma for TFLite models
          ..checksum = sha256Hash
          ..isInstalled = true
          ..downloadedAt = fileStat.changed;
        
        await _modelRepository!.addOrUpdateModel(modelRecord);
        
        // Add to cache
        _installedModelIds.add(matchedModel.id);
        _installedModelFileNames.add(fileName);
        
        debugPrint('[HFModelDownload] Registered existing model: ${matchedModel.displayName}');
      }
      
      debugPrint('[HFModelDownload] Model scanning complete. Total installed: ${_installedModelIds.length}');
    } catch (e, stackTrace) {
      debugPrint('[HFModelDownload] Error scanning for existing models: $e');
      debugPrint('Stack trace: $stackTrace');
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
  
  // Clear the model download cache for a specific model
  void _clearModelDownloadCache(String modelId) {
    _modelDownloadCache.remove(modelId);
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
      
      // Update ModelRepository
      if (_modelRepository != null) {
        try {
          final record = ModelRecord()
            ..modelId = model.id
            ..name = model.displayName
            ..version = model.version
            ..runtime = 'gemma' // Defaulting to gemma for now
            ..sizeBytes = fileSize
            ..path = foundPath
            ..downloadedAt = DateTime.now()
            ..isInstalled = true;

          await _modelRepository!.addOrUpdateModel(record);
          _installedModelIds.add(model.id);
          _installedModelFileNames.add(path.basename(foundPath));
        } catch (e) {
          debugPrint('[HFModelDownload] Error updating model repository: $e');
        }
      }

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
    if (_modelRepository == null) return;

    // If we've already checked recently and not forcing a refresh, return cached result
    if (!force && _lastModelCheck != null && 
        DateTime.now().difference(_lastModelCheck!) < const Duration(minutes: 5)) {
      return;
    }
    
    _lastModelCheck = DateTime.now();
    
    try {
      final installedModels = await _modelRepository!.getInstalledModels();
      
      if (installedModels.isEmpty) {
        _updateState(const HFModelDownloadState(status: HFModelDownloadStatus.notInstalled));
        return;
      }

      // For now, just pick the first one or the most recently downloaded
      // TODO: Add logic to select "active" model
      final activeModel = installedModels.last;
      
      _updateState(HFModelDownloadState(
        status: HFModelDownloadStatus.installed,
        progress: 1.0,
        bytesDownloaded: activeModel.sizeBytes,
        totalBytes: activeModel.sizeBytes,
        modelPath: activeModel.path,
        modelInfo: HFModelInfo(
          id: activeModel.modelId,
          displayName: activeModel.name,
          hfRepoId: activeModel.modelId, // Assuming ID is repo ID for now
          fileName: path.basename(activeModel.path),
          sizeInBytes: activeModel.sizeBytes,
          version: activeModel.version,
        ),
        installedAt: activeModel.downloadedAt,
      ));
      
    } catch (e) {
      debugPrint('[HFModelDownload] Error checking installed model: $e');
      _updateState(const HFModelDownloadState(status: HFModelDownloadStatus.notInstalled));
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

      // Clear the download cache so the model shows as installed
      _modelDownloadCache.clear();
      _addToCache(fileName);
      
      // Force refresh of installed models list
      if (_modelRepository != null) {
        await checkInstalledModel(force: true);
      }

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

      debugPrint('[HFModelDownload] Model installed successfully:$filePath');
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
      
      // Get the model info
      final modelInfo = _state.modelInfo;
      if (modelInfo == null) {
        throw Exception('No model info found');
      }
      
      // Delete all possible model files
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      
      if (await modelsDir.exists()) {
        final fileName = modelInfo.fileName;
        final safeRepoId = modelInfo.hfRepoId.replaceAll('/', '--');
        final safeId = modelInfo.id.replaceAll('/', '--');
        final modelName = modelInfo.id.split('/').last;
        
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
          '${modelInfo.id}--$fileName',
        ];
        
        debugPrint('[HFModelDownload] Looking for model files to delete with patterns: ${possibleFilenames.join(', ')}');
        
        // Check and delete each possible file
        for (final name in possibleFilenames) {
          final path = '${modelsDir.path}/$name';
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            debugPrint('[HFModelDownload] Deleted model file: $path');
            // Remove from cache
            _removeFromCache(name);
          }
        }
        
        // Also try to find and delete any files that contain the model name
        final files = await modelsDir.list().where((entity) => entity is File).toList();
        for (final file in files) {
          if (file is File && 
              (file.path.contains(modelName) || 
               file.path.contains(safeRepoId) || 
               file.path.contains(safeId))) {
            await file.delete();
            debugPrint('[HFModelDownload] Deleted additional model file: ${file.path}');
            // Remove from cache
            final fileName = file.path.split('/').last;
            _removeFromCache(fileName);
          }
        }
      }
      
      // Clear the model from LocalLLMService
      try {
        final localLLMService = LocalLLMService();
        await localLLMService.clearModel();
        debugPrint('[HFModelDownload] Cleared model from LocalLLMService');
      } catch (e) {
        debugPrint('[HFModelDownload] Error clearing model from LocalLLMService: $e');
        // Don't fail the removal, just log the error
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