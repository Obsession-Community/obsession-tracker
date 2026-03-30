import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/background_location_service.dart';

/// Example usage of the BackgroundLocationService
///
/// This demonstrates how to integrate background location tracking
/// into the Obsession Tracker application.
class BackgroundLocationExample {
  final BackgroundLocationService _backgroundLocationService =
      BackgroundLocationService();

  /// Start background location tracking with default settings
  Future<void> startBackgroundTracking() async {
    try {
      await _backgroundLocationService.startBackgroundTracking(
        minimumDistanceMeters: 10.0, // Only update if moved 10+ meters
      );

      debugPrint('Background location tracking started successfully');
    } catch (e) {
      debugPrint('Failed to start background tracking: $e');
      rethrow;
    }
  }

  /// Stop background location tracking
  Future<void> stopBackgroundTracking() async {
    try {
      await _backgroundLocationService.stopBackgroundTracking();
      debugPrint('Background location tracking stopped successfully');
    } catch (e) {
      debugPrint('Failed to stop background tracking: $e');
      rethrow;
    }
  }

  /// Check if background tracking is currently active
  bool get isTrackingActive =>
      _backgroundLocationService.isBackgroundTrackingActive;

  /// Get current update interval
  int get updateInterval => _backgroundLocationService.currentUpdateInterval;

  /// Start background tracking with custom settings for different scenarios
  Future<void> startTrackingForActivity({
    required String activityType,
  }) async {
    int interval;
    double distance;

    switch (activityType.toLowerCase()) {
      case 'hiking':
        interval = 60; // 1 minute intervals for hiking
        distance = 20.0; // 20 meter minimum distance
        break;
      case 'cycling':
        interval = 30; // 30 second intervals for cycling
        distance = 50.0; // 50 meter minimum distance
        break;
      case 'driving':
        interval = 15; // 15 second intervals for driving
        distance = 100.0; // 100 meter minimum distance
        break;
      case 'stationary':
        interval = 300; // 5 minute intervals when stationary
        distance = 5.0; // 5 meter minimum distance
        break;
      default:
        interval = 30; // Default 30 seconds
        distance = 10.0; // Default 10 meters
    }

    await _backgroundLocationService.startBackgroundTracking(
      updateIntervalSeconds: interval,
      minimumDistanceMeters: distance,
    );

    debugPrint('Background tracking started for $activityType activity');
  }
}
