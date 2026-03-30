import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

/// Result of marker type selection
class MarkerTypeSelectionResult {
  const MarkerTypeSelectionResult({
    required this.isWaypoint,
    this.waypointType,
  });

  /// True if user wants to create a waypoint, false for research marker
  final bool isWaypoint;

  /// The selected waypoint type (null if isWaypoint is false)
  final WaypointType? waypointType;
}

/// Bottom sheet for selecting whether to create a waypoint or research marker
class MarkerTypeSelectionSheet extends StatelessWidget {
  const MarkerTypeSelectionSheet({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to Map',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Waypoint types (common ones shown directly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Waypoints',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WaypointTypeChip(
                      icon: Icons.photo_camera,
                      label: 'Photo',
                      color: const Color(0xFFFF9500),
                      onTap: () => Navigator.pop(
                        context,
                        const MarkerTypeSelectionResult(
                          isWaypoint: true,
                          waypointType: WaypointType.photo,
                        ),
                      ),
                    ),
                    _WaypointTypeChip(
                      icon: Icons.mic,
                      label: 'Voice',
                      color: const Color(0xFF7C4DFF),
                      onTap: () => Navigator.pop(
                        context,
                        const MarkerTypeSelectionResult(
                          isWaypoint: true,
                          waypointType: WaypointType.voice,
                        ),
                      ),
                    ),
                    _WaypointTypeChip(
                      icon: Icons.sticky_note_2,
                      label: 'Note',
                      color: const Color(0xFF00BCD4),
                      onTap: () => Navigator.pop(
                        context,
                        const MarkerTypeSelectionResult(
                          isWaypoint: true,
                          waypointType: WaypointType.note,
                        ),
                      ),
                    ),
                    _WaypointTypeChip(
                      icon: Icons.place,
                      label: 'Point of Interest',
                      color: const Color(0xFF4CAF50),
                      onTap: () => Navigator.pop(
                        context,
                        const MarkerTypeSelectionResult(
                          isWaypoint: true,
                          waypointType: WaypointType.interest,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // More waypoint types option
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_location_alt,
                color: Colors.blue,
              ),
            ),
            title: const Text('More Waypoint Types...'),
            subtitle: const Text('View all waypoint categories'),
            trailing: const Icon(Icons.chevron_right),
            // Signal to show full waypoint dialog (waypointType defaults to null)
            onTap: () => Navigator.pop(
              context,
              const MarkerTypeSelectionResult(isWaypoint: true),
            ),
          ),

          const Divider(height: 1),

          // Research marker option
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.push_pin,
                color: Colors.purple,
              ),
            ),
            title: const Text('Research Marker'),
            subtitle: const Text('Save a location for future reference'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(
              context,
              const MarkerTypeSelectionResult(isWaypoint: false),
            ),
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

/// Chip widget for quick waypoint type selection
class _WaypointTypeChip extends StatelessWidget {
  const _WaypointTypeChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: color.withValues(alpha: isDark ? 0.2 : 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the marker type selection sheet
Future<MarkerTypeSelectionResult?> showMarkerTypeSelectionSheet(
  BuildContext context, {
  required double latitude,
  required double longitude,
}) =>
    showModalBottomSheet<MarkerTypeSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MarkerTypeSelectionSheet(
        latitude: latitude,
        longitude: longitude,
      ),
    );
