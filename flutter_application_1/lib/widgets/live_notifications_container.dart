import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notification_forwarder.dart';
import 'context_event_tile.dart';

class LiveNotificationsContainer extends StatefulWidget {
  const LiveNotificationsContainer({super.key});

  @override
  State<LiveNotificationsContainer> createState() => _LiveNotificationsContainerState();
}

class _LiveNotificationsContainerState extends State<LiveNotificationsContainer> {
  final List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = NotificationForwarderService.contextEvents.listen((e) {
      setState(() {
        _events.insert(0, e);
        if (_events.length > 50) {
          _events.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Live notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _events.length.clamp(0, 5),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ev = _events[index];
                final pkg = (ev['package'] ?? ev['app_name'] ?? 'app').toString();
                final text = (ev['text'] ?? ev['message'] ?? '').toString();
                final ts = DateTime.fromMillisecondsSinceEpoch(
                  int.tryParse('${ev['timestamp']}') ?? DateTime.now().millisecondsSinceEpoch,
                  isUtc: false,
                );
                return ContextEventTile(
                  appPackage: pkg,
                  snippet: text,
                  timestamp: ts,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


