import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';

/// State for route planning management
@immutable
class RoutePlanningState {
  const RoutePlanningState({
    this.currentRoute,
    this.savedRoutes = const <PlannedRoute>[],
    this.isPlanning = false,
    this.isNavigating = false,
    this.currentInstruction,
    this.nextInstruction,
    this.distanceToNextInstruction = 0.0,
    this.routeProgress = 0.0,
    this.error,
  });

  /// Currently active route
  final PlannedRoute? currentRoute;

  /// List of saved routes
  final List<PlannedRoute> savedRoutes;

  /// Whether route planning is in progress
  final bool isPlanning;

  /// Whether navigation is active
  final bool isNavigating;

  /// Current navigation instruction
  final NavigationInstruction? currentInstruction;

  /// Next navigation instruction
  final NavigationInstruction? nextInstruction;

  /// Distance to next instruction in meters
  final double distanceToNextInstruction;

  /// Route progress (0.0 to 1.0)
  final double routeProgress;

  /// Current error message
  final String? error;

  /// Create a copy with updated properties
  RoutePlanningState copyWith({
    PlannedRoute? currentRoute,
    List<PlannedRoute>? savedRoutes,
    bool? isPlanning,
    bool? isNavigating,
    NavigationInstruction? currentInstruction,
    NavigationInstruction? nextInstruction,
    double? distanceToNextInstruction,
    double? routeProgress,
    String? error,
  }) =>
      RoutePlanningState(
        currentRoute: currentRoute ?? this.currentRoute,
        savedRoutes: savedRoutes ?? this.savedRoutes,
        isPlanning: isPlanning ?? this.isPlanning,
        isNavigating: isNavigating ?? this.isNavigating,
        currentInstruction: currentInstruction ?? this.currentInstruction,
        nextInstruction: nextInstruction ?? this.nextInstruction,
        distanceToNextInstruction:
            distanceToNextInstruction ?? this.distanceToNextInstruction,
        routeProgress: routeProgress ?? this.routeProgress,
        error: error,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoutePlanningState &&
        other.currentRoute == currentRoute &&
        listEquals(other.savedRoutes, savedRoutes) &&
        other.isPlanning == isPlanning &&
        other.isNavigating == isNavigating &&
        other.currentInstruction == currentInstruction &&
        other.nextInstruction == nextInstruction &&
        other.distanceToNextInstruction == distanceToNextInstruction &&
        other.routeProgress == routeProgress &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(
        currentRoute,
        Object.hashAll(savedRoutes),
        isPlanning,
        isNavigating,
        currentInstruction,
        nextInstruction,
        distanceToNextInstruction,
        routeProgress,
        error,
      );
}

/// Notifier for route planning state management
class RoutePlanningNotifier extends Notifier<RoutePlanningState> {
  late final RoutePlanningService _routePlanningService;
  final Distance _distance = const Distance();

  @override
  RoutePlanningState build() {
    _routePlanningService = RoutePlanningService();

    // Note: Don't dispose the singleton service here - it should persist
    // across provider rebuilds to maintain route data

    _initialize();
    return const RoutePlanningState();
  }

  /// Initialize the notifier by loading routes from database
  Future<void> _initialize() async {
    try {
      // Load routes from database asynchronously
      await _routePlanningService.loadRoutes();
      final List<PlannedRoute> savedRoutes = _routePlanningService.savedRoutes;
      state = state.copyWith(savedRoutes: savedRoutes);
    } catch (e) {
      state = state.copyWith(error: 'Failed to initialize route planning: $e');
    }
  }

  /// Plan a new route
  Future<void> planRoute({
    required LatLng startPoint,
    required LatLng endPoint,
    required RoutePlanningAlgorithm algorithm,
    List<Waypoint> waypoints = const [],
    String? name,
    String? description,
  }) async {
    try {
      state = state.copyWith(isPlanning: true);

      final PlannedRoute route = await _routePlanningService.planRoute(
        startPoint: startPoint,
        endPoint: endPoint,
        algorithm: algorithm,
        waypoints: waypoints,
        name: name,
        description: description,
      );

      state = state.copyWith(
        currentRoute: route,
        isPlanning: false,
      );

      debugPrint('Route planned successfully: ${route.name}');
    } catch (e) {
      state = state.copyWith(
        isPlanning: false,
        error: 'Failed to plan route: $e',
      );
    }
  }

