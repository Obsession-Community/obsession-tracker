# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Commit Message Rules

**Do NOT include the following in commit messages:**

- `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- `Co-Authored-By: Claude ...` or any co-author attribution

Just write a normal commit message describing the changes.

## ⚠️ CRITICAL: Always Use Feature Branches

**NEVER work directly on `main`. ALL work must be done in feature branches.**

Before starting any work:

```bash
git checkout main
git pull origin main
git checkout -b feature/descriptive-name
```

**Branch naming:** `feature/`, `fix/`, `refactor/`, `docs/` prefixes.

After completing work, commit to the feature branch, push, and create a PR to
merge into `main`.

## Project Overview

Obsession Tracker is a privacy-first GPS tracking app for treasure hunters,
explorers, and adventurers. Built with Flutter, it emphasizes offline
functionality, local data storage, and user privacy.

## ⚠️ IMPORTANT: Development Workflow Rules

**DO NOT run `flutter run` or start the Flutter app** - The user will run
Flutter in their own terminal. You should:

- ✅ Make code changes and edits
- ✅ Analyze code and provide suggestions
- ✅ Run tests with `flutter test` if explicitly requested
- ✅ Run analysis tools like `flutter analyze`
- ❌ **NEVER** run `flutter run` - the user manages this themselves

## Essential Commands

### Development

- **Run the app**: `flutter run` (**USER ONLY - do not run this**)
- **Run on specific platform**: `flutter run -d ios` or `flutter run -d android`
  (**USER ONLY**)
- **Install dependencies**: `flutter pub get`

### Testing

- **Run all tests**: `flutter test`
- **Run specific test file**:
  `flutter test test/core/services/location_service_test.dart`
- **Run test suite**: `flutter test test/test_runner.dart`
- **Run with coverage**: `flutter test --coverage`
- **Run integration tests**: `flutter test integration_test/`

### Building

- **Build Android**: `./scripts/build.sh -p android -t release`
- **Build iOS**: `./scripts/build.sh -p ios -t release`
- **Build all platforms**: `./scripts/build.sh -p all -t release`
- **Clean build**: `./scripts/build.sh -p android -t release -c`
- **Debug build**: `./scripts/build.sh -p android -t debug`

### Code Quality

- **Analyze code**: `flutter analyze`
- **Format code**: `dart format .`
- **Check formatting**: `dart format --set-exit-if-changed .`

### Fastlane (App Store Deployment)

See **[docs/FASTLANE_GUIDE.md](docs/FASTLANE_GUIDE.md)** for complete fastlane
documentation.

Quick reference:

```bash
# iOS
bundle exec fastlane ios screenshots_generate && bundle exec fastlane ios screenshots_upload
bundle exec fastlane ios beta && bundle exec fastlane ios submit_for_review

# macOS (screenshots require manual capture - see docs)
bundle exec fastlane mac beta && bundle exec fastlane mac submit_for_review

