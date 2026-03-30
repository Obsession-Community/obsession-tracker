import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/providers/settings_provider.dart';
import 'package:obsession_tracker/core/providers/theme_provider.dart';
import 'package:obsession_tracker/core/utils/coordinate_formatter.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:obsession_tracker/features/settings/presentation/widgets/settings_tile.dart';

/// General application settings page
class GeneralSettingsPage extends ConsumerStatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  ConsumerState<GeneralSettingsPage> createState() =>
      _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends ConsumerState<GeneralSettingsPage> {
  // Local state for immediate UI updates
  late GeneralSettings _localSettings;
  bool _isInitialized = false;

  // Dev data toggle state (debug builds only)
  bool _useDevData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _localSettings = ref.read(appSettingsProvider).general;
      _useDevData = BFFConfig.useDevData;
      _isInitialized = true;
    }
  }

  Future<void> _saveSettings(GeneralSettings newSettings) async {
    setState(() {
      _localSettings = newSettings;
    });

    // Save to the proper settings provider (which persists to JSON file)
    await ref.read(appSettingsProvider.notifier).updateGeneralSettings(newSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
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
          title: const Text('General Settings'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('General Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: ResponsiveContentBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            SettingsSection(
              title: 'Appearance',
              subtitle: 'Theme and visual preferences',
              children: [
                SettingsDropdownTile<ThemeMode>(
                  leading: const Icon(Icons.brightness_6),
                  title: 'Theme Mode',
                  subtitle: 'Choose light, dark, or system theme',
                  value: ref.watch(themeModeProvider),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(value);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Units & Formats Section
            SettingsSection(
              title: 'Units & Formats',
              subtitle: 'Measurement units and display formats',
              children: [
                SettingsDropdownTile<MeasurementUnits>(
                  leading: const Icon(Icons.straighten),
                  title: 'Measurement Units',
                  subtitle: 'Units for distance, speed, and elevation',
                  value: _localSettings.units,
                  items: MeasurementUnits.values
                      .map((unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(unit.displayName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _saveSettings(_localSettings.copyWith(units: value));
                    }
                  },
                ),
                SettingsDropdownTile<TimeFormat>(
                  leading: const Icon(Icons.access_time),
                  title: 'Time Format',
                  subtitle: 'Format for displaying time',
                  value: _localSettings.timeFormat,
                  items: TimeFormat.values
                      .map((format) => DropdownMenuItem(
                            value: format,
                            child: Text(format.displayName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _saveSettings(_localSettings.copyWith(timeFormat: value));
                    }
                  },
                ),
                SettingsDropdownTile<CoordinateFormat>(
                  leading: const Icon(Icons.location_on),
                  title: 'Coordinate Format',
                  subtitle: 'How GPS coordinates are displayed',
                  value: _localSettings.coordinateFormat,
                  items: CoordinateFormat.values
                      .map((format) => DropdownMenuItem(
                            value: format,
                            child: Text(format.displayName),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _saveSettings(_localSettings.copyWith(coordinateFormat: value));
                    }
                  },
                ),
                // Live preview of coordinate format
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
                          Icons.preview,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Example',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CoordinateFormatter.formatPair(
                                  43.879215,
                                  -103.459825,
                                  _localSettings.coordinateFormat,
                                ),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Developer Section (Debug builds only)
            if (kDebugMode) ...[
              SettingsSection(
                title: 'Developer',
                subtitle: 'Debug settings (visible in debug builds only)',
                children: [
                  SettingsSwitchTile(
                    leading: const Icon(Icons.science),
                    title: 'Use Dev Land Data',
                    subtitle: 'Download from dev/ prefix in R2 for testing unreleased data fixes',
                    value: _useDevData,
                    onChanged: (value) async {
                      setState(() {
                        _useDevData = value;
                      });
                      await BFFConfig.setUseDevData(value);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              value
                                  ? 'Dev data enabled - delete existing state data and re-download to test'
                                  : 'Dev data disabled - using production data',
                            ),
                            backgroundColor: value ? Colors.orange : Colors.green,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Reset Section
            SettingsSection(
              title: 'Reset',
              subtitle: 'Reset general settings',
              children: [
                SettingsTile(
                  leading: const Icon(Icons.refresh),
                  title: 'Reset to Default',
                  subtitle: 'Restore default general settings',
                  onTap: () => _resetGeneralToDefault(context),
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

  void _resetGeneralToDefault(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset General Settings'),
        content: const Text(
          'Are you sure you want to reset all general settings to their default values?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveSettings(const GeneralSettings());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('General settings reset to defaults'),
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
