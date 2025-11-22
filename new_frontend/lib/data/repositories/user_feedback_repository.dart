import 'package:isar/isar.dart';
import '../schema/user_feedback.dart';

class UserFeedbackRepository {
  final Isar _isar;

  UserFeedbackRepository(this._isar);

  Future<void> addFeedback(String messageContent, String appPackage, String reason) async {
    final feedback = UserFeedback()
      ..messageContent = messageContent
      ..appPackage = appPackage
      ..reason = reason
      ..timestamp = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.userFeedbacks.put(feedback);
    });
  }

  Future<List<UserFeedback>> getRecentFeedback({int limit = 20}) async {
    return await _isar.userFeedbacks
        .where()
        .sortByTimestampDesc()
        .limit(limit)
        .findAll();
  }
  
  Future<void> clearFeedback() async {
    await _isar.writeTxn(() async {
      await _isar.userFeedbacks.clear();
    });
  }
}
