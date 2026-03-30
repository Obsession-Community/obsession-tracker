# Obsession Tracker - Development Guidelines

## Overview

This document establishes coding standards, testing requirements, and development practices for the Obsession Tracker project. These guidelines ensure code quality, maintainability, and alignment with the privacy-first principles.

## Coding Standards

### Dart/Flutter Style Guide

#### General Principles

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable and function names
- Prefer composition over inheritance
- Write self-documenting code with clear intent

#### Naming Conventions

```dart
// Classes: PascalCase
class SessionManager {}
class TrackingService {}

// Functions and variables: camelCase
void startTracking() {}
final double currentLatitude = 0.0;

// Constants: lowerCamelCase with descriptive names
const double defaultTrackingInterval = 5.0;
const String databaseName = 'obsession_tracker.db';

// Private members: prefix with underscore
class _SessionRepository {}
void _validateGpsAccuracy() {}

// Files: snake_case
session_manager.dart
tracking_service.dart
gps_utils.dart
```

#### Code Organization

```dart
// Import order:
// 1. Dart core libraries
import 'dart:async';
import 'dart:io';

// 2. Flutter libraries
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 3. Third-party packages (alphabetical)
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';

// 4. Local imports (alphabetical)
import '../core/constants.dart';
import '../domain/entities/session.dart';
import 'session_repository.dart';
```

### State Management Guidelines

#### Provider Pattern

```dart
// Use ChangeNotifier for simple state
class TrackingProvider extends ChangeNotifier {
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  void startTracking() {
    _isTracking = true;
    notifyListeners();
  }
}

// Use more complex state management for advanced features
class SessionStateNotifier extends StateNotifier<SessionState> {
  SessionStateNotifier() : super(SessionState.initial());

  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true);
    // Implementation
  }
}
```

#### State Guidelines

- Keep state classes immutable
- Use copyWith methods for state updates
- Avoid business logic in UI widgets
- Separate UI state from domain state

### Error Handling

#### Exception Types

```dart
// Custom exceptions for domain logic
class LocationPermissionException implements Exception {
  final String message;
  const LocationPermissionException(this.message);
}

class DatabaseException implements Exception {
  final String message;
  final Exception? originalException;
  const DatabaseException(this.message, [this.originalException]);
}

// Use Result pattern for operations that can fail
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  const Failure(this.message, [this.exception]);
}
```

#### Error Handling Strategy

- Use try-catch blocks for external API calls
- Implement graceful degradation for non-critical features
- Log errors appropriately without exposing sensitive data
- Provide meaningful error messages to users

### Performance Guidelines

#### GPS and Location Services

```dart
// Optimize location updates
class LocationService {
  late LocationSettings _locationSettings;

  void configureLocationSettings() {
    _locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // Minimum distance in meters
    );
  }

  // Use streams for continuous location updates
  Stream<Position> get positionStream =>
      Geolocator.getPositionStream(locationSettings: _locationSettings);
}
```

#### Database Optimization

```dart
// Use transactions for batch operations
Future<void> saveBreadcrumbs(List<Breadcrumb> breadcrumbs) async {
  await _database.transaction((txn) async {
    final batch = txn.batch();
    for (final breadcrumb in breadcrumbs) {
      batch.insert('breadcrumbs', breadcrumb.toMap());
    }
    await batch.commit();
  });
}

// Index frequently queried columns
static const String createBreadcrumbsTable = '''
  CREATE TABLE breadcrumbs (
    id INTEGER PRIMARY KEY,
    session_id INTEGER NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    timestamp INTEGER NOT NULL
  );
  CREATE INDEX idx_breadcrumbs_session ON breadcrumbs(session_id);
  CREATE INDEX idx_breadcrumbs_timestamp ON breadcrumbs(timestamp);
''';
```

#### Memory Management

- Dispose of controllers and streams properly
- Use lazy loading for large datasets
- Implement image caching for photos
- Monitor memory usage in long tracking sessions

## Testing Requirements

