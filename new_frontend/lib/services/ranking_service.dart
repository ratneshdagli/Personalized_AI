class RankingService {
  // Calculate priority based on importance string and other factors
  int calculatePriority(String importance, {String? content, String? sender}) {
    int basePriority = 1;
    
    switch (importance.toLowerCase()) {
      case 'high':
        basePriority = 9;
        break;
      case 'medium':
        basePriority = 6;
        break;
      case 'low':
        basePriority = 3;
        break;
      default:
        basePriority = 1;
    }

    // Adjust based on keywords (simple example)
    if (content != null) {
      final lowerContent = content.toLowerCase();
      if (lowerContent.contains('urgent') || lowerContent.contains('asap')) {
        basePriority += 2;
      }
      if (lowerContent.contains('deadline') || lowerContent.contains('due')) {
        basePriority += 1;
      }
    }

    // Cap at 10
    if (basePriority > 10) basePriority = 10;
    
    return basePriority;
  }
}
