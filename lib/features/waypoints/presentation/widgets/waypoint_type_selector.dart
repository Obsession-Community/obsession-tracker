import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

/// Widget for selecting waypoint types with visual icons and colors
class WaypointTypeSelector extends StatelessWidget {
  const WaypointTypeSelector({
    required this.selectedType,
    required this.onTypeSelected,
    super.key,
    this.showLabels = true,
    this.isHorizontal = true,
  });

  final WaypointType selectedType;
  final ValueChanged<WaypointType> onTypeSelected;
  final bool showLabels;
  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    final List<Widget> typeWidgets = WaypointType.values
        .map((WaypointType type) => _WaypointTypeButton(
              type: type,
              isSelected: type == selectedType,
              onTap: () => onTypeSelected(type),
              showLabel: showLabels,
            ))
        .toList();

    if (isHorizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: typeWidgets,
        ),
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: typeWidgets,
      );
    }
  }
}

class _WaypointTypeButton extends StatelessWidget {
  const _WaypointTypeButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
    required this.showLabel,
  });

  final WaypointType type;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final Color typeColor = _getTypeColor(type);
    final IconData typeIcon = _getTypeIcon(type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? typeColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              border: Border.all(
                color:
                    isSelected ? typeColor : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: showLabel
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        typeIcon,
                        color: typeColor,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.displayName,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  )
                : Icon(
                    typeIcon,
                    color: typeColor,
                    size: 28,
                  ),
          ),
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

/// Compact horizontal waypoint type selector for toolbars
class WaypointTypeToolbar extends StatelessWidget {
  const WaypointTypeToolbar({
    required this.selectedType,
    required this.onTypeSelected,
    super.key,
  });

  final WaypointType selectedType;
  final ValueChanged<WaypointType> onTypeSelected;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: WaypointTypeSelector(
          selectedType: selectedType,
          onTypeSelected: onTypeSelected,
          showLabels: false,
        ),
      );
}

/// Grid layout for waypoint type selection in dialogs
class WaypointTypeGrid extends StatelessWidget {
  const WaypointTypeGrid({
    required this.selectedType,
    required this.onTypeSelected,
    super.key,
  });

  final WaypointType selectedType;
  final ValueChanged<WaypointType> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    // Split waypoint types into rows of 3
    final List<List<WaypointType>> rows = [];
    const List<WaypointType> types = WaypointType.values;

    for (int i = 0; i < types.length; i += 3) {
      rows.add(types.sublist(
        i,
        (i + 3 > types.length) ? types.length : i + 3,
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows
          .map(
            (List<WaypointType> rowTypes) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: rowTypes
                    .map(
                      (WaypointType type) => Expanded(
                        child: _WaypointTypeButton(
                          type: type,
                          isSelected: type == selectedType,
                          onTap: () => onTypeSelected(type),
                          showLabel: true,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          )
          .toList(),
    );
  }
}
