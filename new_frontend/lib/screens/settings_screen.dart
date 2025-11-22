import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../widgets/lavish_background.dart';
import '../widgets/hf_model_manager_card.dart';
import '../state/app_state.dart';
import '../services/local_llm_service.dart';
import '../services/huggingface_model_download_service.dart';
import '../data/schema/model_record.dart';
import 'debug_llm_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ModelRecord> _installedModels = [];
  bool _isLoadingModels = true;
  String? _selectedModelId;
  bool _isInitializing = false;
  HuggingFaceModelDownloadService? _hfService;

  @override
  void initState() {
    super.initState();
    _setupHFServiceListener();
    // Use addPostFrameCallback to ensure AppState has time to initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstalledModels();
    });
  }

  void _setupHFServiceListener() {
    // Get the HF service and listen for changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hfService = HuggingFaceModelDownloadService();
      _hfService!.addListener(_onHFServiceStateChanged);
    });
  }

  HFModelDownloadStatus? _lastKnownStatus;
  
  void _onHFServiceStateChanged() {
    // Only refresh if status actually changed to installed (prevent infinite loop)
    final state = _hfService?.state;
    if (state?.status == HFModelDownloadStatus.installed && 
        _lastKnownStatus != HFModelDownloadStatus.installed) {
      _lastKnownStatus = state?.status;
      _loadInstalledModels();
    } else if (state?.status != HFModelDownloadStatus.installed) {
      _lastKnownStatus = state?.status;
    }
  }

  @override
  void dispose() {
    _hfService?.removeListener(_onHFServiceStateChanged);
    super.dispose();
  }

  Future<void> _loadInstalledModels() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      
      // Force a refresh of the cache first
      if (_hfService != null) {
        await _hfService!.checkInstalledModel(force: true);
      }
      
      // Try to get installed models, handle if AppState not ready
      List<ModelRecord> models = [];
      try {
        models = await appState.modelRepository.getInstalledModels();
      } catch (e) {
        if (e.toString().contains('not initialized')) {
          // AppState not ready yet, retry after a short delay
          debugPrint('[Settings] AppState not ready yet, retrying in 500ms');
          setState(() {
            _isLoadingModels = true;
          });
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _loadInstalledModels();
          }
          return;
        }
        rethrow;
      }
      
      // Get current selected model from LocalLLMService
      final currentModelPath = await LocalLLMService.getDownloadedModelPath();
      
      setState(() {
        _installedModels = models;
        _isLoadingModels = false;
        
        // Set selected model based on current LLM service path
        if (currentModelPath != null) {
          final currentModel = models.where((m) => m.path == currentModelPath).firstOrNull;
          _selectedModelId = currentModel?.modelId;
        }
      });
    } catch (e) {
      debugPrint('Error loading installed models: $e');
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  Future<void> _selectModel(ModelRecord model) async {
    setState(() {
      _isInitializing = true;
      _selectedModelId = model.modelId;
    });

    try {
      final llmService = LocalLLMService();
      
      // Initialize the LLM with the selected model
      await llmService.initialize(
        modelPath: model.path,
        modelName: model.name,
        llmSupportImage: false, // Update based on model capabilities if needed
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model "${model.name}" initialized successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error initializing model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LavishBackground(
      dark: true,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Personalize theme and preferences.', style: TextStyle(color: Color(0xFF94A3B8))),
              const SizedBox(height: 24),
              
              // Active Model Selector
              const Text('Active Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Select which model to use for local AI processing', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 12),
              
              if (_isLoadingModels)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                )
              else if (_installedModels.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x1A64748B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x3364748B)),
                  ),
                  child: const Text(
                    'No models installed. Download a model below to get started.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                )
              else
                ..._installedModels.map((model) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _selectedModelId == model.modelId 
                          ? const Color(0x1A3B82F6) 
                          : const Color(0x1A64748B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedModelId == model.modelId 
                            ? const Color(0xFF3B82F6) 
                            : const Color(0x3364748B),
                        width: _selectedModelId == model.modelId ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: model.modelId,
                      groupValue: _selectedModelId,
                      onChanged: _isInitializing ? null : (value) {
                        if (value != null) {
                          _selectModel(model);
                        }
                      },
                      activeColor: const Color(0xFF3B82F6),
                      title: Text(
                        model.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${(model.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB${model.version != null ? ' • v${model.version}' : ''}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ),
                  ),
                )),
              
              if (_isInitializing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                      ),
                      SizedBox(width: 12),
                      Text('Initializing model...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              const Text('Models & AI', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const HFModelManagerCard(),
              
              const SizedBox(height: 24),
              if (kDebugMode) ...[
                const Text('Developer Tools', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Open LLM Diagnostics', style: TextStyle(color: Color(0xFFC084FC))),
                  subtitle: const Text('Test local LLM extraction manually', style: TextStyle(color: Colors.white54)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DebugLlmScreen()),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
