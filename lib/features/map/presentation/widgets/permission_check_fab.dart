import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';
import 'package:obsession_tracker/core/providers/current_location_land_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/subscription/presentation/widgets/paywall_widget.dart';

/// A floating action button that quickly checks land permissions at current location or map center
class PermissionCheckFAB extends ConsumerStatefulWidget {
  const PermissionCheckFAB({
    super.key,
    this.onPermissionDetailsRequested,
    this.mapCenterLocation,
  });

  /// Callback when user wants to see full permission details
  final void Function(ComprehensiveLandOwnership property)? onPermissionDetailsRequested;

  /// Optional map center location - if provided, FAB checks at map center instead of GPS
  final LatLng? mapCenterLocation;

  @override
  ConsumerState<PermissionCheckFAB> createState() => _PermissionCheckFABState();
}

class _PermissionCheckFABState extends ConsumerState<PermissionCheckFAB> {
  bool _isLoadingMapCenter = false;
  ComprehensiveLandOwnership? _mapCenterProperty;
  String? _mapCenterError;

  /// Determines if we should use map center mode (user is viewing a different area)
  bool get _useMapCenterMode {
    if (widget.mapCenterLocation == null) return false;

    final locationState = ref.read(locationProvider);
    final gpsPosition = locationState.currentPosition;

    // If no GPS position, always use map center
    if (gpsPosition == null) return true;

    // Check if map center is significantly different from GPS (more than ~500m)
    const threshold = 0.005; // ~500m in degrees
    final latDiff = (widget.mapCenterLocation!.latitude - gpsPosition.latitude).abs();
    final lngDiff = (widget.mapCenterLocation!.longitude - gpsPosition.longitude).abs();

    return latDiff > threshold || lngDiff > threshold;
  }

  @override
  Widget build(BuildContext context) {
    final currentLocationLandState = ref.watch(currentLocationLandProvider);

    // Determine which state to show based on mode
    final isMapCenterMode = _useMapCenterMode;
    final isLoading = isMapCenterMode ? _isLoadingMapCenter : currentLocationLandState.isLoading;
    final hasData = isMapCenterMode ? (_mapCenterProperty != null) : currentLocationLandState.hasData;
    final property = isMapCenterMode ? _mapCenterProperty : currentLocationLandState.property;

    return FloatingActionButton(
      heroTag: 'permission_check',
      backgroundColor: _getButtonColor(isLoading, hasData, property),
      onPressed: () => _showQuickPermissionCheck(context),
      tooltip: isMapCenterMode ? 'Check Permissions at Map Center' : 'Check Permissions at Your Location',
      child: _buildIcon(isLoading, isMapCenterMode),
    );
  }

  Color _getButtonColor(bool isLoading, bool hasData, ComprehensiveLandOwnership? property) {
    if (isLoading) return AppTheme.textOnDarkMuted;
    if (!hasData || property == null) return AppTheme.gold;

    final status = property.activityPermissions.metalDetecting;

    switch (status) {
      case PermissionStatus.allowed:
        return AppTheme.success;
      case PermissionStatus.prohibited:
        return AppTheme.error;
      case PermissionStatus.permitRequired:
        return AppTheme.warning;
      case PermissionStatus.ownerPermissionRequired:
        return AppTheme.goldDark;
      case PermissionStatus.unknown:
        return AppTheme.gold;
    }
  }

