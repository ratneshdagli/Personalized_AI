import 'package:isar/isar.dart';

part 'calendar_event.g.dart';

@collection
class CalendarEvent {
  Id id = Isar.autoIncrement;

  @Index()
  int? feedItemId; // Link to parent FeedItem

  late String title;
  late DateTime start;
  DateTime? end;
  String? location;
  late bool allDay;

  String? metadataJson;
}
