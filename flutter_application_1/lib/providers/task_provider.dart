import 'package:flutter/material.dart';
import '../services/local_storage.dart';
import '../models/task.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  List<Task> get tasks => _tasks;

  TaskProvider() {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = LocalStorage.tasks;
    final raw = (box.get('items') as List?) ?? [];
    _tasks = raw.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    notifyListeners();
  }

  void _saveToHive() {
    final box = LocalStorage.tasks;
    box.put('items', _tasks.map((t) => t.toJson()).toList());
  }

  void addTask(Task task) {
    _tasks = [task, ..._tasks];
    _saveToHive();
    notifyListeners();
  }

  void toggleComplete(String id, bool value) {
    _tasks = _tasks.map((t) {
      if (t.id == id) {
        t.isCompleted = value;
        t.completedAt = value ? DateTime.now() : null;
      }
      return t;
    }).toList();
    _saveToHive();
    notifyListeners();
  }

  void removeTask(String id) {
    _tasks = _tasks.where((t) => t.id != id).toList();
    _saveToHive();
    notifyListeners();
  }
}
