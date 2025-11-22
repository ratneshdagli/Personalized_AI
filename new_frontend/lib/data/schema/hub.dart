import 'package:isar/isar.dart';

part 'hub.g.dart';

@collection
class Hub {
  Id id = Isar.autoIncrement;

  @Index(unique: true, caseSensitive: false)
  late String name;

  String? colorHex;

  int sortOrder = 0;

  bool isDefault = false;
}
