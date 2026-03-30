import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

/// Custom marker widget for displaying waypoints on the map
class WaypointMarker extends StatelessWidget {
  const WaypointMarker({
    required this.waypoint,
    super.key,
    this.size = 32.0,
    this.isSelected = false,
    this.onTap,
  });

  final Waypoint waypoint;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color typeColor = _getTypeColor(waypoint.type);
    final IconData typeIcon = _getTypeIcon(waypoint.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: typeColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.black26,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            if (isSelected)
              BoxShadow(
                color: typeColor.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Icon(
          typeIcon,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }

  Color _getTypeColor(WaypointType type) {
    final String colorHex = type.colorHex;
    return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
  }

  IconData _getTypeIcon(WaypointType type) {
    switch (type) {
      // Personal Markers
      case WaypointType.treasure:
        return Icons.diamond;
      case WaypointType.custom:
        return Icons.push_pin;
      case WaypointType.photo:
        return Icons.photo_camera;
      case WaypointType.note:
        return Icons.sticky_note_2;
      case WaypointType.voice:
        return Icons.mic;
      case WaypointType.favorite:
        return Icons.favorite;
      case WaypointType.memory:
        return Icons.auto_awesome;
      case WaypointType.goal:
        return Icons.flag;
      // Outdoor Activities
      case WaypointType.hiking:
        return Icons.hiking;
      case WaypointType.climbing:
        return Icons.terrain;
      case WaypointType.camp:
        return Icons.cabin;
      case WaypointType.fishing:
        return Icons.phishing;
      case WaypointType.hunting:
        return Icons.gps_fixed;
      case WaypointType.cycling:
        return Icons.pedal_bike;
      case WaypointType.kayaking:
        return Icons.kayaking;
      case WaypointType.skiing:
        return Icons.downhill_skiing;
      // Points of Interest
      case WaypointType.interest:
        return Icons.place;
      case WaypointType.viewpoint:
        return Icons.panorama;
      case WaypointType.landmark:
        return Icons.account_balance;
      case WaypointType.waterfall:
        return Icons.water;
      case WaypointType.cave:
        return Icons.dark_mode;
      case WaypointType.bridge:
        return Icons.architecture;
      case WaypointType.ruins:
        return Icons.castle;
      case WaypointType.wildlife:
        return Icons.pets;
      case WaypointType.flora:
        return Icons.eco;
      // Facilities & Services
      case WaypointType.parking:
        return Icons.local_parking;
      case WaypointType.restroom:
        return Icons.wc;
      case WaypointType.shelter:
        return Icons.house;
      case WaypointType.waterSource:
        return Icons.water_drop;
      case WaypointType.fuelStation:
        return Icons.local_gas_station;
      case WaypointType.restaurant:
        return Icons.restaurant;
      case WaypointType.lodging:
        return Icons.hotel;
      // Safety & Navigation
      case WaypointType.warning:
        return Icons.warning;
      case WaypointType.danger:
        return Icons.dangerous;
      case WaypointType.emergency:
        return Icons.emergency;
      case WaypointType.firstAid:
        return Icons.medical_services;
    }
  }
}

/// Animated waypoint marker with pulse effect
class AnimatedWaypointMarker extends StatefulWidget {
  const AnimatedWaypointMarker({
    required this.waypoint,
    super.key,
    this.size = 32.0,
    this.isSelected = false,
    this.onTap,
    this.showPulse = false,
  });

  final Waypoint waypoint;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showPulse;

  @override
  State<AnimatedWaypointMarker> createState() => _AnimatedWaypointMarkerState();
}

class _AnimatedWaypointMarkerState extends State<AnimatedWaypointMarker>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedWaypointMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPulse != oldWidget.showPulse) {
      if (widget.showPulse) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (BuildContext context, Widget? child) => Transform.scale(
          scale: widget.showPulse ? _pulseAnimation.value : 1.0,
          child: WaypointMarker(
            waypoint: widget.waypoint,
            size: widget.size,
            isSelected: widget.isSelected,
            onTap: widget.onTap,
          ),
        ),
      );
}

/// Waypoint marker with label for detailed view
class LabeledWaypointMarker extends StatelessWidget {
  const LabeledWaypointMarker({
    required this.waypoint,
    super.key,
    this.size = 32.0,
    this.isSelected = false,
    this.onTap,
    this.showAccuracy = false,
  });

  final Waypoint waypoint;
  final double size;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showAccuracy;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black26),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  waypoint.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showAccuracy && waypoint.accuracy != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '±${waypoint.accuracy!.toStringAsFixed(0)}m',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Marker
          WaypointMarker(
            waypoint: waypoint,
            size: size,
            isSelected: isSelected,
            onTap: onTap,
          ),
        ],
      );
}

/// Cluster marker for multiple waypoints in close proximity
class WaypointClusterMarker extends StatelessWidget {
  const WaypointClusterMarker({
    required this.waypoints,
    super.key,
    this.size = 40.0,
    this.onTap,
  });

  final List<Waypoint> waypoints;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final int count = waypoints.length;
    final Color clusterColor = _getClusterColor(count);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: clusterColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            count.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _getClusterColor(int count) {
    if (count < 5) return Colors.blue;
    if (count < 10) return Colors.orange;
    return Colors.red;
  }
}

/// Mini waypoint marker for overview/thumbnail views
class MiniWaypointMarker extends StatelessWidget {
  const MiniWaypointMarker({
    required this.waypoint,
    super.key,
    this.size = 16.0,
  });

  final Waypoint waypoint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color typeColor = _getTypeColor(waypoint.type);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: typeColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getTypeColor(WaypointType type) {
    final String colorHex = type.colorHex;
    return Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
  }
}
