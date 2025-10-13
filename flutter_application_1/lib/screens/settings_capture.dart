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
            child: SwitchListTile(
              title: const Text('Forward to Server'),
              subtitle: const Text('Send sanitized context events to backend for personalization'),
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
              title: const Text('Advanced Capture (Accessibility)'),
              subtitle: const Text('Highly sensitive. Rate-limited; excludes sensitive apps; opt-in only.'),
              value: _advancedAccessibility,
              onChanged: (v) async {
                if (v) {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Enable Advanced Capture?'),
                      content: const Text('This uses Android AccessibilityService to read limited visible text in apps you choose. It is strictly opt-in, rate-limited, and excludes sensitive apps. You can disable at any time in Settings.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enable')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                }
                await _toggleAdvanced(v);
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
          const Text('- Notification access: Reads notification metadata you choose to personalize your feed. Forwarding off-device is off by default.'),
          const SizedBox(height: 4),
          const Text('- Accessibility: Captures limited on-screen text in apps you select. Strictly opt-in, rate-limited, excludes sensitive apps.'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}