# Android
bundle exec fastlane android screenshots_generate && bundle exec fastlane android screenshots_upload
bundle exec fastlane android beta build_number:XX && bundle exec fastlane android promote
```

## Architecture Overview

The project follows Clean Architecture with clear separation of concerns:

```
obsession-tracker/
├── lib/                  # Flutter application code
│   ├── core/            # Shared utilities, services, and base components
│   │   ├── models/      # Core data models (TrackingSession, Waypoint, etc.)
│   │   ├── providers/   # State management providers
│   │   ├── services/    # Platform services (location, database, photo storage)
│   │   ├── theme/       # App theming and styling
│   │   └── widgets/     # Reusable UI components
│   ├── features/        # Feature modules
│   │   ├── home/       # Home screen
│   │   ├── map/        # Map visualization
│   │   ├── sessions/   # Session management
│   │   ├── statistics/ # Statistics display
│   │   ├── tracking/   # GPS tracking
│   │   └── waypoints/  # Waypoint management
│   └── main.dart       # App entry point
├── server/              # Node.js API (tracker-api)
│   ├── src/            # TypeScript source code
│   │   ├── routes/     # API endpoints (devices, subscriptions, downloads)
│   │   ├── db/         # Database schema and queries
│   │   └── middleware/ # Auth and validation middleware
│   ├── Dockerfile      # Container configuration
│   └── package.json    # Node dependencies
├── test/               # Flutter unit and widget tests
└── integration_test/   # Flutter integration tests
```

### Key Services

**Flutter Mobile App Services**:

1. **DatabaseService** (`lib/core/services/database_service.dart`): SQLite
   database management with schema v2
2. **LocationService** (`lib/core/services/location_service.dart`): GPS tracking
   and location management
3. **PhotoStorageService** (`lib/core/services/photo_storage_service.dart`):
   UUID-based privacy-first photo storage
4. **BackgroundLocationService**
   (`lib/core/services/background_location_service.dart`): Platform-specific
   background tracking
5. **RoutePlanningService** (`lib/core/services/route_planning_service.dart`):
   Route creation, waypoint management, and path calculation
6. **RouteImportService** (`lib/core/services/route_import_service.dart`):
   GPX/KML file import with automatic conversion to PlannedRoute format
7. **SubscriptionService** (`lib/core/services/subscription_service.dart`):
   Direct Apple StoreKit / Google Play Billing integration for premium
   subscriptions
8. **NhpDownloadService** (`lib/core/services/nhp_download_service.dart`):
   NHP-protected premium state data downloads
9. **DeviceRegistrationService**
   (`lib/core/services/device_registration_service.dart`): Device registration
   with tracker-api
10. **DeviceIdService** (`lib/core/services/device_id_service.dart`): Consistent
    device identifier for subscriptions

**Backend API (tracker-api)**:

- See `server/README.md` for complete tracker-api documentation
- Node.js/TypeScript REST API running on DigitalOcean Droplet
- Handles device registration, subscription validation, and download
  authentication

### State Management

The app uses Riverpod for state management with providers for:

- Location tracking state
- Session management
- Photo waypoints
- App settings
- Map layers and gestures
- Land ownership data and property boundaries
- BFF connection and API response caching

### Database Schema

The app uses SQLite with the following main tables:

- `sessions`: Tracking session metadata
- `breadcrumbs`: GPS location points
- `waypoints`: Points of interest
- `photo_waypoints`: Photo attachments
- `photo_metadata`: Extensible photo metadata
- `session_statistics`: Real-time tracking statistics

## Development Guidelines

### Adding New Features

1. Follow the existing architecture pattern:
   - Create models in `core/models/`
   - Add services in `core/services/`
   - Create providers in `core/providers/`
   - Build UI in appropriate `features/` subdirectory

2. Maintain privacy-first principles:
   - Store all data locally by default
   - Use UUID-based file naming for photos
   - No analytics or tracking
   - Optional features should be opt-in

3. Ensure offline functionality:
   - Core features must work without internet
   - Cache necessary data for offline use
   - Handle network errors gracefully

### Testing Requirements

The project follows a focused testing approach that prioritizes valuable,
maintainable tests:

**✅ Write These Tests:**

- **Model Tests**: Constructor validation, serialization, business rule
  enforcement
- **Provider Tests**: State management behavior, error handling, state
  transitions
- **Pure Function Tests**: Calculations, utilities, transformations

**❌ Avoid These Tests:**

- Complex widget/UI tests requiring extensive mocking
- Integration tests with external dependencies (GPS, file system)
- Performance simulation tests
- Tests that duplicate coverage or test implementation details

**Current Test Suite:**

- 100 focused unit tests (17 provider tests, 83 model tests)
- 100% pass rate, ~1 second execution time
- Easy maintenance - tests rarely need updates when code changes

**Test Coverage Philosophy:**

- High confidence in core business logic (>95%)
- Simple, fast-running tests
- Focus on behavior over implementation details

### Performance Considerations

- Optimize GPS polling for battery life
- Lazy load large datasets
- Compress photos before storage
- Use pagination for long lists
- Monitor memory usage in long sessions

## Common Development Tasks

### Adding a New Waypoint Type

1. Add the type to `WaypointType` enum in `lib/core/models/waypoint.dart`
2. Create SVG icon in `assets/icons/waypoints/`
3. Update `WaypointIconService` to include the new icon
4. Add localization strings if needed

### Implementing a New Export Format

1. Create exporter in `lib/core/services/`
2. Add to export options in session detail screen
3. Include appropriate privacy controls (location fuzzing, etc.)
4. Write tests for the export functionality

### Working with Photos

1. Use `PhotoStorageService` for all file operations
2. Always generate thumbnails for gallery display
3. Store metadata in the database, not EXIF
4. Implement privacy controls for location data

### ⚠️ IMPORTANT: File Path Handling

**Photo and media file paths are stored as RELATIVE paths in the database**, not
absolute paths.

**Database stores paths like:**

```text
photos/sessions/{session_id}/originals/{uuid}.jpg
photos/sessions/{session_id}/thumbnails/{uuid}_thumb.jpg
voice_notes/{session_id}/{uuid}.m4a
```

**To access files, you MUST prepend the app's documents directory:**

```dart
final documentsDir = await getApplicationDocumentsDirectory();
final absolutePath = '${documentsDir.path}/$relativePath';
```

**Helper pattern for resolving paths:**

```dart
String resolveFilePath(String filePath, String documentsPath) {
  if (filePath.startsWith('/')) {
    // Already absolute
    return filePath;
  }
  // Relative path - prepend documents directory
  return '$documentsPath/$filePath';
}
```

**Common mistake**: Treating `photoWaypoint.filePath` or `voiceNote.filePath` as
absolute paths. They are NOT - they are relative to the documents directory.

**Services that handle this correctly:**

- `PhotoStorageService`: Uses relative paths internally
- `PhotoCaptureService`: Stores relative paths in database
- `SessionExportService`: Resolves paths before copying files
- `AppBackupService`: Resolves paths during backup/restore

### Working with Route Planning

The app includes a complete route planning system with Mapbox integration:

**Route Creation**:

- Tap-to-add waypoints on Mapbox map with land overlay data
- Drag waypoints to adjust route path in real-time
- Multiple routing algorithms (straight line, shortest path, scenic, etc.)
- Automatic route calculation between waypoints
- Real-time distance and elevation statistics

**GPX Import/Export**:

- Import GPX/KML files via system file picker
- Export routes to GPX format with system share sheet
- Automatic conversion between `ImportedRoute` and `PlannedRoute` formats
- Preserves all waypoints and route metadata
- Compatible with standard GPS applications

**Key Components**:

1. **RouteLibraryPage**: Main route management interface
2. **RoutePlanningPage**: Interactive Mapbox-based route creation
3. **RouteImportDialog**: GPX/KML file import with preview
4. **RoutePlanningService**: Route storage and management (saves to
   `planned_routes` table)
5. **RouteImportService**: GPX/KML parsing (imports to `imported_routes` table,
   then converts)

**Important**: The app maintains two route systems:

- `ImportedRoute`: Temporary format from GPX/KML files
- `PlannedRoute`: App's native format stored in database

When importing, routes are automatically converted from `ImportedRoute` to
`PlannedRoute` format to ensure they appear in the route library.

### Offline Caching and Data Management

The app includes comprehensive offline caching for BFF land ownership data:

**Offline Cache Features**:

- **Manual Area Caching**: Download specific geographic areas (Settings →
  Offline Data Management)
- **Automatic Offline Fallback**: App automatically uses cached data when
  network unavailable
- **Smart Cache Management**: 7-day expiration, compressed storage (~KB vs MB)
- **Visual Indicators**: Offline mode banner shows when using cached data

**How It Works**:

1. **Online Mode**: Downloads state ZIPs from tracker-api (droplet filesystem)
2. **Offline Mode**: Uses downloaded state data from encrypted SQLite cache
3. **Network Errors**: Graceful fallback to cached data
4. **Cache Storage**: SQLCipher encrypted database (AES-256)

**Cache Management**:

- Access: Settings → Offline Data Management
- Cache areas by name with center point and radius (km)
- View cached areas with property count and storage size
- Delete individual areas or clear all cache
- Cached data includes permissions, contacts, restrictions (polygon coordinates
  omitted for space efficiency)

**Key Services**:

- **OfflineCacheService**: Manages cache storage and retrieval
- **BFFMappingService**: Automatic connectivity detection and cache fallback
- **OfflineModeIndicator**: Visual UI component showing offline status

### App Settings and Configuration

The app provides essential, functional settings (no placeholders). All settings
are actively used throughout the app:

**Settings → General**
(`lib/features/settings/presentation/pages/general_settings_page.dart`):

- **Theme Mode**: System / Light / Dark
  - Stored in SharedPreferences via `ThemeModeProvider`
  - Dynamically updates app theme instantly
  - Default: System (follows device settings)
  - Implementation: `lib/core/providers/theme_provider.dart`

- **Measurement Units**: Imperial / Metric
  - Default: **Imperial** (miles, feet, mph)
  - Used by `InternationalizationService` for all distance, speed, and altitude
    formatting
  - Affects: Session statistics, tracking display, waypoint details, route
    planning
  - Implementation: `lib/core/services/internationalization_service.dart`

- **Time Format**: 12-hour / 24-hour
  - Used throughout app for all timestamps
  - Implemented in `InternationalizationService.formatTime()`

**Settings → Tracking**
(`lib/features/settings/presentation/pages/tracking_settings_page.dart`):

- GPS accuracy settings
- Battery optimization modes
- Background tracking configuration
- Auto-pause behavior

**Settings → Location Monitoring**
(`lib/features/settings/presentation/pages/location_monitoring_settings_page.dart`):

- Property permission alerts
- Restricted area notifications
- Alert radius and sensitivity

**Settings → Map Settings**
(`lib/features/settings/presentation/pages/map_settings_page.dart`):

- Trail color and width
- Land overlay visibility
- Waypoint display options
- BFF data integration toggle

**Settings → Accessibility**
(`lib/features/settings/presentation/pages/accessibility_settings_page.dart`):

- Screen reader support
- Audio cues
- High contrast mode
- Haptic feedback
- Large text support
- Fully integrated with `AccessibilityService`

**Settings → Advanced**
(`lib/features/settings/presentation/pages/advanced_settings_page.dart`):

- Network timeout configuration
- Max retry attempts
- Custom API endpoint (for local development)
- Custom user agent

**Key Files**:

- `lib/core/providers/theme_provider.dart`: Theme mode state management
- `lib/core/services/internationalization_service.dart`: Units and time
  formatting
- `lib/features/settings/presentation/pages/settings_page.dart`: Main settings
  menu

**Note**: All settings pages contain only real, functional features.
Placeholder/fake settings have been removed to maintain app integrity.

## Platform-Specific Notes

### iOS

- Requires location permissions in Info.plist
- Background location needs special capabilities
- Camera access requires NSCameraUsageDescription

### Android

- Minimum SDK 24 (Android 7.0)
- Requires fine location permission
- Foreground service for background tracking
- Camera permission for photo waypoints

## Debugging Tips

- Use `AppLogger` for consistent logging
- Check `DeviceOrientation` for sensor issues
- Monitor `BatteryOptimizationCoordinator` for power usage
- Use Flutter DevTools for performance profiling

## Current Development Status

The project has completed Milestones 1-8:

- ✅ Basic GPS tracking and breadcrumbs
- ✅ Enhanced tracking with waypoints and statistics
- ✅ Photo waypoints with privacy-first storage
- ✅ Route planning with Mapbox integration and land overlay data
- ✅ GPX/KML import/export capabilities for route sharing
- ✅ Hunt Tracker (treasure hunt organization)
- ✅ Full app backup/restore (.obk format)
- ✅ In-app announcements and push notifications
- 🚧 Field Testing Phase
- 📋 Milestone 9: Privacy & security enhancements
- 📋 Milestone 10: Optional cloud sync and collaboration

## Important Files to Know

- `lib/app/enhanced_app.dart`: Main app widget with theme and routing
- `lib/core/services/database_service.dart`: Database operations
- `lib/core/services/bff_mapping_service.dart`: BFF REST API integration and
  land data processing
- `lib/features/tracking/presentation/pages/tracking_page.dart`: Main tracking
  UI
- `lib/features/map/presentation/pages/map_page.dart`: Map visualization
- `lib/core/providers/land_ownership_provider.dart`: State management for land
  ownership data
- `lib/core/models/land_ownership.dart`: Land ownership and property rights data
  models
- `test/test_runner.dart`: Comprehensive test suite runner
- `server/`: Node.js API server (tracker-api) for device registration and
  subscriptions

## Premium Downloads with NHP

### Overview

Premium offline map data downloads are protected using **OpenNHP**
(Network-infrastructure Hiding Protocol) with subscription validation via direct
Apple StoreKit / Google Play receipt validation through tracker-api.

**Key Concept**: Downloads are invisible to non-premium users (HTTP 444 silent
close) and only accessible after subscription validation.

### How It Works

```text
Mobile App
  ↓ 1. User subscribes via Google Play/App Store
  ↓    App sends purchase receipt to tracker-api for validation
  ↓    tracker-api validates with Apple/Google servers and stores result in DB
  ↓
  ↓ 2. User downloads state data (e.g., Wyoming)
  ↓    App calls knockForDownloads() with device credentials
  ↓
