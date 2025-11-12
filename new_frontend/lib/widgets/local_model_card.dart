import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:figma/widgets/glass_card.dart';
import '../services/local_llm_service.dart';
import 'local_model_chat_interface.dart';

class LocalModelCard extends StatefulWidget {
  const LocalModelCard({super.key});

  @override
  State<LocalModelCard> createState() => _LocalModelCardState();
}

class _LocalModelCardState extends State<LocalModelCard> {
  String? _modelPath;
  String? _modelName;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedModel();
  }

  Future<void> _loadSavedModel() async {
    try {
      final modelPath = await LocalLLMService.getDownloadedModelPath();
      final modelName = await LocalLLMService.getDownloadedModelName();
      
      if (mounted) {
        setState(() {
          _modelPath = modelPath;
          _modelName = modelName ?? 'Local Model';
        });
      }
    } catch (e) {
      debugPrint('Error loading saved model: $e');
    }
  }

  Future<void> _saveModelPath(String path, String name) async {
    try {
      await LocalLLMService.saveModelPath(path, name);
      
      if (mounted) {
        setState(() {
          _modelPath = path;
          _modelName = name;
        });
      }
    } catch (e) {
      debugPrint('Error saving model path: $e');
      rethrow;
    }
  }

  Future<void> _pickModelFile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['task', 'tflite', 'bin'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = path.basename(filePath);
        
        // Copy file to app's documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final modelsDir = Directory('${appDir.path}/models');
        if (!await modelsDir.exists()) {
          await modelsDir.create(recursive: true);
        }
        
        final newPath = '${modelsDir.path}/$fileName';
        await File(filePath).copy(newPath);
        
        // Save the new model path
        await _saveModelPath(newPath, path.basenameWithoutExtension(fileName));
      }
    } catch (e) {
      debugPrint('Error picking model file: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to select model: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openChat() {
    if (_modelPath == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocalModelChatInterface(
          modelPath: _modelPath!,
          modelName: _modelName ?? 'Local Model',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.cpu, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Local LLM Model',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _modelPath != null ? 'Ready to chat' : 'No model selected',
                      style: TextStyle(
                        color: _modelPath != null ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_modelPath != null)
                IconButton(
                  icon: const Icon(LucideIcons.messageSquare, color: Color(0xFF94A3B8)),
                  onPressed: _openChat,
                  tooltip: 'Chat with model',
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Model info
          if (_modelPath != null) ...[
            _buildInfoRow('Model', _modelName ?? 'Local Model'),
            const SizedBox(height: 6),
            _buildInfoRow('Path', _modelPath!),
            const SizedBox(height: 12),
          ],
          
          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1AEF4444),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x33EF4444)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickModelFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                  ),
                  icon: const Icon(LucideIcons.upload, size: 16),
                  label: Text(_modelPath == null ? 'Select Model File' : 'Change Model'),
                ),
              ),
              if (_modelPath != null) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _openChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(LucideIcons.messageSquare, size: 16),
                  label: const Text('Chat'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
        ),
        const Text(':', style: TextStyle(color: Color(0xFF94A3B8))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
