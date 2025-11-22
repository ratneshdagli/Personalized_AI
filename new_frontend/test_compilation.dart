// Quick test to verify the implementation compiles correctly
import 'lib/models/task_types.dart';
import 'lib/services/local_llm_service.dart';

void main() {
  // Test TaskType enum
  final chatTask = TaskType.llmChat;
  print('Task: ${chatTask.displayName}');
  
  // Test TaskConfig
  final taskConfig = BuiltInTasks.getTaskByType(TaskType.llmChat);
  print('Config: ${taskConfig?.displayName}');
  print('Placeholder: ${taskConfig?.inputPlaceholder}');
  
  // Test PerformanceMetrics
  final metrics = PerformanceMetrics(
    timeToFirstToken: 1.5,
    prefillSpeed: 100.0,
    decodeSpeed: 50.0,
    latency: 2.0,
    totalTokens: 100,
  );
  print('Metrics: TTFT=${metrics.timeToFirstToken}s');
  
  print('✅ All components compile successfully!');
}
