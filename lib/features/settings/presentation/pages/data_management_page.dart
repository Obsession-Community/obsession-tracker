import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/session_provider.dart';
import 'package:obsession_tracker/core/services/app_backup_service.dart';
import 'package:obsession_tracker/core/services/session_import_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:obsession_tracker/features/sync/presentation/pages/local_sync_page.dart';

/// Data management page for backup, restore, and data export
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({
    super.key,
    this.incomingFilePath,
  });

  /// Optional file path for automatic import (from deep link or file association)
  final String? incomingFilePath;

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  final AppBackupService _backupService = AppBackupService();
  bool _isProcessing = false;
  String? _statusMessage;
  String? _progressPhase;
  double _progressValue = 0.0;
  String? _progressDetail;

  @override
  void initState() {
    super.initState();

    // Handle incoming file if provided (from deep link or file association)
    if (widget.incomingFilePath != null) {
      debugPrint('DataManagement: Received incoming file: ${widget.incomingFilePath}');
      // Process the incoming file after the first frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processIncomingFile(widget.incomingFilePath!);
      });
    }
  }

  /// Process an incoming file from deep link or file association
  Future<void> _processIncomingFile(String filePath) async {
    debugPrint('DataManagement: Processing incoming file: $filePath');

    // Determine file type
    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.obstrack')) {
      await _handleObstrackImport(filePath);
    } else if (lowerPath.endsWith('.obk')) {
      await _handleObkRestore(filePath);
    } else {
      setState(() {
        _statusMessage = 'Error: Unsupported file type. Expected .obstrack or .obk file.';
      });
    }
  }

  /// Handle .obk full backup restore from incoming file
  Future<void> _handleObkRestore(String filePath) async {
    debugPrint('DataManagement: Processing .obk file: $filePath');

    // Ask for password to decrypt
    final password = await _showPasswordDialog(
      title: 'Decrypt Backup',
      message: 'Enter the password used to encrypt this backup.',
    );

    if (password == null) {
      debugPrint('DataManagement: Password dialog cancelled');
      return;
    }

    // Validate and read backup contents with password
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Decrypting backup...';
    });

    final manifest = await _backupService.validateBackup(filePath, password: password);

    setState(() {
      _isProcessing = false;
      _statusMessage = null;
    });

    if (manifest == null) {
      setState(() {
        _statusMessage = 'Error: Invalid password or corrupted backup file';
      });
      return;
    }

    // Extract stats for display
    final stats = manifest['stats'] as Map<String, dynamic>?;
    final huntCount = stats?['huntCount'] ?? 0;
    final sessionCount = stats?['sessionCount'] ?? 0;
    final routeCount = stats?['routeCount'] ?? 0;

    // Show detailed backup contents and get restore mode
    if (!mounted) return;
    final restoreMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This backup file was shared with you.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),

              // Contents summary
              const Text(
                'This backup contains:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildContentRow(Icons.search, '$huntCount treasure hunts'),
              _buildContentRow(Icons.route, '$sessionCount tracking sessions'),
              _buildContentRow(Icons.map, '$routeCount routes'),
              _buildContentRow(Icons.settings, 'App settings'),
              const SizedBox(height: 16),

              // Restore mode selection
              const Text(
                'How would you like to restore?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'merge'),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );

    if (restoreMode == null) return;

    // Continue with restore using the existing logic
    await _performRestore(filePath, password, restoreMode == 'replace');
  }

  /// Perform the actual restore operation
  Future<void> _performRestore(String filePath, String password, bool replaceExisting) async {
    // For replace mode, warn and require safety backup
    if (replaceExisting) {
      if (!mounted) return;
      final safetyConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Warning'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Replace mode will DELETE all your current data before restoring from the backup.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'A safety backup will be created automatically before the restore begins. '
                'If something goes wrong, you can use it to recover your data.',
              ),
              SizedBox(height: 16),
              Text('Do you want to continue?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (safetyConfirmed != true) return;
    }

    // Perform restore with safety backup
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _progressPhase = 'Creating safety backup...';
      _progressValue = 0.0;
      _progressDetail = null;
    });

    String? safetyBackupPath;
    try {
      // Create safety backup
      final safetyResult = await _backupService.createBackup(
        password: password,
        description: 'Safety backup before restore',
        shareAfterCreate: false,
        onProgress: (phase, progress, detail) {
          if (mounted) {
            setState(() {
              _progressPhase = 'Safety backup: $phase';
              _progressValue = progress * 0.2;
              _progressDetail = detail;
            });
          }
        },
      );
      safetyBackupPath = safetyResult.filePath;

      if (!safetyResult.success) {
        setState(() {
          _progressPhase = 'Warning: Could not create safety backup. Proceeding anyway...';
        });
      }

      // Now perform the restore
      final restoreResult = await _backupService.restoreFromBackup(
        filePath,
        password: password,
        options: RestoreOptions(replaceExisting: replaceExisting),
        onProgress: (phase, progress, detail) {
          if (mounted) {
            setState(() {
              _progressPhase = phase;
              _progressValue = 0.2 + (progress * 0.8);
              _progressDetail = detail;
            });
          }
        },
      );

      if (restoreResult.success && restoreResult.stats != null) {
        final restoredStats = restoreResult.stats!;
        var message =
            'Restore completed!\n'
            '${restoredStats.huntCount} hunts, ${restoredStats.sessionCount} sessions, '
            '${restoredStats.routeCount} routes';

        if (restoreResult.warnings.isNotEmpty) {
          message += '\n\nWarnings:\n${restoreResult.warnings.take(3).join('\n')}';
          if (restoreResult.warnings.length > 3) {
            message += '\n...and ${restoreResult.warnings.length - 3} more';
          }
        }

        // Clean up safety backup on success
        if (safetyBackupPath != null) {
          try {
            final safetyFile = File(safetyBackupPath);
            if (safetyFile.existsSync()) {
              await safetyFile.delete();
              debugPrint('Deleted safety backup: $safetyBackupPath');
            }
          } catch (e) {
            debugPrint('Failed to delete safety backup: $e');
          }
        }

        // Clean up Inbox file if this came from iOS share sheet
        await _cleanupInboxFile(filePath);

        setState(() {
          _statusMessage = message;
          _isProcessing = false;
          _progressPhase = null;
          _progressValue = 0.0;
          _progressDetail = null;
        });

        // Show success dialog
        if (mounted) {
          await _showResultDialog(
            isSuccess: true,
            title: 'Restore Successful',
            message: 'Your backup has been restored!',
            details: '${restoredStats.huntCount} hunts\n'
                '${restoredStats.sessionCount} sessions\n'
                '${restoredStats.routeCount} routes',
          );
        }
      } else {
        var errorMessage = 'Error: ${restoreResult.error ?? 'Unknown error'}';
        if (safetyBackupPath != null) {
          errorMessage += '\n\nYour data was backed up before the restore attempt. '
              'You can find the safety backup in your files.';
        }
        setState(() {
          _statusMessage = errorMessage;
          _isProcessing = false;
          _progressPhase = null;
          _progressValue = 0.0;
          _progressDetail = null;
        });

        // Show error dialog
        if (mounted) {
          await _showResultDialog(
            isSuccess: false,
            title: 'Restore Failed',
            message: restoreResult.error ?? 'Unknown error',
            details: safetyBackupPath != null
                ? 'Your data was backed up before the restore attempt. You can find the safety backup in your files.'
                : null,
          );
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isProcessing = false;
        _progressPhase = null;
        _progressValue = 0.0;
        _progressDetail = null;
      });

      // Show error dialog
      if (mounted) {
        await _showResultDialog(
          isSuccess: false,
          title: 'Restore Failed',
          message: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: ResponsiveContentBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backup Section
            SettingsSection(
              title: 'Backup',
              subtitle: 'Create a full backup of all your app data',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.backup),
                  title: 'Create Backup',
                  subtitle: 'Export hunts, sessions, routes, and settings',
                  trailing: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isProcessing ? null : _createBackup,
                ),
              ],
            ),

            // Progress indicator section
            if (_isProcessing && _progressPhase != null) ...[
              const SizedBox(height: 16),
              _buildProgressIndicator(),
            ],

            const SizedBox(height: 24),

            // Restore Section
            SettingsSection(
              title: 'Restore',
              subtitle: 'Restore data from a backup file',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.restore),
                  title: 'Restore from Backup',
                  subtitle: 'Import data from a .obk backup file',
                  trailing: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isProcessing ? null : _showRestoreDialog,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Local Sync Section
            SettingsSection(
              title: 'Local Sync',
              subtitle: 'Transfer data between devices over WiFi',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.wifi_tethering),
                  title: 'Local WiFi Sync',
                  subtitle: 'Send or receive data without cloud services',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const LocalSyncPage(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Backup Info Section
            SettingsSection(
              title: 'About Backups',
              subtitle: 'Information about the backup format',
              children: [
                _buildInfoTile(
                  icon: Icons.inventory_2,
                  title: "What's Included",
                  content:
                      'Treasure hunts (with documents, locations, and cover images), '
                      'tracking sessions (with breadcrumbs and waypoints), '
                      'imported routes, and app settings.',
                ),
                _buildInfoTile(
                  icon: Icons.lock,
                  title: 'Security',
                  content:
                      'Backups are encrypted with AES-256-GCM using your password. '
                      'PBKDF2 key derivation (600,000 iterations) protects against '
                      'brute force attacks. Your data is secure even if the file is stolen.',
                ),
                _buildInfoTile(
                  icon: Icons.folder_zip,
                  title: 'Backup Format',
                  content:
                      'Backups are saved as encrypted .obk files that can be shared '
                      'via AirDrop, email, or cloud storage. You will need your '
                      'password to restore the backup.',
                ),
                _buildInfoTile(
                  icon: Icons.update,
                  title: 'Version Compatibility',
                  content:
                      'Backups include version information to ensure compatibility '
                      'with future app updates. Older backups can always be restored.',
                ),
              ],
            ),

            // Status message
            if (_statusMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusMessage!.contains('Error')
                      ? Colors.red.withValues(alpha: 0.1)
                      : AppTheme.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage!.contains('Error')
                        ? Colors.red.withValues(alpha: 0.3)
                        : AppTheme.gold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage!.contains('Error')
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: _statusMessage!.contains('Error')
                          ? Colors.red
                          : AppTheme.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _statusMessage!.contains('Error')
                              ? Colors.red
                              : AppTheme.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.gold),
      title: Text(title),
      subtitle: Text(
        content,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      isThreeLine: true,
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.gold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _progressPhase ?? 'Processing...',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gold,
                  ),
                ),
              ),
              Text(
                '${(_progressValue * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progressValue,
              backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
              minHeight: 6,
            ),
          ),
          if (_progressDetail != null) ...[
            const SizedBox(height: 8),
            Text(
              _progressDetail!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    // Show password dialog first
    final password = await _showPasswordDialog(
      title: 'Encrypt Backup',
      message: 'Enter a password to protect your backup. '
          'You will need this password to restore the backup.',
      confirmPassword: true,
    );

    if (password == null) return; // User cancelled

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _progressPhase = 'Starting backup...';
      _progressValue = 0.0;
      _progressDetail = null;
    });

    try {
      final result = await _backupService.createBackup(
        password: password,
        onProgress: (phase, progress, detail) {
          if (mounted) {
            setState(() {
              _progressPhase = phase;
              _progressValue = progress;
              _progressDetail = detail;
            });
          }
        },
      );

      if (result.success && result.stats != null) {
        final stats = result.stats!;
        setState(() {
          _statusMessage =
              'Encrypted backup created successfully!\n'
              '${stats.huntCount} hunts, ${stats.sessionCount} sessions, '
              '${stats.routeCount} routes';
        });
      } else {
        setState(() {
          _statusMessage = 'Error: ${result.error ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
        _progressPhase = null;
        _progressValue = 0.0;
        _progressDetail = null;
      });
    }
  }

  Future<void> _showRestoreDialog() async {
    // Step 1: Pick backup file first
    debugPrint('DataManagement: Opening file picker for restore...');
    final result = await FilePicker.platform.pickFiles();

    if (result == null || result.files.isEmpty) {
      debugPrint('DataManagement: File picker cancelled or no files selected');
      return;
    }

    final filePath = result.files.single.path;
    final fileName = result.files.single.name;
    debugPrint('DataManagement: Selected file: $fileName, path: $filePath');

    if (filePath == null) {
      // iOS can return null paths for iCloud files that need downloading
      debugPrint('DataManagement: File path is null (iOS iCloud file?)');
      setState(() {
        _statusMessage = 'Error: Could not access file. If this is an iCloud file, '
            'please download it first or move it to "On My iPhone".';
      });
      return;
    }

    // Validate it's a backup file (case-insensitive for iOS compatibility)
    final lowerPath = filePath.toLowerCase();
    final isObkFile = lowerPath.endsWith('.obk');
    final isObstrackFile = lowerPath.endsWith('.obstrack');

    if (!isObkFile && !isObstrackFile) {
      debugPrint('DataManagement: Invalid file type: $fileName');
      setState(() {
        _statusMessage = 'Error: Please select a .obk (full backup) or .obstrack (session) file';
      });
      return;
    }

    // Route to appropriate handler
    if (isObstrackFile) {
      debugPrint('DataManagement: Detected .obstrack file, redirecting to session import...');
      await _handleObstrackImport(filePath);
      return;
    }

    debugPrint('DataManagement: Proceeding with .obk full backup restore...');

    // Step 2: Ask for password to decrypt
    final password = await _showPasswordDialog(
      title: 'Decrypt Backup',
      message: 'Enter the password used to encrypt this backup.',
    );

    if (password == null) return; // User cancelled

    // Step 3: Validate and read backup contents with password
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Decrypting backup...';
    });

    final manifest = await _backupService.validateBackup(filePath, password: password);

    setState(() {
      _isProcessing = false;
      _statusMessage = null;
    });

    if (manifest == null) {
      setState(() {
        _statusMessage = 'Error: Invalid password or corrupted backup file';
      });
      return;
    }

    // Extract stats for display
    final stats = manifest['stats'] as Map<String, dynamic>?;
    final huntCount = stats?['huntCount'] ?? 0;
    final sessionCount = stats?['sessionCount'] ?? 0;
    final routeCount = stats?['routeCount'] ?? 0;

    // Step 3: Show detailed backup contents and get restore mode
    if (!mounted) return;
    final restoreMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Contents'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backup info
              Text(
                'Created: ${_formatDate(manifest['createdAt'] as String?)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (manifest['description'] != null)
                Text('Description: ${manifest['description']}'),
              const SizedBox(height: 16),

              // Contents summary
              const Text(
                'This backup contains:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildContentRow(Icons.search, '$huntCount treasure hunts'),
              _buildContentRow(Icons.route, '$sessionCount tracking sessions'),
              _buildContentRow(Icons.map, '$routeCount routes'),
              _buildContentRow(Icons.settings, 'App settings'),
              const SizedBox(height: 16),

              // Restore mode selection
              const Text(
                'How would you like to restore?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'merge'),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );

    if (restoreMode == null) return;
    final replaceExisting = restoreMode == 'replace';

    // Step 4: For replace mode, warn and require safety backup
    if (replaceExisting) {
      if (!mounted) return;
      final safetyConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text('Warning'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Replace mode will DELETE all your current data before restoring from the backup.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'A safety backup will be created automatically before the restore begins. '
                'If something goes wrong, you can use it to recover your data.',
              ),
              SizedBox(height: 16),
              Text('Do you want to continue?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (safetyConfirmed != true) return;
    }

    // Step 5: Perform restore with safety backup
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _progressPhase = 'Creating safety backup...';
      _progressValue = 0.0;
      _progressDetail = null;
    });

    String? safetyBackupPath;
    try {
      // Create safety backup (without sharing) - use the same password for convenience
      final safetyResult = await _backupService.createBackup(
        password: password,
        description: 'Safety backup before restore',
        shareAfterCreate: false,
        onProgress: (phase, progress, detail) {
          if (mounted) {
            setState(() {
              _progressPhase = 'Safety backup: $phase';
              _progressValue = progress * 0.2; // Safety backup is 20% of total
              _progressDetail = detail;
            });
          }
        },
      );
      safetyBackupPath = safetyResult.filePath;

      if (!safetyResult.success) {
        setState(() {
          _progressPhase = 'Warning: Could not create safety backup. Proceeding anyway...';
        });
      }

      // Now perform the restore
      final restoreResult = await _backupService.restoreFromBackup(
        filePath,
        password: password,
        options: RestoreOptions(replaceExisting: replaceExisting),
        onProgress: (phase, progress, detail) {
          if (mounted) {
            setState(() {
              _progressPhase = phase;
              _progressValue = 0.2 + (progress * 0.8); // Restore is 80% of total
              _progressDetail = detail;
            });
          }
        },
      );

      if (restoreResult.success && restoreResult.stats != null) {
        final restoredStats = restoreResult.stats!;
        var message =
            'Restore completed!\n'
            '${restoredStats.huntCount} hunts, ${restoredStats.sessionCount} sessions, '
            '${restoredStats.routeCount} routes';

        if (restoreResult.warnings.isNotEmpty) {
          message += '\n\nWarnings:\n${restoreResult.warnings.take(3).join('\n')}';
          if (restoreResult.warnings.length > 3) {
            message += '\n...and ${restoreResult.warnings.length - 3} more';
          }
        }

        // Clean up safety backup on success (no longer needed)
        if (safetyBackupPath != null) {
          try {
            final safetyFile = File(safetyBackupPath);
            if (safetyFile.existsSync()) {
              await safetyFile.delete();
              debugPrint('Deleted safety backup: $safetyBackupPath');
            }
          } catch (e) {
            debugPrint('Failed to delete safety backup: $e');
            // Non-critical, don't show to user
          }
        }

        setState(() {
          _statusMessage = message;
        });
      } else {
        // Restore failed - inform user about safety backup
        var errorMessage = 'Error: ${restoreResult.error ?? 'Unknown error'}';
        if (safetyBackupPath != null) {
          errorMessage += '\n\nYour data was backed up before the restore attempt. '
              'You can find the safety backup in your files.';
        }
        setState(() {
          _statusMessage = errorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
        _progressPhase = null;
        _progressValue = 0.0;
        _progressDetail = null;
      });
    }
  }

  Widget _buildContentRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.gold),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  /// Handle import of .obstrack session files
  ///
  /// Shows password dialog, imports the session, and displays results
  Future<void> _handleObstrackImport(String filePath) async {
    // Ask for password to decrypt
    final password = await _showPasswordDialog(
      title: 'Decrypt Session',
      message: 'Enter the password used when exporting this session.',
    );

    if (password == null) {
      debugPrint('DataManagement: Password dialog cancelled');
      return;
    }

    // Show progress indicator
    setState(() {
      _isProcessing = true;
      _progressPhase = 'Importing session...';
      _progressValue = 0.0;
      _statusMessage = null;
    });

    try {
      final importService = SessionImportService();

      // Update progress
      setState(() {
        _progressPhase = 'Decrypting file...';
        _progressValue = 0.2;
      });

      final result = await importService.importSession(
        obstrackFilePath: filePath,
        password: password,
      );

      setState(() {
        _progressPhase = 'Finalizing...';
        _progressValue = 0.9;
      });

      if (result.success) {
        // Refresh sessions list
        await ref.read(sessionProvider.notifier).refresh();

        // Clean up Inbox file if this came from iOS share sheet
        await _cleanupInboxFile(filePath);

        setState(() {
          _isProcessing = false;
          _progressPhase = null;
          _progressValue = 0.0;
          _statusMessage = 'Session imported successfully!\n'
              '${result.counts?['breadcrumbs'] ?? 0} breadcrumbs, '
              '${result.counts?['waypoints'] ?? 0} waypoints, '
              '${result.counts?['custom_markers'] ?? 0} markers';
        });

        debugPrint('DataManagement: Session import successful');

        // Show success dialog
        if (mounted) {
          await _showResultDialog(
            isSuccess: true,
            title: 'Import Successful',
            message: 'Session imported successfully!',
            details: '${result.counts?['breadcrumbs'] ?? 0} breadcrumbs\n'
                '${result.counts?['waypoints'] ?? 0} waypoints\n'
                '${result.counts?['photo_waypoints'] ?? 0} photos\n'
                '${result.counts?['custom_markers'] ?? 0} markers',
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
          _progressPhase = null;
          _progressValue = 0.0;
          _statusMessage = 'Error: ${result.errorMessage ?? 'Import failed'}';
        });

        debugPrint('DataManagement: Session import failed: ${result.errorMessage}');

        // Show error dialog
        if (mounted) {
          await _showResultDialog(
            isSuccess: false,
            title: 'Import Failed',
            message: result.errorMessage ?? 'Unknown error occurred',
          );
        }
      }
    } catch (e, stack) {
      debugPrint('DataManagement: Session import exception: $e');
      debugPrint('Stack: $stack');

      setState(() {
        _isProcessing = false;
        _progressPhase = null;
        _progressValue = 0.0;
        _statusMessage = 'Error: $e';
      });

      // Show error dialog
      if (mounted) {
        await _showResultDialog(
          isSuccess: false,
          title: 'Import Failed',
          message: e.toString(),
        );
      }
    }
  }

  /// Show a result dialog for import/restore operations
  Future<void> _showResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
    String? details,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  details,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Clean up a file after successful import
  ///
  /// Handles cleanup of:
  /// - iOS: tmp/imports/ directory (copied from iCloud/external sources)
  /// - iOS: Documents/Inbox/ directory (shared via share sheet)
  /// - Android: cache/imports/ directory (copied from Google Drive, etc.)
  ///
  /// After successful import, we delete the temp file to avoid re-importing.
  Future<void> _cleanupInboxFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('DataManagement: File already cleaned up: $filePath');
        return;
      }

      // Check if this is a temp import file that should be cleaned up
      // iOS: /tmp/imports/ or /Documents/Inbox/
      // Android: /cache/imports/
      final shouldCleanup = filePath.contains('/imports/') ||
          filePath.contains('/Inbox/');

      if (shouldCleanup) {
        await file.delete();
        debugPrint('DataManagement: Cleaned up import file: $filePath');
      } else {
        debugPrint('DataManagement: Skipping cleanup for non-temp file: $filePath');
      }
    } catch (e) {
      debugPrint('DataManagement: Error cleaning up import file: $e');
      // Don't throw - cleanup failure shouldn't affect the import result
    }
  }

  /// Show a password dialog for backup encryption/decryption
  ///
  /// [title] - Dialog title
  /// [message] - Instructional message
  /// [confirmPassword] - If true, shows a confirm password field
  ///
  /// Returns the password if entered, null if cancelled
  Future<String?> _showPasswordDialog({
    required String title,
    required String message,
    bool confirmPassword = false,
  }) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscurePassword = true;
    var obscureConfirm = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password (min 8 characters)',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () => setDialogState(() {
                          obscurePassword = !obscurePassword;
                        }),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  if (confirmPassword) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter password',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setDialogState(() {
                            obscureConfirm = !obscureConfirm;
                          }),
                        ),
                      ),
                      validator: (value) {
                        if (value != passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, passwordController.text);
                }
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
