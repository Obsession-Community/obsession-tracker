import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/custom_north_reference.dart';
import 'package:obsession_tracker/core/services/database_service.dart';

/// State for custom North reference management.
@immutable
class CustomNorthState {
  const CustomNorthState({
    this.references = const [],
    this.activeReference,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<CustomNorthReference> references;

  /// The currently active reference. Null means magnetic North mode.
  final CustomNorthReference? activeReference;
  final bool isLoading;
  final String? errorMessage;

  CustomNorthState copyWith({
    List<CustomNorthReference>? references,
    CustomNorthReference? activeReference,
    bool clearActiveReference = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) =>
      CustomNorthState(
        references: references ?? this.references,
        activeReference: clearActiveReference
            ? null
            : (activeReference ?? this.activeReference),
        isLoading: isLoading ?? this.isLoading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomNorthState &&
          runtimeType == other.runtimeType &&
          references == other.references &&
          activeReference == other.activeReference &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      references.hashCode ^
      activeReference.hashCode ^
      isLoading.hashCode ^
      errorMessage.hashCode;
}

/// Notifier for managing custom North references and bearing calculations.
class CustomNorthNotifier extends Notifier<CustomNorthState> {
  @override
  CustomNorthState build() {
    // Load references on creation
    Future.microtask(loadReferences);
    return const CustomNorthState();
  }

  /// Load all saved references from the database.
  Future<void> loadReferences() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = DatabaseService();
      final references = await db.getCustomNorthReferences();
      state = state.copyWith(references: references, isLoading: false);
    } catch (e) {
      debugPrint('Error loading custom north references: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load references: $e',
      );
    }
  }

  /// Add a new custom North reference.
  Future<void> addReference(String name, double lat, double lon) async {
    try {
      final reference = CustomNorthReference.create(
        name: name,
        latitude: lat,
        longitude: lon,
      );
      final db = DatabaseService();
      await db.insertCustomNorthReference(reference);
      state = state.copyWith(
        references: [...state.references, reference],
        clearError: true,
      );
    } catch (e) {
      debugPrint('Error adding custom north reference: $e');
      state = state.copyWith(errorMessage: 'Failed to add reference: $e');
    }
  }

  /// Delete a custom North reference by ID.
  Future<void> deleteReference(String id) async {
    try {
      final db = DatabaseService();
      await db.deleteCustomNorthReference(id);
      final updated = state.references.where((r) => r.id != id).toList();
      state = state.copyWith(
        references: updated,
        clearActiveReference: state.activeReference?.id == id,
        clearError: true,
      );
    } catch (e) {
      debugPrint('Error deleting custom north reference: $e');
      state = state.copyWith(errorMessage: 'Failed to delete reference: $e');
    }
  }

  /// Set the active reference. Pass null to return to magnetic North mode.
  void setActiveReference(String? id) {
    if (id == null) {
      state = state.copyWith(clearActiveReference: true);
      return;
    }
    final ref = state.references.where((r) => r.id == id).firstOrNull;
    if (ref != null) {
      state = state.copyWith(activeReference: ref);
    }
  }

  /// Standard bearing calculation using atan2.
  static double calculateBearingToTarget(
    double fromLat,
    double fromLon,
    double toLat,
    double toLon,
  ) {
    final dLon = (toLon - fromLon) * pi / 180;
    final lat1 = fromLat * pi / 180;
    final lat2 = toLat * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  static const double _earthRadiusMeters = 6371000.0;

  /// Haversine distance calculation.
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }
}

/// Provider for custom North reference state.
final customNorthProvider =
    NotifierProvider<CustomNorthNotifier, CustomNorthState>(
  CustomNorthNotifier.new,
);

/// Convenience: the active custom North reference (null = magnetic mode).
final activeCustomNorthProvider = Provider<CustomNorthReference?>(
  (ref) => ref.watch(customNorthProvider).activeReference,
);
