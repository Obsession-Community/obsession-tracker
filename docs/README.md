# Obsession Tracker Documentation

**Last Updated**: January 2026

## Current Status

**App Version**: v2.0.0+ (Live on App Store, Google Play, Mac App Store)
**Milestones Completed**: All 10 of 10 **Next Phase**: Safety Hub, Statistics
Dashboard, Sun/Moon Times

---

## Quick Links

### Planning & Roadmap

- **[milestones.md](milestones.md)** - 10-milestone development plan with
  completion status
- **[feature-roadmap/CURRENT-STATUS.md](feature-roadmap/CURRENT-STATUS.md)** -
  What's implemented vs planned (primary planning doc)

### Architecture & Development

- **[architecture.md](architecture.md)** - System architecture and database
  design
- **[development-guidelines.md](development-guidelines.md)** - Coding standards
  and practices
- **[FASTLANE_GUIDE.md](FASTLANE_GUIDE.md)** - App Store deployment (iOS, macOS,
  Android)
- **[OFFLINE-STORAGE-ARCHITECTURE.md](OFFLINE-STORAGE-ARCHITECTURE.md)** -
  Offline data caching architecture

### Backend Integration

- **[api-integration-guide.md](api-integration-guide.md)** - Tracker API
  integration (complete reference)
- **[api_keys_and_services.md](api_keys_and_services.md)** - API keys and
  external services

### Monetization & Subscriptions

- **[MONETIZATION_STRATEGY.md](MONETIZATION_STRATEGY.md)** - Subscription model
  (Free/Premium tiers)
- **[api-integration-guide.md](api-integration-guide.md)** - Subscription
  validation via tracker-api (Apple StoreKit / Google Play receipts)

### User & Legal

- **[user-guide.md](user-guide.md)** - End-user documentation
- **[SECURITY.md](SECURITY.md)** - Security architecture and CI/CD scanning

---

## Documentation Structure

```text
docs/
├── README.md                      # This file
├── milestones.md                  # Development milestones (M1-M10, all complete)
├── architecture.md                # System architecture
├── development-guidelines.md      # Coding standards
├── FASTLANE_GUIDE.md              # App Store deployment
├── OFFLINE-STORAGE-ARCHITECTURE.md # Offline caching
├── api-integration-guide.md       # API integration (complete reference)
├── api_keys_and_services.md       # Service credentials
├── user-guide.md                  # User documentation
├── SECURITY.md                    # Security documentation
├── MONETIZATION_STRATEGY.md       # Subscription model
├── api-integration-guide.md       # Includes subscription validation docs
│
└── feature-roadmap/               # Feature planning
    ├── CURRENT-STATUS.md          # Implementation tracking (what's done)
    └── FUTURE-FEATURES.md         # Future roadmap (what's next)
```

---

## For New Developers

1. **Start here**: Main [README.md](../README.md)
2. **Understand architecture**: [architecture.md](architecture.md)
3. **Check current status**: [milestones.md](milestones.md)
4. **Follow standards**: [development-guidelines.md](development-guidelines.md)
5. **Set up API**: [api-integration-guide.md](api-integration-guide.md)

---

## Key Technical Details

### Tech Stack

- **Mobile/Desktop**: Flutter 3.x (iOS, Android, macOS)
- **Maps**: Mapbox Maps SDK (native on mobile, WebView on macOS)
- **Database**: SQLite with SQLCipher encryption
- **Backend**: Express.js on Droplet (TypeScript REST API)
- **Storage**: Local filesystem (state ZIPs, historical MBTiles) + SQLite (app
  data)

### Implemented Features

- GPS tracking with sessions & waypoints
- Hunt Tracker (treasure hunt organization)
- Land ownership data (PAD-US, 49 continental US states)
- Trail overlays (USFS, OSM, BLM, NPS, State)
- **Historical Map Overlays** (16,142 USGS topos, 1880-1925)
- **Historical Places (GNIS)** (1M+ mines, ghost towns, cemeteries)
- **Custom Map Markers** (7 categories, attachments)
- **Achievement System** (32 badges, lifetime stats)
- **Field Journal** (notes, observations, finds)
- **Local WiFi Sync** (device-to-device transfer)
- **macOS Desktop App** (Universal Purchase)
- Photo waypoints with pro camera
- Route planning (GPX/KML import/export)
- Session export (GPX, KML, CSV, JSON, OTX)
- Full app backup/restore (.obk format)
- Biometric lock & AES-256 encryption
- Map search (places, coordinates, trails)
- Per-device API authentication
- In-app announcements system

### Next Priorities

1. Safety Hub (emergency contacts, check-in reminders, trip planning)
2. Session Statistics Dashboard (restore lifetime stats)
3. Sun/Moon Times (offline astronomical calculations)

All planned features are privacy-compatible (no data leaves device).

See [feature-roadmap/FUTURE-FEATURES.md](feature-roadmap/FUTURE-FEATURES.md) for
details.
