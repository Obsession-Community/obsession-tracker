# Automated Screenshot Generation

This project uses Flutter's integration test framework to automatically generate App Store and Google Play screenshots.

## 🚀 Quick Start

### 1. Start a Simulator/Emulator

```bash
# iOS - List available simulators
xcrun simctl list devices available

# Start iPhone 15 Pro (or your preferred device)
open -a Simulator

# Android - List available emulators
emulator -list-avds

# Start an emulator
emulator -avd Pixel_6_API_33 &
```

### 2. Generate Screenshots

```bash
# iOS - Uses iPhone 17 Pro Max by default (6.9" display - required for App Store)
cd obsession-tracker
fastlane ios generate_screenshots

# iOS with specific device
fastlane ios generate_screenshots device:"iPhone 17 Pro Max"
fastlane ios generate_screenshots device:"iPad Pro 13-inch (M5)"

# Android
fastlane android generate_screenshots

# Android with specific device
fastlane android generate_screenshots device:"Pixel_6_API_33"
```

### 3. Upload to App Stores

```bash
# iOS - Upload screenshots to App Store Connect
fastlane ios screenshots_full

# Android - Upload screenshots to Google Play
fastlane android screenshots_full
```

## 📱 Screenshots Captured

The integration test captures 5 key screens:

1. **01-tracking-ready** - Main tracking interface
2. **02-sessions-list** - Session history
3. **03-route-planning** - Route planning
4. **04-gps-settings** - GPS settings
5. **05-map-view** - Interactive map

## 📐 Device Sizes

### iOS (App Store Requirements - 2024/2025)

Apple now requires screenshots for these display sizes. You have Xcode 26 with the latest simulators:

**Required Screenshots:**
```bash
# 6.9" display - iPhone 17 Pro Max (REQUIRED - newest size)
fastlane ios generate_screenshots device:"iPhone 17 Pro Max"

# 13" iPad Pro (REQUIRED for iPad)
fastlane ios generate_screenshots device:"iPad Pro 13-inch (M5)"
```

**Recommended Additional Sizes** (if you install older Xcode simulators):
```bash
# 6.7" display - iPhone 15/16 Pro Max
# Note: Requires iOS 17 simulator (not in Xcode 26)
# Skip if only using Xcode 26

# 6.5" display - iPhone 14 Plus
# Note: Requires iOS 16 simulator
# Skip if only using Xcode 26
```

**For App Store submission, you only NEED the 6.9" iPhone and 13" iPad screenshots with Xcode 26.**

### Android (Google Play Requirements)

```bash
# Phone (Pixel 6)
fastlane android generate_screenshots device:"Pixel_6_API_33"

# Tablet (if needed)
fastlane android generate_screenshots device:"pixel_tablet_API_33"
```

## 🎯 Customize Screenshots

### Modify Test Flow

Edit `integration_test/screenshots_test.dart` to:
- Change navigation sequence
- Add interactions with UI elements
- Adjust wait times for animations
- Capture different screens

### Add Mock Data

To show populated screens instead of empty states:

```dart
// In screenshots_test.dart
setUp(() async {
  // Add mock sessions
  // Add mock waypoints
  // Pre-populate data
});
```

## 🔧 Troubleshooting

### Build Errors
```bash
# Clean build
flutter clean
flutter pub get
flutter build ios --simulator --debug
```

### Simulator Not Found
```bash
# List iOS simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot "iPhone 15 Pro"
```

### Android Emulator Issues
```bash
# Kill all emulators
adb devices | grep emulator | cut -f1 | xargs -I {} adb -s {} emu kill

# Start fresh
emulator -avd Pixel_6_API_33 -wipe-data
```

### Screenshots Not Saving
- Check simulator/emulator is running
- Verify app builds successfully
- Check integration test passes: `flutter test integration_test/screenshots_test.dart`
- Screenshots save to: `build/ios_integration_test_screenshots/`

## 📝 Manual Screenshot Workflow (Fallback)

If automated screenshots don't work:

### iOS
1. Run app on simulator
2. Navigate to each screen
3. Take screenshot: `Cmd + S`
4. Screenshots save to `~/Desktop`
5. Move to: `fastlane/screenshots/en-US/`

### Android
1. Run app on emulator
2. Navigate to each screen
3. Take screenshot in Android Studio or: `adb exec-out screencap -p > screenshot.png`
4. Move to: `fastlane/metadata/android/en-US/images/phoneScreenshots/`

## 📏 Screenshot Specifications

### iOS (App Store Connect - 2024/2025 Requirements)
- **6.9"** - 1320 x 2868 px (iPhone 17 Pro Max) - **REQUIRED**
- **13" iPad Pro** - 2064 x 2752 px (portrait) - **REQUIRED for iPad apps**
- **6.7"** - 1290 x 2796 px (iPhone 15/16 Pro Max) - Optional (older size)
- **6.5"** - 1284 x 2778 px (iPhone 14 Plus) - Optional (older size)

### Android (Google Play)
- **Minimum**: 320 x 320 px
- **Maximum**: 3840 x 3840 px
- **Recommended**: 1080 x 1920 px (portrait)

## 🎨 Best Practices

1. **Use realistic data** - Show app in action, not empty states
2. **Consistent lighting** - Use same time of day for all screenshots
3. **Hide sensitive data** - No personal information
4. **Clean UI** - Dismiss any debug overlays or notifications
5. **Proper orientation** - Portrait for phones, landscape for tablets

## 🔗 Useful Commands

```bash
# Run integration test locally (without screenshots)
flutter test integration_test/screenshots_test.dart

# Run with driver for screenshots
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart

# List Fastlane lanes
fastlane lanes

# View screenshot upload status
fastlane ios screenshots --verbose
```

## 📦 What Gets Uploaded

When you run `fastlane ios screenshots` or `fastlane android screenshots`:

- **iOS**: Uploads from `fastlane/screenshots/en-US/` to App Store Connect
- **Android**: Uploads from `fastlane/metadata/android/en-US/images/phoneScreenshots/` to Google Play Console

Make sure screenshots are properly named and sized before uploading!
