# Changelog

All notable changes to Obsession Tracker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - Full-Page Compass with Custom North Reference

- **Full-page compass tool** accessible from the "Your Journey" section
  - Large compass rose display with real-time magnetic heading
  - Bearing and distance to custom North reference points
- **Custom North reference system** for treasure hunters and explorers
  - Save named GPS coordinates as custom North reference points
  - Switch between magnetic North and any saved reference
  - Real-time bearing and distance calculations using Haversine formula
- **Database schema v16** with `custom_north_references` table

### Added - Meta Ray-Ban Smart Glasses Integration (2025-12-06) [EXPERIMENTAL]

- **Quick-capture photo workflow** with Meta Ray-Ban smart glasses (requires Meta AI app)
  - Tap glasses to pause/unpause experience with automatic photo capture
  - Photos automatically geotagged and added to current tracking session as waypoints
  - Works on both iOS and Android (Android requires DAT SDK 0.2.1+)
- **Stay in the flow** - no need to stop, pull out phone, unlock, and open camera
  - Simple tap interaction keeps you focused on detecting
  - Audio feedback confirms experience state changes
- **Seamless integration** with existing tracking sessions
  - Photos captured via glasses appear in session timeline and photo gallery
  - Full EXIF metadata including GPS coordinates, compass heading, and elevation
- **Note**: This is an experimental feature requiring Meta Ray-Ban smart glasses and the Meta AI companion app
- **Disclaimer**: Meta and Ray-Ban are trademarks of their respective owners. Obsession Tracker ™ is not affiliated with, endorsed by, or sponsored by Meta Platforms, Inc. or EssilorLuxottica.

### Added - Achievement & Statistics System (2025-01-13)

- **Lifetime statistics dashboard** tracking your treasure hunting journey
  - Total distance tracked across all sessions
  - Total time spent in the field
  - Personal records (longest session, most elevation gain)
  - States explored with detailed breakdown
- **32 achievement badges** across 6 categories, all computed locally on-device
  - Milestones: First Steps, Getting Started, Century Club, Veteran Explorer
  - Distance: First Ten, Long Haul, Century Miles, Thousand Miler
  - Explorer: Home State, Regional Explorer, Multi-State Hunter, All 50 States
  - Dedication: Week Warrior, Monthly Commitment, Ultimate Dedication
  - Memory: Shutterbug, Photo Collector, Voice Logger
  - Hunter: First Hunt, Active Hunter, Treasure Found, Serial Solver
- **State collection map** showing which US states you've explored
  - Tap any state for detailed stats (sessions, distance, time)
  - Goal: "Collect" all 50 states through your adventures
- **Streak tracking** for consecutive days with tracking sessions
  - Current streak and longest streak displayed
  - Gentle encouragement without punishing missed days
- **Achievement unlock notifications** with animated celebration dialogs
- **100% offline** - all statistics computed from your local session data
  - No external services, no privacy concerns
  - Your journey data never leaves your device

### Added - Route Planning & Editing (2025-01-16)
- **Route editing** with interactive dialog for updating route name and description
  - Edit button on route detail page opens editing dialog with form validation
  - Updates persist to database and refresh the route display
  - User-friendly error handling with success/failure notifications
- **POI marker alignment fixes** for accurate pin placement on maps
  - Pin icons now anchor at bottom-center for precise location marking
  - Current location markers stay centered for accurate GPS positioning
  - Consistent alignment across route planning, detail, and map views

### Added - TODO Completion & Fee Tracking (2025-01-02)
- **Entrance fee tracking** for public lands with intelligent fee determination
  - Displays "FREE" or "FEE REQUIRED" badge prominently in land detail popup
  - Provides fee information based on agency (NPS, BLM, USFS, State Parks, etc.)
  - National Parks show $20-35 entrance fee information
  - BLM and National Forest lands marked as free
  - State parks show typical day-use fees
- **Offline area management** with refresh and retry functionality for failed downloads
- **Device ID service** for privacy-preserving user identification across app features
- **Route following** with automatic tracking session creation from imported routes
- **GPX route export** with sharing capabilities for imported routes
- **Manual cache sync** to refresh all cached offline areas with latest data
- **Cache export/import** with metadata backup and restore functionality
- **Tutorial system improvements** with actual user ID tracking for progress

