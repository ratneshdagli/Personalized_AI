// Example: How to use LavishBackground in your existing app

import 'package:flutter/material.dart';
import 'package:your_app/widgets/lavish_background.dart';

/// Example 1: Simple Home Screen with LavishBackground
class HomeScreenExample extends StatelessWidget {
  const HomeScreenExample({super.key});

  @override
  Widget build(BuildContext context) {
    return LavishBackground(
      isDark: true,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Important!
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('My App'),
        ),
        body: Center(
          child: Text(
            'Beautiful, isn\'t it?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Example 2: With Glassmorphic Card
class GlassmorphismExample extends StatelessWidget {
  const GlassmorphismExample({super.key});

  @override
  Widget build(BuildContext context) {
    return LavishBackground(
      isDark: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 48, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Premium Card',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This glass card pops beautifully on the subtle background',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Example 3: Theme-Adaptive
class ThemeAdaptiveExample extends StatelessWidget {
  const ThemeAdaptiveExample({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LavishBackground(
      isDark: isDarkMode, // Automatically adapts to theme
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            'Switches with theme!',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Example 4: Replace Existing GradientBackground
/// 
/// BEFORE:
/// ```dart
/// GradientBackground(
///   child: HomeScreen(),
/// )
/// ```
/// 
/// AFTER:
/// ```dart
/// LavishBackground(
///   isDark: true,
///   child: HomeScreen(),
/// )
/// ```

/// Example 5: Full App Integration
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Premium App',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LavishBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Home'),
        ),
        body: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildGlassCard(
              icon: Icons.notifications_active,
              title: 'Notifications',
              subtitle: '3 new updates',
            ),
            SizedBox(height: 16),
            _buildGlassCard(
              icon: Icons.task_alt,
              title: 'Tasks',
              subtitle: '5 pending items',
            ),
            SizedBox(height: 16),
            _buildGlassCard(
              icon: Icons.calendar_today,
              title: 'Calendar',
              subtitle: '2 events today',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white70),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white38),
        ],
      ),
    );
  }
}
