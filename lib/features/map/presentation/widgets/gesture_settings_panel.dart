import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/map_gesture_settings.dart';
import 'package:obsession_tracker/core/providers/map_gesture_provider.dart';

/// Settings panel for map gesture configuration
class GestureSettingsPanel extends ConsumerWidget {
  const GestureSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(mapGestureSettingsProvider);
    final notifier = ref.read(mapGestureProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.touch_app, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gesture Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Rotation Lock Toggle
            SwitchListTile(
              title: const Text('Lock Rotation'),
              subtitle: const Text('Disable map rotation completely'),
              value: settings.rotationLockEnabled,
              onChanged: (value) {
                notifier.updateSettings(
                  settings.copyWith(rotationLockEnabled: value),
                );
              },
              secondary: Icon(
                settings.rotationLockEnabled ? Icons.lock : Icons.lock_open,
                color: settings.rotationLockEnabled ? Colors.red : Colors.green,
              ),
            ),

            // Rotation Sensitivity
            if (!settings.rotationLockEnabled) ...[
              const Divider(),
              ListTile(
                title: const Text('Rotation Sensitivity'),
                subtitle: Text(settings.rotationSensitivity.description),
                trailing: DropdownButton<RotationSensitivity>(
                  value: settings.rotationSensitivity,
                  onChanged: (value) {
                    if (value != null) {
                      notifier.setRotationSensitivity(value);
                    }
                  },
                  items: RotationSensitivity.values
                      .map((sensitivity) => DropdownMenuItem(
                            value: sensitivity,
                            child: Text(sensitivity.displayName),
                          ))
                      .toList(),
                ),
              ),
            ],

            const Divider(),

            // Zoom Priority
            SwitchListTile(
              title: const Text('Zoom Priority'),
              subtitle: const Text(
                  'Prioritize zoom over rotation when both detected'),
              value: settings.zoomPriorityEnabled,
              onChanged: settings.rotationLockEnabled
                  ? null
                  : (value) {
                      notifier.updateSettings(
                        settings.copyWith(zoomPriorityEnabled: value),
                      );
                    },
              secondary: const Icon(Icons.zoom_in),
            ),

            const Divider(),

            // Visual Indicators
            SwitchListTile(
              title: const Text('Show Gesture Indicators'),
              subtitle:
                  const Text('Display visual feedback for active gestures'),
              value: settings.showGestureIndicators,
              onChanged: (value) {
                notifier.updateSettings(
                  settings.copyWith(showGestureIndicators: value),
                );
              },
              secondary: const Icon(Icons.visibility),
            ),

            // Haptic Feedback
            SwitchListTile(
              title: const Text('Haptic Feedback'),
              subtitle: const Text('Vibrate when gesture state changes'),
              value: settings.hapticFeedbackEnabled,
              onChanged: (value) {
                notifier.updateSettings(
                  settings.copyWith(hapticFeedbackEnabled: value),
                );
              },
              secondary: const Icon(Icons.vibration),
            ),

            const SizedBox(height: 16),

            // Advanced Settings Expander
            ExpansionTile(
              title: const Text('Advanced Settings'),
              leading: const Icon(Icons.tune),
              children: [
                // Rotation Threshold Slider
                if (!settings.rotationLockEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rotation Threshold: ${settings.rotationThreshold.toInt()}°',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: settings.rotationThreshold,
                          min: 5.0,
                          max: 45.0,
                          divisions: 8,
                          label: '${settings.rotationThreshold.toInt()}°',
                          onChanged: (value) {
                            notifier.updateSettings(
                              settings.copyWith(rotationThreshold: value),
                            );
                          },
                        ),
                        const Text(
                          'Minimum rotation angle before rotation is considered intentional',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Simultaneous Gesture Threshold
                if (!settings.rotationLockEnabled &&
                    settings.zoomPriorityEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zoom Priority Threshold: ${(settings.simultaneousGestureThreshold * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: settings.simultaneousGestureThreshold,
                          min: 0.1,
                          divisions: 9,
                          label:
                              '${(settings.simultaneousGestureThreshold * 100).toInt()}%',
                          onChanged: (value) {
                            notifier.updateSettings(
                              settings.copyWith(
                                  simultaneousGestureThreshold: value),
                            );
                          },
                        ),
                        const Text(
                          'How easily zoom takes priority over rotation',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Reset to Defaults Button
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  notifier.updateSettings(const MapGestureSettings());
                },
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Defaults'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact gesture settings for toolbar use
class CompactGestureSettings extends ConsumerWidget {
  const CompactGestureSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(mapGestureSettingsProvider);
    final notifier = ref.read(mapGestureProvider.notifier);

    return PopupMenuButton<String>(
      icon: Icon(
        settings.rotationLockEnabled ? Icons.lock : Icons.touch_app,
        color: settings.rotationLockEnabled ? Colors.red : null,
      ),
      tooltip: 'Gesture Settings',
      onSelected: (value) {
        switch (value) {
          case 'toggle_lock':
            notifier.toggleRotationLock();
            break;
          case 'sensitivity_low':
            notifier.setRotationSensitivity(RotationSensitivity.low);
            break;
          case 'sensitivity_medium':
            notifier.setRotationSensitivity(RotationSensitivity.medium);
            break;
          case 'sensitivity_high':
            notifier.setRotationSensitivity(RotationSensitivity.high);
            break;
          case 'toggle_zoom_priority':
            notifier.updateSettings(
              settings.copyWith(
                  zoomPriorityEnabled: !settings.zoomPriorityEnabled),
            );
            break;
          case 'toggle_indicators':
            notifier.updateSettings(
              settings.copyWith(
                  showGestureIndicators: !settings.showGestureIndicators),
            );
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'toggle_lock',
          child: ListTile(
            leading: Icon(
              settings.rotationLockEnabled ? Icons.lock_open : Icons.lock,
              size: 20,
            ),
            title: Text(
              settings.rotationLockEnabled
                  ? 'Unlock Rotation'
                  : 'Lock Rotation',
            ),
            dense: true,
          ),
        ),
        if (!settings.rotationLockEnabled) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            enabled: false,
            child: Text(
              'Sensitivity',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          PopupMenuItem(
            value: 'sensitivity_low',
            child: ListTile(
              leading: Icon(
                settings.rotationSensitivity == RotationSensitivity.low
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: const Text('Low'),
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'sensitivity_medium',
            child: ListTile(
              leading: Icon(
                settings.rotationSensitivity == RotationSensitivity.medium
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: const Text('Medium'),
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'sensitivity_high',
            child: ListTile(
              leading: Icon(
                settings.rotationSensitivity == RotationSensitivity.high
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: const Text('High'),
              dense: true,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'toggle_zoom_priority',
            child: ListTile(
              leading: Icon(
                settings.zoomPriorityEnabled
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 20,
              ),
              title: const Text('Zoom Priority'),
              dense: true,
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'toggle_indicators',
          child: ListTile(
            leading: Icon(
              settings.showGestureIndicators
                  ? Icons.visibility
                  : Icons.visibility_off,
              size: 20,
            ),
            title: const Text('Show Indicators'),
            dense: true,
          ),
        ),
      ],
    );
  }
}

/// Quick rotation lock toggle button
class RotationLockButton extends ConsumerWidget {
  const RotationLockButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(mapGestureSettingsProvider);
    final notifier = ref.read(mapGestureProvider.notifier);

    return FloatingActionButton.small(
      heroTag: 'rotation_lock',
      onPressed: notifier.toggleRotationLock,
      backgroundColor: settings.rotationLockEnabled ? Colors.red : null,
      tooltip:
          settings.rotationLockEnabled ? 'Unlock Rotation' : 'Lock Rotation',
      child: Icon(
        settings.rotationLockEnabled ? Icons.lock : Icons.lock_open,
        color: settings.rotationLockEnabled ? Colors.white : null,
      ),
    );
  }
}
