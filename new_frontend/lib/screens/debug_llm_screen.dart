import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../llm/llm_service.dart';
import '../llm/llm_config.dart';

class DebugLlmScreen extends StatefulWidget {
  const DebugLlmScreen({super.key});

  @override
  State<DebugLlmScreen> createState() => _DebugLlmScreenState();
}

class _DebugLlmScreenState extends State<DebugLlmScreen> {
  final _svc = LlmService();
  String _summary = '';
  Map<String, dynamic>? _status;
  bool _preferLocal = true;
  bool _fallbackCloud = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await _svc.status();
    _preferLocal = await LlmConfig.preferLocal();
    _fallbackCloud = await LlmConfig.fallbackCloud();
    setState(() {
      _status = {
        'modelLoaded': st.modelLoaded,
        'modelName': st.modelName,
        'modelPath': st.modelPath,
        'modelSize': st.modelSizeBytes,
        'checksumVerified': st.checksumVerified,
        'lastLatencyMs': st.lastLatencyMs,
        'downloadDate': st.downloadDate?.toIso8601String(),
      };
    });
  }

  Future<void> _runSample() async {
    const sample = 'Meeting tomorrow at 2 PM. Please submit the report by Friday.';
    final t0 = DateTime.now();
    final s = await _svc.summarizeText(sample, maxLength: 80);
    final t1 = DateTime.now();
    setState(() {
      _summary = s + '  (latency: ${t1.difference(t0).inMilliseconds} ms)';
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LLM Diagnostics (Debug)'), backgroundColor: const Color(0xFF0F172A)),
      backgroundColor: const Color(0xFF0B1220),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Status', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(12)),
              child: Text(
                _status?.entries.map((e) => '${e.key}: ${e.value}').join('\n') ?? 'Loading...',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Configuration', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Prefer local on-device model', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Use on-device model first, fallback to cloud if enabled', style: TextStyle(color: Colors.white54)),
              value: _preferLocal,
              onChanged: (v) async {
                await LlmConfig.setPreferLocal(v);
                setState(() => _preferLocal = v);
              },
            ),
            SwitchListTile(
              title: const Text('Allow fallback to cloud', style: TextStyle(color: Colors.white)),
              subtitle: const Text('If local inference fails or no model present', style: TextStyle(color: Colors.white54)),
              value: _fallbackCloud,
              onChanged: (v) async {
                await LlmConfig.setFallbackCloud(v);
                setState(() => _fallbackCloud = v);
              },
            ),
            const SizedBox(height: 16),
            const Text('Diagnostics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _runSample,
              child: const Text('Run sample summarization'),
            ),
            const SizedBox(height: 8),
            Text(_summary, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
