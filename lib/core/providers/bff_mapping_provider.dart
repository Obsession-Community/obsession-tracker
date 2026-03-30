import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';

/// State for BFF mapping data
@immutable
class BFFMappingState {
  const BFFMappingState({
    this.landOwnerships = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdateTime,
    this.dataSourceStatus = const [],
  });

  final List<LandOwnership> landOwnerships;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdateTime;
  final List<Map<String, dynamic>> dataSourceStatus;

  BFFMappingState copyWith({
    List<LandOwnership>? landOwnerships,
    bool? isLoading,
    String? error,
    DateTime? lastUpdateTime,
    List<Map<String, dynamic>>? dataSourceStatus,
  }) {
    return BFFMappingState(
      landOwnerships: landOwnerships ?? this.landOwnerships,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      dataSourceStatus: dataSourceStatus ?? this.dataSourceStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BFFMappingState &&
          runtimeType == other.runtimeType &&
          listEquals(landOwnerships, other.landOwnerships) &&
          isLoading == other.isLoading &&
          error == other.error &&
          lastUpdateTime == other.lastUpdateTime &&
          listEquals(dataSourceStatus, other.dataSourceStatus);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(landOwnerships),
        isLoading,
        error,
        lastUpdateTime,
        Object.hashAll(dataSourceStatus),
      );
}

/// Provider for BFF mapping data using GraphQL
class BFFMappingNotifier extends AsyncNotifier<BFFMappingState> {
  final BFFMappingService _mappingService = BFFMappingService.instance;

  @override
  Future<BFFMappingState> build() async {
    // Initialize with empty state
    return const BFFMappingState();
  }

  /// Load land ownership data for a specific geographic area
  Future<void> loadLandOwnershipData({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int limit = 50,
  }) async {
    if (state.isLoading) return;

    state = const AsyncValue.loading();

    try {
      final landOwnerships = await _mappingService.getLandOwnershipData(
        northBound: northBound,
        southBound: southBound,
        eastBound: eastBound,
        westBound: westBound,
        limit: limit,
      );

      state = AsyncValue.data(BFFMappingState(
        landOwnerships: landOwnerships,
        lastUpdateTime: DateTime.now(),
      ));
    } catch (error, stackTrace) {
      debugPrint('Error loading land ownership data: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Search for land ownership by query
  Future<List<LandOwnership>> searchLandOwnership({
    required String query,
    double? latitude,
    double? longitude,
    int limit = 20,
  }) async {
    try {
      return await _mappingService.searchLandOwnership(
        query: query,
        latitude: latitude,
        longitude: longitude,
        limit: limit,
      );
    } catch (error) {
      debugPrint('Error searching land ownership: $error');
      return [];
    }
  }

  /// Get detailed information for a specific land ownership
  Future<LandOwnership?> getLandOwnershipDetails(String id) async {
    try {
      return await _mappingService.getLandOwnershipDetails(id);
    } catch (error) {
      debugPrint('Error getting land ownership details: $error');
      return null;
    }
  }

  /// Load data source status information
  Future<void> loadDataSourceStatus() async {
    try {
      final currentState = state.value ?? const BFFMappingState();

      state = AsyncValue.data(currentState.copyWith(isLoading: true));

      final dataSourceStatus = await _mappingService.getDataSourceStatus();

      state = AsyncValue.data(currentState.copyWith(
        dataSourceStatus: dataSourceStatus,
        isLoading: false,
        lastUpdateTime: DateTime.now(),
      ));
    } catch (error, stackTrace) {
      debugPrint('Error loading data source status: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Trigger data sync for a specific data source (admin operation)
  Future<bool> triggerDataSync({
    required String dataSourceType,
    String? stateCode,
    Map<String, double>? bounds,
  }) async {
    try {
      final success = await _mappingService.triggerDataSync(
        dataSourceType: dataSourceType,
        stateCode: stateCode,
        bounds: bounds,
      );

      if (success) {
        // Refresh data source status after sync
        await loadDataSourceStatus();
      }

      return success;
    } catch (error) {
      debugPrint('Error triggering data sync: $error');
      return false;
    }
  }

  /// Clear current land ownership data
  void clearData() {
    state = const AsyncValue.data(BFFMappingState());
  }

  /// Refresh current data
  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState?.landOwnerships.isNotEmpty == true) {
      // If we have previous data, clear it and reload
      clearData();
    }
    await loadDataSourceStatus();
  }
}

/// Provider for BFF mapping functionality
final bffMappingProvider =
    AsyncNotifierProvider<BFFMappingNotifier, BFFMappingState>(
  BFFMappingNotifier.new,
);

/// Convenience provider for accessing just the BFF land ownership data
final bffLandOwnershipDataProvider = Provider<List<LandOwnership>>((ref) {
  final state = ref.watch(bffMappingProvider);
  return state.value?.landOwnerships ?? [];
});

/// Provider for data source status
final dataSourceStatusProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final state = ref.watch(bffMappingProvider);
  return state.value?.dataSourceStatus ?? [];
});

/// Provider for BFF mapping loading state
final bffMappingLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(bffMappingProvider);
  return state.isLoading || state.value?.isLoading == true;
});
