import 'package:flutter/material.dart';
import '../models/feed_item.dart';

class FeedCard extends StatelessWidget {
  final FeedItem feedItem;

  const FeedCard({Key? key, required this.feedItem}) : super(key: key);

  Color getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      default:
        return Colors.green.shade400;
    }
  }

  void _showFullText(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(feedItem.title),
          content: SingleChildScrollView(
            child: Text(feedItem.full_text),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    feedItem.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: getPriorityColor(feedItem.priority),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    feedItem.source,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(feedItem.summary),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _showFullText(context),
                child: const Text('Read More'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}