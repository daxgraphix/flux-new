import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../flux_engine/recording_service.dart';

class RecordingsManagerWidget extends StatefulWidget {
  const RecordingsManagerWidget({super.key});

  @override
  State<RecordingsManagerWidget> createState() =>
      _RecordingsManagerWidgetState();
}

class _RecordingsManagerWidgetState extends State<RecordingsManagerWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecordingService>().loadSavedRecordings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingService>(
      builder: (context, recordingService, child) {
        final theme = Theme.of(context);
        final textColor = theme.colorScheme.onSurface;
        final primaryColor = theme.colorScheme.primary;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECORDINGS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      '${recordingService.savedRecordings.length} FILES',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (recordingService.savedRecordings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.mic_off_rounded,
                          size: 40,
                          color: textColor.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'NO RECORDINGS YET',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: textColor.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recordingService.savedRecordings.length,
                  itemBuilder: (context, index) {
                    final recordingPath = recordingService.savedRecordings[index];
                    final file = File(recordingPath);
                    final filename = file.path.split('/').last;
                    final size = file.lengthSync();
                    final sizeStr = _formatBytes(size);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mic_rounded, color: Colors.red, size: 20),
                        ),
                        title: Text(
                          filename.toUpperCase(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          sizeStr.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: textColor.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          iconColor: textColor.withValues(alpha: 0.4),
                          onSelected: (value) async {
                            if (value == 'share') {
                              await _shareRecording(recordingPath);
                            } else if (value == 'export') {
                              await _exportRecording(recordingPath);
                            } else if (value == 'delete') {
                              await _deleteRecording(recordingService, recordingPath);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 12),
                                  const Text('SHARE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.download_rounded, size: 18, color: Colors.green),
                                  const SizedBox(width: 12),
                                  const Text('EXPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                                  const SizedBox(width: 12),
                                  Text('DELETE', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w900, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording location: $path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportRecording(String path) async {
    try {
      final filename = path.split('/').last;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording saved: $filename'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => _shareRecording(path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRecording(RecordingService service, String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recording?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await service.deleteRecording(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Recording deleted'
                  : 'Failed to delete recording',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
