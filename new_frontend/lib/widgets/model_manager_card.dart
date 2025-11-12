import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/model_download_service.dart';
import 'glass_card.dart';

class ModelManagerCard extends StatelessWidget {
  const ModelManagerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ModelDownloadService()..checkInstalledModel(),
      child: const _ModelManagerCardContent(),
    );
  }
}

class _ModelManagerCardContent extends StatelessWidget {
  const _ModelManagerCardContent();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ModelDownloadService>();
    final state = service.state;

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
                    colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
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
                      'On-Device AI Model',
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
              _buildStatusIcon(state.status),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar (only show when downloading)
          if (state.status == ModelDownloadStatus.downloading || 
              state.status == ModelDownloadStatus.verifying)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.status == ModelDownloadStatus.verifying 
                        ? null 
                        : state.progress,
                    backgroundColor: const Color(0xFF1E293B),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.status == ModelDownloadStatus.verifying
                      ? 'Verifying SHA256...'
                      : '${(state.progress * 100).toStringAsFixed(0)}% • ${_formatBytes(state.bytesDownloaded)}${state.totalBytes != null ? ' / ${_formatBytes(state.totalBytes!)}' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),

          // Model info (when installed)
          if (state.status == ModelDownloadStatus.installed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Model', state.modelName ?? 'Unknown'),
                const SizedBox(height: 6),
                _buildInfoRow('Size', _formatBytes(state.bytesDownloaded)),
                const SizedBox(height: 6),
                if (state.sha256 != null)
                  _buildInfoRow('SHA256', '${state.sha256!.substring(0, 12)}...'),
                if (state.installedAt != null) ...[
                  const SizedBox(height: 6),
                  _buildInfoRow('Installed', _formatDate(state.installedAt!)),
                ],
                const SizedBox(height: 12),
              ],
            ),

          // Error message
          if (state.status == ModelDownloadStatus.failed)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          state.errorMessage ?? 'Download failed',
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

  Widget _buildActionButtons(BuildContext context, ModelDownloadService service, ModelDownloadState state) {
    switch (state.status) {
      case ModelDownloadStatus.notInstalled:
      case ModelDownloadStatus.failed:
      case ModelDownloadStatus.cancelled:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => service.downloadModel(),
                icon: const Icon(LucideIcons.download, size: 16),
                label: Text(state.status == ModelDownloadStatus.failed ? 'Retry Download' : 'Download Model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA855F7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );

      case ModelDownloadStatus.downloading:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => service.cancelDownload(),
                icon: const Icon(LucideIcons.x, size: 16),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );

      case ModelDownloadStatus.verifying:
        return const SizedBox(
          height: 40,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
              strokeWidth: 2,
            ),
          ),
        );

      case ModelDownloadStatus.installed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRemoveConfirmation(context, service),
                icon: const Icon(LucideIcons.trash2, size: 16),
                label: const Text('Remove Model'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0x33EF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  void _showRemoveConfirmation(BuildContext context, ModelDownloadService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Remove Model?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete the downloaded model from your device. You can download it again later.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              service.removeModel();
            },
            child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ModelDownloadStatus status) {
    switch (status) {
      case ModelDownloadStatus.installed:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0x1A10B981),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(LucideIcons.checkCircle, color: Color(0xFF10B981), size: 16),
        );
      case ModelDownloadStatus.downloading:
      case ModelDownloadStatus.verifying:
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
          ),
        );
      case ModelDownloadStatus.failed:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0x1AEF4444),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(LucideIcons.xCircle, color: Color(0xFFEF4444), size: 16),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0x1A64748B),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(LucideIcons.download, color: Color(0xFF64748B), size: 16),
        );
    }
  }

  String _getStatusText(ModelDownloadStatus status) {
    switch (status) {
      case ModelDownloadStatus.notInstalled:
        return 'Not installed • Using cloud fallback';
      case ModelDownloadStatus.downloading:
        return 'Downloading...';
      case ModelDownloadStatus.verifying:
        return 'Verifying integrity...';
      case ModelDownloadStatus.installed:
        return 'Installed • Ready for use';
      case ModelDownloadStatus.failed:
        return 'Download failed';
      case ModelDownloadStatus.cancelled:
        return 'Download cancelled';
    }
  }

  Color _getStatusColor(ModelDownloadStatus status) {
    switch (status) {
      case ModelDownloadStatus.installed:
        return const Color(0xFF10B981);
      case ModelDownloadStatus.downloading:
      case ModelDownloadStatus.verifying:
        return const Color(0xFFA855F7);
      case ModelDownloadStatus.failed:
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
