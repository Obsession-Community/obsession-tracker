import 'dart:io';

import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/session_export_service.dart';
import 'package:obsession_tracker/core/services/session_gpx_export_service.dart';
import 'package:obsession_tracker/core/widgets/password_dialog.dart';
import 'package:share_plus/share_plus.dart';

/// Bottom sheet showing export options for a session
class SessionExportMenu {
  /// Show export options for a session
  static Future<void> show(BuildContext context, TrackingSession session) async {
    final navigator = Navigator.of(context);

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => _SessionExportBottomSheet(session: session),
    );

    // User selected an export option
    if (result == 'obstrack') {
      await _exportCompleteSession(navigator, session);
    } else if (result == 'gpx') {
      await _exportGpx(navigator, session);
    }
  }

  static Future<void> _exportCompleteSession(
    NavigatorState navigator,
    TrackingSession session,
  ) async {
    final context = navigator.context;

    // Show password dialog
    final password = await PasswordDialog.showExportDialog(context);
    if (password == null) return; // User cancelled

    // Show loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Export session
      final exportService = SessionExportService();
      final result = await exportService.exportSession(
        sessionId: session.id,
        password: password,
      );

      // Dismiss loading
      navigator.pop();

      if (result.success) {
        // Show success and share options
        _showExportSuccess(
          navigator,
          session: session,
          filePath: result.filePath!,
          fileSize: result.fileSize!,
          format: '.obstrack',
          encrypted: true,
        );
      } else {
        _showExportError(navigator, result.errorMessage!);
      }
    } catch (e) {
      // Dismiss loading
      navigator.pop();
      _showExportError(navigator, e.toString());
    }
  }

  static Future<void> _exportGpx(
    NavigatorState navigator,
    TrackingSession session,
  ) async {
    final context = navigator.context;

    // Show loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Export GPX
      final exportService = SessionGpxExportService();
      final result = await exportService.exportSession(
        sessionId: session.id,
      );

      // Dismiss loading
      navigator.pop();

      if (result.success) {
        // Show success and share options
        _showExportSuccess(
          navigator,
          session: session,
          filePath: result.filePath!,
          fileSize: result.fileSize!,
          format: 'GPX',
          encrypted: false,
        );
      } else {
        _showExportError(navigator, result.errorMessage!);
      }
    } catch (e) {
      // Dismiss loading
      navigator.pop();
      _showExportError(navigator, e.toString());
    }
  }

  static Future<void> _showExportSuccess(
    NavigatorState navigator, {
    required TrackingSession session,
    required String filePath,
    required int fileSize,
    required String format,
    required bool encrypted,
  }) async {
    final context = navigator.context;
    final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);

    // Show dialog and get result - true if user wants to share
    final shouldShare = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Export Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Format: $format'),
            Text('Size: $fileSizeMB MB'),
            if (encrypted) const Text('Encryption: AES-256'),
            const SizedBox(height: 8),
            Text(
              'Tap Share to save or send the file.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );

    // If user chose to share, do it now BEFORE cleanup
    if (shouldShare == true) {
      try {
        // Extract filename from path for explicit naming in share
        final filename = filePath.split('/').last;
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                filePath,
                name: filename,
                mimeType: 'application/octet-stream',
              ),
            ],
            subject: 'Obsession Tracker - ${session.name}',
          ),
        );
      } catch (e) {
        debugPrint('⚠️ Share failed: $e');
      }
    }

    // Clean up: delete the temporary export file after share completes
    await _deleteExportFile(filePath);
  }

  /// Delete the temporary export file to prevent storage bloat
  static Future<void> _deleteExportFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🧹 Cleaned up export file: $filePath');
      }
    } catch (e) {
      // Don't throw - cleanup failure shouldn't impact user experience
      debugPrint('⚠️ Failed to clean up export file: $e');
    }
  }

  static void _showExportError(NavigatorState navigator, String error) {
    showDialog<void>(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 12),
            Text('Export Failed'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _SessionExportBottomSheet extends StatelessWidget {
  final TrackingSession session;

  const _SessionExportBottomSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Icon(Icons.share, color: theme.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    'Export Session',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                session.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 24),

            // Export Complete Session (.obstrack)
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Export Complete Session'),
              subtitle: const Text(
                'Encrypted backup with photos, tracks, and waypoints\nPassword protected • .obstrack format',
              ),
              onTap: () => Navigator.pop(context, 'obstrack'),
            ),

            // Export Track Only (GPX)
            ListTile(
              leading: const Icon(Icons.route),
              title: const Text('Export Track (GPX)'),
              subtitle: const Text(
                'GPS track for Gaia, AllTrails, Garmin, etc.\nNo encryption • Standard GPX format',
              ),
              onTap: () => Navigator.pop(context, 'gpx'),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
