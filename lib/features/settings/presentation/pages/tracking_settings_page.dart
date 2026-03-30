import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/providers/settings_provider.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_tile.dart';

/// GPS tracking and navigation settings page
class TrackingSettingsPage extends ConsumerStatefulWidget {
  const TrackingSettingsPage({super.key});

  @override
  ConsumerState<TrackingSettingsPage> createState() =>
      _TrackingSettingsPageState();
}

class _TrackingSettingsPageState extends ConsumerState<TrackingSettingsPage> {
  // Local state for immediate UI updates
  late TrackingSettings _localSettings;
  bool _isInitialized = false;

  // Debounce timer for slider changes
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    // Will initialize from provider in didChangeDependencies
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _localSettings = ref.read(appSettingsProvider).tracking;
      _isInitialized = true;
    }
  }

  /// Save settings immediately (for non-slider changes)
  Future<void> _saveSettings(TrackingSettings newSettings) async {
    setState(() {
      _localSettings = newSettings;
    });

    // Save to the proper settings provider (which persists to JSON file)
    await ref.read(appSettingsProvider.notifier).updateTrackingSettings(newSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tracking settings saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// Update local state immediately but debounce the actual save
  /// Used for sliders where we want responsive UI but don't want to
  /// save on every tiny change
  void _updateSettingsDebounced(TrackingSettings newSettings) {
    // Update UI immediately for responsiveness
    setState(() {
      _localSettings = newSettings;
    });

    // Cancel any pending save
    _debounceTimer?.cancel();

    // Schedule a new save after the debounce period
    _debounceTimer = Timer(_debounceDuration, () async {
      await ref.read(appSettingsProvider.notifier).updateTrackingSettings(newSettings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tracking settings saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  /// Format distance threshold respecting user's imperial/metric preference
  String _formatDistanceThreshold(double meters) {
    final i18n = InternationalizationService();
    final feet = meters * 3.28084;

    if (i18n.measurementSystem == 'imperial') {
      // Imperial: show feet as primary, meters in parentheses
      return '${feet.toStringAsFixed(0)} ft (~${meters.toStringAsFixed(0)}m)';
    } else {
      // Metric: show meters as primary, feet in parentheses
      return '${meters.toStringAsFixed(0)}m (~${feet.toStringAsFixed(0)}ft)';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('GPS Tracking'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS Tracking'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: ResponsiveContentBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // GPS Accuracy & Mode Section
            SettingsSection(
              title: 'GPS Settings',
              subtitle: 'Control GPS precision and battery usage',
              children: [
                SettingsSliderTile(
                  leading: const Icon(Icons.gps_fixed),
                  title: 'Distance Threshold',
                  subtitle:
                      'Minimum distance before recording a new breadcrumb',
                  value: _localSettings.minDistanceFilter,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: _formatDistanceThreshold(_localSettings.minDistanceFilter),
                  onChanged: (value) {
                    // Use debounced update for slider - responsive UI but saves only after user stops sliding
                    _updateSettingsDebounced(_localSettings.copyWith(minDistanceFilter: value));
                  },
                ),
                SettingsDropdownTile<GpsMode>(
                  leading: const Icon(Icons.settings_suggest),
                  title: 'GPS Mode',
                  subtitle: 'Balance between accuracy and battery life',
                  value: _localSettings.gpsMode,
                  items: GpsMode.values
                      .map((mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(mode.displayName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _saveSettings(_localSettings.copyWith(gpsMode: value));
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Help Section
            SettingsSection(
              title: 'Help',
              subtitle: 'Tips for better tracking',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.help_outline),
                  title: 'Tracking Tips',
                  subtitle: 'Learn how to improve tracking accuracy',
                  onTap: () => _showTrackingTips(context),
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
                  subtitle: 'Restore default tracking settings',
                  onTap: () => _resetTrackingToDefault(context),
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

  void _showTrackingTips(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tracking Tips'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Background Tracking:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                  '• Set location permission to "Always" in device settings'),
              SizedBox(height: 8),
              Text('• Disable battery optimization for Obsession Tracker'),
              SizedBox(height: 8),
              Text('• This allows tracking with your phone in your pocket'),
              SizedBox(height: 16),
              Text(
                'For Best Accuracy:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Keep device in an open area with clear sky view'),
              SizedBox(height: 8),
              Text('• Wait for GPS to stabilize before starting'),
              SizedBox(height: 8),
              Text('• Dense forests and canyons reduce accuracy'),
              SizedBox(height: 16),
              Text(
                'Battery Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Use "Balanced" GPS mode for most adventures'),
              SizedBox(height: 8),
              Text('• Lower distance threshold = more detailed trail'),
              SizedBox(height: 8),
              Text('• Higher distance threshold = better battery life'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _resetTrackingToDefault(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Tracking Settings'),
        content: const Text(
          'Are you sure you want to reset all tracking settings to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveSettings(const TrackingSettings());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tracking settings reset to defaults'),
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
