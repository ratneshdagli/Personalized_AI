import 'package:flutter/material.dart';
import '../services/notification_forwarder.dart';

class SettingsCaptureScreen extends StatefulWidget {
  const SettingsCaptureScreen({super.key});

  @override
  State<SettingsCaptureScreen> createState() => _SettingsCaptureScreenState();
}

class _SettingsCaptureScreenState extends State<SettingsCaptureScreen> {
  bool _serverForwarding = false;
  bool _advancedAccessibility = false;
  bool _localOnly = true;
  String _backendUrl = '';
  String _userId = 'device';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await NotificationForwarderService.getCaptureStatus();
    setState(() {
      _serverForwarding = status['serverForwarding'] == true;
      _advancedAccessibility = status['advancedAccessibility'] == true;
      _backendUrl = (status['backendUrl'] ?? '') as String;
      _userId = (status['userId'] ?? 'device') as String;
      _localOnly = !_serverForwarding;
    });
    if (mounted) {
      // Gently prompt to enable permissions if missing
      final notifOk = status['notificationAccessEnabled'] == true;
      final accOk = status['accessibilityEnabled'] == true;
      if (!notifOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Grant Notification Access to capture events'),
            action: SnackBarAction(label: 'Open', onPressed: () {
              NotificationForwarderService.openNotificationSettings();
            }),
          ),
        );
      }
      if (_advancedAccessibility && !accOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enable Accessibility service for Advanced Capture'),
            action: SnackBarAction(label: 'Open', onPressed: () {
              NotificationForwarderService.openAccessibilitySettings();
            }),
          ),
        );
      }
    }
  }

  Future<void> _toggleServerForwarding(bool value) async {
    setState(() {
      _serverForwarding = value;
      _localOnly = !value;
    });
    await NotificationForwarderService.setServerForwarding(value);
  }

  Future<void> _toggleAdvanced(bool value) async {
    setState(() => _advancedAccessibility = value);
    await NotificationForwarderService.enableAccessibilityAdvancedMode(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture & Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Notification access'),
              subtitle: Text(_serverForwarding ? 'Enabled for capture' : 'Disabled'),
              trailing: FilledButton(
                onPressed: () => NotificationForwarderService.openNotificationSettings(),
                child: const Text('Open'),
              ),
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Forward to Server'),
              subtitle: const Text('Send WhatsApp messages and other context events to backend for personalization'),
              value: _serverForwarding,
              onChanged: _toggleServerForwarding,
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Local-only Mode'),
              subtitle: const Text('Keep events on-device only; no network forwarding'),
              value: _localOnly,
              onChanged: (v) => _toggleServerForwarding(!v),
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('WhatsApp Notification Capture'),
              subtitle: const Text('Capture WhatsApp messages from notifications (requires Notification Access permission)'),
              value: _serverForwarding, // Use server forwarding as proxy for WhatsApp capture
              onChanged: (v) async {
                if (v) {
                  // Check if notification access is enabled
                  final status = await NotificationForwarderService.getCaptureStatus();
                  if (status['notificationAccessEnabled'] != true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Enable Notification Access to capture WhatsApp messages'),
                        action: SnackBarAction(label: 'Open Settings', onPressed: () {
                          NotificationForwarderService.openNotificationSettings();
                        }),
                      ),
                    );
                    return;
                  }
                }
                await _toggleServerForwarding(v);
              },
            ),
          ),
          Card(
            child: SwitchListTile(
              title: const Text('Advanced Capture (Accessibility)'),
              subtitle: const Text('Capture WhatsApp content via screen reading (requires Accessibility permission)'),
              value: _advancedAccessibility,
              onChanged: (v) async {
                if (v) {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Enable Advanced Capture?'),
                      content: const Text('This uses Android AccessibilityService to read limited visible text in WhatsApp and other apps you choose. It is strictly opt-in, rate-limited, and excludes sensitive apps. You can disable at any time in Settings.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                }
                await _toggleAdvanced(v);
                if (v) {
                  // Navigate user to system settings
                  await NotificationForwarderService.openAccessibilitySettings();
                }
              },
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backend Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _backendUrl,
                    decoration: const InputDecoration(labelText: 'Backend URL (e.g., http://10.0.2.2:8000)'),
                    onChanged: (v) => _backendUrl = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _userId,
                    decoration: const InputDecoration(labelText: 'User ID'),
                    onChanged: (v) => _userId = v,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () async {
                        await NotificationForwarderService.setBackendUrl(_backendUrl);
                        await NotificationForwarderService.setUserId(_userId);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
                      },
                      child: const Text('Save'),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Play Store disclosure (to copy into listing):'),
          const SizedBox(height: 6),
          const Text('- Notification access: Reads WhatsApp and other app notifications to personalize your feed. Forwarding off-device is off by default.'),
          const SizedBox(height: 4),
          const Text('- Accessibility: Captures limited on-screen text in WhatsApp and other apps you select. Strictly opt-in, rate-limited, excludes sensitive apps.'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


