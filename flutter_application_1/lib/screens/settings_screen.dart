import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  
  // Settings states
  bool _notificationsEnabled = true;
  bool _localOnlyMode = false;
  bool _autoSyncEnabled = true;
  bool _darkModeEnabled = false;
  int _syncIntervalMinutes = 30;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _localOnlyMode = prefs.getBool('local_only_mode') ?? false;
        _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
        _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
        _syncIntervalMinutes = prefs.getInt('sync_interval_minutes') ?? 30;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool('local_only_mode', _localOnlyMode);
      await prefs.setBool('auto_sync_enabled', _autoSyncEnabled);
      await prefs.setBool('dark_mode_enabled', _darkModeEnabled);
      await prefs.setInt('sync_interval_minutes', _syncIntervalMinutes);
      
      _showSuccessSnackBar('Settings saved successfully');
    } catch (e) {
      _showErrorSnackBar('Error saving settings: $e');
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will delete all your feed items, tasks, and settings. '
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear auth data
        await _authService.clearAllAuth();
        
        // Clear local settings
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        // TODO: Clear local database/cache
        
        _showSuccessSnackBar('All data cleared successfully');
        
        // Reload settings
        await _loadSettings();
      } catch (e) {
        _showErrorSnackBar('Error clearing data: $e');
      }
    }
  }

  Future<void> _exportData() async {
    try {
      // TODO: Implement data export
      _showSuccessSnackBar('Data export started. You will be notified when ready.');
    } catch (e) {
      _showErrorSnackBar('Error exporting data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Center'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(PhosphorIconsBold.floppyDisk),
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Notifications Section
                _buildSectionHeader('Notifications').animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
                _buildSwitchTile(
                  'Enable Notifications',
                  'Receive notifications for important tasks and updates',
                  PhosphorIconsLight.bell,
                  _notificationsEnabled,
                  (value) => setState(() => _notificationsEnabled = value),
                ),
                _buildSwitchTile(
                  'Auto Sync',
                  'Automatically sync data in the background',
                  PhosphorIconsLight.arrowsClockwise,
                  _autoSyncEnabled,
                  (value) => setState(() => _autoSyncEnabled = value),
                ),
                
                const SizedBox(height: 24),
                
                // Privacy Section
                _buildSectionHeader('Privacy & Security').animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
                _buildSwitchTile(
                  'Local Only Mode',
                  'Process data only on your device (no cloud sync)',
                  PhosphorIconsLight.shieldCheck,
                  _localOnlyMode,
                  (value) => setState(() => _localOnlyMode = value),
                ),
                _buildSwitchTile(
                  'Dark Mode',
                  'Use dark theme for better battery life',
                  PhosphorIconsLight.moon,
                  _darkModeEnabled,
                  (value) => setState(() => _darkModeEnabled = value),
                ),
                
                const SizedBox(height: 24),
                
                // Sync Settings
                _buildSectionHeader('Sync Settings').animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
                ListTile(
                  leading: const Icon(PhosphorIconsLight.timer),
                  title: const Text('Sync Interval'),
                  subtitle: Text('Every $_syncIntervalMinutes minutes'),
                  trailing: DropdownButton<int>(
                    value: _syncIntervalMinutes,
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('1 hour')),
                      DropdownMenuItem(value: 120, child: Text('2 hours')),
                      DropdownMenuItem(value: 240, child: Text('4 hours')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _syncIntervalMinutes = value);
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Data Management Section
                _buildSectionHeader('Data Management').animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
                ListTile(
                  leading: const Icon(PhosphorIconsLight.downloadSimple),
                  title: const Text('Export Data'),
                  subtitle: const Text('Download your data as JSON'),
                  trailing: const Icon(PhosphorIconsLight.caretRight),
                  onTap: _exportData,
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsLight.trashSimple, color: Colors.red),
                  title: const Text('Clear All Data'),
                  subtitle: const Text('Delete all data and reset settings'),
                  trailing: const Icon(PhosphorIconsLight.caretRight),
                  onTap: _clearAllData,
                ),
                
                const SizedBox(height: 24),
                
                // Connectors Section
                _buildSectionHeader('Data Sources').animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
                ListTile(
                  leading: const Icon(PhosphorIconsLight.plug),
                  title: const Text('Manage Connectors'),
                  subtitle: const Text('Configure Gmail, WhatsApp, News, Reddit'),
                  trailing: const Icon(PhosphorIconsLight.caretRight),
                  onTap: () {
                    Navigator.pushNamed(context, '/login');
                  },
                ),
                
                const SizedBox(height: 24),
                
                // About Section
                _buildSectionHeader('About').animate().fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
                ListTile(
                  leading: const Icon(PhosphorIconsLight.info),
                  title: const Text('App Version'),
                  subtitle: const Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsLight.shield),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('View our privacy policy'),
                  trailing: const Icon(PhosphorIconsLight.caretRight),
                  onTap: () {
                    // TODO: Open privacy policy
                    _showSuccessSnackBar('Privacy policy will open in browser');
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsLight.question),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Get help and contact support'),
                  trailing: const Icon(PhosphorIconsLight.caretRight),
                  onTap: () {
                    // TODO: Open help/support
                    _showSuccessSnackBar('Help section will open');
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(PhosphorIconsBold.floppyDisk),
                    label: const Text('Save Settings'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
