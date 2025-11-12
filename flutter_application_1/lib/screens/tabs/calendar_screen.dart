import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>().tasks;
    final grouped = <String, List<String>>{};
    for (final t in tasks) {
      final key = (t.dueDate ?? t.createdAt).toIso8601String().substring(0, 10);
      grouped.putIfAbsent(key, () => []).add(t.title);
    }
    final days = grouped.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final d = days[index];
          final items = grouped[d]!;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...items.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $t'),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


