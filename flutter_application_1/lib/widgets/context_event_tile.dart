import 'package:flutter/material.dart';

class ContextEventTile extends StatelessWidget {
  final String appPackage;
  final String snippet;
  final DateTime timestamp;
  final double confidence;

  const ContextEventTile({super.key, required this.appPackage, required this.snippet, required this.timestamp, this.confidence = 0.7});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.circle_notifications_outlined),
      title: Text(appPackage),
      subtitle: Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${timestamp.hour.toString().padLeft(2,'0')}:${timestamp.minute.toString().padLeft(2,'0')}'),
          const SizedBox(height: 4),
          Text('${(confidence*100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}


