// Card for each task
import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(title: Text('Task')));
  }
}
