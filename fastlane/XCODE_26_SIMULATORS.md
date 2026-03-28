# Xcode 26 Screenshot Generation Guide

You're running **Xcode 26.1.1** which has the latest iPhone 17 and iPad Pro (M5) simulators.

## ✅ What You Have (Perfect for App Store 2024/2025)

Your available simulators that meet App Store requirements:

| Simulator | Display Size | Resolution | App Store Status |
|-----------|--------------|------------|------------------|
| iPhone 17 Pro Max | 6.9" | 1320 x 2868 px | ✅ **REQUIRED** |
| iPad Pro 13-inch (M5) | 13" | 2064 x 2752 px | ✅ **REQUIRED for iPad** |
| iPhone 17 Pro | 6.9" | 1320 x 2868 px | ✅ Same as Pro Max |
| iPhone Air | ~6.7" | Varies | ⚠️ Use Pro Max instead |

## 🚀 Generate Required Screenshots

### For iPhone (Required)
```bash
fastlane ios generate_screenshots device:"iPhone 17 Pro Max"
```

### For iPad (Required if supporting iPad)
```bash
fastlane ios generate_screenshots device:"iPad Pro 13-inch (M5)"
```

That's it! These two sizes are all Apple requires for 2024/2025 App Store submissions.

## ❓ Do I Need Older Simulator Sizes?

**No!** As of 2024/2025, Apple accepts the latest display sizes and scales them for older devices.

However, if you want pixel-perfect screenshots for older devices, you would need:
- iPhone 8 Plus simulator (iOS 15 or earlier)
- iPhone 15 Pro Max simulator (iOS 17)
- iPhone 14 Plus simulator (iOS 16)

**But this requires installing older Xcode versions**, which is NOT recommended.

## 🎯 Recommended Approach

Use only your Xcode 26 simulators:
1. Generate iPhone screenshots on **iPhone 17 Pro Max**
2. Generate iPad screenshots on **iPad Pro 13-inch (M5)**
3. Upload to App Store Connect
4. Apple will automatically scale for older devices

## 📱 Complete Screenshot Generation Workflow

```bash
# 1. Boot the iPhone simulator
open -a Simulator
# Select: iPhone 17 Pro Max

# 2. Generate iPhone screenshots (takes ~5 minutes)
fastlane ios generate_screenshots device:"iPhone 17 Pro Max"

# 3. Boot the iPad simulator
# In Simulator menu: File > Open Simulator > iPad Pro 13-inch (M5)

# 4. Generate iPad screenshots (takes ~5 minutes)
fastlane ios generate_screenshots device:"iPad Pro 13-inch (M5)"

# 5. Upload to App Store Connect
fastlane ios screenshots

# Or do all at once:
fastlane ios screenshots_full
```

## 🔍 Verify Screenshot Sizes

After generation, check the screenshots:

```bash
# Check screenshot dimensions
sips -g pixelWidth -g pixelHeight fastlane/screenshots/en-US/*.png

# Expected output:
# - iPhone 17 Pro Max: 1320 x 2868
# - iPad Pro 13-inch: 2064 x 2752 (portrait) or 2752 x 2064 (landscape)
```

## ⚠️ If App Store Rejects Screenshots

If Apple rejects saying "missing screenshot sizes":

1. **Check App Store Connect requirements** - They may still require older sizes temporarily
2. **Install Xcode 15 or 16** alongside Xcode 26:
   - Download from [Apple Developer Downloads](https://developer.apple.com/download/all/)
   - Install to separate folder (e.g., `/Applications/Xcode_15.app`)
   - Switch Xcode: `sudo xcode-select -s /Applications/Xcode_15.app`
3. **Generate older screenshots** with older simulators
4. **Switch back to Xcode 26**: `sudo xcode-select -s /Applications/Xcode.app`

But try with just the latest sizes first - Apple usually accepts them!

## 🎨 Pro Tips

1. **Use landscape orientation for iPad** to show more content:
   - In test file, detect iPad and rotate
   - Or manually take landscape screenshots

2. **Test before generating all sizes**:
   ```bash
   # Run test without driver to verify navigation works
   flutter test integration_test/screenshots_test.dart
   ```

3. **Clean between runs** if regenerating:
   ```bash
   rm -rf build/ios_integration_test_screenshots
   rm fastlane/screenshots/en-US/*.png
   ```

## 📊 App Store Connect Upload Status

After upload, check status at:
https://appstoreconnect.apple.com > Your App > App Store > Screenshots

You should see:
- ✅ iPhone 6.9" Display
- ✅ iPad Pro (3rd Gen) 13"

If you see red warnings about missing sizes, that's when you'd need older simulators.
