import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../providers/task_provider.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<TaskProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: tp.tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final t = tp.tasks[index];
          return _TaskTile(task: t);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final now = DateTime.now();
          final task = Task(
            id: 'task-${now.microsecondsSinceEpoch}',
            title: 'New Task',
            verb: 'do',
            text: 'Describe your task',
          );
          tp.addTask(task);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<TaskProvider>(context, listen: false);
    return Card(
      child: ListTile(
        title: Text(task.title),
        subtitle: Text(task.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Checkbox(
          value: task.isCompleted,
          onChanged: (v) => tp.toggleComplete(task.id, v ?? false),
        ),
        onLongPress: () => tp.removeTask(task.id),
      ),
    );
  }
}


