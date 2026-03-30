// Astronomical Data Provider for Sun/Moon Times Feature
// Manages state and recalculates when location changes or at midnight

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/astronomical_data.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/services/astronomical_service.dart';

/// State for astronomical data
@immutable
class AstronomicalState {
  const AstronomicalState({
    this.data,
    this.isLoading = false,
    this.errorMessage,
    this.lastCalculatedDate,
  });

  /// The calculated astronomical data
  final AstronomicalData? data;

  /// Whether calculations are in progress
  final bool isLoading;

  /// Error message if calculation failed
  final String? errorMessage;

  /// The date for which data was last calculated
  final DateTime? lastCalculatedDate;

  /// Whether data is available
  bool get hasData => data != null;

  /// Whether we're waiting for location
  bool get isWaitingForLocation => !hasData && !isLoading && errorMessage == null;

  AstronomicalState copyWith({
    AstronomicalData? data,
    bool? isLoading,
    String? errorMessage,
    DateTime? lastCalculatedDate,
    bool clearError = false,
    bool clearLastCalculatedDate = false,
  }) =>
      AstronomicalState(
        data: data ?? this.data,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        lastCalculatedDate: clearLastCalculatedDate
            ? null
            : (lastCalculatedDate ?? this.lastCalculatedDate),
      );
}

/// Notifier for managing astronomical calculations
class AstronomicalNotifier extends Notifier<AstronomicalState> {
  late final AstronomicalService _service;
  Timer? _midnightTimer;
  bool _isDisposed = false;

  @override
  AstronomicalState build() {
    _service = AstronomicalService();
    _isDisposed = false;

    // Set up midnight timer for date change
    _scheduleMidnightRecalculation();

    // Clean up on dispose
    ref.onDispose(() {
      _isDisposed = true;
      _midnightTimer?.cancel();
    });

    // Watch for location changes and recalculate
    ref.listen<Position?>(currentPositionProvider, (previous, next) {
      if (_isDisposed) return;

      if (next != null) {
        // Check if location changed significantly (more than ~1km)
        if (previous == null ||
            _calculateDistance(previous, next) > 1000 ||
            state.data == null) {
          _calculateForPosition(next);
        }
      }
    });

    // Get initial position if available
    final initialPosition = ref.read(currentPositionProvider);
    if (initialPosition != null) {
      // Use addPostFrameCallback equivalent - schedule after build
      Future.microtask(() {
        if (!_isDisposed) {
          _calculateForPosition(initialPosition);
        }
      });
    }

    return const AstronomicalState();
  }

  /// Calculate distance between two positions in meters
  double _calculateDistance(Position a, Position b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Schedule recalculation at midnight
  void _scheduleMidnightRecalculation() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);

    _midnightTimer = Timer(durationUntilMidnight, () {
      if (_isDisposed) return;

      debugPrint('Astronomical: Midnight reached, recalculating for new day');

      // Recalculate for new day
      final position = ref.read(currentPositionProvider);
      if (position != null) {
        _calculateForPosition(position);
      }

      // Schedule next midnight
      _scheduleMidnightRecalculation();
    });

    debugPrint(
        'Astronomical: Scheduled midnight recalculation in ${durationUntilMidnight.inMinutes} minutes');
  }

  /// Calculate astronomical data for a position
  Future<void> _calculateForPosition(Position position) async {
    if (_isDisposed) return;

    // Check if we already have data for today at a similar location
    final today = DateTime.now();
    if (state.lastCalculatedDate != null &&
        state.data != null &&
        _isSameDay(state.lastCalculatedDate!, today)) {
      // Check if position is close enough (within 1km)
      final existingLat = state.data!.latitude;
      final existingLon = state.data!.longitude;
      final distance = Geolocator.distanceBetween(
        existingLat,
        existingLon,
        position.latitude,
        position.longitude,
      );
      if (distance < 1000) {
        debugPrint(
            'Astronomical: Skipping recalculation - position within 1km of last calculation');
        return;
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final data = _service.calculate(
        latitude: position.latitude,
        longitude: position.longitude,
        date: today,
      );

      if (_isDisposed) return;

      state = state.copyWith(
        data: data,
        isLoading: false,
        lastCalculatedDate: today,
      );

      debugPrint(
          'Astronomical: Calculated for ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
      debugPrint(
          'Astronomical: Sunrise: ${data.sunrise}, Sunset: ${data.sunset}, Moon: ${data.moonPhase.displayName}');
    } catch (e) {
      debugPrint('Astronomical: Calculation error: $e');

      if (_isDisposed) return;

      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to calculate astronomical data: $e',
      );
    }
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Force recalculation (e.g., after time zone change)
  Future<void> refresh() async {
    final position = ref.read(currentPositionProvider);
    if (position != null) {
      // Clear cached date to force recalculation
      state = state.copyWith(clearLastCalculatedDate: true);
      await _calculateForPosition(position);
    }
  }

  /// Calculate for a specific location (for planning purposes)
  Future<AstronomicalData?> calculateForLocation({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) async {
    try {
      return _service.calculate(
        latitude: latitude,
        longitude: longitude,
        date: date,
      );
    } catch (e) {
      debugPrint('Astronomical: Error calculating for location: $e');
      return null;
    }
  }
}

/// Main provider for astronomical data
final astronomicalProvider =
    NotifierProvider<AstronomicalNotifier, AstronomicalState>(
  AstronomicalNotifier.new,
);

/// Convenience provider for just the astronomical data
final astronomicalDataProvider = Provider<AstronomicalData?>((ref) {
  return ref.watch(astronomicalProvider).data;
});

/// Convenience provider for checking if it's golden hour
final isGoldenHourProvider = Provider<bool>((ref) {
  final data = ref.watch(astronomicalDataProvider);
  return data?.isGoldenHour ?? false;
});

/// Convenience provider for checking if it's blue hour
final isBlueHourProvider = Provider<bool>((ref) {
  final data = ref.watch(astronomicalDataProvider);
  return data?.isBlueHour ?? false;
});

/// Convenience provider for the next sun event
final nextSunEventProvider = Provider<({DateTime? time, bool isSunrise})>((ref) {
  final data = ref.watch(astronomicalDataProvider);
  if (data == null) {
    return (time: null, isSunrise: false);
  }
  return (time: data.nextSunEvent, isSunrise: data.isNextEventSunrise);
});

/// Convenience provider for moon phase info
final moonPhaseProvider = Provider<({MoonPhase phase, double illumination})?>((ref) {
  final data = ref.watch(astronomicalDataProvider);
  if (data == null) return null;
  return (phase: data.moonPhase, illumination: data.moonIllumination);
});
