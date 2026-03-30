# Obsession Tracker - Land Rights GPS Navigation

**Your compass when nothing adds up.** A privacy-first GPS tracking app with
**comprehensive land rights determination** for outdoor adventurers, hikers,
explorers, bikers, treasure hunters, metal detectorists, geocachers, and anyone
exploring the outdoors. Features exact property boundaries, owner contacts, and
activity-specific permissions.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey.svg)](https://flutter.dev/)

## Overview

Obsession Tracker provides **complete land rights determination** for outdoor
exploration and adventure activities. The app combines GPS tracking with a
comprehensive backend system that determines property ownership, access rights,
and activity-specific permissions in real-time.

### 🎯 **Key Features for Outdoor Adventurers**

- **Exact Property Boundaries**: Survey-accurate GPS coordinates (8-decimal
  precision) for precise navigation
- **Activity Permissions**: Real-time permissions for outdoor activities
  (Allowed/Prohibited/Permit Required/Owner Permission Required)
- **Property Owner Contacts**: Direct access to landowner information and
  mailing addresses
- **Federal vs Private Land**: Comprehensive coverage of public and private
  properties
- **Legal Compliance**: Access rights, easements, and seasonal restrictions
- **Activity-Specific Policies**: Hiking, camping, metal detecting, treasure
  hunting, archaeology, and more

## Subscription Model

### Free Tier - Basic GPS Navigation

**Perfect for getting started:**

- ✅ Unlimited GPS tracking and sessions
- ✅ All waypoint types and geotagged photos
- ✅ Route planning and GPX/KML import
- ✅ Session export (GPX, KML, CSV)
- ✅ Basic map layers (Mapbox base tiles)
- ✅ Local data storage (unlimited)

### Premium - $49.99/year or $6.99/month

**Unlock comprehensive land rights data and advanced features:**

- ✅ **Full Land Ownership Data** - Activity permissions, owner contact info,
  legal descriptions
- ✅ **Historical Map Overlays** - 16,142 USGS topo quadrangles (1880-1925)
- ✅ **Historical Places (GNIS)** - 1M+ locations: mines, ghost towns,
  cemeteries, churches
- ✅ **Trail Overlays** - USFS, BLM, NPS, and State trail data
- ✅ **Real-Time Permission Alerts** - Get notified when entering restricted
  areas
- ✅ **Offline Land Data Caching** - Download entire states for offline use
- ✅ **Achievement System** - 32 badges, lifetime stats, state explorer tracking
- ✅ **Field Journal** - Quick notes, observations, and finds
- ✅ **Priority Support** - Faster response to issues and feature requests

**7-Day Free Trial**: Try all premium features risk-free. Annual plan saves 40%
($4.17/month vs $6.99/month).

**Why Premium?** Land ownership data, property boundaries, and activity
permissions are essential for legal compliance and avoiding $10,000-$100,000
ARPA fines. Premium pays for access to authoritative data sources and ongoing
legal compliance updates.

## Current Features (Working)

✅ **Land Rights & Property Information**

- **Real-time Land Rights Lookup**: Check property ownership and permissions at
  GPS location
- **Comprehensive Property Data**: Owner names, legal descriptions, acreage, tax
  status
- **Activity Permissions**: Hiking, camping, metal detecting, treasure hunting,
  archaeology, and other activity policies by property
- **Survey-Accurate Boundaries**: Exact property lines with 8-decimal GPS
  precision
- **Multi-Source Integration**: Federal (PAD-US, NPS, BLM) and private (County)
  land data
- **Owner Contact Information**: Real property owner addresses and contact
  preferences

✅ **Core GPS Tracking**

- Start/stop GPS tracking with breadcrumb trails
- Real-time location display on Mapbox Maps with land ownership overlay
- Session management (create, view, edit, delete)
- GPX export for data portability
- Land ownership layer toggle for permission visualization

✅ **Map Search & Navigation**

- **Place Name Search**: Find BLM land, national forests, cities, and landmarks
- **Coordinate Search**: Navigate to exact coordinates (decimal degrees, DMS, DM
  formats)
- **Smart Results**: Location-aware results prioritized by proximity
- **Auto Zoom**: Intelligent zoom levels for different location types
- **Route Planning**: Perfect for planning trips to public lands

✅ **Enhanced Waypoints & Photos**

- Mark points of interest with permission status indicators
- Capture geotagged photos with land rights information
- Property boundary waypoints for legal compliance
- Owner contact waypoints for permission requests

✅ **Legal Compliance Visualization**

- Color-coded property boundaries by permission status
- Trail overlay showing legal vs prohibited areas
- Permission alerts and warnings
- Property ownership information display

✅ **App Configuration & Settings**

- **Theme Mode**: Choose Light, Dark, or System theme (adapts to device
  settings)
- **Measurement Units**: Imperial (default) or Metric for all
  distance/speed/altitude displays
- **Time Format**: 12-hour or 24-hour time display
- **Tracking Settings**: GPS accuracy, battery optimization, background tracking
  configuration
- **Location Monitoring**: Permission alerts, restricted area notifications,
  alert radius
- **Map Customization**: Trail color/width, land overlay toggle, waypoint
  display options
- **Accessibility**: Screen reader, audio cues, high contrast, large text,
  haptic feedback
- **Advanced**: Custom API endpoint, network timeout, retry attempts (for
  developers)
- **Note**: All settings are functional and actively used - no placeholder
  features

## Recent Updates

**January 2026:**

- **macOS Desktop App**: Native Mac App Store release with Universal Purchase
  (subscription works across all Apple devices)
- **Local WiFi Sync**: Device-to-device data transfer over local network (no
  cloud required)
- **Field Journal (Android)**: Quick notes, observations, and finds during
  sessions

**December 2025:**

- **Historical Map Overlays**: 16,142 USGS topo quadrangles (1880-1925) with
  opacity slider
- **Historical Places (GNIS)**: 1M+ locations including mines, ghost towns,
  cemeteries
- **Custom Map Markers**: Long-press to create markers with 7 categories
- **Achievement System**: 32 badges across 6 categories with lifetime stats
- **In-App Announcements**: News, updates, and hunt notifications
- **Security Hardening**: R8/ProGuard obfuscation, CI/CD security scanning

**November 2025:**

- Hunt Tracker: Treasure hunt organization system
- Full App Backup: Complete .obk backup/restore with all data
- In-App Purchase Integration: Subscription infrastructure (Apple StoreKit /
  Google Play Billing)

## Current Focus

**Next Priorities (Privacy-First):**

- Safety Hub (emergency contacts, check-in reminders, trip planning)
- Session Statistics Dashboard (restore lifetime stats)
- Sun/Moon Times (offline astronomical calculations)

## Installation

### Prerequisites

- Flutter 3.x or later
- Dart SDK 3.x or later
- iOS 12.0+ / Android 7.0+ (API level 24+)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/Obsession-Community/obsession-tracker.git
cd obsession-tracker

# Install dependencies
flutter pub get

# Run the app (iOS or Android)
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=your_token_here
```

**Note**: Mapbox Maps requires an access token. Get yours at
[mapbox.com/account/access-tokens](https://account.mapbox.com/access-tokens/)

### Platform Configuration

**Supported Platforms:**

- ✅ iOS 12.0+
- ✅ Android 7.0+ (API level 24+)
- ✅ macOS (Mac App Store - WebView-based Mapbox rendering)
- ❌ Web (not supported by Mapbox Flutter SDK)

**Note**: macOS uses WebView-based map rendering. Windows/Linux are not
supported.

#### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Track your adventures</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Track in background</string>
<key>NSCameraUsageDescription</key>
<string>Capture waypoint photos</string>
```

#### Android

Already configured in `AndroidManifest.xml`

## Project Structure

```bash
lib/
├── core/
│   ├── services/
│   │   ├── bff_mapping_service.dart           # REST API land rights integration
│   │   ├── offline_land_rights_service.dart   # SQLite caching with spatial indexing
│   │   ├── permission_alert_service.dart      # Real-time GPS permission monitoring
│   │   ├── land_overlay_service.dart          # Map visualization service
│   │   └── location_service.dart              # Enhanced GPS with land rights
│   ├── models/
│   │   ├── comprehensive_land_ownership.dart  # Complete property models
│   │   ├── activity_permissions.dart          # Permission status enums
│   │   ├── access_rights.dart                 # Legal access and restrictions
│   │   └── owner_contact.dart                 # Property owner information
│   └── providers/
│       ├── bff_mapping_provider.dart          # Land rights state management
│       └── permission_alert_provider.dart     # Alert system state management
├── features/
│   ├── map/                                   # Enhanced with land rights overlay
│   ├── offline/                               # Offline area download management
│   ├── permissions/                           # Permission alerts and dialogs
│   ├── settings/                              # Location monitoring settings
│   ├── sync/                                  # Cache management and sync status
│   └── waypoints/                             # Permission-aware waypoint system
├── test/
│   └── offline_functionality_test.dart        # Comprehensive offline system tests
└── main.dart
```

## Land Rights Architecture

### Backend Integration

**Tracker API** (`api.obsessiontracker.com`)

- **Production Architecture**: Express.js + SQLite on DigitalOcean Droplet
  (Docker)
- **Comprehensive Data**: PAD-US land ownership data for continental US (49
  states)
- **Static ZIP Files**: Pre-generated state data packages for offline use
- **Survey Precision**: 8-decimal coordinate accuracy (~1.1mm precision)
- **Mobile Optimization**: Simplified boundaries for efficient GPS navigation
- **NHP Protected Downloads**: Premium state data via
  downloads.obsessiontracker.com

### Flutter Implementation

**Core Services:**

- `BFFMappingService`: REST API client for state data downloads
- `DynamicLandDataService`: Manages state ZIP downloads and caching
- `OfflineLandRightsService`: SQLCipher encrypted local cache
- `LandOverlayService`: Real-time map visualization with property boundaries

**Data Models:**

- `LandOwnership`: Complete property information with boundaries
- `ActivityPermissions`: Metal detecting, treasure hunting, archaeology policies
- `AccessRights`: Public access, easements, seasonal restrictions, permit
  requirements

**API Integration:**

- **State Downloads**: Download entire states for offline use
- **Per-device Auth**: API key authentication via `X-API-Key` header
- **Offline First**: Downloaded data stored in encrypted SQLite
- **Error Handling**: Graceful degradation when network unavailable

## Development Status

**Current Phase**: All 10 Milestones Complete - Production (v2.0.0+)

### ✅ Completed Milestones

- ✅ **Milestone 1**: Basic GPS tracking with breadcrumb trails
- ✅ **Milestone 2**: Enhanced tracking with waypoints and session management
- ✅ **Milestone 3**: Photo waypoints with geotagged images
- ✅ **Milestone 4**: Land Rights Integration with tracker-api REST API
- ✅ **Milestone 5**: Enhanced user interface and permission workflows
- ✅ **Milestone 6**: Advanced database features with waypoint templates and
  metadata
- ✅ **Milestone 7**: Photo sharing and map integration
- ✅ **Milestone 8**: Desktop expansion (macOS app with Universal Purchase)
- ✅ **Milestone 9**: Sync & collaboration (Local WiFi Sync)
- ✅ **Milestone 10**: Advanced features (Achievements, Field Journal,
  Historical Maps)

### 🚧 Current Focus

- Safety Hub (emergency contacts, check-in reminders)
- Session statistics dashboard
- Sun/Moon times (offline calculation)

See [milestones.md](docs/milestones.md) for detailed status.

## Testing

```bash
# Run tests - Core functionality verified
flutter test

# Check code quality
flutter analyze

# Build verification - APK builds successfully
flutter build apk --debug

# API verification - Test REST endpoint
curl https://api.obsessiontracker.com/health
```

### Integration Test Status

- ✅ **Tracker API**: Express.js REST API operational (Docker on Droplet)
- ✅ **REST Endpoints**: Health check and state downloads working
- ✅ **Flutter Compilation**: APK builds successfully with all dependencies
  resolved
- ✅ **Core Functionality**: Location services, mapping, and offline caching
  integrated
- ✅ **Land Rights Integration**: State ZIP downloads with encrypted caching

## Documentation

- [Project Progress](PROJECT_PROGRESS.md) - Current development status
- [Milestones](docs/milestones.md) - Detailed roadmap
- [Architecture](docs/architecture.md) - Technical design
- [Contributing](CONTRIBUTING.md) - How to contribute

## Known Issues

- Background tracking needs reliability improvements
- Limited test coverage
- Photo storage needs management tools
- Performance optimization needed for large sessions

## Contributing

We welcome contributions! Please ensure:

- Code passes `flutter analyze`
- Features work offline-first
- Privacy is maintained (no analytics/tracking)

## License

MIT License - see [LICENSE](LICENSE) file

## Support

- 📖 [Documentation](docs/)
- 🐛
  [Issue Tracker](https://github.com/Obsession-Community/obsession-tracker/issues)
- 💬
  [Discussions](https://github.com/Obsession-Community/obsession-tracker/discussions)

---

**Privacy First**: No accounts required • No cloud dependencies • Your data
stays on your device
