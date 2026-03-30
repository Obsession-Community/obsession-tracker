import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/services/route_import_service.dart';

/// State for imported routes
class ImportedRouteState {
  const ImportedRouteState({
    this.routes = const [],
    this.selectedRoute,
    this.isLoading = false,
    this.error,
  });

  final List<ImportedRoute> routes;
  final ImportedRoute? selectedRoute;
  final bool isLoading;
  final String? error;

  ImportedRouteState copyWith({
    List<ImportedRoute>? routes,
    ImportedRoute? selectedRoute,
    bool clearSelectedRoute = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ImportedRouteState(
      routes: routes ?? this.routes,
      selectedRoute:
          clearSelectedRoute ? null : selectedRoute ?? this.selectedRoute,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Notifier for managing imported routes
class ImportedRouteNotifier extends Notifier<ImportedRouteState> {
  late final RouteImportService _routeImportService;

  @override
  ImportedRouteState build() {
    _routeImportService = RouteImportService();
    return const ImportedRouteState();
  }

  /// Load all imported routes
  Future<void> loadRoutes() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final routes = await _routeImportService.getAllRoutes();
      state = state.copyWith(routes: routes, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Select a route for display
  Future<void> selectRoute(String routeId) async {
    state = state.copyWith(isLoading: true);

    try {
      final route = await _routeImportService.getRouteById(routeId);
      state = state.copyWith(
        selectedRoute: route,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear the selected route
  void clearSelectedRoute() {
    state = state.copyWith(clearSelectedRoute: true);
  }

  /// Delete a route
  Future<void> deleteRoute(String routeId) async {
    try {
      await _routeImportService.deleteRoute(routeId);

      // Remove from local state
      final updatedRoutes = state.routes.where((r) => r.id != routeId).toList();

      // Clear selection if the deleted route was selected
      final clearSelected = state.selectedRoute?.id == routeId;

      state = state.copyWith(
        routes: updatedRoutes,
        clearSelectedRoute: clearSelected,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Update route metadata
  Future<void> updateRoute(ImportedRoute route) async {
    try {
      await _routeImportService.updateRoute(route);

      // Update local state
      final updatedRoutes = state.routes.map((r) {
        return r.id == route.id ? route : r;
      }).toList();

      // Update selected route if it matches
      final updatedSelected =
          state.selectedRoute?.id == route.id ? route : state.selectedRoute;

      state = state.copyWith(
        routes: updatedRoutes,
        selectedRoute: updatedSelected,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Import a new route
  Future<void> importRoute(ImportedRoute route) async {
    // Add to local state immediately (it's already been imported by the service)
    final updatedRoutes = [route, ...state.routes];
    state = state.copyWith(routes: updatedRoutes);
  }

  /// Refresh routes
  Future<void> refresh() async {
    await loadRoutes();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for imported routes
final importedRouteProvider =
    NotifierProvider<ImportedRouteNotifier, ImportedRouteState>(
        ImportedRouteNotifier.new);

/// Provider for just the selected route (convenience)
final selectedRouteProvider = Provider<ImportedRoute?>((ref) {
  return ref.watch(importedRouteProvider).selectedRoute;
});

/// Provider for checking if a route is selected
final hasSelectedRouteProvider = Provider<bool>((ref) {
  return ref.watch(importedRouteProvider).selectedRoute != null;
});
