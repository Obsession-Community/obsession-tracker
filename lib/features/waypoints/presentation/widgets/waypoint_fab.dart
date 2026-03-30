import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/waypoint_icon_service.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/custom_marker_creation_sheet.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/waypoint_creation_dialog.dart';

/// Floating Action Button for quick waypoint creation with photo capture emphasis.
///
/// During active tracking, this FAB prioritizes photo capture as the primary action
/// with other waypoint types accessible through expansion. Optimized for one-handed
/// use while walking/hiking.
class WaypointFab extends ConsumerStatefulWidget {
  const WaypointFab({
    required this.sessionId,
    super.key,
    this.onWaypointCreated,
    this.isTrackingActive = false,
  });

  /// The active tracking session ID
  final String sessionId;

  /// Callback when a waypoint is successfully created
  final VoidCallback? onWaypointCreated;

  /// Whether tracking is currently active (affects photo capture prominence)
  final bool isTrackingActive;

  @override
  ConsumerState<WaypointFab> createState() => _WaypointFabState();
}

class _WaypointFabState extends ConsumerState<WaypointFab>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.75, // 3/4 rotation (270 degrees)
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WaypointState waypointState = ref.watch(waypointProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // Waypoint type options (excluding photo when tracking is active)
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (BuildContext context, Widget? child) => Transform.scale(
            scale: _expandAnimation.value,
            child: Opacity(
              opacity: _expandAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _getWaypointTypesForMenu()
                    .map((WaypointType type) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildTypeFab(type, waypointState.isCreating),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),

        // Main FAB - optimized for photo capture during tracking
        if (widget.isTrackingActive)
          FloatingActionButton.large(
            onPressed: waypointState.isCreating ? null : _handleMainFabTap,
            backgroundColor: Theme.of(context).colorScheme.primary,
            elevation: 12, // Increased elevation for better visibility over map
            heroTag: 'photo_capture_fab', // Unique hero tag to avoid conflicts
            child: AnimatedBuilder(
              animation: _rotateAnimation,
              builder: (BuildContext context, Widget? child) => DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      blurRadius: 12, // Enhanced shadow for iOS visibility
                      spreadRadius: 3,
                      offset: const Offset(0, 4), // iOS-style shadow offset
                    ),
                    // Additional shadow for better contrast on map
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _getFabIcon(),
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          )
        else
          FloatingActionButton(
            onPressed: waypointState.isCreating ? null : _handleMainFabTap,
            backgroundColor: _isExpanded
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.primary,
            elevation: 8, // Standard elevation for non-tracking mode
            heroTag: 'waypoint_fab', // Unique hero tag
            child: AnimatedBuilder(
              animation: _rotateAnimation,
              builder: (BuildContext context, Widget? child) =>
                  Transform.rotate(
                angle:
                    _rotateAnimation.value * 2 * 3.14159, // Convert to radians
                child: Icon(
                  _getFabIcon(),
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeFab(WaypointType type, bool isCreating) {
    final Color typeColor = WaypointIconService.instance.getIconColor(type);

    return FloatingActionButton.small(
      onPressed: isCreating ? null : () => _createQuickWaypoint(type),
      backgroundColor: typeColor,
      heroTag: 'waypoint_fab_${type.name}',
      child: WaypointIconService.instance.getIconWidgetCustomSize(
        type,
        width: 20,
        color: Colors.white,
      ),
    );
  }

  /// Get waypoint types for the expandable menu
  /// During active tracking, photo is handled by main FAB, so exclude it from menu
  List<WaypointType> _getWaypointTypesForMenu() {
    if (widget.isTrackingActive) {
      return WaypointType.values
          .where((type) => type != WaypointType.photo)
          .toList()
          .reversed
          .toList();
    }
    return WaypointType.values.reversed.toList();
  }

  /// Handle main FAB tap - open marker creation sheet
  Future<void> _handleMainFabTap() async {
    if (_isExpanded) {
      // Close the expanded menu
      await _toggleExpanded();
    } else {
      // Open marker creation sheet directly
      await _openMarkerCreationSheet();
    }
  }

  /// Get appropriate icon for the main FAB
  IconData _getFabIcon() {
    if (_isExpanded) {
      return Icons.close;
    }
    return Icons.add_location_alt; // Unified waypoint icon
  }

  Future<void> _toggleExpanded() async {
    HapticFeedback.lightImpact();

    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      await _animationController.forward();
    } else {
      await _animationController.reverse();
    }
  }

  Future<void> _createQuickWaypoint(WaypointType type) async {
    // Close the expanded menu first
    await _toggleExpanded();

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // For photo and voice types, open the marker creation sheet
    // which provides a better multi-media creation experience
    if (type == WaypointType.photo || type == WaypointType.voice) {
      await _openMarkerCreationSheet();
      return;
    }

    try {
      final WaypointNotifier waypointNotifier =
          ref.read(waypointProvider.notifier);

      final Waypoint? waypoint =
          await waypointNotifier.createWaypointAtCurrentLocation(
        sessionId: widget.sessionId,
        type: type,
      );

      if (waypoint != null) {
        // Success haptic feedback
        HapticFeedback.heavyImpact();

        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: <Widget>[
                  WaypointIconService.instance.getIconWidgetCustomSize(
                    type,
                    width: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text('${type.displayName} waypoint created'),
                ],
              ),
              backgroundColor: WaypointIconService.instance.getIconColor(type),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }

        widget.onWaypointCreated?.call();
      } else {
        // Error haptic feedback
        HapticFeedback.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create ${type.displayName} waypoint'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: () => _createQuickWaypoint(type),
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Error haptic feedback
      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating waypoint: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  /// Open the marker creation sheet for creating a marker with any attachments
  Future<void> _openMarkerCreationSheet() async {
    // Immediate haptic feedback for responsiveness
    HapticFeedback.lightImpact();

    try {
      // Get current GPS position
      final LocationState locationState = ref.read(locationProvider);
      final Position? currentPosition = locationState.currentPosition;

      if (currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Waiting for GPS location...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Open marker creation sheet
      final marker = await showCustomMarkerCreationSheet(
        context,
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        sessionId: widget.sessionId,
      );

      // Check if user canceled (result is null)
      if (marker == null) {
        return;
      }

      // Success haptic feedback
      HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      HapticFeedback.lightImpact();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Marker "${marker.name}" saved!',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD4AF37), // Gold
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      widget.onWaypointCreated?.call();
    } catch (e) {
      // Error haptic feedback
      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Error opening marker creation: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

/// Compact waypoint FAB for minimal UI footprint
class CompactWaypointFab extends ConsumerWidget {
  const CompactWaypointFab({
    required this.sessionId,
    super.key,
    this.onWaypointCreated,
  });

  /// The active tracking session ID
  final String sessionId;

  /// Callback when a waypoint is successfully created
  final VoidCallback? onWaypointCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WaypointState waypointState = ref.watch(waypointProvider);

    return FloatingActionButton.small(
      onPressed:
          waypointState.isCreating ? null : () => _showQuickCreate(context),
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: waypointState.isCreating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(
              Icons.add_location,
              color: Colors.white,
              size: 20,
            ),
    );
  }

  void _showQuickCreate(BuildContext context) {
    HapticFeedback.lightImpact();

    showDialog<void>(
      context: context,
      builder: (BuildContext context) => WaypointCreationDialog(
        sessionId: sessionId,
      ),
    );
  }
}
