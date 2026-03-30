import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';

/// Provider for land ownership at the map center (target crosshair location)
/// Used for the permission status banner when user pans the map
final mapCenterLandProvider =
    NotifierProvider<MapCenterLandNotifier, MapCenterLandState>(
        MapCenterLandNotifier.new);

/// State for map center land ownership
class MapCenterLandState {
  const MapCenterLandState({
    this.property,
    this.lastLatitude,
    this.lastLongitude,
  });

  final ComprehensiveLandOwnership? property;
  final double? lastLatitude;
  final double? lastLongitude;

  bool get hasData => property != null;

  MapCenterLandState copyWith({
    ComprehensiveLandOwnership? property,
    double? lastLatitude,
    double? lastLongitude,
    bool clearProperty = false,
  }) {
    return MapCenterLandState(
      property: clearProperty ? null : (property ?? this.property),
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
    );
  }
}

/// Notifier for managing map center land ownership
/// Property is set directly from local parcel data (no BFF queries needed)
class MapCenterLandNotifier extends Notifier<MapCenterLandState> {
  @override
  MapCenterLandState build() {
    return const MapCenterLandState();
  }

  /// Set the property at the current map center (from local parcel lookup)
  void setProperty(ComprehensiveLandOwnership? property, {double? latitude, double? longitude}) {
    // Only log when we find data (avoid spamming logs during map pan)
    if (property != null) {
      debugPrint('🎯 Map center land: ${property.displayName} (${property.permissionSummary})');
    }

    state = MapCenterLandState(
      property: property,
      lastLatitude: latitude ?? state.lastLatitude,
      lastLongitude: longitude ?? state.lastLongitude,
    );
  }

  /// Clear current data
  void clear() {
    state = const MapCenterLandState();
  }
}
