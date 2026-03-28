import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for integration tests with screenshot support
///
/// Supports iOS, Android, and macOS screenshot paths:
/// - iOS: fastlane/screenshots/en-US/{index}_{DEVICE_PREFIX}_{order}.png
/// - Android: fastlane/metadata/android/en-US/images/{deviceType}Screenshots/{index}.png
/// - macOS: fastlane/screenshots/en-US/{index}_{DEVICE_PREFIX}_{order}.png (shared with iOS)
///
/// Set SCREENSHOT_PLATFORM=android to use Android paths
/// Set SCREENSHOT_PLATFORM=mac to use macOS paths
/// Set SCREENSHOT_DEVICE_TYPE=phone|tenInch|sevenInch for Android device type
Future<void> main() async {
  // Track screenshot index for ordering
  var screenshotIndex = 0;

  try {
    await integrationDriver(
      onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
        final platform = Platform.environment['SCREENSHOT_PLATFORM'] ?? 'ios';

        String screenshotDir;
        String filename;

        if (platform == 'android') {
          // Android: Google Play structure
          // metadata/android/en-US/images/phoneScreenshots/1.png, 2.png, etc.
          final deviceType = Platform.environment['SCREENSHOT_DEVICE_TYPE'] ?? 'phone';
          screenshotDir = 'fastlane/metadata/android/en-US/images/${deviceType}Screenshots';
          // Google Play uses 1-indexed naming: 1.png, 2.png, etc.
          filename = '${screenshotIndex + 1}.png';
        } else if (platform == 'mac') {
          // macOS: Same folder as iOS (Universal Purchase - shared metadata)
          // screenshots/en-US/{index}_{DEVICE_PREFIX}_{order}.png
          final devicePrefix = Platform.environment['SCREENSHOT_DEVICE_PREFIX'] ?? 'APP_DESKTOP_MAC';
          screenshotDir = 'fastlane/screenshots/en-US';
          filename = '${screenshotIndex}_${devicePrefix}_0.png';
        } else {
          // iOS: Fastlane deliver structure
          // screenshots/en-US/{index}_{DEVICE_PREFIX}_{order}.png
          final devicePrefix = Platform.environment['SCREENSHOT_DEVICE_PREFIX'] ?? 'APP_IPHONE_67';
          screenshotDir = 'fastlane/screenshots/en-US';
          filename = '${screenshotIndex}_${devicePrefix}_0.png';
        }

        // Create directory if needed
        final dir = Directory(screenshotDir);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }

        final file = File('$screenshotDir/$filename');
        file.writeAsBytesSync(screenshotBytes);
        stderr.writeln('📸 Saved screenshot: ${file.path}');

        screenshotIndex++;
        return true;
      },
    );
  } catch (e) {
    // Handle "Service has disappeared" error gracefully
    // This can happen when the app closes before the driver finishes cleanup
    // If screenshots were captured, consider it a success
    final errorMessage = e.toString();
    if (errorMessage.contains('Service has disappeared') ||
        errorMessage.contains('device offline')) {
      if (screenshotIndex > 0) {
        stderr.writeln('⚠️ Driver cleanup failed but $screenshotIndex screenshots were captured');
        exit(0); // Exit successfully since screenshots were taken
      }
    }
    rethrow;
  }
}
