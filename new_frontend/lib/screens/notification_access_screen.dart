import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/lavish_background.dart';

class NotificationAccessScreen extends StatefulWidget {
  const NotificationAccessScreen({super.key});

  @override
  State<NotificationAccessScreen> createState() => _NotificationAccessScreenState();
}

class _NotificationAccessScreenState extends State<NotificationAccessScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.personalized_ai.app/notifications');
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (_isChecking) return; // Prevent multiple simultaneous checks
    
    setState(() => _isChecking = true);
    try {
      final bool granted = await platform.invokeMethod('isNotificationAccessGranted');
      debugPrint('Notification permission check result: $granted');
      
      if (granted && mounted) {
        // Permission granted, go back to the main app
        Navigator.of(context).pop();
      } else if (mounted) {
        // Show a message if permission is still not granted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable notification access in Settings'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to check permission: '${e.message}'.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking permission: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Unexpected error checking permission: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _openSettings() async {
    try {
      await platform.invokeMethod('openNotificationAccessSettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open settings: '${e.message}'.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open settings: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _skipForNow() {
    // For development/testing - allow skipping the permission check
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LavishBackground(
        dark: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.notifications_active_outlined, size: 80, color: Color(0xFFC084FC)),
                const SizedBox(height: 32),
                const Text(
                  'Enable Notification Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'To provide personalized insights, this app needs to read your notifications locally on your device.\n\nYour data never leaves your phone and is processed offline.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Open Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isChecking)
                  const CircularProgressIndicator(color: Colors.white54)
                else
                  Column(
                    children: [
                      TextButton(
                        onPressed: _checkPermission,
                        child: const Text(
                          'I have enabled it',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _skipForNow,
                        child: const Text(
                          'Skip for now (Development)',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
