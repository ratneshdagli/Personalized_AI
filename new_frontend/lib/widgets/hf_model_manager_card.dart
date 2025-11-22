import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/huggingface_model_download_service.dart';
import '../state/app_state.dart';
import 'glass_card.dart';
import 'model_chat_interface.dart';

// The parent widget remains StatelessWidget.
// It's only responsible for creating the provider.
class HFModelManagerCard extends StatelessWidget {
  const HFModelManagerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HuggingFaceModelDownloadService>(
      create: (context) {
        final service = HuggingFaceModelDownloadService();
        
        // Try to initialize with ModelRepository if AppState is ready
        try {
          final appState = Provider.of<AppState>(context, listen: false);
          service.init(appState.modelRepository);
          
          // Use a post-frame callback to avoid doing work during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Only check installed model if we don't have any state yet
            if (service.state.status == HFModelDownloadStatus.notInstalled) {
              service.checkInstalledModel();
            }
            // Load available models in the background
            service.loadAvailableModels();
          });
        } catch (e) {
          debugPrint('[HFModelManagerCard] AppState not ready yet: $e');
          // Service will work in limited mode without database
        }
        
        return service;
      },
      child: const _HFModelManagerCardContent(),
    );
  }
}

//
// --- This is the widget we are converting to a StatefulWidget ---
//
class _HFModelManagerCardContent extends StatefulWidget {
  const _HFModelManagerCardContent();

  @override
  State<_HFModelManagerCardContent> createState() =>
      _HFModelManagerCardContentState();
}

class _HFModelManagerCardContentState extends State<_HFModelManagerCardContent> {
  // 1. Add _isExpanded to the State
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<HuggingFaceModelDownloadService>();
    final state = service.state;

    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2. Wrap the header in a GestureDetector to toggle state
          GestureDetector(
            onTap: () {
              // 3. Use setState to toggle the _isExpanded variable
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            behavior: HitTestBehavior.opaque, // Makes the whole area tappable
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9D00), Color(0xFFFFB800)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.brain,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hugging Face Model',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getStatusText(state.status),
                        style: TextStyle(
                          color: _getStatusColor(state.status),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // 4. Add a rotating arrow icon
                AnimatedRotation(
                  turns: _isExpanded ? 0.0 : -0.5, // Rotates 180 degrees
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    LucideIcons.chevronDown,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // 5. Wrap the rest of the content in AnimatedSize
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: Container(
              // The 'child' of AnimatedSize must not be visible when collapsed
              child: !_isExpanded
                  ? const SizedBox(width: double.infinity) // Collapsed state
                  : Column(
                      // Expanded state
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        // Progress bar (downloading)
                        if (state.status == HFModelDownloadStatus.downloading)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: state.progress,
                                  backgroundColor: const Color(0xFF1E293B),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFF9D00)),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(state.progress * 100).toStringAsFixed(0)}% • ${_formatBytes(state.bytesDownloaded)}${state.totalBytes != null ? ' / ${_formatBytes(state.totalBytes!)}' : ''}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),

                        // Model info (installed)
                        if (state.status == HFModelDownloadStatus.installed &&
                            state.modelInfo != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Model', state.modelInfo!.name),
                              const SizedBox(height: 6),
                              _buildInfoRow(
                                  'Model ID', state.modelInfo!.modelId),
                              const SizedBox(height: 6),
                              _buildInfoRow('Size',
                                  _formatBytes(state.modelInfo!.sizeInBytes)),
                              const SizedBox(height: 6),
                              if (state.sha256 != null)
                                _buildInfoRow(
                                    'SHA256', '${state.sha256!.substring(0, 12)}...'),
                              if (state.installedAt != null) ...[
                                const SizedBox(height: 6),
                                _buildInfoRow(
                                    'Installed', _formatDate(state.installedAt!)),
                              ],
                              const SizedBox(height: 12),
                            ],
                          ),

