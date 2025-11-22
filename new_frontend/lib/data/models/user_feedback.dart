import 'package:isar/isar.dart';

part 'user_feedback.g.dart';

@collection
class UserFeedback {
  Id id = Isar.autoIncrement;

  late String messageContent; // The content of the message that was hidden
  late String appPackage;     // The app package name (e.g., com.whatsapp)
  late String reason;         // e.g., "hidden"
  
  late DateTime timestamp;
}