  /// Save the current route
  Future<void> saveCurrentRoute() async {
    final PlannedRoute? route = state.currentRoute;
    if (route == null) {
      state = state.copyWith(error: 'No route to save');
      return;
    }

    try {
      await _routePlanningService.saveRoute(route);

      final List<PlannedRoute> updatedRoutes =
          _routePlanningService.savedRoutes;
      state = state.copyWith(
        savedRoutes: updatedRoutes,
      );

      debugPrint('Route saved: ${route.name}');
    } catch (e) {
      state = state.copyWith(error: 'Failed to save route: $e');
    }
  }

  /// Load a saved route
  void loadRoute(String routeId) {
    try {
      final PlannedRoute? route = _routePlanningService.getRoute(routeId);
      if (route == null) {
        state = state.copyWith(error: 'Route not found');
        return;
      }

      state = state.copyWith(
        currentRoute: route,
      );

      debugPrint('Route loaded: ${route.name}');
    } catch (e) {
      state = state.copyWith(error: 'Failed to load route: $e');
    }
  }

  /// Delete a saved route
  Future<void> deleteRoute(String routeId) async {
    try {
      await _routePlanningService.deleteRoute(routeId);

      final List<PlannedRoute> updatedRoutes =
          _routePlanningService.savedRoutes;
      state = state.copyWith(
        savedRoutes: updatedRoutes,
      );

      // Clear current route if it was deleted
      if (state.currentRoute?.id == routeId) {
        state = state.copyWith();
      }

      debugPrint('Route deleted: $routeId');
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete route: $e');
    }
  }

  /// Start navigation for current route
  void startNavigation() {
    final PlannedRoute? route = state.currentRoute;
    if (route == null) {
      state = state.copyWith(error: 'No route to navigate');
      return;
    }

    try {
      final NavigationInstruction? firstInstruction =
          route.instructions.isNotEmpty ? route.instructions.first : null;

      final NavigationInstruction? secondInstruction =
          route.instructions.length > 1 ? route.instructions[1] : null;

      state = state.copyWith(
        isNavigating: true,
        currentInstruction: firstInstruction,
        nextInstruction: secondInstruction,
        routeProgress: 0.0,
        distanceToNextInstruction: secondInstruction?.distance ?? 0.0,
      );

      debugPrint('Navigation started for route: ${route.name}');
    } catch (e) {
      state = state.copyWith(error: 'Failed to start navigation: $e');
    }
  }

  /// Stop navigation
  void stopNavigation() {
    state = state.copyWith(
      isNavigating: false,
      routeProgress: 0.0,
      distanceToNextInstruction: 0.0,
    );

    debugPrint('Navigation stopped');
  }

  /// Update navigation progress based on current location
  void updateNavigationProgress(LatLng currentLocation) {
    final PlannedRoute? route = state.currentRoute;
    if (route == null || !state.isNavigating) return;

    try {
      // Calculate progress along route
      final double progress = _calculateRouteProgress(currentLocation, route);

      // Find current and next instructions
      final NavigationInstructionUpdate instructionUpdate =
          _findCurrentInstructions(currentLocation, route);

      state = state.copyWith(
        routeProgress: progress,
        currentInstruction: instructionUpdate.current,
        nextInstruction: instructionUpdate.next,
        distanceToNextInstruction: instructionUpdate.distanceToNext,
      );
    } catch (e) {
      debugPrint('Error updating navigation progress: $e');
    }
  }

