# Privacy Transparency Report

## Our Privacy Promise

Obsession Tracker is built with a **privacy-first architecture**. Your GPS
tracks, waypoints, photos, and adventure data belong to you - not us, not
advertisers, not data brokers.

**Last Updated**: January 2026

---

## What Stays on Your Device (Never Leaves)

These packages and features operate entirely locally:

| Component                                            | Purpose                   | Data Access                           |
| ---------------------------------------------------- | ------------------------- | ------------------------------------- |
| **GPS Tracking** (`geolocator`)                      | Record your trail         | Location stays local                  |
| **Database** (`sqflite_sqlcipher`)                   | Store sessions, waypoints | Encrypted locally                     |
| **Camera** (`camera`)                                | Photo waypoints           | Photos stored locally                 |
| **Voice Notes** (`record`, `just_audio`)             | Audio waypoints           | Audio stored locally                  |
| **Compass** (`flutter_compass`, `sensors_plus`)      | Navigation                | Sensor data local only                |
| **Encryption** (`encrypt`, `crypto`, `pointycastle`) | Secure exports            | Keys generated locally                |
| **Biometric Auth** (`local_auth`)                    | App lock                  | Handled by OS                         |
| **Secure Storage** (`flutter_secure_storage`)        | API keys                  | iOS Keychain / Android EncryptedPrefs |

**Your GPS breadcrumbs, coordinates, photos, and voice notes are NEVER uploaded
to any server.**

---

## What We Receive (Your Tracker API Server)

Our backend receives minimal data for app functionality:

| Endpoint                   | Data Sent                                                                | Purpose                     |
| -------------------------- | ------------------------------------------------------------------------ | --------------------------- |
| `/api/v1/devices/register` | device_id (random UUID), platform, app_version, device_model, os_version | Get API key for downloads   |
| `/api/v1/downloads/*`      | API key only                                                             | Download land/trail data    |
| `/announcements`           | API key only                                                             | Fetch app announcements     |
| `/hunts`                   | API key only                                                             | Fetch public treasure hunts |

**Privacy Notes:**

- **device_id** is a random UUID generated on your device - not tied to hardware
  IDs or Apple/Google accounts
- **No user accounts** - no email, no name, no password
- **No GPS coordinates** sent to our servers
- **All land data** downloaded in bulk ZIPs and queried locally

---

## Third-Party Services

### Mapbox (Maps)

| What          | Details                                                  |
| ------------- | -------------------------------------------------------- |
| **Purpose**   | Map tiles, place search                                  |
| **Telemetry** | **DISABLED** (via platform config)                       |
| **Data sent** | Map tile requests (standard for any map), search queries |
| **NOT sent**  | Your GPS tracks, waypoints, or trail data                |

**Configuration:**

- iOS: `Info.plist` → `MBXEventsDisabled = true`,
  `MGLMapboxMetricsEnabled = false`
- Android: `AndroidManifest.xml` → `com.mapbox.common.telemetry.enabled = false`

**Note on Search:** When you search for a location, your search query is sent to
Mapbox. If proximity search is enabled, your approximate location is included to
improve results. Your actual GPS tracks are never sent.

### Firebase Cloud Messaging (Push Notifications)

| What             | Details                                                  |
| ---------------- | -------------------------------------------------------- |
| **Purpose**      | Deliver push notifications (announcements, hunt updates) |
| **Data sent**    | FCM token (device identifier for push delivery)          |
| **NOT included** | Firebase Analytics, Crashlytics, or any tracking         |

**Privacy Notes:**

- We use ONLY `firebase_core` and `firebase_messaging` - NO Firebase Analytics
- Comments in code explicitly state "no analytics or tracking"
- You can delete your FCM token at any time for complete opt-out
- Token is refreshed periodically by Firebase (standard behavior)

### Apple StoreKit / Google Play Billing (Subscriptions)

| What          | Details                                                                        |
| ------------- | ------------------------------------------------------------------------------ |
| **Purpose**   | Process Pro subscription purchases                                             |
| **Data sent** | Purchase receipts sent to tracker-api for validation with Apple/Google servers |
| **NOT sent**  | Email, name, or any personal information                                       |

