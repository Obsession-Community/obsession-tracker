# Obsession Tracker - API Documentation

## Overview

This document outlines the internal API architecture and future external API integrations for Obsession Tracker. The app follows a privacy-first approach with local-only data storage initially, with optional cloud services introduced in later milestones.

## Internal API Architecture

### Core Services

#### Location Service API
```dart
abstract class LocationService {
  /// Stream of position updates during tracking
  Stream<Position> get positionStream;

  /// Get current location once
  Future<Position> getCurrentPosition();

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled();

  /// Request location permissions
  Future<LocationPermission> requestPermission();

  /// Configure location settings for tracking
  void configureSettings(LocationSettings settings);
}
```

#### Session Management API
```dart
abstract class SessionRepository {
  /// Create a new tracking session
  Future<Result<Session>> createSession(String name);

  /// Get all sessions
  Future<List<Session>> getAllSessions();

  /// Get session by ID
  Future<Session?> getSessionById(int id);

  /// Update session
  Future<Result<void>> updateSession(Session session);

  /// Delete session and all associated data
  Future<Result<void>> deleteSession(int sessionId);

  /// Get active session
  Future<Session?> getActiveSession();
}
```

#### Breadcrumb Tracking API
```dart
abstract class BreadcrumbRepository {
  /// Add breadcrumb point to session
  Future<Result<void>> addBreadcrumb(int sessionId, Breadcrumb breadcrumb);

  /// Add multiple breadcrumbs in batch
  Future<Result<void>> addBreadcrumbs(int sessionId, List<Breadcrumb> breadcrumbs);

  /// Get all breadcrumbs for session
  Future<List<Breadcrumb>> getBreadcrumbs(int sessionId);

  /// Get breadcrumbs with pagination
  Future<List<Breadcrumb>> getBreadcrumbsPaged(
    int sessionId,
    int offset,
    int limit
  );

  /// Get breadcrumbs in time range
  Future<List<Breadcrumb>> getBreadcrumbsInRange(
    int sessionId,
    DateTime startTime,
    DateTime endTime
  );
}
```

#### Waypoint Management API
```dart
abstract class WaypointRepository {
  /// Create waypoint at location
  Future<Result<Waypoint>> createWaypoint(CreateWaypointRequest request);

  /// Get all waypoints for session
  Future<List<Waypoint>> getWaypoints(int sessionId);

  /// Update waypoint
  Future<Result<void>> updateWaypoint(Waypoint waypoint);

  /// Delete waypoint
  Future<Result<void>> deleteWaypoint(int waypointId);

  /// Search waypoints by text
  Future<List<Waypoint>> searchWaypoints(String query);

  /// Filter waypoints by type
  Future<List<Waypoint>> filterWaypointsByType(WaypointType type);
}
```

### Data Models

#### Core Entities
```dart
class Session {
  final int? id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final SessionMetadata metadata;

  const Session({
    this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    required this.isActive,
    required this.metadata,
  });
}

class Breadcrumb {
  final int? id;
  final int sessionId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  const Breadcrumb({
    this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.heading,
    this.speed,
    required this.timestamp,
  });
}

class Waypoint {
  final int? id;
  final int sessionId;
  final double latitude;
  final double longitude;
  final WaypointType type;
  final String? name;
  final String? notes;
  final String? photoPath;
  final String? voiceNotePath;
  final DateTime timestamp;

  const Waypoint({
    this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.name,
    this.notes,
    this.photoPath,
    this.voiceNotePath,
    required this.timestamp,
  });
}
```

### Export/Import API (Milestone 5)

#### Export Service
```dart
abstract class ExportService {
  /// Export session as GPX file
  Future<Result<File>> exportAsGpx(int sessionId, ExportOptions options);

  /// Export session as KML file
  Future<Result<File>> exportAsKml(int sessionId, ExportOptions options);

  /// Export session data as CSV
  Future<Result<File>> exportAsCsv(int sessionId, ExportOptions options);

  /// Export session as PDF report
  Future<Result<File>> exportAsPdf(int sessionId, ExportOptions options);

  /// Export encrypted session file
  Future<Result<File>> exportEncrypted(int sessionId, String password);
}

class ExportOptions {
  final bool includePhotos;
  final bool includeNotes;
  final bool includeVoiceNotes;
  final bool anonymizeData;
  final LocationPrecision precision;
  final DateRange? dateRange;

  const ExportOptions({
    this.includePhotos = true,
    this.includeNotes = true,
    this.includeVoiceNotes = true,
    this.anonymizeData = false,
    this.precision = LocationPrecision.full,
    this.dateRange,
  });
}
```

#### Import Service
```dart
abstract class ImportService {
  /// Import GPX file
  Future<Result<ImportResult>> importGpx(File gpxFile);

  /// Import geotagged photos
  Future<Result<ImportResult>> importPhotos(List<File> photoFiles);

  /// Import encrypted session file
  Future<Result<ImportResult>> importEncrypted(File encryptedFile, String password);

  /// Merge imported data with existing session
  Future<Result<void>> mergeWithSession(int sessionId, ImportResult data);
}
```

## External API Integrations

### Weather Service Integration (Milestone 10)

#### Weather API Interface
```dart
abstract class WeatherService {
  /// Get current weather for location
  Future<Result<WeatherData>> getCurrentWeather(double lat, double lon);

  /// Get weather forecast
  Future<Result<List<WeatherData>>> getForecast(
    double lat,
    double lon,
    int days
  );

  /// Get historical weather for session
  Future<Result<WeatherData>> getHistoricalWeather(
    double lat,
    double lon,
    DateTime timestamp
  );
}

class WeatherData {
  final double temperature;
  final String condition;
  final double humidity;
  final double windSpeed;
  final double windDirection;
  final double pressure;
  final double visibility;
  final DateTime timestamp;

  const WeatherData({
    required this.temperature,
    required this.condition,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.pressure,
    required this.visibility,
    required this.timestamp,
  });
}
```

