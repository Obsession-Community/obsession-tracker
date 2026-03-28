import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';

class PermissionStatusBanner extends StatelessWidget {
  const PermissionStatusBanner({
    super.key,
    required this.property,
    this.onTap,
    this.compact = false,
    this.isMapCenterMode = false,
  });

  final ComprehensiveLandOwnership property;
  final VoidCallback? onTap;
  final bool compact;
  /// When true, shows "at center" indicator instead of "at your location"
  final bool isMapCenterMode;

  @override
  Widget build(BuildContext context) {
    final mostRestrictive = property.activityPermissions.mostRestrictive;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use solid semi-transparent background for visibility on all map types
    // Dark mode: dark background for contrast on satellite/dark maps
    // Light mode: light background for contrast on light maps
    final backgroundColor = isDark
        ? Colors.black.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.92);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(compact ? 8 : 12),
        decoration: BoxDecoration(
          // Solid background layer for visibility
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color(mostRestrictive.color).withValues(alpha: 0.6),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          // Inner colored tint layer
          decoration: BoxDecoration(
            color: Color(mostRestrictive.color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: compact ? _buildCompactContent(context) : _buildFullContent(context),
        ),
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context) {
    final mostRestrictive = property.activityPermissions.mostRestrictive;
    
    return Row(
      children: [
        Text(
          mostRestrictive.icon,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getCompactMessage(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Color(mostRestrictive.color),
            ),
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.chevron_right,
            size: 16,
            color: Color(mostRestrictive.color),
          ),
      ],
    );
  }

  Widget _buildFullContent(BuildContext context) {
    final mostRestrictive = property.activityPermissions.mostRestrictive;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Color(mostRestrictive.color).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                mostRestrictive.icon,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.displayName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Color(mostRestrictive.color),
                    ),
                  ),
                  Text(
                    property.ownershipType.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Color(mostRestrictive.color).withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.info_outline,
                color: Color(mostRestrictive.color),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Permission summary
        Text(
          property.permissionSummary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Color(mostRestrictive.color),
          ),
        ),
        
        // Quick activity status
        const SizedBox(height: 8),
        Row(
          children: [
            _buildQuickStatus(
              context,
              'Metal Detecting',
              property.activityPermissions.metalDetecting,
            ),
            const SizedBox(width: 16),
            _buildQuickStatus(
              context,
              'Treasure Hunting',
              property.activityPermissions.treasureHunting,
            ),
          ],
        ),
        
        // Additional info for specific cases
        if (mostRestrictive == PermissionStatus.ownerPermissionRequired &&
            property.ownerContact?.hasContactInfo == true) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.contact_phone,
                size: 14,
                color: Color(mostRestrictive.color).withValues(alpha: 0.8),
              ),
              const SizedBox(width: 4),
              Text(
                property.ownerContact!.contactSummary,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Color(mostRestrictive.color).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
        
        if (property.accessRights.hasActiveRestrictions) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 4),
              Text(
                '${property.accessRights.activeRestrictions.length} active restriction(s)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuickStatus(
    BuildContext context,
    String activity,
    PermissionStatus status,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status.icon,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          activity,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Color(status.color),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getCompactMessage() {
    final mostRestrictive = property.activityPermissions.mostRestrictive;
    final locationIndicator = isMapCenterMode ? '📍 ' : '';

    switch (mostRestrictive) {
      case PermissionStatus.prohibited:
        return '${locationIndicator}Prohibited: ${property.displayName}';
      case PermissionStatus.ownerPermissionRequired:
        return '${locationIndicator}Owner permission: ${property.displayName}';
      case PermissionStatus.permitRequired:
        return '${locationIndicator}Permit required: ${property.displayName}';
      case PermissionStatus.allowed:
        return '${locationIndicator}Allowed: ${property.displayName}';
      case PermissionStatus.unknown:
        return '${locationIndicator}Unknown: ${property.displayName}';
    }
  }
}

class PermissionStatusIndicator extends StatelessWidget {
  const PermissionStatusIndicator({
    super.key,
    required this.status,
    this.size = 24,
    this.showLabel = false,
  });

  final PermissionStatus status;
  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Color(status.color).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(
              color: Color(status.color),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              status.icon,
              style: TextStyle(fontSize: size * 0.6),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Color(status.color),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}