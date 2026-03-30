import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Dialog that warns users when "Always Allow" location permission is not enabled
///
/// This is critical for iOS background tracking functionality. iOS requires users
/// to manually enable "Always Allow" in Settings after initially granting "While Using"
/// permission. Without "Always" permission, background tracking will not work reliably.
class BackgroundLocationWarningDialog extends StatelessWidget {
  const BackgroundLocationWarningDialog({
    super.key,
    required this.currentPermission,
    this.onOpenSettings,
    this.onContinueAnyway,
  });

  final LocationPermission currentPermission;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onContinueAnyway;

  @override
  Widget build(BuildContext context) {
    // Only show warning on iOS when permission is "whileInUse"
    if (!Platform.isIOS || currentPermission == LocationPermission.always) {
      return const SizedBox.shrink();
    }

    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Colors.orange.shade700,
        size: 48,
      ),
      title: const Text(
        'Background Tracking Not Enabled',
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your location permission is set to "While Using App" which means tracking will stop when the app is backgrounded.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue.shade900.withValues(alpha: 0.3)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade700
                      : Colors.blue.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'To enable background tracking:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Tap "Open Settings" below\n'
                    '2. Find "Location" settings\n'
                    '3. Change from "While Using App" to "Always"\n'
                    '4. Return to the app',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange.shade900.withValues(alpha: 0.3)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.shade700
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_outlined,
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.shade300
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Without "Always" permission, your GPS track will have gaps when you switch apps or lock your phone.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onContinueAnyway?.call();
          },
          child: const Text('Continue Anyway'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onOpenSettings?.call();
          },
          icon: const Icon(Icons.settings, size: 18),
          label: const Text('Open Settings'),
        ),
      ],
    );
  }

  /// Show the dialog and return true if user wants to continue anyway
  static Future<bool> show({
    required BuildContext context,
    required LocationPermission currentPermission,
    VoidCallback? onOpenSettings,
  }) async {
    // Don't show on Android or if already has always permission
    if (!Platform.isIOS || currentPermission == LocationPermission.always) {
      return true;
    }

    bool continueTracking = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => BackgroundLocationWarningDialog(
        currentPermission: currentPermission,
        onOpenSettings: onOpenSettings,
        onContinueAnyway: () {
          continueTracking = true;
        },
      ),
    );

    return continueTracking;
  }
}

/// Warning banner widget to show persistent reminder about background location
class BackgroundLocationWarningBanner extends StatelessWidget {
  const BackgroundLocationWarningBanner({
    super.key,
    required this.currentPermission,
    this.onOpenSettings,
    this.onDismiss,
  });

  final LocationPermission currentPermission;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    // Only show on iOS when permission is whileInUse
    if (!Platform.isIOS || currentPermission == LocationPermission.always) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(8),
      child: Material(
        color: isDark
            ? Colors.orange.shade900.withValues(alpha: 0.3)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpenSettings,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Background Tracking Limited',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enable "Always Allow" in Settings for continuous tracking',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onOpenSettings,
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Fix',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onDismiss,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
