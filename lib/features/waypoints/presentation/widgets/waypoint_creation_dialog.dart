import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/app_settings_provider.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/utils/coordinate_formatter.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/waypoint_type_selector.dart';

/// Dialog for creating a new waypoint with type selection and optional details
class WaypointCreationDialog extends ConsumerStatefulWidget {
  const WaypointCreationDialog({
    required this.sessionId,
    super.key,
    this.latitude,
    this.longitude,
    this.initialType = WaypointType.interest,
  });

  final String sessionId;
  final double? latitude;
  final double? longitude;
  final WaypointType initialType;

  @override
  ConsumerState<WaypointCreationDialog> createState() =>
      _WaypointCreationDialogState();
}

class _WaypointCreationDialogState
    extends ConsumerState<WaypointCreationDialog> {
  late WaypointType _selectedType;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WaypointNotifier waypointNotifier =
        ref.read(waypointProvider.notifier);
    final generalSettings = ref.watch(generalSettingsProvider);
    final bool hasGoodAccuracy = waypointNotifier.hasGoodLocationAccuracy();
    final String accuracyDescription =
        waypointNotifier.getCurrentLocationAccuracyDescription();
    final bool isUsingCurrentLocation =
        widget.latitude == null || widget.longitude == null;

    return AlertDialog(
      title: const Text('Create Waypoint'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Location info
            if (isUsingCurrentLocation) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasGoodAccuracy
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasGoodAccuracy
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      hasGoodAccuracy ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: hasGoodAccuracy ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Using current location',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            'GPS Accuracy: $accuracyDescription',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: hasGoodAccuracy
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...<Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.place,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lat: ${CoordinateFormatter.formatLatitude(widget.latitude!, generalSettings.coordinateFormat)}\nLng: ${CoordinateFormatter.formatLongitude(widget.longitude!, generalSettings.coordinateFormat)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Waypoint type selection
            Text(
              'Waypoint Type',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            WaypointTypeGrid(
              selectedType: _selectedType,
              onTypeSelected: (WaypointType type) {
                setState(() {
                  _selectedType = type;
                });
              },
            ),
            const SizedBox(height: 16),

            // Optional name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'Enter waypoint name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),

            // Optional notes field
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add notes about this location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note_outlined),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createWaypoint,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createWaypoint() async {
    setState(() {
      _isCreating = true;
    });

    try {
      final WaypointNotifier waypointNotifier =
          ref.read(waypointProvider.notifier);
      final String? name = _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim();
      final String? notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      Waypoint? waypoint;

      if (widget.latitude != null && widget.longitude != null) {
        // Create waypoint at specific coordinates
        waypoint = await waypointNotifier.createWaypointAtCoordinates(
          sessionId: widget.sessionId,
          latitude: widget.latitude!,
          longitude: widget.longitude!,
          type: _selectedType,
          name: name,
          notes: notes,
        );
      } else {
        // Create waypoint at current location
        waypoint = await waypointNotifier.createWaypointAtCurrentLocation(
          sessionId: widget.sessionId,
          type: _selectedType,
          name: name,
          notes: notes,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(waypoint);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Waypoint "${waypoint?.displayName ?? 'Unnamed'}" created'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        // Show error message
        final WaypointState waypointState = ref.read(waypointProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(waypointState.error ?? 'Failed to create waypoint'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating waypoint: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}

/// Quick waypoint creation dialog with minimal UI for fast marking
class QuickWaypointDialog extends ConsumerStatefulWidget {
  const QuickWaypointDialog({
    required this.sessionId,
    super.key,
    this.latitude,
    this.longitude,
  });

  final String sessionId;
  final double? latitude;
  final double? longitude;

  @override
  ConsumerState<QuickWaypointDialog> createState() =>
      _QuickWaypointDialogState();
}

class _QuickWaypointDialogState extends ConsumerState<QuickWaypointDialog> {
  WaypointType _selectedType = WaypointType.interest;
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quick Waypoint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Select waypoint type:'),
            const SizedBox(height: 16),
            WaypointTypeToolbar(
              selectedType: _selectedType,
              onTypeSelected: (WaypointType type) {
                setState(() {
                  _selectedType = type;
                });
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isCreating ? null : _createQuickWaypoint,
            child: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      );

  Future<void> _createQuickWaypoint() async {
    setState(() {
      _isCreating = true;
    });

    try {
      final WaypointNotifier waypointNotifier =
          ref.read(waypointProvider.notifier);
      Waypoint? waypoint;

      if (widget.latitude != null && widget.longitude != null) {
        waypoint = await waypointNotifier.createWaypointAtCoordinates(
          sessionId: widget.sessionId,
          latitude: widget.latitude!,
          longitude: widget.longitude!,
          type: _selectedType,
        );
      } else {
        waypoint = await waypointNotifier.createWaypointAtCurrentLocation(
          sessionId: widget.sessionId,
          type: _selectedType,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(waypoint);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}