### Testing Strategy

#### Test Coverage Requirements

- **Minimum 90% code coverage** for business logic
- **80% coverage** for UI components
- **100% coverage** for critical paths (data loss prevention, privacy)

#### Test Categories

##### Unit Tests

```dart
// Test business logic and utilities
group('SessionManager', () {
  late SessionManager sessionManager;
  late MockRepository mockRepository;

  setUp(() {
    mockRepository = MockRepository();
    sessionManager = SessionManager(mockRepository);
  });

  test('should create new tracking session', () async {
    // Arrange
    const sessionName = 'Test Adventure';

    // Act
    final result = await sessionManager.startSession(sessionName);

    // Assert
    expect(result, isA<Success>());
    verify(mockRepository.saveSession(any)).called(1);
  });
});
```

##### Widget Tests

```dart
// Test UI components
group('TrackingButton', () {
  testWidgets('should display start tracking when not tracking', (tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => TrackingProvider(),
          child: const TrackingButton(),
        ),
      ),
    );

    // Assert
    expect(find.text('Start Tracking'), findsOneWidget);
  });
});
```

##### Integration Tests

```dart
// Test complete workflows
group('Tracking Flow', () {
  testWidgets('should complete full tracking session', (tester) async {
    // Test from start tracking to session save
    await tester.pumpWidget(const MyApp());

    // Start tracking
    await tester.tap(find.byKey(const Key('start_tracking_button')));
    await tester.pumpAndSettle();

    // Verify tracking started
    expect(find.text('Stop Tracking'), findsOneWidget);

    // Stop tracking
    await tester.tap(find.byKey(const Key('stop_tracking_button')));
    await tester.pumpAndSettle();

    // Verify session saved
    expect(find.text('Session Saved'), findsOneWidget);
  });
});
```

### Platform-Specific Testing

#### GPS Testing Strategy

```dart
// Mock GPS for consistent testing
class MockGeolocator extends Mock implements GeolocatorPlatform {
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return Stream.fromIterable([
      Position(
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      ),
    ]);
  }
}
```

#### Battery Testing

- Monitor battery usage during extended tracking
- Test background location services
- Verify power optimization features

#### Performance Benchmarks

```dart
// Performance test for large datasets
test('should handle 10000 waypoints without lag', () async {
  final stopwatch = Stopwatch()..start();

  // Generate test data
  final waypoints = List.generate(10000, (i) => createTestWaypoint(i));

  // Test operation
  await sessionManager.loadWaypoints(waypoints);

  stopwatch.stop();

  // Assert performance target
  expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // <2 seconds
});
```

## Quality Assurance

### Code Review Process

#### Pre-Review Checklist

- [ ] All tests pass locally
- [ ] Code follows style guidelines
- [ ] No sensitive data in commits
- [ ] Performance impact considered
- [ ] Documentation updated if needed

#### Review Focus Areas

1. **Privacy Compliance**: No data leaks or unauthorized sharing
2. **Performance**: GPS battery usage, memory management
3. **Error Handling**: Graceful failure scenarios
4. **Testing**: Adequate test coverage
5. **Architecture**: Clean code principles

### Continuous Integration

#### Required Checks

```yaml
# Example GitHub Actions check
- name: Run Tests
  run: |
    flutter test --coverage
    flutter test integration_test/

- name: Check Coverage
  run: |
    lcov --summary coverage/lcov.info
    # Fail if coverage below 90%

- name: Static Analysis
  run: |
    flutter analyze
    dart format --set-exit-if-changed .
```

### Documentation Standards

#### Code Documentation

```dart
/// Manages GPS tracking sessions for the Obsession Tracker app.
///
/// This service handles starting, stopping, and persisting tracking sessions
/// while maintaining privacy and performance requirements.
class SessionManager {
  /// Starts a new tracking session with the given [name].
  ///
  /// Returns a [Result] containing the created session or an error.
  /// Throws [LocationPermissionException] if GPS permission denied.
  Future<Result<Session>> startSession(String name) async {
    // Implementation
  }
}
```

