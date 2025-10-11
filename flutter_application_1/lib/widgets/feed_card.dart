import 'package:flutter/material.dart';
import '../models/feed_item.dart';

class FeedCard extends StatelessWidget {
  final FeedItem feedItem;

  const FeedCard({Key? key, required this.feedItem}) : super(key: key);

  Color getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        title: Text(feedItem.title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(feedItem.summary),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getPriorityColor(feedItem.priority),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "Priority ${feedItem.priority}",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
