import 'package:isar/isar.dart';

part 'model_record.g.dart';

@collection
class ModelRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String modelId; // Unique string ID from HF or server

  late String name;
  String? version;
  late String runtime; // 'gemma', 'tflite', 'gguf'
  late int sizeBytes;
  late String path; // Local file path
  String? checksum;

  @Index()
  late DateTime downloadedAt;
  
  late bool isInstalled;
}
