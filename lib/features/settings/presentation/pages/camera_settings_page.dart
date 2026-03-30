import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/providers/settings_provider.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_tile.dart';

/// Camera and photo settings page
class CameraSettingsPage extends ConsumerStatefulWidget {
  const CameraSettingsPage({super.key});

  @override
  ConsumerState<CameraSettingsPage> createState() => _CameraSettingsPageState();
}

class _CameraSettingsPageState extends ConsumerState<CameraSettingsPage> {
  // Local state for immediate UI updates
  late TrackingSettings _localSettings;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _localSettings = ref.read(appSettingsProvider).tracking;
      _isInitialized = true;
    }
  }

  Future<void> _saveSettings(TrackingSettings newSettings) async {
    setState(() {
      _localSettings = newSettings;
    });

    await ref.read(appSettingsProvider.notifier).updateTrackingSettings(newSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera settings saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Camera'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: ResponsiveContentBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Photo Quality Section
            SettingsSection(
              title: 'Photo Quality',
              subtitle: 'Configure waypoint photo resolution',
              children: [
                SettingsDropdownTile<PhotoQuality>(
                  leading: const Icon(Icons.high_quality),
                  title: 'Photo Quality',
                  subtitle: _localSettings.photoQuality.description,
                  value: _localSettings.photoQuality,
                  items: PhotoQuality.values
                      .map((quality) => DropdownMenuItem(
                            value: quality,
                            child: Text(quality.displayName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _saveSettings(_localSettings.copyWith(photoQuality: value));
                    }
                  },
                ),
                // Quality explanation
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Higher quality photos take longer to save and use more storage space.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Reset Section
            SettingsSection(
              title: 'Reset',
              subtitle: 'Restore defaults',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.refresh),
                  title: 'Reset to Default',
                  subtitle: 'Restore default camera settings',
                  onTap: () => _resetCameraToDefault(context),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
        ),
      ),
    );
  }

  void _resetCameraToDefault(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Camera Settings'),
        content: const Text(
          'Are you sure you want to reset camera settings to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Only reset photo quality, keep other tracking settings
              _saveSettings(_localSettings.copyWith(photoQuality: PhotoQuality.max));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Camera settings reset to defaults'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
