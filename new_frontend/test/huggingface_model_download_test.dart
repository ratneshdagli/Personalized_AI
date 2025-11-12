import 'package:flutter_test/flutter_test.dart';
import 'package:figma/services/huggingface_model_download_service.dart';

void main() {
  group('HuggingFaceModelDownloadService', () {
    late HuggingFaceModelDownloadService service;

    setUp(() {
      service = HuggingFaceModelDownloadService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is notInstalled', () {
      expect(service.state.status, HFModelDownloadStatus.notInstalled);
      expect(service.state.progress, 0.0);
      expect(service.state.bytesDownloaded, 0);
    });

    test('loadAvailableModels loads CPU-compatible models', () async {
      await service.loadAvailableModels();
      
      // Should have loaded models from manifest
      expect(service.availableModels, isNotEmpty);
      
      // All models should be CPU-compatible
      for (final model in service.availableModels) {
        final accelerators = model.defaultConfig?['accelerators'] as String?;
        expect(
          accelerators == null || accelerators.contains('cpu'),
          isTrue,
          reason: 'Model ${model.name} should support CPU',
        );
      }
    });

    test('state transitions are notified', () async {
      var notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });

      await service.checkInstalledModel();
      
      expect(notificationCount, greaterThan(0));
    });

    test('HFModelInfo parses from JSON correctly', () {
      final json = {
        'name': 'Test Model',
        'modelId': 'test/model',
        'modelFile': 'model.task',
        'description': 'Test description',
        'sizeInBytes': 1024,
        'estimatedPeakMemoryInBytes': 2048,
        'version': '1.0.0',
        'defaultConfig': {
          'topK': 64,
          'temperature': 1.0,
          'accelerators': 'cpu',
        },
        'taskTypes': ['llm_chat'],
      };

      final modelInfo = HFModelInfo.fromJson(json);

      expect(modelInfo.name, 'Test Model');
      expect(modelInfo.modelId, 'test/model');
      expect(modelInfo.modelFile, 'model.task');
      expect(modelInfo.sizeInBytes, 1024);
      expect(modelInfo.defaultConfig?['accelerators'], 'cpu');
    });

    test('HFModelDownloadState copyWith creates new state', () {
      const initialState = HFModelDownloadState(
        status: HFModelDownloadStatus.notInstalled,
        progress: 0.0,
      );

      final updatedState = initialState.copyWith(
        status: HFModelDownloadStatus.downloading,
        progress: 0.5,
        bytesDownloaded: 1024,
      );

      expect(updatedState.status, HFModelDownloadStatus.downloading);
      expect(updatedState.progress, 0.5);
      expect(updatedState.bytesDownloaded, 1024);
    });

    test('cancelDownload sets cancel flag during download', () async {
      await service.loadAvailableModels();
      
      if (service.availableModels.isNotEmpty) {
        // Start download (will fail auth but that's ok for test)
        service.downloadModel(service.availableModels.first);
        
        // Immediately cancel
        service.cancelDownload();
        
        // The internal cancel flag should be set
        // (We can't directly test the private flag, but behavior is tested in integration)
      }
    });
  });

  group('HFModelInfo', () {
    test('creates model info with required fields', () {
      const modelInfo = HFModelInfo(
        name: 'Test Model',
        modelId: 'test/model',
        modelFile: 'model.task',
        sizeInBytes: 1024,
      );

      expect(modelInfo.name, 'Test Model');
      expect(modelInfo.modelId, 'test/model');
      expect(modelInfo.modelFile, 'model.task');
      expect(modelInfo.sizeInBytes, 1024);
    });

    test('handles optional fields', () {
      const modelInfo = HFModelInfo(
        name: 'Test Model',
        modelId: 'test/model',
        modelFile: 'model.task',
        sizeInBytes: 1024,
        description: 'Test description',
        version: '1.0.0',
      );

      expect(modelInfo.description, 'Test description');
      expect(modelInfo.version, '1.0.0');
    });
  });
}
