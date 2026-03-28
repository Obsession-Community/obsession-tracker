import 'package:flutter_test/flutter_test.dart';

// Import all test files
// Core Models
import 'core/models/breadcrumb_test.dart' as breadcrumb_tests;
import 'core/models/tracking_session_test.dart' as tracking_session_tests;
import 'core/models/waypoint_test.dart' as waypoint_tests;
// Core Providers
import 'core/providers/compass_provider_test.dart' as compass_provider_tests;
import 'core/providers/location_provider_test.dart' as location_provider_tests;

/// Comprehensive test runner for all Obsession Tracker tests
///
/// This file imports and runs all unit tests for the Obsession Tracker app.
///
/// Usage:
/// - Run all tests: flutter test test/test_runner.dart
/// - Run with coverage: flutter test --coverage test/test_runner.dart
void main() {
  group('🎯 Obsession Tracker - Test Suite', () {
    group('🏗️ Core Layer Tests', () {
      group('📦 Models', () {
        breadcrumb_tests.main();
        tracking_session_tests.main();
        waypoint_tests.main();
      });

      group('🔄 Providers', () {
        compass_provider_tests.main();
        location_provider_tests.main();
      });
    });
  });
}