  Widget _buildIcon(bool isLoading, bool isMapCenterMode) {
    if (isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.darkBackground),
        ),
      );
    }

    // Show different icon based on mode
    return Icon(
      isMapCenterMode ? Icons.center_focus_strong : Icons.policy,
      color: AppTheme.darkBackground,
    );
  }

  Future<void> _queryMapCenterPermissions() async {
    if (widget.mapCenterLocation == null) return;

    setState(() {
      _isLoadingMapCenter = true;
      _mapCenterError = null;
    });

    try {
      final lat = widget.mapCenterLocation!.latitude;
      final lng = widget.mapCenterLocation!.longitude;

      debugPrint('📍 Querying permissions at map center: ($lat, $lng)');

      // Query a small area around the map center
      const radiusKm = 0.5; // 500m radius
      final properties = await BFFMappingService.instance.getComprehensiveLandRightsData(
        northBound: lat + (radiusKm / 111.0),
        southBound: lat - (radiusKm / 111.0),
        eastBound: lng + (radiusKm / 111.0),
        westBound: lng - (radiusKm / 111.0),
        limit: 5,
      );

      if (properties.isNotEmpty) {
        // Select the most relevant property (prioritize by restriction level)
        final property = _selectMostRelevantProperty(properties);
        debugPrint('✅ Found property at map center: ${property.displayName}');

        setState(() {
          _mapCenterProperty = property;
          _isLoadingMapCenter = false;
        });
      } else {
        debugPrint('ℹ️ No land data at map center');
        setState(() {
          _mapCenterProperty = null;
          _isLoadingMapCenter = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to query map center permissions: $e');
      setState(() {
        _isLoadingMapCenter = false;
        _mapCenterError = e.toString();
      });
    }
  }

  ComprehensiveLandOwnership _selectMostRelevantProperty(List<ComprehensiveLandOwnership> properties) {
    final sorted = List<ComprehensiveLandOwnership>.from(properties);
    sorted.sort((a, b) {
      final aRestriction = _getRestrictionLevel(a);
      final bRestriction = _getRestrictionLevel(b);
      return bRestriction.compareTo(aRestriction);
    });
    return sorted.first;
  }

  int _getRestrictionLevel(ComprehensiveLandOwnership property) {
    final status = property.activityPermissions.mostRestrictive;
    switch (status) {
      case PermissionStatus.prohibited:
        return 4;
      case PermissionStatus.ownerPermissionRequired:
        return 3;
      case PermissionStatus.permitRequired:
        return 2;
      case PermissionStatus.allowed:
        return 1;
      case PermissionStatus.unknown:
        return 0;
    }
  }

  Future<void> _showQuickPermissionCheck(BuildContext context) async {
    // Check subscription status - permission checks are premium only
    final isPremium = ref.read(isPremiumProvider);

    if (!isPremium) {
      // Show paywall for free users
      await showPaywall(
        context,
        title: 'Premium Feature',
      );
      return;
    }

    final isMapCenterMode = _useMapCenterMode;

    if (isMapCenterMode) {
      // Query map center permissions if not already loaded
      if (_mapCenterProperty == null && !_isLoadingMapCenter) {
        _queryMapCenterPermissions();
      }

      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _MapCenterPermissionSheet(
          mapCenter: widget.mapCenterLocation!,
          property: _mapCenterProperty,
          isLoading: _isLoadingMapCenter,
          error: _mapCenterError,
          onRefresh: _queryMapCenterPermissions,
          onViewDetails: widget.onPermissionDetailsRequested,
        ),
      );
    } else {
      // Use GPS-based provider
      final currentLocationLandState = ref.read(currentLocationLandProvider);
      final locationState = ref.read(locationProvider);

      // If no data yet, trigger a refresh
      if (!currentLocationLandState.hasData && locationState.currentPosition != null) {
        ref.read(currentLocationLandProvider.notifier).forceRefresh();
      }

      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _QuickPermissionSheet(
          state: currentLocationLandState,
          onViewDetails: widget.onPermissionDetailsRequested,
        ),
      );
    }
  }
}

class _QuickPermissionSheet extends ConsumerWidget {
  const _QuickPermissionSheet({
    required this.state,
    this.onViewDetails,
  });

