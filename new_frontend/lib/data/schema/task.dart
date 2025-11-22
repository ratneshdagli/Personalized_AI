import 'package:isar/isar.dart';

part 'task.g.dart';

@collection
class Task {
  Id id = Isar.autoIncrement;

  @Index()
  int? feedItemId; // Link to parent FeedItem

  late String title;
  String? verb;
  String? text;

  @Index()
  DateTime? dueDate;

  late int priority; // 1-5 scale

  late bool completed;

  @Index()
  late DateTime createdAt;
  
  String? metadataJson;
}
