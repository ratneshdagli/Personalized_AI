import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/gradient_background.dart';
import 'debug_llm_screen.dart';

// Placeholder layout-only screens mapped from corresponding React components:
// - SettingsScreen.tsx -> `SettingsScreen`
// These are visual shells only (no functionality yet) to ensure the
// navigation structure and visuals match the Figma export.

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Personalize theme and preferences.', style: TextStyle(color: Color(0xFF94A3B8))),
              const SizedBox(height: 16),
              if (kDebugMode)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DebugLlmScreen()),
                    ),
                    child: const Text('Open LLM Diagnostics', style: TextStyle(color: Color(0xFFC084FC))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