### In Development
- Field testing with real treasure hunting scenarios
- Desktop application enhancements and keyboard shortcuts
- Advanced filtering interfaces for photo gallery
- Enhanced GPX/KML export with land rights metadata

## [0.7.0] - 2025-12-04 - Advanced Features Complete

### Added - Database Enhancements
- **Advanced waypoint system** with templates, metadata, relationships, and clustering
- **Waypoint history & snapshots** for complete change tracking and point-in-time backups
- **Enhanced search functionality** with advanced filtering by location, date range, type, and proximity
- **Database schema v6** with 6 new tables and comprehensive indexing for optimal performance
- **Waypoint templates system** for rapid waypoint creation with predefined settings
- **Waypoint relationships** for linking related waypoints with typed connections
- **Waypoint clustering** for organizing waypoints into logical groups with spatial boundaries

### Added - Photo Management System
- **Native photo sharing** across all photo viewer pages using device share functionality
- **Photo-to-map navigation** with direct waypoint highlighting and location focusing
- **Multi-photo operations** with bulk sharing, batch file handling, and error recovery
- **Enhanced photo viewer integration** with seamless navigation between photos and maps
- **Photo selection management** with clear selection states and user feedback

### Added - Route Import System
- **KML file import support** with comprehensive parsing for Google Earth and GPS device compatibility
- **KML coordinate parsing** supporting longitude,latitude,elevation format with proper validation
- **Route visualization** with enhanced display, waypoint integration, and metadata preservation
- **Distance calculation** using Haversine formula for accurate route measurements
- **Multi-format route support** with both GPX and KML import capabilities
- **Route metadata extraction** from KML documents including names, descriptions, and properties

### Added - Development Infrastructure
- **Comprehensive TODO analysis** with 150+ items identified, categorized, and prioritized
- **Implementation roadmap** with 4-phase development strategy over 8-12 weeks
- **Quick wins identification** for rapid feature completion and immediate user value
- **Technical debt documentation** with clear priorities and complexity ratings

## [0.6.0] - 2025-09-03 - Production Integration Complete

### Added - Land Rights Integration System
- **Federated GraphQL BFF backend** integration at api.obsessiontracker.com/graphql
- **Real-time land rights lookup** with comprehensive property data
- **Activity-specific permissions** for metal detecting, treasure hunting, archaeology
- **Survey-accurate boundaries** with 8-decimal GPS precision
- **Multi-source data federation** (PAD-US, NPS, BLM, County data)
- **Offline land rights cache** with SQLite spatial indexing
- **Real-time permission alerts** for GPS-triggered restricted area notifications
- **Owner contact integration** with direct landowner information
- **Federal vs private land detection** with comprehensive coverage

### Added - Backend Infrastructure
- **Production BFF cluster** with PostgreSQL, Redis, and GraphQL services
- **High-performance caching** with 80%+ cache hit rate using Redis
- **Mobile optimization** with simplified polygons for GPS navigation
- **Comprehensive error handling** with graceful provider degradation
- **Real-time data updates** with provider refresh cycles

### Added - Enhanced Core Features
- **Permission-aware GPS tracking** with land rights timeline
- **Enhanced waypoint system** with land rights status indicators
- **Real-time map overlays** showing property boundaries and ownership
- **Permission status visualization** with color-coded boundaries
- **Comprehensive property information** display with owner details
- **Background location monitoring** with restriction detection

### Changed
- **Upgraded tracking system** to be land rights aware
- **Enhanced map display** with property ownership overlays
- **Improved database schema** with spatial indexing for offline operation
- **Extended export formats** to include land rights metadata

### Performance
- **APK build verification** - Successfully compiles with all features
- **BFF cluster testing** - All services operational and tested
- **Integration testing** - End-to-end system functionality verified
- **Mobile optimization** - Efficient property data handling for GPS devices

### Security
- **Privacy-first architecture** maintained with local data storage
- **No tracking or analytics** - user data stays on device
- **Optional cloud features** - BFF system provides data without storing user sessions

## [0.5.0] - 2025-08-15 - Enhanced UI & Workflows Complete

### Added
- **Permission workflow system** with landowner contact integration
- **Enhanced user interface** with land rights visualization
- **Color-coded property boundaries** based on access permissions
- **Real-time permission indicators** on map and waypoint systems
- **Owner contact information** with verification status

