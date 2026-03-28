import 'dart:math' as math;

/// Utilities for calculating device orientation angles (pitch, roll, yaw)
/// from sensor data (accelerometer, magnetometer)
class OrientationCalculator {
  /// Calculate pitch angle (tilt forward/backward) from accelerometer gravity
  ///
  /// Returns angle in degrees:
  /// - Positive: tilted up (looking at sky)
  /// - Negative: tilted down (looking at ground)
  /// - Range: -90° to +90°
  static double calculatePitch(double gravityX, double gravityY, double gravityZ) {
    // Pitch = arctan2(gY, sqrt(gX² + gZ²))
    final double pitch = math.atan2(
      gravityY,
      math.sqrt(gravityX * gravityX + gravityZ * gravityZ),
    );

    return _radiansToDegrees(pitch);
  }

  /// Calculate roll angle (tilt left/right) from accelerometer gravity
  ///
  /// Returns angle in degrees:
  /// - Positive: tilted right
  /// - Negative: tilted left
  /// - Range: -180° to +180°
  static double calculateRoll(double gravityX, double gravityY, double gravityZ) {
    // Roll = arctan2(-gX, gZ)
    final double roll = math.atan2(-gravityX, gravityZ);

    return _radiansToDegrees(roll);
  }

  /// Calculate yaw angle (compass heading) from magnetometer
  ///
  /// This is typically provided directly by the compass service,
  /// but can be calculated from magnetometer X/Y if needed.
  ///
  /// Returns angle in degrees:
  /// - 0° = North
  /// - 90° = East
  /// - 180° = South
  /// - 270° = West
  static double calculateYaw(double magnetometerX, double magnetometerY) {
    // Yaw = arctan2(-mY, mX) with adjustments
    final double yaw = math.atan2(-magnetometerY, magnetometerX);

    // Convert to 0-360 range
    double heading = _radiansToDegrees(yaw);
    if (heading < 0) {
      heading += 360;
    }

    return heading;
  }

  /// Calculate tilt-compensated heading (yaw) using both accelerometer and magnetometer
  ///
  /// This provides a more accurate heading when the device is tilted.
  static double calculateTiltCompensatedHeading({
    required double magnetometerX,
    required double magnetometerY,
    required double magnetometerZ,
    required double gravityX,
    required double gravityY,
    required double gravityZ,
  }) {
    // Calculate pitch and roll
    final double pitch = calculatePitch(gravityX, gravityY, gravityZ) * math.pi / 180;
    final double roll = calculateRoll(gravityX, gravityY, gravityZ) * math.pi / 180;

    // Tilt-compensated magnetometer readings
    final double magX = magnetometerX * math.cos(pitch) +
        magnetometerZ * math.sin(pitch);

    final double magY = magnetometerX * math.sin(roll) * math.sin(pitch) +
        magnetometerY * math.cos(roll) -
        magnetometerZ * math.sin(roll) * math.cos(pitch);

    // Calculate heading
    double heading = math.atan2(-magY, magX) * 180 / math.pi;

    // Normalize to 0-360
    if (heading < 0) {
      heading += 360;
    }

    return heading;
  }

  /// Normalize angle to -180 to +180 range
  static double normalizeAngle180(double angle) {
    double normalized = angle % 360;
    if (normalized > 180) {
      normalized -= 360;
    } else if (normalized < -180) {
      normalized += 360;
    }
    return normalized;
  }

  /// Normalize angle to 0 to 360 range
  static double normalizeAngle360(double angle) {
    double normalized = angle % 360;
    if (normalized < 0) {
      normalized += 360;
    }
    return normalized;
  }

  /// Convert radians to degrees
  static double _radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  /// Convert degrees to radians
  static double degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Get cardinal direction from heading
  ///
  /// Returns: N, NE, E, SE, S, SW, W, NW
  static String getCardinalDirection(double heading) {
    // Normalize to 0-360
    final double normalized = normalizeAngle360(heading);

    // 16-point compass (simplified to 8 points)
    const List<String> directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final int index = ((normalized + 22.5) / 45).floor() % 8;

    return directions[index];
  }

  /// Format angle for display
  ///
  /// Example: 42.3456 -> "42°"
  static String formatAngle(double angle, {int decimals = 0}) {
    return '${angle.toStringAsFixed(decimals)}°';
  }

  /// Format heading for display with cardinal direction
  ///
  /// Example: 42.5 -> "043° NE"
  static String formatHeading(double heading) {
    final String cardinal = getCardinalDirection(heading);
    final String degrees = heading.toStringAsFixed(0).padLeft(3, '0');
    return '$degrees° $cardinal';
  }
}