### External Device Integration (Milestone 10)

#### Garmin Device API
```dart
abstract class GarminService {
  /// Connect to Garmin device
  Future<Result<void>> connect();

  /// Sync activities from device
  Future<Result<List<GarminActivity>>> syncActivities();

  /// Import Garmin track as session
  Future<Result<Session>> importGarminTrack(GarminActivity activity);

  /// Check device connection status
  Future<bool> isConnected();
}

class GarminActivity {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final List<GarminTrackPoint> trackPoints;
  final ActivityType type;

  const GarminActivity({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.trackPoints,
    required this.type,
  });
}
```

### Cloud Sync API (Milestone 9)

#### Sync Service Interface
```dart
abstract class SyncService {
  /// Initialize cloud sync with end-to-end encryption
  Future<Result<void>> initialize(String userKey);

  /// Sync sessions to cloud
  Future<Result<SyncResult>> syncToCloud();

  /// Sync sessions from cloud
  Future<Result<SyncResult>> syncFromCloud();

  /// Share session with read-only access
  Future<Result<ShareLink>> shareSession(
    int sessionId,
    ShareOptions options
  );

  /// Revoke session share
  Future<Result<void>> revokeShare(String shareId);
}

class ShareOptions {
  final Duration? expiration;
  final String? password;
  final bool allowDownload;
  final LocationPrecision precision;

  const ShareOptions({
    this.expiration,
    this.password,
    this.allowDownload = false,
    this.precision = LocationPrecision.reduced,
  });
}
```

### Map Tile Services

#### Map Provider Interface
```dart
abstract class MapTileProvider {
  /// Get tile URL for coordinates
  String getTileUrl(int x, int y, int zoom);

  /// Download and cache tile
  Future<Result<void>> cacheTile(int x, int y, int zoom);

  /// Download tiles for region
  Future<Result<void>> cacheRegion(BoundingBox region, int maxZoom);

  /// Get cached tile
  Future<File?> getCachedTile(int x, int y, int zoom);

  /// Clear tile cache
  Future<void> clearCache();
}

// Supported map providers
class OpenStreetMapProvider implements MapTileProvider {
  // OpenStreetMap implementation
}

class SatelliteMapProvider implements MapTileProvider {
  // Satellite imagery implementation
}

class TopographicMapProvider implements MapTileProvider {
  // Topographic map implementation
}
```

## Privacy and Security APIs

### Encryption Service (Milestone 6)
```dart
abstract class EncryptionService {
  /// Initialize encryption with user key
  Future<Result<void>> initialize(String userKey);

  /// Encrypt data
  Future<Result<EncryptedData>> encrypt(String data);

  /// Decrypt data
  Future<Result<String>> decrypt(EncryptedData encryptedData);

  /// Encrypt file
  Future<Result<File>> encryptFile(File file);

  /// Decrypt file
  Future<Result<File>> decryptFile(File encryptedFile);

  /// Generate secure random key
  String generateSecureKey();
}
```

### Authentication Service (Milestone 6)
```dart
abstract class AuthenticationService {
  /// Setup biometric authentication
  Future<Result<void>> setupBiometric();

  /// Authenticate with biometrics
  Future<Result<bool>> authenticateWithBiometric();

  /// Setup PIN authentication
  Future<Result<void>> setupPin(String pin);

  /// Authenticate with PIN
  Future<Result<bool>> authenticateWithPin(String pin);

  /// Check if authentication is required
  bool isAuthenticationRequired();

  /// Lock application
  void lockApp();
}
```

## Error Handling

### Standard Error Types
```dart
// Base error class
abstract class ObsessionError {
  final String message;
  final String? code;
  final dynamic originalError;

  const ObsessionError(this.message, {this.code, this.originalError});
}

// Location-related errors
class LocationPermissionDeniedError extends ObsessionError {
  const LocationPermissionDeniedError()
      : super('Location permission denied', code: 'LOCATION_PERMISSION_DENIED');
}

class LocationServiceDisabledError extends ObsessionError {
  const LocationServiceDisabledError()
      : super('Location service disabled', code: 'LOCATION_SERVICE_DISABLED');
}

// Database errors
class DatabaseError extends ObsessionError {
  const DatabaseError(String message, {dynamic originalError})
      : super(message, code: 'DATABASE_ERROR', originalError: originalError);
}

// Network errors (for cloud features)
class NetworkError extends ObsessionError {
  const NetworkError(String message)
      : super(message, code: 'NETWORK_ERROR');
}

// Encryption errors
class EncryptionError extends ObsessionError {
  const EncryptionError(String message)
      : super(message, code: 'ENCRYPTION_ERROR');
}
```

## API Versioning

### Internal API Versioning
- Database schema migrations for data compatibility
- Backward-compatible API changes
- Deprecation warnings for breaking changes

### External API Versioning
- RESTful API versioning for cloud services
- Client SDK versioning for external integrations
- Feature flags for experimental APIs

## Rate Limiting and Performance

### Internal Rate Limiting
- GPS update frequency controls (5-30 seconds configurable)
- Database batch operation limits
- Photo capture throttling

### External API Limits
- Weather API: 1000 requests/day
- Map tile downloads: Region size limits
- Cloud sync: Data volume limits per user

This API documentation serves as the foundation for implementing Obsession Tracker's features while maintaining privacy, performance, and extensibility requirements.
