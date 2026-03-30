# Quick Start: Generate Screenshots

## 🚀 TL;DR

```bash
# Just run this - it handles everything automatically:
fastlane ios generate_screenshots
```

The command will:
1. ✅ Boot the iPhone 17 Pro Max simulator
2. ✅ Install Flutter dependencies
3. ✅ Pre-grant location permissions (no dialog in screenshots)
4. ✅ Build the app
5. ✅ Run the integration test
6. ✅ Capture 5 screenshots
7. ✅ Save to `fastlane/screenshots/en-US/`

## 📱 Available Simulators

| Simulator | Device ID (UUID) | Command |
|-----------|-----------------|---------|
| **iPhone 17 Pro Max** | `42486023-06EA-4B2D-9C06-DFEE8E0CA60D` | `fastlane ios generate_screenshots` |
| iPhone 17 Pro | `E458321E-4F2C-45FF-A47F-6CD645D890E8` | `fastlane ios generate_screenshots device:"E458321E-4F2C-45FF-A47F-6CD645D890E8"` |
| iPad Pro 13-inch (M5) | Run `xcrun simctl list devices` to get ID | `fastlane ios generate_screenshots device:"<UUID>"` |

## 🔧 If You Get Errors

### "No device found"
```bash
# List available simulators
xcrun simctl list devices available | grep iPhone

# Boot manually
xcrun simctl boot 42486023-06EA-4B2D-9C06-DFEE8E0CA60D
open -a Simulator

# Wait 10 seconds, then try again
fastlane ios generate_screenshots
```

### "Flutter build failed"
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build ios --simulator --debug

# Then try again
fastlane ios generate_screenshots
```

### "Screenshots directory not found"
This means the test ran but screenshots weren't captured. Check:
```bash
# Run test manually to see errors
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart
```

## 📸 What Gets Generated

After running, check:
```bash
ls -lh fastlane/screenshots/en-US/

# Should see:
# 01-tracking-ready.png
# 02-sessions-list.png
# 03-route-planning.png
# 04-gps-settings.png
# 05-map-view.png
```

## ⬆️ Upload to App Store

Once screenshots look good:
```bash
# Upload screenshots only
fastlane ios screenshots

# Or generate + upload in one command
fastlane ios screenshots_full
```

## 🎯 Pro Tips

**Fastest workflow:**
1. Keep Simulator.app open
2. Run `fastlane ios generate_screenshots` multiple times
3. Simulator stays warm between runs = faster screenshots

**Testing before screenshot generation:**
```bash
# Verify test works without full driver
flutter test integration_test/screenshots_test.dart
```

**Generate for different devices:**
```bash
# iPhone 17 Pro Max (default - 6.9")
fastlane ios generate_screenshots

# iPhone 17 Pro (also 6.9")
fastlane ios generate_screenshots device:"E458321E-4F2C-45FF-A47F-6CD645D890E8"

# iPad (get UUID first)
xcrun simctl list devices | grep "iPad Pro 13"
fastlane ios generate_screenshots device:"<UUID_HERE>"
```

## 🆘 Still Having Issues?

Check Ruby/Fastlane setup:
```bash
# Check Ruby version (should be 3.x)
ruby --version

# Check Fastlane version
fastlane --version

# Check Flutter can see simulators
flutter devices

# Should see your simulator listed
```

If simulator not showing in `flutter devices`:
1. Open Simulator.app manually
2. Boot the device from Simulator menu
3. Wait 10 seconds
4. Run `flutter devices` again

## 📚 More Details

- Full documentation: [SCREENSHOTS.md](SCREENSHOTS.md)
- Xcode 26 specific: [XCODE_26_SIMULATORS.md](XCODE_26_SIMULATORS.md)
- Fastlane reference: Run `fastlane lanes` to see all commands
