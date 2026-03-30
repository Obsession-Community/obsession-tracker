# Fastlane Guide - App Store Deployment

This guide covers using fastlane for iOS, macOS, and Android app store deployment.

## Prerequisites

- Ruby and Bundler installed
- fastlane installed: `bundle install` in the project root
- App Store Connect API key at `fastlane/AuthKey_{KEY_ID}.p8`
- Google Play service account key at `fastlane/google-play-key.json`

## iOS (iPhone & iPad)

### Screenshots

Automated screenshot generation using simulators:

```bash
# Generate all screenshots (iPhone + iPad)
bundle exec fastlane ios screenshots_generate

# Generate for specific device
bundle exec fastlane ios screenshots_generate device_type:iphone
bundle exec fastlane ios screenshots_generate device_type:ipad

# Upload to App Store Connect
bundle exec fastlane ios screenshots_upload

# Generate AND upload
bundle exec fastlane ios screenshots_full
```

**Device Configuration:**
- iPhone 17 Pro Max (6.7" display) - 1290×2796
- iPad Pro 13-inch M5 (12.9" display) - 2048×2732

Screenshots are saved to `fastlane/screenshots/en-US/`.

### Build & Submit

```bash
# Build and upload to TestFlight
bundle exec fastlane ios beta

# Upload metadata only (no screenshots)
bundle exec fastlane ios metadata

# Submit existing TestFlight build for review
bundle exec fastlane ios submit_for_review

# Submit specific build
bundle exec fastlane ios submit_for_review build_number:123
```

---

## macOS

### Screenshots

**⚠️ Automated screenshot generation is NOT supported on macOS** due to the Mapbox Flutter plugin's native platform channels not initializing properly with `flutter drive` or `flutter test` on desktop platforms.

**Manual Screenshot Workflow:**

1. **Run the app:**
   ```bash
   flutter run -d macos
   ```

2. **Take screenshots** using Cmd+Shift+4 or Cmd+Shift+5

3. **Capture these screens:**
   - Map with land overlay
   - Sessions list
   - Session detail
   - Routes list
   - Achievements

4. **Resize to 2880×1800** (16" MacBook Pro Retina):
   ```bash
   sips -z 1800 2880 screenshot.png
   ```

5. **Save to** `fastlane/screenshots_mac/en-US/` with naming:
   ```
   0_APP_DESKTOP_0.png
   1_APP_DESKTOP_0.png
   2_APP_DESKTOP_0.png
   ...
   ```

6. **Upload:**
   ```bash
   bundle exec fastlane mac screenshots_upload
   ```

### Build & Submit

```bash
# Build and upload to TestFlight
bundle exec fastlane mac beta

# Upload metadata only
bundle exec fastlane mac metadata

# Submit existing TestFlight build for review
bundle exec fastlane mac submit_for_review

# Submit specific build
bundle exec fastlane mac submit_for_review build_number:123
```

**Note:** macOS and iOS share metadata via Universal Purchase. The `fastlane/metadata/en-US/` folder is used for both platforms.

---

## Android

### Screenshots

Automated screenshot generation using emulators:

```bash
# Generate all screenshots (phone + 7" tablet + 10" tablet)
bundle exec fastlane android screenshots_generate

# Generate for specific device
bundle exec fastlane android screenshots_generate device_type:phone
bundle exec fastlane android screenshots_generate device_type:sevenInch
bundle exec fastlane android screenshots_generate device_type:tenInch

# Upload to Google Play
bundle exec fastlane android screenshots_upload

# Generate AND upload
bundle exec fastlane android screenshots_full
```

**Device Configuration:**
- Pixel 9 Pro (phone) - 1080×2400
- Nexus 7 (7" tablet) - 1200×1920
- Medium Tablet (10" tablet) - 1600×2560

Screenshots are saved to `fastlane/metadata/android/en-US/images/{deviceType}Screenshots/`.

### Build & Submit

```bash
# Build and upload to internal testing (build_number required)
bundle exec fastlane android beta build_number:XX

# Upload metadata only
bundle exec fastlane android metadata

# Deploy to production
bundle exec fastlane android release build_number:XX

# Promote internal build to production
bundle exec fastlane android promote

# Staged rollout (50%)
bundle exec fastlane android promote rollout:0.5
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_API_KEY_PATH` | Path to .p8 key file (default: `fastlane/AuthKey_{KEY_ID}.p8`) |
| `SUPPLY_JSON_KEY` | Path to Google Play service account JSON (default: `fastlane/google-play-key.json`) |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID |

---

## Metadata Locations

| Platform | Location |
|----------|----------|
| iOS & macOS | `fastlane/metadata/en-US/` |
| Android | `fastlane/metadata/android/en-US/` |

### iOS/macOS Metadata Files

- `name.txt` - App name
- `subtitle.txt` - App subtitle
- `description.txt` - Full description
- `keywords.txt` - Search keywords
- `promotional_text.txt` - Promotional text
- `release_notes.txt` - What's New (max 4000 chars)
- `privacy_url.txt`, `support_url.txt`, `marketing_url.txt`

### Android Metadata Files

- `title.txt` - App name
- `short_description.txt` - Short description (max 80 chars)
- `full_description.txt` - Full description (max 4000 chars)
- `changelogs/default.txt` - Release notes (max 500 chars)

---

## Troubleshooting

### "No app version found in App Store Connect"

You need to create a version in App Store Connect first:
1. Go to https://appstoreconnect.apple.com
2. Select your app
3. Create a new version and upload a build
4. Then run the fastlane command

### "AVD not found" (Android)

Create the emulator in Android Studio:
1. Tools > Device Manager > Create Device
2. Select the device type (Pixel 9 Pro, Nexus 7, etc.)
3. Download API 35 system image
4. Name it exactly as shown in the error message

### macOS Screenshots Fail

Automated screenshots don't work on macOS due to Mapbox plugin limitations. Use the manual workflow described above.
