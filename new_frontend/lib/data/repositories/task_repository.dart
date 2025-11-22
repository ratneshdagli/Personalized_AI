import 'package:isar/isar.dart';
import '../schema/task.dart';

class TaskRepository {
  final Isar isar;

  TaskRepository(this.isar);

  Future<List<Task>> getTasks() async {
    return await isar.tasks
        .where()
        .sortByPriorityDesc()
        .thenByDueDate()
        .findAll();
  }
  
  Future<List<Task>> getIncompleteTasks() async {
    return await isar.tasks
        .filter()
        .completedEqualTo(false)
        .sortByPriorityDesc()
        .thenByDueDate()
        .findAll();
  }

  Future<int> addTask(Task task) async {
    return await isar.writeTxn(() async {
      return await isar.tasks.put(task);
    });
  }

  Future<void> updateTask(Task task) async {
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
  }

  Future<void> deleteTask(int id) async {
    await isar.writeTxn(() async {
      await isar.tasks.delete(id);
    });
  }

  Future<List<Task>> getTasksForFeedItem(int feedItemId) async {
    return await isar.tasks
        .filter()
        .feedItemIdEqualTo(feedItemId)
        .findAll();
  }
}
