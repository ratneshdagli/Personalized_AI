import 'package:flutter/material.dart';
import '../services/notification_forwarder.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personalized AI', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Enable capture to see live notifications and personalized feed.'),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Notification Access'),
                subtitle: const Text('Allow to capture incoming notifications'),
                trailing: ElevatedButton(onPressed: NotificationForwarderService.openNotificationSettings, child: const Text('Open')),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.accessibility_new_outlined),
                title: const Text('Advanced Capture (Accessibility)'),
                subtitle: const Text('Optional, opt-in with consent'),
                trailing: ElevatedButton(onPressed: NotificationForwarderService.openAccessibilitySettings, child: const Text('Open')),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: const Text('Get Started'),
              ),
            )
          ],
        ),
      ),
    );
  }
}