#### README Guidelines

- Clear setup instructions
- Prerequisites and dependencies
- Build and test commands
- Troubleshooting common issues

#### API Documentation

- Document all public interfaces
- Include usage examples
- Specify error conditions
- Maintain changelog

## Privacy and Security Guidelines

### Data Handling

- Never log GPS coordinates in production
- Encrypt sensitive data at rest
- Implement secure deletion
- Minimize data collection

### Code Security

```dart
// Secure random generation for IDs
import 'dart:math';

class SecurityUtils {
  static final _random = Random.secure();

  static String generateSecureId() {
    return _random.nextInt(1000000).toString();
  }
}
```

### Dependency Management

- Regular security audits of dependencies
- Pin dependency versions
- Monitor for security vulnerabilities
- Use only trusted packages

## Performance Targets

### App Performance

- **Launch Time**: <2 seconds cold start
- **Photo Capture**: <1 second from tap to save
- **Map Rendering**: 60fps during interaction
- **Data Loading**: <500ms for session list

### Battery Performance

- **Active Tracking**: 8+ hours continuous use
- **Background Mode**: Minimal battery drain
- **Idle State**: No background processing

### Memory Usage

- **Baseline**: <50MB without tracking
- **Active Tracking**: <100MB during recording
- **Large Sessions**: Handle 10,000+ points efficiently

## Photo Waypoint Development Patterns (Milestone 3)

### Photo Storage Guidelines

#### UUID-Based File Naming

```dart
// Always use UUID for photo file names to ensure privacy
class PhotoStorageService {
  String generatePhotoFileName() {
    return '${const Uuid().v4()}.jpg';
  }

  String generateThumbnailFileName(String photoId) {
    return '${photoId}_thumb.jpg';
  }
}
```

#### Directory Organization

```dart
// Organize photos by year/month for efficient storage
String getPhotoDirectory(DateTime date) {
  return 'photos/${date.year}/${date.month.toString().padLeft(2, '0')}/';
}
```

### Photo Metadata Patterns

#### Flexible Metadata Storage

```dart
// Use key-value pairs for extensible metadata
class PhotoMetadata {
  final String key;
  final String? value;
  final String type; // 'string', 'number', 'boolean', 'json'

  // Support multiple data types
  T? getValue<T>() {
    switch (type) {
      case 'number':
        return double.tryParse(value ?? '') as T?;
      case 'boolean':
        return (value?.toLowerCase() == 'true') as T?;
      case 'json':
        return jsonDecode(value ?? '{}') as T?;
      default:
        return value as T?;
    }
  }
}
```

#### Privacy-First Metadata Handling

```dart
// Always provide privacy controls for sensitive metadata
class PhotoMetadataService {
  Map<String, dynamic> getFilteredMetadata(
    List<PhotoMetadata> metadata,
    PrivacyLevel privacyLevel
  ) {
    return metadata
        .where((meta) => _isAllowedForPrivacyLevel(meta.key, privacyLevel))
        .fold<Map<String, dynamic>>({}, (map, meta) {
          map[meta.key] = meta.getValue();
          return map;
        });
  }
}
```

### Responsive Design Patterns

#### Adaptive Layout Components

```dart
// Create responsive components that adapt to screen size
class ResponsivePhotoGallery extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return TabletPhotoGallery(); // Master-detail layout
        } else {
          return MobilePhotoGallery(); // Single-column layout
        }
      },
    );
  }
}
```

#### Breakpoint Management

```dart
// Define consistent breakpoints across the app
class ScreenBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobile &&
      MediaQuery.of(context).size.width < desktop;
}
```

### Photo Performance Patterns

#### Memory-Efficient Image Loading

```dart
// Use progressive loading for large images
class ProgressiveImageLoader extends StatefulWidget {
  final String imagePath;
  final String? thumbnailPath;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: _loadThumbnailFirst(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _buildProgressiveImage(snapshot.data!);
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

#### Image Caching Strategy

```dart
// Implement intelligent caching for photo thumbnails
class PhotoCacheManager {
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB

