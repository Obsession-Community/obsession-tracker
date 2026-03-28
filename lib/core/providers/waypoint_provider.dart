import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/waypoint_service.dart';

/// Provider for the waypoint service
final Provider<WaypointService> waypointServiceProvider =
    Provider<WaypointService>((Ref ref) => WaypointService.instance);

/// State class for waypoint management
@immutable
class WaypointState {
  const WaypointState({
    this.waypoints = const <Waypoint>[],
    this.isLoading = false,
    this.error,
    this.selectedWaypoint,
    this.isCreating = false,
  });

  final List<Waypoint> waypoints;
  final bool isLoading;
  final String? error;
  final Waypoint? selectedWaypoint;
  final bool isCreating;

  WaypointState copyWith({
    List<Waypoint>? waypoints,
    bool? isLoading,
    String? error,
    Waypoint? selectedWaypoint,
    bool? isCreating,
    bool clearError = false,
    bool clearSelectedWaypoint = false,
  }) =>
      WaypointState(
        waypoints: waypoints ?? this.waypoints,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        selectedWaypoint: clearSelectedWaypoint
            ? null
            : (selectedWaypoint ?? this.selectedWaypoint),
        isCreating: isCreating ?? this.isCreating,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaypointState &&
          runtimeType == other.runtimeType &&
          waypoints == other.waypoints &&
          isLoading == other.isLoading &&
          error == other.error &&
          selectedWaypoint == other.selectedWaypoint &&
          isCreating == other.isCreating;

  @override
  int get hashCode =>
      waypoints.hashCode ^
      isLoading.hashCode ^
      error.hashCode ^
      selectedWaypoint.hashCode ^
      isCreating.hashCode;
}

/// Notifier for managing waypoint state
class WaypointNotifier extends Notifier<WaypointState> {
  late final WaypointService _waypointService;

  @override
  WaypointState build() {
    _waypointService = WaypointService.instance;
    return const WaypointState();
  }

  /// Load waypoints for a session
  Future<void> loadWaypointsForSession(String sessionId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final List<Waypoint> waypoints =
          await _waypointService.getWaypointsForSession(sessionId);
      state = state.copyWith(
        waypoints: waypoints,
        isLoading: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load waypoints: $e',
      );
    }
  }