**Privacy Notes:**

- Uses native Apple StoreKit and Google Play Billing (no third-party
  subscription SDK)
- Purchase receipts are validated server-side via tracker-api with Apple App
  Store / Google Play servers
- Subscription status stored in tracker-api database, linked only to anonymous
  device ID
- We do not pass any user-identifying information beyond the device UUID

### Apple App Store / Google Play Store

| What              | Details                       |
| ----------------- | ----------------------------- |
| **Purpose**       | Process subscription payments |
| **Data sent**     | Standard purchase receipts    |
| **Controlled by** | Apple/Google, not us          |

---

## What We DON'T Have

- **No user accounts** - no email addresses, no passwords
- **No analytics SDKs** - no Firebase Analytics, no Mixpanel, no Amplitude
- **No ad networks** - no AdMob, no Facebook Ads SDK
- **No tracking pixels** - no marketing attribution
- **No data sales** - we don't sell any data to anyone
- **No GPS tracking** - your coordinates never leave your device
- **No cloud backups** - your data stays on your device unless you export it

---

## Full Dependency List

### Local-Only Packages (No Network)

| Package                                                 | Purpose                         |
| ------------------------------------------------------- | ------------------------------- |
| `sqflite_sqlcipher`                                     | Encrypted SQLite database       |
| `camera`                                                | Photo capture                   |
| `geolocator`                                            | GPS hardware access             |
| `sensors_plus`                                          | Device sensors                  |
| `flutter_compass`                                       | Compass hardware                |
| `encrypt`, `crypto`, `pointycastle`                     | Encryption algorithms           |
| `flutter_secure_storage`                                | Secure key storage              |
| `local_auth`                                            | Biometric authentication        |
| `path_provider`                                         | Local file paths                |
| `shared_preferences`                                    | Local settings                  |
| `archive`                                               | ZIP file handling               |
| `image`, `flutter_image_compress`                       | Image processing                |
| `record`, `just_audio`, `audio_waveforms`               | Voice notes                     |
| `uuid`                                                  | Generate local IDs              |
| `connectivity_plus`                                     | Check connection status         |
| `permission_handler`                                    | OS permissions                  |
| `device_info_plus`, `package_info_plus`, `battery_plus` | Device info (local)             |
| `latlong2`                                              | Coordinate calculations (local) |
| `intl`                                                  | Date/number formatting (local)  |
| `flutter_svg`, `photo_view`, `pdfx`                     | UI display (local)              |

### Network-Enabled Packages

| Package                               | Destination                   | Purpose                 |
| ------------------------------------- | ----------------------------- | ----------------------- |
| `http`, `dio`                         | Your Tracker API server       | API calls               |
| `mapbox_maps_flutter`                 | Mapbox (telemetry disabled)   | Map tiles               |
| `firebase_core`, `firebase_messaging` | Firebase                      | Push notifications only |
| `in_app_purchase`                     | Apple App Store / Google Play | Subscription management |

---

## How to Verify (For Technical Users)

### Inspect Network Traffic

1. Install a proxy tool (Charles Proxy, mitmproxy, Proxyman)
2. Install the proxy's CA certificate on your device
3. Build a debug version of the app
4. Monitor all network traffic

**What you should see:**

- Map tile requests to `api.mapbox.com`
- API calls to `api.obsessiontracker.com`
- Push notification setup to Firebase
- Subscription receipt validation to Apple App Store / Google Play (via
  tracker-api)

**What you should NOT see:**

- Your GPS coordinates being uploaded
- Analytics events
- Ad network calls
- Unknown third-party domains

### Verify Telemetry is Disabled

Check that `events.mapbox.com` receives no location telemetry events. The map
tile requests to `api.mapbox.com` are normal and required for maps to work.

---

## Questions?

If you have questions about our privacy practices:

- Email: [your support email]
- GitHub: [your issues page]

We're happy to explain any aspect of how your data is handled.
