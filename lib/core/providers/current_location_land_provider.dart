import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/subscription_provider.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';

/// Provider for land ownership at the user's current GPS location
/// Used for the permission status banner and real-time alerts
final currentLocationLandProvider =
    NotifierProvider<CurrentLocationLandNotifier, CurrentLocationLandState>(
        CurrentLocationLandNotifier.new);

/// State for current location land ownership
class CurrentLocationLandState {
  const CurrentLocationLandState({
    this.property,
    this.isLoading = false,
    this.lastError,
    this.lastQueryTime,
    this.queryLatitude,
    this.queryLongitude,
  });

  final ComprehensiveLandOwnership? property;
  final bool isLoading;
  final String? lastError;
  final DateTime? lastQueryTime;
  final double? queryLatitude;
  final double? queryLongitude;

  bool get hasData => property != null;
  bool get hasError => lastError != null;

  CurrentLocationLandState copyWith({
    ComprehensiveLandOwnership? property,
    bool? isLoading,
    String? lastError,
    DateTime? lastQueryTime,
    double? queryLatitude,
    double? queryLongitude,
    bool clearProperty = false,
    bool clearError = false,
  }) {
    return CurrentLocationLandState(
      property: clearProperty ? null : (property ?? this.property),
      isLoading: isLoading ?? this.isLoading,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastQueryTime: lastQueryTime ?? this.lastQueryTime,
      queryLatitude: queryLatitude ?? this.queryLatitude,
      queryLongitude: queryLongitude ?? this.queryLongitude,
    );
  }
}

/// Notifier for managing current location land ownership queries
class CurrentLocationLandNotifier extends Notifier<CurrentLocationLandState> {
  // Debounce timer to avoid too many queries
  Timer? _debounceTimer;

  @override
  CurrentLocationLandState build() {
    // Listen to location changes and update land ownership
    ref.listen<LocationState>(locationProvider, (previous, next) {
      final position = next.currentPosition;
      if (position != null) {
        updateForLocation(position.latitude, position.longitude);
      }
    });

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const CurrentLocationLandState();
  }
  static const _debounceDuration = Duration(milliseconds: 500);

  // Minimum distance change to trigger a new query (in degrees, ~111m)
  static const _minDistanceChange = 0.001;

  // Cache expiry duration
  static const _cacheExpiry = Duration(minutes: 5);

  /// Update land ownership for a new location
  Future<void> updateForLocation(double latitude, double longitude) async {
    // Skip if already loading
    if (state.isLoading) return;

    // Skip if location hasn't changed significantly
    if (_shouldSkipQuery(latitude, longitude)) return;

    // Debounce rapid updates
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _queryLandOwnership(latitude, longitude);
    });
  }

  /// Force refresh regardless of cache
  Future<void> forceRefresh() async {
    final lat = state.queryLatitude;
    final lng = state.queryLongitude;
    if (lat != null && lng != null) {
      await _queryLandOwnership(lat, lng, forceRefresh: true);
    }
  }

  /// Clear current data
  void clear() {
    state = const CurrentLocationLandState();
  }

  bool _shouldSkipQuery(double latitude, double longitude) {
    // Always query if we have no data
    if (!state.hasData) return false;

    // Skip if location hasn't changed significantly
    if (state.queryLatitude != null && state.queryLongitude != null) {
      final latDiff = (latitude - state.queryLatitude!).abs();
      final lngDiff = (longitude - state.queryLongitude!).abs();

      if (latDiff < _minDistanceChange && lngDiff < _minDistanceChange) {
        // Check cache expiry
        if (state.lastQueryTime != null) {
          final age = DateTime.now().difference(state.lastQueryTime!);
          if (age < _cacheExpiry) {
            return true; // Skip - data is still fresh
          }
        }
      }
    }

    return false;
  }

  Future<void> _queryLandOwnership(
    double latitude,
    double longitude, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _shouldSkipQuery(latitude, longitude)) return;

    // Check subscription status - real-time permission alerts are premium only
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) {
      debugPrint('🚫 Real-time permission alerts blocked - premium subscription required');
      state = state.copyWith(
        clearProperty: true,
        isLoading: false,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      queryLatitude: latitude,
      queryLongitude: longitude,
    );

    try {
      debugPrint('📍 Querying land ownership at ($latitude, $longitude)');

      // Query a small area around the current location
      const radiusKm = 0.5; // 500m radius
      final properties = await BFFMappingService.instance.getComprehensiveLandRightsData(
        northBound: latitude + (radiusKm / 111.0),
        southBound: latitude - (radiusKm / 111.0),
        eastBound: longitude + (radiusKm / 111.0),
        westBound: longitude - (radiusKm / 111.0),
        limit: 5, // Just get a few nearby properties
      );

      if (properties.isNotEmpty) {
        // Select the most relevant property (prioritize by restriction level)
        final property = _selectMostRelevantProperty(properties);

        debugPrint('✅ Found property: ${property.displayName}');
        debugPrint('   Permissions: ${property.permissionSummary}');

        state = state.copyWith(
          property: property,
          isLoading: false,
          lastQueryTime: DateTime.now(),
        );
      } else {
        debugPrint('ℹ️ No land ownership data at current location');
        state = state.copyWith(
          isLoading: false,
          clearProperty: true,
          lastQueryTime: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to query land ownership: $e');
      state = state.copyWith(
        isLoading: false,
        lastError: e.toString(),
      );
    }
  }

  /// Select the most relevant property for display
  /// Prioritizes properties with restrictions or permission requirements
  ComprehensiveLandOwnership _selectMostRelevantProperty(
    List<ComprehensiveLandOwnership> properties,
  ) {
    // Sort by restriction level (most restrictive first)
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

}