## [0.4.0] - 2025-07-20 - Offline Functionality & Alerts Complete

### Added
- **Offline land rights cache** with comprehensive SQLite spatial indexing
- **Real-time permission alerts** with GPS boundary detection
- **Background location monitoring** with customizable alert cooldowns
- **Download area management** with progress tracking and storage controls
- **Cache management system** with database statistics and optimization

## [0.3.0] - 2025-06-10 - Backend Federation Complete

### Added
- **Federated GraphQL backend** with Spring Boot microservices
- **Multi-provider integration** with PAD-US, NPS, BLM, and County data sources
- **Apollo Router gateway** for unified GraphQL federation
- **Mobile-optimized queries** with simplified polygon data
- **Redis caching layer** for high-performance data access

## [0.2.0] - 2025-05-01 - Property Data Integration Complete

### Added
- **Comprehensive property data** with ownership and legal descriptions
- **Activity-specific permission systems** for treasure hunting activities
- **Real-time property lookup** based on GPS coordinates
- **Survey-accurate boundaries** with precise coordinate handling
- **Multi-source data federation** architecture

### Changed
- **Extended database schema** to support comprehensive land ownership data
- **Enhanced location services** to integrate with property data systems
- **Upgraded mapping system** to display property information

## [0.1.0] - 2025-04-01 - Land Rights Integration Foundation

### Added - Core Land Rights Features
- **Basic land rights integration** with federated backend system
- **Property ownership lookup** functionality
- **Real-time permission checking** at GPS locations
- **Enhanced tracking system** with land rights awareness

### Changed from Previous Milestones
- **Upgraded core GPS tracking** beyond basic breadcrumb MVP
- **Enhanced waypoint system** beyond photo capture milestone
- **Advanced session management** with comprehensive metadata

## Previous Milestones (Pre Land Rights Integration)

### Milestone 3: Photo Waypoints ✅
- In-app camera with automatic geotagging
- Photo gallery with map integration
- EXIF data handling and photo metadata capture

### Milestone 2: Enhanced Tracking ✅
- Advanced location data (altitude, speed, heading)
- Trail color coding and real-time statistics
- Waypoint system with multiple icon types

### [0.1.0] - Milestone 1: Breadcrumb MVP ✅
**Target**: Basic location tracking with visual breadcrumb trail

#### Planned Features
- Start/stop tracking with single button operation
- Basic breadcrumb trail recording (5-30 second intervals)
- Simple OpenStreetMap integration
- Current location beacon with compass heading
- Session list with basic metadata
- Local SQLite storage only
- No internet requirement after initial setup

#### Technical Deliverables
- Core Flutter app architecture
- SQLite database implementation
- Location services integration
- Basic map rendering
- Session management system

#### Success Criteria
- ±5m GPS accuracy in optimal conditions
- 4+ hour battery life during tracking
- <2 second app launch time
- Zero data loss during sessions
- Intuitive single-button operation

---

### [0.2.0] - Milestone 2: Enhanced Tracking (Planned)
**Target**: More accurate tracking with basic annotations

#### Planned Features
- Quick waypoint marking with 5 basic icon types
- Enhanced location data (altitude, speed, heading)
- Real-time statistics (distance, time, elevation)
- Trail color coding by speed or time
- Experimental background tracking

#### Technical Improvements
- Advanced location data collection
- Waypoint system implementation
- Statistics calculation engine
- Platform-specific background services
- Performance monitoring

---

### [0.3.0] - Milestone 3: Photo Waypoints (Planned)
**Target**: Capture and geotag photos along the trail

#### Planned Features
- In-app camera with automatic geotagging
- Complete photo metadata capture
- Photo gallery with map integration
- Basic photo management (view, delete)
- iPad and Android tablet support

#### Technical Additions
- Camera integration
- Photo storage and compression
- EXIF data handling
- Responsive design for tablets
- Cross-platform photo management

---

### [0.4.0] - Milestone 4: Notes & Annotations (Planned)
**Target**: Add context to locations and photos

#### Planned Features
- Plain text notes for waypoints and photos
- Voice note recording (30-second limit)
- Extended waypoint customization (20+ icons)
- Search and filter functionality
- Custom waypoint naming and color coding

#### Enhancements
- Text input and editing system
- Audio recording and playback
- Advanced search engine
- Data indexing optimization
- Enhanced waypoint management

