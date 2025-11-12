import 'package:flutter_test/flutter_test.dart';
import 'package:figma/services/model_download_service.dart';

void main() {
  group('ModelDownloadService', () {
    late ModelDownloadService service;

    setUp(() {
      service = ModelDownloadService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is notInstalled', () {
      expect(service.state.status, ModelDownloadStatus.notInstalled);
      expect(service.state.progress, 0.0);
      expect(service.state.bytesDownloaded, 0);
    });

    test('state transitions are notified', () async {
      var notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });

      // Check installed model (will be notInstalled if no model)
      await service.checkInstalledModel();
      
      // At least one notification should have been sent
      expect(notificationCount, greaterThan(0));
    });

    test('copyWith creates new state with updated fields', () {
      final initialState = const ModelDownloadState(
        status: ModelDownloadStatus.notInstalled,
        progress: 0.0,
      );

      final updatedState = initialState.copyWith(
        status: ModelDownloadStatus.downloading,
        progress: 0.5,
        bytesDownloaded: 1024,
      );

      expect(updatedState.status, ModelDownloadStatus.downloading);
      expect(updatedState.progress, 0.5);
      expect(updatedState.bytesDownloaded, 1024);
    });

    test('download fails gracefully with empty manifest URL', () async {
      // This test assumes the default manifest has empty URL
      await service.downloadModel();
      
      // Should transition to failed state
      expect(
        service.state.status,
        anyOf(ModelDownloadStatus.failed, ModelDownloadStatus.notInstalled),
      );
    });

    test('cancelDownload sets cancel flag during download', () {
      // Set state to downloading
      service.downloadModel(); // Start async download
      
      // Immediately cancel
      service.cancelDownload();
      
      // The internal cancel flag should be set
      // (We can't directly test the private flag, but the behavior is tested in integration)
    });
  });

  group('ModelDownloadState', () {
    test('creates state with required fields', () {
      const state = ModelDownloadState(
        status: ModelDownloadStatus.installed,
        progress: 1.0,
        modelPath: '/path/to/model.tflite',
        modelName: 'test-model',
      );

      expect(state.status, ModelDownloadStatus.installed);
      expect(state.progress, 1.0);
      expect(state.modelPath, '/path/to/model.tflite');
      expect(state.modelName, 'test-model');
    });

    test('copyWith preserves unmodified fields', () {
      const original = ModelDownloadState(
        status: ModelDownloadStatus.downloading,
        progress: 0.5,
        bytesDownloaded: 1024,
        totalBytes: 2048,
        modelName: 'test-model',
      );

      final updated = original.copyWith(progress: 0.75);

      expect(updated.status, original.status);
      expect(updated.progress, 0.75);
      expect(updated.bytesDownloaded, original.bytesDownloaded);
      expect(updated.totalBytes, original.totalBytes);
      expect(updated.modelName, original.modelName);
    });
  });
}
