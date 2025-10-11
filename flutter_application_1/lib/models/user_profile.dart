// User preferences, keywords, important senders
class UserProfile {
  final String userId;
  final List<String> keywords;
  final List<String> importantSenders;

  UserProfile({required this.userId, required this.keywords, required this.importantSenders});
}