https://downloads.obsessiontracker.com/knock
  ↓ 3. NHP server validates subscription
  ↓    Calls tracker-api: POST /api/v1/subscription/validate
  ↓    tracker-api checks subscription status in its database
  ↓
  ↓ 4. If premium: whitelist IP for 1 hour
  ↓    Returns {success: true, open_time: 3600}
  ↓
  ↓ 5. App downloads state files
  ↓    GET /states/WY/land.zip
  ↓    GET /states/WY/trails.zip
  ↓    GET /states/WY/historical.zip
```

### Why Device ID Matters

**CRITICAL**: The subscription service must be initialized with the device ID so
that purchase receipts are associated with the correct device:

```dart
final deviceId = await DeviceIdService().getDeviceId();
await SubscriptionService.instance.initialize(
  appUserId: deviceId, // Links purchases to device ID!
);
```

**Why**: tracker-api validates subscriptions by looking up the device ID in its
database. The app sends Apple/Google purchase receipts to tracker-api, which
validates them with Apple App Store / Google Play servers and stores the
subscription status.

### Components

**Flutter Services**:

- `NhpDownloadService`: Handles knock authentication and download orchestration
- `SubscriptionService`: Direct Apple StoreKit / Google Play Billing integration
  (uses `in_app_purchase` package, MUST use device ID as app user ID)
- `DeviceIdService`: Generates/retrieves consistent device identifier
- `DeviceRegistrationService`: Registers device with tracker-api, gets API key
- `StateDownloadManager`: Manages multi-state download workflows

**Backend (tracker-api)**:

- Endpoint: `POST /api/v1/subscription/validate`
- Validates device API key
- Checks subscription status in tracker-api database (validated via Apple/Google
  receipt validation)
- Returns `{is_premium: boolean}`
- Test bypass for development devices

**Infrastructure (NHP)**:

- OpenNHP server: Receives knock requests, validates subscriptions
- Downloads nginx: Serves state ZIPs, checks IP whitelist
- NHP plugin: Integrates with tracker-api for subscription validation

### Troubleshooting

**Download fails with "Premium subscription required"**:

1. Check subscription status in tracker-api database
2. Verify device ID matches between app and tracker-api
3. Test subscription endpoint:
   `POST https://api.obsessiontracker.com/api/v1/subscription/validate`
4. Check tracker-api logs for Apple/Google receipt validation errors

**Download fails with "Download server unavailable" (HTTP 444)**:

1. Check NHP server is running: `docker ps | grep nhp-server`
2. Verify DNS: `dig downloads.obsessiontracker.com` (should be YOUR_SERVER_IP)
3. Check tracker-api health: `curl http://localhost:3003/health`
4. See full troubleshooting: `infrastructure/README-NHP-DOWNLOADS.md`

**User has subscription but downloads fail**:

- Likely cause: Purchase receipt not yet validated by tracker-api
- Solution: User should restore purchases in app, which re-sends receipts to
  tracker-api for validation with Apple/Google servers

### Documentation

- **Complete NHP system docs**: `infrastructure/README-NHP-DOWNLOADS.md`
- **tracker-api docs**: `server/README.md`
- **Deployment**: `.github/workflows/deploy-droplet.yml`

## Documentation Maintenance

When making changes to this codebase:

1. Update relevant documentation if behavior changes
2. Keep CLAUDE.md synchronized with project evolution
3. Update docs/README.md index when adding new documentation
4. Ensure code examples in docs remain accurate