  Future<File?> getCachedThumbnail(String photoId) async {
    final cacheFile = await _getCacheFile(photoId);
    if (await cacheFile.exists()) {
      await _updateAccessTime(cacheFile);
      return cacheFile;
    }
    return null;
  }
}
```

### Database Migration Patterns

#### Schema Version Management

```dart
// Handle database migrations gracefully
class DatabaseMigrationService {
  Future<void> migrateToVersion2(Database db) async {
    await db.transaction((txn) async {
      // Create new tables
      await txn.execute(createPhotoWaypointsTable);
      await txn.execute(createPhotoMetadataTable);

      // Create indexes for performance
      await txn.execute(createPhotoIndexes);

      // Migrate existing data if needed
      await _migrateExistingPhotoReferences(txn);
    });
  }
}
```

### Privacy Implementation Patterns

#### Location Fuzzing

```dart
// Implement configurable location fuzzing
class LocationFuzzer {
  static LatLng fuzzLocation(LatLng original, FuzzLevel level) {
    final fuzzAmount = _getFuzzAmount(level);
    final random = Random.secure();

    return LatLng(
      original.latitude + (random.nextDouble() - 0.5) * fuzzAmount,
      original.longitude + (random.nextDouble() - 0.5) * fuzzAmount,
    );
  }
}
```

#### EXIF Data Handling

```dart
// Provide granular control over EXIF data
class ExifManager {
  Future<void> stripSensitiveExif(String imagePath) async {
    final exifData = await readExifFromBytes(await File(imagePath).readAsBytes());

    // Remove GPS and other sensitive data
    exifData.removeWhere((key, value) =>
        key.startsWith('GPS') ||
        key.contains('Location') ||
        _isSensitiveTag(key));

    await writeExifToFile(imagePath, exifData);
  }
}
```

### Testing Patterns for Photo Features

#### Photo Service Testing

```dart
// Test photo operations with mock file system
group('PhotoStorageService', () {
  late PhotoStorageService service;
  late MockFileSystem mockFileSystem;

  setUp(() {
    mockFileSystem = MockFileSystem();
    service = PhotoStorageService(fileSystem: mockFileSystem);
  });

  test('should generate unique photo file names', () {
    final fileName1 = service.generatePhotoFileName();
    final fileName2 = service.generatePhotoFileName();

    expect(fileName1, isNot(equals(fileName2)));
    expect(fileName1, matches(RegExp(r'^[a-f0-9-]+\.jpg$')));
  });
});
```

#### Responsive Layout Testing

```dart
// Test responsive layouts across different screen sizes
group('ResponsivePhotoGallery', () {
  testWidgets('should show tablet layout on large screens', (tester) async {
    await tester.binding.setSurfaceSize(Size(1000, 800)); // Tablet size

    await tester.pumpWidget(
      MaterialApp(home: ResponsivePhotoGallery()),
    );

    expect(find.byType(TabletPhotoGallery), findsOneWidget);
    expect(find.byType(MobilePhotoGallery), findsNothing);
  });
});
```

### Performance Monitoring

#### Photo-Specific Metrics

```dart
// Monitor photo-related performance metrics
class PhotoPerformanceMonitor {
  static void trackPhotoCapture(Duration captureTime) {
    if (captureTime.inMilliseconds > 1000) {
      debugPrint('WARNING: Photo capture took ${captureTime.inMilliseconds}ms');
    }
  }

  static void trackGalleryLoad(int photoCount, Duration loadTime) {
    final photosPerSecond = photoCount / loadTime.inSeconds;
    if (photosPerSecond < 10) {
      debugPrint('WARNING: Gallery loading slowly: $photosPerSecond photos/sec');
    }
  }
}
```

These guidelines ensure the Obsession Tracker maintains high quality, performance, and privacy standards throughout development, with specific focus on the photo waypoint system introduced in Milestone 3.