---

### [0.5.0] - Milestone 5: Playback & Export (Planned)
**Target**: Replay adventures and share data

#### Planned Features
- Animated ghost trail playback
- Multiple export formats (GPX, KML, CSV, PDF)
- Import capabilities for GPX and photos
- Privacy-focused sharing (encrypted files only)
- Playback speed controls and timeline scrubbing

#### Technical Features
- Animation and playback engine
- Multi-format export system
- Import and data merging
- File encryption for sharing
- Advanced playback controls

---

### [1.0.0] - Milestone 6: Privacy & Security (Planned)
**Target**: Protect sensitive location data - First Major Release

#### Planned Features
- Biometric authentication (Face ID, Touch ID, Fingerprint)
- Database and photo encryption
- Privacy tools (location fuzzing, EXIF stripping)
- Local encrypted backups with cloud storage options
- Granular privacy controls for exports

#### Security Enhancements
- End-to-end encryption implementation
- Authentication system
- Privacy control interface
- Secure backup and restore
- Security audit compliance

---

### [1.1.0] - Milestone 7: Advanced Tracking (Planned)
**Target**: Professional-grade tracking features

#### Planned Features
- Multi-day session support with pause/resume
- Downloadable offline maps with multiple layers
- Advanced waypoint templates with required fields
- Trail planning with route comparison
- Topographic and satellite map options

#### Advanced Capabilities
- Extended session management
- Offline map tile system
- Custom waypoint template engine
- Route planning algorithms
- Professional mapping features

---

### [2.0.0] - Milestone 8: Desktop Expansion (Planned)
**Target**: Full desktop applications - Cross-Platform Release

#### Planned Features
- Native macOS and Windows applications
- Large screen optimized layouts
- Advanced editing capabilities
- Desktop-specific features (printing, bulk operations)
- Full feature parity across platforms

#### Desktop Features
- Multi-platform builds
- Desktop-optimized user interface
- Advanced data management tools
- Cross-platform synchronization
- Professional desktop workflows

---

### [2.1.0] - Milestone 9: Sync & Collaboration (Planned)
**Target**: Optional cloud features with privacy

#### Planned Features
- End-to-end encrypted cloud synchronization
- Selective session sharing with time limits
- Team collaboration features
- Read-only web viewer
- Real-time collaboration tools

#### Cloud Integration
- Privacy-compliant cloud infrastructure
- Secure sharing system
- Collaboration platform
- Web-based session viewer
- Multi-device synchronization

---

### [3.0.0] - Milestone 10: Advanced Features (Planned)
**Target**: Power user features and integrations - Advanced Release

#### Planned Features
- External device integrations (Garmin, weather services)
- AI-powered photo categorization and pattern recognition
- Gamification system with achievements
- Advanced analytics and heat maps
- Route optimization and success tracking

#### Advanced Technology
- External API integrations
- Machine learning pipeline
- Gamification framework
- Advanced analytics engine
- AI-powered insights

---

## Development Notes

### Version Numbering
- **Major versions (x.0.0)**: Significant milestones with new core features
- **Minor versions (x.y.0)**: Feature additions and enhancements
- **Patch versions (x.y.z)**: Bug fixes and small improvements

### Release Types
- **Alpha**: Internal testing builds
- **Beta**: Public testing releases
- **RC**: Release candidates
- **Stable**: Production releases

### Privacy Commitment
Every release maintains our core privacy principles:
- Local-first data storage
- No tracking or analytics
- User data ownership
- Optional cloud features only
- Complete data export capability

### Performance Targets
Maintained across all releases:
- App launch: <2 seconds
- Photo capture: <1 second
- Battery life: 8+ hours tracking
- Map interaction: 60fps smooth
- Data capacity: 10,000+ waypoints

### Backward Compatibility
- Database migrations for all schema changes
- Graceful handling of older session formats
- Import capabilities for previous versions
- Clear upgrade paths between milestones

---

## Template for Future Releases

```
## [Version] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Features marked for removal

### Removed
- Features removed in this version

### Fixed
- Bug fixes

### Security
- Security improvements

### Performance
- Performance enhancements

### Privacy
- Privacy-related changes
```

---

**Note**: This changelog will be updated as development progresses. All dates and features are subject to change based on development priorities and user feedback.

For the most current development status, see the project's GitHub milestones and issues.