  final CurrentLocationLandState state;
  final void Function(ComprehensiveLandOwnership property)? onViewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for updates
    final currentState = ref.watch(currentLocationLandProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title
              Text(
                'Can I Metal Detect Here?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Content based on state
              if (currentState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checking land ownership...'),
                    ],
                  ),
                )
              else if (currentState.hasError)
                _buildErrorState(context, currentState.lastError!)
              else if (!currentState.hasData)
                _buildNoDataState(context)
              else
                _buildPermissionResult(context, currentState.property!),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.orange),
        const SizedBox(height: 12),
        Text(
          'Unable to check permissions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Make sure you have an internet connection',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNoDataState(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.location_searching, size: 48, color: AppTheme.gold),
        const SizedBox(height: 12),
        Text(
          'No land data available',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Land ownership data may not be available for this location',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionResult(BuildContext context, ComprehensiveLandOwnership property) {
    final metalDetecting = property.activityPermissions.metalDetecting;
    final treasureHunting = property.activityPermissions.treasureHunting;

    return Column(
      children: [
        // Property name
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${property.ownershipType.toUpperCase()} • ${property.sizeSummary}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Main permission result
        Row(
          children: [
            Expanded(
              child: _buildPermissionCard(
                context,
                'Metal Detecting',
                metalDetecting,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPermissionCard(
                context,
                'Treasure Hunting',
                treasureHunting,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // View details button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onViewDetails?.call(property);
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('View Full Details'),
          ),
        ),

        const SizedBox(height: 12),

        // Disclaimer
        Text(
          'Data for reference only. Verify with land agencies before accessing.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    String activity,
    PermissionStatus status,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(status.color).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(status.color).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            status.icon,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            activity,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            status.displayName,
            style: TextStyle(
              color: Color(status.color),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Permission sheet for map center queries (when user is viewing a different location)
class _MapCenterPermissionSheet extends StatelessWidget {
  const _MapCenterPermissionSheet({
    required this.mapCenter,
    required this.property,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    this.onViewDetails,
  });

  final LatLng mapCenter;
  final ComprehensiveLandOwnership? property;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final void Function(ComprehensiveLandOwnership property)? onViewDetails;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title with location indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.center_focus_strong, size: 20, color: AppTheme.gold),
                  const SizedBox(width: 8),
                  Text(
                    'Checking at Map Center',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Coordinates display
              Text(
                '${mapCenter.latitude.toStringAsFixed(5)}, ${mapCenter.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 20),

              // Content based on state
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checking land ownership...'),
                    ],
                  ),
                )
              else if (error != null)
                _buildErrorState(context)
              else if (property == null)
                _buildNoDataState(context)
              else
                _buildPermissionResult(context, property!),

              const SizedBox(height: 16),

              // Refresh button
              if (!isLoading)
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.orange),
        const SizedBox(height: 12),
        Text(
          'Unable to check permissions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Make sure you have an internet connection',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNoDataState(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.location_searching, size: 48, color: AppTheme.gold),
        const SizedBox(height: 12),
        Text(
          'No land data available',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Land ownership data may not be available for this location',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionResult(BuildContext context, ComprehensiveLandOwnership property) {
    final metalDetecting = property.activityPermissions.metalDetecting;
    final treasureHunting = property.activityPermissions.treasureHunting;

    return Column(
      children: [
        // Property name
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${property.ownershipType.toUpperCase()} • ${property.sizeSummary}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Main permission result
        Row(
          children: [
            Expanded(
              child: _buildPermissionCard(
                context,
                'Metal Detecting',
                metalDetecting,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPermissionCard(
                context,
                'Treasure Hunting',
                treasureHunting,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // View details button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onViewDetails?.call(property);
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('View Full Details'),
          ),
        ),

        const SizedBox(height: 12),

        // Disclaimer
        Text(
          'Data for reference only. Verify with land agencies before accessing.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    String activity,
    PermissionStatus status,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(status.color).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(status.color).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            status.icon,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            activity,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            status.displayName,
            style: TextStyle(
              color: Color(status.color),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