  /// Create a waypoint at current location
  Future<Waypoint?> createWaypointAtCurrentLocation({
    required String sessionId,
    required WaypointType type,
    String? name,
    String? notes,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);

    try {
      final Waypoint waypoint =
          await _waypointService.createWaypointAtCurrentLocation(
        sessionId: sessionId,
        type: type,
        name: name,
        notes: notes,
      );

      // Add to current waypoints list
      final List<Waypoint> updatedWaypoints =
          List<Waypoint>.from(state.waypoints)..add(waypoint);

      state = state.copyWith(
        waypoints: updatedWaypoints,
        isCreating: false,
      );

      return waypoint;
    } on Exception catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: 'Failed to create waypoint: $e',
      );
      return null;
    }
  }

  /// Create a waypoint at specific coordinates
  ///
  /// If [sessionId] is null, creates a standalone waypoint not associated with
  /// any tracking session.
  Future<Waypoint?> createWaypointAtCoordinates({
    String? sessionId,
    required double latitude,
    required double longitude,
    required WaypointType type,
    String? name,
    String? notes,
    double? altitude,
    double? accuracy,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);

    try {
      final Waypoint waypoint =
          await _waypointService.createWaypointAtCoordinates(
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        type: type,
        name: name,
        notes: notes,
        altitude: altitude,
        accuracy: accuracy,
      );

      // Add to current waypoints list
      final List<Waypoint> updatedWaypoints =
          List<Waypoint>.from(state.waypoints)..add(waypoint);

      state = state.copyWith(
        waypoints: updatedWaypoints,
        isCreating: false,
      );

      return waypoint;
    } on Exception catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: 'Failed to create waypoint: $e',
      );
      return null;
    }
  }

  /// Add an already-saved waypoint to the provider state
  /// Use this when waypoints are created outside the provider (e.g., photo waypoints)
  void addWaypointToState(Waypoint waypoint) {
    final List<Waypoint> updatedWaypoints =
        List<Waypoint>.from(state.waypoints)..add(waypoint);
    state = state.copyWith(waypoints: updatedWaypoints);
  }

  /// Update an existing waypoint
  Future<bool> updateWaypoint(Waypoint waypoint) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final Waypoint updatedWaypoint =
          await _waypointService.updateWaypoint(waypoint);

      // Update in current waypoints list
      final List<Waypoint> updatedWaypoints = state.waypoints
          .map((Waypoint w) => w.id == updatedWaypoint.id ? updatedWaypoint : w)
          .toList();

      state = state.copyWith(
        waypoints: updatedWaypoints,
        isLoading: false,
        selectedWaypoint: state.selectedWaypoint?.id == updatedWaypoint.id
            ? updatedWaypoint
            : state.selectedWaypoint,
      );

      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update waypoint: $e',
      );
      return false;
    }
  }

  /// Delete a waypoint
  Future<bool> deleteWaypoint(String waypointId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _waypointService.deleteWaypoint(waypointId);

      // Remove from current waypoints list
      final List<Waypoint> updatedWaypoints =
          state.waypoints.where((Waypoint w) => w.id != waypointId).toList();

      state = state.copyWith(
        waypoints: updatedWaypoints,
        isLoading: false,
        clearSelectedWaypoint: state.selectedWaypoint?.id == waypointId,
      );

      return true;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete waypoint: $e',
      );
      return false;
    }
  }

  /// Select a waypoint
  void selectWaypoint(Waypoint? waypoint) {
    state = state.copyWith(selectedWaypoint: waypoint);
  }

  /// Clear selected waypoint
  void clearSelectedWaypoint() {
    state = state.copyWith(clearSelectedWaypoint: true);
  }

  /// Get waypoints by type
  List<Waypoint> getWaypointsByType(WaypointType type) =>
      state.waypoints.where((Waypoint w) => w.type == type).toList();

  /// Find nearby waypoints
  Future<List<Waypoint>> findNearbyWaypoints({
    required String sessionId,
    required LatLng location,
    required double maxDistanceMeters,
    WaypointType? type,
  }) async {
    try {
      return await _waypointService.findNearbyWaypoints(
        sessionId: sessionId,
        location: location,
        maxDistanceMeters: maxDistanceMeters,
        type: type,
      );
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to find nearby waypoints: $e');
      return <Waypoint>[];
    }
  }

  /// Get waypoint statistics
  Future<Map<WaypointType, int>> getWaypointStatistics(String sessionId) async {
    try {
      return await _waypointService.getWaypointStatistics(sessionId);
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to get waypoint statistics: $e');
      return <WaypointType, int>{};
    }
  }

  /// Check if location has good accuracy for waypoint creation
  bool hasGoodLocationAccuracy() => _waypointService.hasGoodLocationAccuracy();

  /// Get current location accuracy description
  String getCurrentLocationAccuracyDescription() =>
      _waypointService.getCurrentLocationAccuracyDescription();

  /// Clear error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for waypoint state management
final NotifierProvider<WaypointNotifier, WaypointState> waypointProvider =
    NotifierProvider<WaypointNotifier, WaypointState>(WaypointNotifier.new);

/// Provider for waypoints filtered by type
final waypointsByTypeProvider =
    Provider.family<List<Waypoint>, WaypointType>((Ref ref, WaypointType type) {
  final WaypointState waypointState = ref.watch(waypointProvider);
  return waypointState.waypoints
      .where((Waypoint waypoint) => waypoint.type == type)
      .toList();
});

/// Provider for waypoint count by type
final waypointCountByTypeProvider =
    Provider.family<int, WaypointType>((Ref ref, WaypointType type) {
  final List<Waypoint> waypoints = ref.watch(waypointsByTypeProvider(type));
  return waypoints.length;
});

/// Provider for total waypoint count
final Provider<int> totalWaypointCountProvider = Provider<int>((Ref ref) {
  final WaypointState waypointState = ref.watch(waypointProvider);
  return waypointState.waypoints.length;
});
