import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/waypoint_icon_service.dart';

/// Quick waypoint creation toolbar for active tracking sessions.
///
/// Provides one-tap waypoint creation with 5 waypoint type buttons
/// arranged horizontally for easy access during tracking.
class QuickWaypointToolbar extends ConsumerStatefulWidget {
  const QuickWaypointToolbar({
    required this.sessionId,
    super.key,
    this.onWaypointCreated,
  });

  /// The active tracking session ID
  final String sessionId;

  /// Callback when a waypoint is successfully created
  final VoidCallback? onWaypointCreated;

  @override
  ConsumerState<QuickWaypointToolbar> createState() =>
      _QuickWaypointToolbarState();
}

class _QuickWaypointToolbarState extends ConsumerState<QuickWaypointToolbar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  WaypointType? _lastCreatedType;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
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

    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: WaypointType.values
            .map((WaypointType type) => _buildWaypointButton(
                  type,
                  waypointState.isCreating,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildWaypointButton(WaypointType type, bool isCreating) {
    final Color typeColor = _getTypeColor(type);
    final bool isLastCreated = _lastCreatedType == type;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        scale: isLastCreated ? _scaleAnimation.value : 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isCreating ? null : () => _createWaypoint(type),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isLastCreated
                    ? typeColor.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: isLastCreated
                    ? Border.all(color: typeColor, width: 2)
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (isCreating && _lastCreatedType == type)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                      ),
                    )
                  else
                    WaypointIconService.instance.getIconWidgetCustomSize(
                      type,
                      width: 24,
                      color: typeColor,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createWaypoint(WaypointType type) async {
    setState(() {
      _lastCreatedType = type;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Animate button press
    await _animationController.forward();

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
        HapticFeedback.mediumImpact();

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
              backgroundColor: _getTypeColor(type),
              duration: const Duration(seconds: 2),
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
    } finally {
      // Reset animation and state
      await _animationController.reverse();
      if (mounted) {
        setState(() {
          _lastCreatedType = null;
        });
      }
    }
  }

  Color _getTypeColor(WaypointType type) {
    final String colorHex = type.colorHex;
    return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
  }
}