                        // Available models list or Offline message
                        if (service.availableModels.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available Models (CPU-only):',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...service.availableModels.map((model) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: _buildModelOption(
                                        context, service, model),
                                  )),
                              const SizedBox(height: 4),
                            ],
                          )
                        else if (state.status != HFModelDownloadStatus.downloading && 
                                 state.status != HFModelDownloadStatus.preparing)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0x1A64748B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0x3364748B)),
                            ),
                            child: const Row(
                              children: [
                                Icon(LucideIcons.wifiOff, color: Color(0xFF94A3B8), size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cannot load models. Please check your connection.',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Error message
                        if (state.status == HFModelDownloadStatus.failed)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AEF4444),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0x33EF4444)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.alertCircle,
                                        color: Color(0xFFEF4444), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        state.errorMessage ??
                                            'Download failed',
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
                          ),

                        // Action buttons
                        _buildActionButtons(context, service, state),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- All helper methods below this line are moved from the Stateless widget ---
  // --- They do not need to be changed. ---

  // Helper method to check if a model is downloaded
  Future<bool> _isModelDownloaded(
      HuggingFaceModelDownloadService service, HFModelInfo model) async {
    try {
      // Check all possible model identifiers in parallel
      final results = await Future.wait([
        service.isModelDownloaded(model.id),
        service.isModelDownloaded(model.fileName),
        service.isModelDownloaded(model.hfRepoId)
      ]);

      // Return true if any of the checks returned true
      return results.any((isDownloaded) => isDownloaded == true);
    } catch (e) {
      debugPrint('Error checking if model is downloaded: $e');
      return false;
    }
  }

  Future<void> _handleModelTap(
    BuildContext context,
    HuggingFaceModelDownloadService service,
    HFModelInfo model,
  ) async {
    // Check if this is the current model by ID, filename, or repo ID
    final isCurrentModel = service.state.status ==
            HFModelDownloadStatus.installed &&
        (service.state.modelInfo?.id == model.id ||
            service.state.modelInfo?.fileName == model.fileName ||
            service.state.modelInfo?.hfRepoId == model.hfRepoId);

    // Check if the model is downloaded
    final isDownloaded = await _isModelDownloaded(service, model);

    if (isCurrentModel) {
      // Show model details in a dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title:
              const Text('Model Details', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Name', model.displayName),
                const SizedBox(height: 8),
                _buildInfoRow('Model ID', model.hfRepoId),
                const SizedBox(height: 8),
                _buildInfoRow('Size', _formatBytes(model.sizeInBytes)),
                if (service.state.sha256 != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('SHA256', service.state.sha256!),
                ],
                if (service.state.installedAt != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                      'Installed', _formatDate(service.state.installedAt!)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else if (isDownloaded) {
      // Directly install the model without showing confirmation dialog
      await service.installModel(model);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Switched to selected model'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Download the model
      try {
        await service.downloadModel(model);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Model download started'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to start download: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start download: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Helper method to determine if a model supports images
  bool _supportsImages(HFModelInfo model) {
    // Check if taskTypes includes 'llm_ask_image' or 'llm_vision'
    if (model.taskTypes.contains('llm_ask_image') ||
        model.taskTypes.contains('llm_vision')) {
      return true;
    }

    // Check if model explicitly supports images
    if (model.llmSupportImage) {
      return true;
    }

    // Check for common naming patterns in model ID as a last resort
    final modelName = model.id.toLowerCase();
    if (modelName.contains('vision') ||
        modelName.contains('multimodal') ||
        modelName.contains('clip') ||
        modelName.contains('flava') ||
        modelName.contains('gemma-3n')) {
      return true;
    }

    return false;
  }

  // Helper method to build a feature indicator icon
  Widget _buildFeatureIcon(IconData icon, String tooltip,
      {bool available = true}) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: available ? const Color(0x1A10B981) : const Color(0x1A6B7280),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 12,
          color: available ? const Color(0xFF10B981) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildModelOption(BuildContext context,
      HuggingFaceModelDownloadService service, HFModelInfo model) {
    // Make _isModelDownloaded and _handleModelTap available to the widget
    final isModelDownloaded = _isModelDownloaded;
    final handleModelTap = _handleModelTap;
    final supportsImages = _supportsImages(model);

    // Check if this is the current model by ID, filename, or repo ID
    final isCurrentModel = service.state.status ==
            HFModelDownloadStatus.installed &&
        (service.state.modelInfo?.id == model.id ||
            service.state.modelInfo?.fileName == model.fileName ||
            service.state.modelInfo?.hfRepoId == model.hfRepoId);

    // Use a FutureBuilder to handle the asynchronous isModelDownloaded check
    return FutureBuilder<bool>(
      future: isModelDownloaded(service, model),
      builder: (context, snapshot) {
        final isDownloaded = isCurrentModel || (snapshot.data ?? false);

        return InkWell(
          onTap: () => handleModelTap(context, service, model),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentModel
                  ? const Color(0x1A10B981)
                  : const Color(0x1A3B82F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrentModel
                    ? const Color(0x3310B981)
                    : const Color(0x333B82F6),
              ),
            ),
            child: Row(
              children: [
                isCurrentModel
                    ? const Icon(LucideIcons.checkCircle,
                        color: Color(0xFF10B981), size: 16)
                    : isDownloaded
                        ? const Icon(LucideIcons.check,
                            color: Color(0xFF94A3B8), size: 16)
                        : const Icon(LucideIcons.download,
                            color: Color(0xFF3B82F6), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              model.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Text support indicator (always true for language models)
                          _buildFeatureIcon(
                            Icons.text_fields,
                            'Text input',
                            available: true,
                          ),
                          const SizedBox(width: 4),
                          // Image support indicator (only show if model supports images)
                          if (supportsImages)
                            _buildFeatureIcon(
                              Icons.image_outlined,
                              'Image input',
                              available: true,
                            ),
                        ],
                      ),
                      Text(
                        '${_formatBytes(model.sizeInBytes)} • ${model.hfRepoId.split('/').last}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentModel)
                  const Icon(LucideIcons.info,
                      color: Color(0xFF94A3B8), size: 16)
                else if (isDownloaded)
                  const Icon(LucideIcons.check,
                      color: Color(0xFF94A3B8), size: 16)
                else
                  const Icon(LucideIcons.download,
                      color: Color(0xFF64748B), size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _openChatInterface(BuildContext context, HFModelDownloadState state) {
    if (state.modelInfo == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Model Playground',
                style: TextStyle(color: Colors.white)),
          ),
          body: ModelChatInterface(
            modelName: state.modelInfo!.name,
            modelId: state.modelInfo!.modelId,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context,
      HuggingFaceModelDownloadService service, HFModelDownloadState state) {
    switch (state.status) {
      case HFModelDownloadStatus.notInstalled:
        return ElevatedButton.icon(
          onPressed: service.availableModels.isEmpty
              ? null
              : () {
                  if (service.availableModels.isNotEmpty) {
                    service.downloadModel(service.availableModels.first);
                  }
                },
          icon: const Icon(LucideIcons.download, size: 16),
          label: const Text('Download Model'),
        );
      case HFModelDownloadStatus.preparing:
        return const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Preparing download...',
                style: TextStyle(color: Colors.white70)),
          ],
        );
      case HFModelDownloadStatus.downloading:
        return Column(
          children: [
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 8),
            Text(
              'Downloading: ${(state.progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        );
      case HFModelDownloadStatus.verifying:
        return const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Verifying model...',
                style: TextStyle(color: Colors.white70)),
          ],
        );
      case HFModelDownloadStatus.installed:
        return Row(
          children: [
            const Icon(LucideIcons.checkCircle, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            const Text('Installed', style: TextStyle(color: Colors.green)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _openChatInterface(context, state),
              icon: const Icon(LucideIcons.messageSquare, size: 16),
              label: const Text('Chat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B82F6),
                side: const BorderSide(color: Color(0x333B82F6)),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showRemoveConfirmation(context, service),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      case HFModelDownloadStatus.failed:
        return Column(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.red, size: 16),
            const SizedBox(height: 4),
            Text(
              state.errorMessage ?? 'Download failed',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => service.downloadModel(state.modelInfo!),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
            ),
          ],
        );
      case HFModelDownloadStatus.cancelled:
        return Column(
          children: [
            const Text('Download cancelled',
                style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => service.downloadModel(state.modelInfo!),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
            ),
          ],
        );
    }
  }

  void _showRemoveConfirmation(
      BuildContext context, HuggingFaceModelDownloadService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title:
            const Text('Remove Model?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete the downloaded model from your device. You can download it again later.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              service.removeModel();
            },
            child:
                const Text('Remove', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(HFModelDownloadStatus status) {
    switch (status) {
      case HFModelDownloadStatus.installed:
        return const Icon(LucideIcons.checkCircle,
            color: Color(0xFF10B981), size: 20);
      case HFModelDownloadStatus.downloading:
      case HFModelDownloadStatus.preparing:
      case HFModelDownloadStatus.verifying:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
          ),
        );
      case HFModelDownloadStatus.failed:
        return const Icon(LucideIcons.alertCircle,
            color: Color(0xFFEF4444), size: 20);
      case HFModelDownloadStatus.cancelled:
        return const Icon(LucideIcons.alertTriangle,
            color: Color(0xFFF59E0B), size: 20);
      default:
        return const Icon(LucideIcons.download,
            color: Color(0xFF94A3B8), size: 20);
    }
  }

  Color _getStatusColor(HFModelDownloadStatus status) {
    switch (status) {
      case HFModelDownloadStatus.installed:
        return const Color(0xFF10B981);
      case HFModelDownloadStatus.downloading:
      case HFModelDownloadStatus.preparing:
      case HFModelDownloadStatus.verifying:
        return const Color(0xFF3B82F6);
      case HFModelDownloadStatus.failed:
        return const Color(0xFFEF4444);
      case HFModelDownloadStatus.cancelled:
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _getStatusText(HFModelDownloadStatus status) {
    switch (status) {
      case HFModelDownloadStatus.notInstalled:
        return 'Not installed';
      case HFModelDownloadStatus.preparing:
        return 'Preparing...';
      case HFModelDownloadStatus.downloading:
        return 'Downloading...';
      case HFModelDownloadStatus.verifying:
        return 'Verifying...';
      case HFModelDownloadStatus.installed:
        return 'Installed';
      case HFModelDownloadStatus.failed:
        return 'Download failed';
      case HFModelDownloadStatus.cancelled:
        return 'Download cancelled';
      default:
        return 'Unknown status';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}