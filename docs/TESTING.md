# Testing Guide

## Overview

Obsession Tracker uses Flutter's testing framework with `flutter test` for unit tests and `flutter analyze` for static analysis.

## Running Analysis

```bash
# Static analysis (required before commits)
flutter analyze

# Run with specific options
flutter analyze --no-fatal-infos --no-fatal-warnings
```

**Important**: Per CLAUDE.md, `flutter analyze` must pass with zero issues before any feature is complete.

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/models/waypoint_test.dart

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Test Structure

```text
test/
├── unit/
│   ├── models/         # Data model tests
│   ├── services/       # Service logic tests
│   └── utils/          # Utility function tests
├── widget/             # Widget tests
└── integration/        # Integration tests
```

## Writing Tests

### Unit Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';

void main() {
  group('Waypoint', () {
    test('should create waypoint with valid coordinates', () {
      final waypoint = Waypoint(
        latitude: 45.0,
        longitude: -103.0,
        timestamp: DateTime.now(),
      );

      expect(waypoint.latitude, 45.0);
      expect(waypoint.longitude, -103.0);
    });
  });
}
```

### Widget Test Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/waypoint_marker.dart';

void main() {
  testWidgets('WaypointMarker displays correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WaypointMarker(waypoint: mockWaypoint),
        ),
      ),
    );

    expect(find.byType(WaypointMarker), findsOneWidget);
  });
}
```

## CI/CD Testing

Tests run automatically in GitHub Actions:

```yaml
- name: Analyze
  run: flutter analyze

- name: Test
  run: flutter test --coverage
```

## Test Coverage Goals

| Area | Target |
|------|--------|
| Models | 90% |
| Services | 80% |
| Utils | 90% |
| Widgets | 60% |

---

## Dependency Update Validation

<!-- MACHINE-READABLE: Claude Code parses this block for /update-deps -->
```yaml
# dep-config
project_type: flutter
package_manager: pub

subprojects:
  - name: main
    path: ./
    pre_update:
      - flutter pub get
      - flutter analyze
    post_update:
      - flutter analyze
      # Note: flutter test NOT auto-run per CLAUDE.md rules

commit_message_prefix: "deps(tracker)"
```