  /// Calculate route progress (0.0 to 1.0)
  double _calculateRouteProgress(LatLng currentLocation, PlannedRoute route) {
    if (route.routePoints.isEmpty) return 0.0;

    double minDistance = double.infinity;
    int closestPointIndex = 0;

    // Find closest point on route
    for (int i = 0; i < route.routePoints.length; i++) {
      final double distance = _distance.as(
        LengthUnit.Meter,
        currentLocation,
        route.routePoints[i],
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // Calculate progress as percentage along route
    return closestPointIndex / (route.routePoints.length - 1);
  }

  /// Find current and next navigation instructions
  NavigationInstructionUpdate _findCurrentInstructions(
    LatLng currentLocation,
    PlannedRoute route,
  ) {
    if (route.instructions.isEmpty) {
      return const NavigationInstructionUpdate(
        current: null,
        next: null,
        distanceToNext: 0.0,
      );
    }

    NavigationInstruction? current;
    NavigationInstruction? next;
    double distanceToNext = 0.0;

    // Find the instruction closest to current location
    double minDistance = double.infinity;
    int currentIndex = 0;

    for (int i = 0; i < route.instructions.length; i++) {
      final NavigationInstruction instruction = route.instructions[i];
      final double distance = _distance.as(
        LengthUnit.Meter,
        currentLocation,
        instruction.position,
      );

      if (distance < minDistance) {
        minDistance = distance;
        currentIndex = i;
      }
    }

    current = route.instructions[currentIndex];

    // Get next instruction
    if (currentIndex < route.instructions.length - 1) {
      next = route.instructions[currentIndex + 1];
      distanceToNext = _distance.as(
        LengthUnit.Meter,
        currentLocation,
        next.position,
      );
    }

    return NavigationInstructionUpdate(
      current: current,
      next: next,
      distanceToNext: distanceToNext,
    );
  }

  /// Clear current route
  void clearCurrentRoute() {
    state = state.copyWith(
      isNavigating: false,
      routeProgress: 0.0,
      distanceToNextInstruction: 0.0,
    );
  }

  /// Clear all saved routes
  Future<void> clearAllRoutes() async {
    try {
      await _routePlanningService.clearRoutes();
      state = state.copyWith(
        savedRoutes: const [],
      );

      debugPrint('All routes cleared');
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear routes: $e');
    }
  }

  /// Load all routes from database
  Future<void> loadAllRoutes() async {
    try {
      await _routePlanningService.loadRoutes();
      final List<PlannedRoute> loadedRoutes = _routePlanningService.savedRoutes;
      state = state.copyWith(savedRoutes: loadedRoutes);
      debugPrint('Loaded ${loadedRoutes.length} routes');
    } catch (e) {
      state = state.copyWith(error: 'Failed to load routes: $e');
    }
  }

  /// Get route statistics
  Map<String, dynamic> getRouteStatistics() {
    final PlannedRoute? route = state.currentRoute;
    if (route == null) return {};

    return {
      'totalDistance': route.formattedDistance,
      'totalDuration': route.formattedDuration,
      'elevationGain': '${route.totalElevationGain.toStringAsFixed(0)}m',
      'difficulty': route.difficultyDescription,
      'segmentCount': route.segments.length,
      'waypointCount': route.waypoints.length,
      'instructionCount': route.instructions.length,
    };
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith();
  }

}

/// Helper class for navigation instruction updates
@immutable
class NavigationInstructionUpdate {
  const NavigationInstructionUpdate({
    required this.current,
    required this.next,
    required this.distanceToNext,
  });

  final NavigationInstruction? current;
  final NavigationInstruction? next;
  final double distanceToNext;
}

/// Provider for route planning state
final NotifierProvider<RoutePlanningNotifier, RoutePlanningState>
    routePlanningProvider =
    NotifierProvider<RoutePlanningNotifier, RoutePlanningState>(
  RoutePlanningNotifier.new,
);

/// Provider for current route
final Provider<PlannedRoute?> currentRouteProvider =
    Provider<PlannedRoute?>((ref) {
  final RoutePlanningState state = ref.watch(routePlanningProvider);
  return state.currentRoute;
});

/// Provider for navigation status
final Provider<bool> isNavigatingProvider = Provider<bool>((ref) {
  final RoutePlanningState state = ref.watch(routePlanningProvider);
  return state.isNavigating;
});

/// Provider for current navigation instruction
final Provider<NavigationInstruction?> currentInstructionProvider =
    Provider<NavigationInstruction?>((ref) {
  final RoutePlanningState state = ref.watch(routePlanningProvider);
  return state.currentInstruction;
});

/// Provider for route statistics
final Provider<Map<String, dynamic>> routeStatisticsProvider =
    Provider<Map<String, dynamic>>((ref) {
  final RoutePlanningNotifier notifier =
      ref.read(routePlanningProvider.notifier);
  return notifier.getRouteStatistics();
});
