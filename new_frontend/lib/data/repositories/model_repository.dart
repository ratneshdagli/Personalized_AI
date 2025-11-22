import 'package:isar/isar.dart';
import '../schema/model_record.dart';

class ModelRepository {
  final Isar isar;

  ModelRepository(this.isar);

  Future<List<ModelRecord>> getInstalledModels() async {
    return await isar.modelRecords
        .filter()
        .isInstalledEqualTo(true)
        .findAll();
  }

  Future<void> addOrUpdateModel(ModelRecord model) async {
    await isar.writeTxn(() async {
      // Check if model exists by modelId
      final existing = await isar.modelRecords
          .filter()
          .modelIdEqualTo(model.modelId)
          .findFirst();
          
      if (existing != null) {
        model.id = existing.id; // Preserve Isar ID
      }
      
      await isar.modelRecords.put(model);
    });
  }

  Future<void> removeModel(String modelId) async {
    await isar.writeTxn(() async {
      await isar.modelRecords
          .filter()
          .modelIdEqualTo(modelId)
          .deleteAll();
    });
  }

  Future<ModelRecord?> getModel(String modelId) async {
    return await isar.modelRecords
        .filter()
        .modelIdEqualTo(modelId)
        .findFirst();
  }
}
