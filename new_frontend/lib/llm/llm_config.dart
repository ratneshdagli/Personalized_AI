import 'package:shared_preferences/shared_preferences.dart';

class LlmConfig {
  static const _keyPreferLocal = 'llm_prefer_local';
  static const _keyFallbackCloud = 'llm_fallback_cloud';
  static const _keyThreads = 'llm_threads';

  static Future<bool> preferLocal() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyPreferLocal) ?? true; // default prefer local
  }

  static Future<void> setPreferLocal(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyPreferLocal, v);
  }

  static Future<bool> fallbackCloud() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyFallbackCloud) ?? true; // default allow fallback
  }

  static Future<void> setFallbackCloud(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyFallbackCloud, v);
  }

  static Future<int> threads() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyThreads) ?? 1; // CPU-only single-thread default
  }

  static Future<void> setThreads(int t) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyThreads, t);
  }
}
