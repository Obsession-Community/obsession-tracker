import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';

/// Bottom sheet for displaying land parcel details
/// Can be used standalone (with internal DraggableScrollableSheet) or
/// inside a modal bottom sheet (with external scrollController)
class LandParcelBottomSheet extends ConsumerWidget {
  const LandParcelBottomSheet({
    super.key,
    required this.parcel,
    required this.onDismiss,
    this.scrollController,
  });

  final LandOwnership parcel;
  final VoidCallback onDismiss;
  /// When provided, used instead of internal DraggableScrollableSheet
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // If scrollController is provided, render content directly (modal mode)
    if (scrollController != null) {
      return _buildContent(context, theme, scrollController!);
    }

    // Otherwise, wrap in DraggableScrollableSheet (standalone mode)
    return DraggableScrollableSheet(
      initialChildSize: 0.2,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.2, 0.5, 0.9],
      builder: (context, controller) => _buildContent(context, theme, controller),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, ScrollController controller) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        controller: controller,
        padding: EdgeInsets.zero,
        children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
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

              // Content with horizontal padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Land parcel header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(parcel.ownershipType.defaultColor).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getIconForLandType(parcel.ownershipType),
                            color: Color(parcel.ownershipType.defaultColor),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parcel.ownerName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                parcel.ownershipType.displayName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick stats cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Access',
                            _getAccessTypeLabel(parcel.accessType),
                            _getAccessTypeIcon(parcel.accessType),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Source',
                            parcel.dataSource,
                            Icons.source,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Activity permissions section (most important for treasure hunting!)
                    Text(
                      'Activity Permissions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Permission cards
                    _buildPermissionCard(
                      context,
                      'Metal Detecting',
                      _getPermissionFromProperties(parcel, 'metalDetecting'),
                      Icons.search,
                    ),
                    const SizedBox(height: 8),
                    _buildPermissionCard(
                      context,
                      'Treasure Hunting',
                      _getPermissionFromProperties(parcel, 'treasureHunting'),
                      Icons.diamond,
                    ),
                    const SizedBox(height: 8),
                    _buildPermissionCard(
                      context,
                      'Archaeology',
                      _getPermissionFromProperties(parcel, 'archaeology'),
                      Icons.history_edu,
                    ),

                    const SizedBox(height: 24),

                    // Additional details (expanded state)
                    if (parcel.agencyName != null) ...[
                      _buildInfoRow(
                        context,
                        'Agency',
                        parcel.agencyName!,
                        Icons.business,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (parcel.unitName != null) ...[
                      _buildInfoRow(
                        context,
                        'Unit',
                        parcel.unitName!,
                        Icons.park,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (parcel.designation != null) ...[
                      _buildInfoRow(
                        context,
                        'Designation',
                        parcel.designation!,
                        Icons.label,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (parcel.contactInfo != null) ...[
                      _buildInfoRow(
                        context,
                        'Contact',
                        parcel.contactInfo!,
                        Icons.phone,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (parcel.website != null) ...[
                      _buildInfoRow(
                        context,
                        'Website',
                        parcel.website!,
                        Icons.link,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (parcel.fees != null) ...[
                      _buildInfoRow(
                        context,
                        'Fees',
                        parcel.fees!,
                        Icons.attach_money,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (parcel.seasonalInfo != null) ...[
                      _buildInfoRow(
                        context,
                        'Seasonal Info',
                        parcel.seasonalInfo!,
                        Icons.calendar_today,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Restrictions
                    if (parcel.restrictions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Restrictions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...parcel.restrictions.map((restriction) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    restriction,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],

                    const SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    String activity,
    PermissionStatus status,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final color = _getPermissionColor(status);
    final statusText = _getPermissionText(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            statusText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper methods

  IconData _getIconForLandType(LandOwnershipType type) {
    switch (type) {
      case LandOwnershipType.nationalForest:
      case LandOwnershipType.stateForest:
        return Icons.forest;
      case LandOwnershipType.nationalPark:
      case LandOwnershipType.statePark:
        return Icons.park;
      case LandOwnershipType.nationalWildlifeRefuge:
      case LandOwnershipType.stateWildlifeArea:
        return Icons.pets;
      case LandOwnershipType.bureauOfLandManagement:
        return Icons.landscape;
      case LandOwnershipType.privateLand:
        return Icons.home;
      case LandOwnershipType.tribalLand:
        return Icons.account_balance;
      case LandOwnershipType.wilderness:
        return Icons.terrain;
      default:
        return Icons.map;
    }
  }

  String _getAccessTypeLabel(AccessType accessType) {
    switch (accessType) {
      case AccessType.publicOpen:
        return 'Public';
      case AccessType.permitRequired:
        return 'Permit';
      case AccessType.seasonalRestrictions:
        return 'Seasonal';
      case AccessType.feeRequired:
        return 'Fee';
      case AccessType.huntingLicenseRequired:
        return 'License';
      case AccessType.restrictedAccess:
        return 'Restricted';
      case AccessType.noPublicAccess:
        return 'Private';
    }
  }

  IconData _getAccessTypeIcon(AccessType accessType) {
    switch (accessType) {
      case AccessType.publicOpen:
        return Icons.lock_open;
      case AccessType.permitRequired:
        return Icons.badge;
      case AccessType.seasonalRestrictions:
        return Icons.schedule;
      case AccessType.feeRequired:
        return Icons.attach_money;
      case AccessType.huntingLicenseRequired:
        return Icons.card_membership;
      case AccessType.restrictedAccess:
        return Icons.lock_outline;
      case AccessType.noPublicAccess:
        return Icons.lock;
    }
  }

  PermissionStatus _getPermissionFromProperties(LandOwnership parcel, String permissionType) {
    // First check if activityPermissions is directly on the model
    final permissions = parcel.activityPermissions;
    if (permissions != null) {
      switch (permissionType) {
        case 'metalDetecting':
          return permissions.metalDetecting;
        case 'treasureHunting':
          return permissions.treasureHunting;
        case 'archaeology':
          return permissions.archaeology;
        case 'camping':
          return permissions.camping;
        case 'hunting':
          return permissions.hunting;
        case 'fishing':
          return permissions.fishing;
        default:
          return PermissionStatus.unknown;
      }
    }

    // Fallback: Try to get activity permissions from properties map
    final properties = parcel.properties;
    if (properties.containsKey('activityPermissions')) {
      final permissionsMap = properties['activityPermissions'];
      if (permissionsMap is Map && permissionsMap.containsKey(permissionType)) {
        return PermissionStatus.fromString(permissionsMap[permissionType] as String?);
      }
    }
    return PermissionStatus.unknown;
  }

  Color _getPermissionColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.allowed:
        return Colors.green;
      case PermissionStatus.prohibited:
        return Colors.red;
      case PermissionStatus.permitRequired:
        return Colors.orange;
      case PermissionStatus.ownerPermissionRequired:
        return Colors.orange;
      case PermissionStatus.unknown:
        return Colors.grey;
    }
  }

  String _getPermissionText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.allowed:
        return 'ALLOWED';
      case PermissionStatus.prohibited:
        return 'PROHIBITED';
      case PermissionStatus.permitRequired:
        return 'PERMIT REQUIRED';
      case PermissionStatus.ownerPermissionRequired:
        return 'ASK OWNER';
      case PermissionStatus.unknown:
        return 'UNKNOWN';
    }
  }
}
