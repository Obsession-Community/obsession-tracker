import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';

/// Bottom sheet that displays details about a tapped historical place
class HistoricalPlaceDetailSheet extends StatelessWidget {
  const HistoricalPlaceDetailSheet({
    super.key,
    required this.place,
    required this.onDismiss,
    this.onNavigate,
    this.onAddWaypoint,
  });

  final HistoricalPlace place;
  final VoidCallback onDismiss;
  final VoidCallback? onNavigate;
  final VoidCallback? onAddWaypoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final typeMeta = place.typeMetadata;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
              tooltip: 'Close',
            ),
          ),
          // Header with type icon and name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Type icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeMeta.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      typeMeta.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Name and type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.featureName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: typeMeta.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          typeMeta.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : typeMeta.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildDetailRow(
                  context,
                  Icons.location_on,
                  'Location',
                  '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
                ),
                if (place.countyName != null)
                  _buildDetailRow(
                    context,
                    Icons.map,
                    'County',
                    '${place.countyName}, ${place.stateCode}',
                  ),
                if (place.elevationFormatted != null)
                  _buildDetailRow(
                    context,
                    Icons.terrain,
                    'Elevation',
                    place.elevationFormatted!,
                  ),
                if (place.mapName != null)
                  _buildDetailRow(
                    context,
                    Icons.grid_on,
                    'USGS Quad',
                    place.mapName!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddWaypoint,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Add Waypoint'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Safe area padding for bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show the historical place detail sheet as a modal bottom sheet
Future<void> showHistoricalPlaceDetailSheet(
  BuildContext context,
  HistoricalPlace place, {
  VoidCallback? onNavigate,
  VoidCallback? onAddWaypoint,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => HistoricalPlaceDetailSheet(
      place: place,
      onDismiss: () => Navigator.pop(context),
      onNavigate: onNavigate ?? () => Navigator.pop(context),
      onAddWaypoint: onAddWaypoint ?? () => Navigator.pop(context),
    ),
  );
}
