import 'package:obsession_tracker/core/models/settings_models.dart';

/// Utility class for formatting GPS coordinates according to user preferences.
///
/// Supports three formats:
/// - Decimal: 43.123456°
/// - Degrees Minutes: 43° 7.407'
/// - Degrees Minutes Seconds: 43° 7' 24.44"
class CoordinateFormatter {
  /// Format a latitude value according to the specified format.
  ///
  /// Returns a string with the appropriate direction indicator (N/S).
  static String formatLatitude(double latitude, CoordinateFormat format) {
    return _formatCoordinate(latitude, true, format);
  }

  /// Format a longitude value according to the specified format.
  ///
  /// Returns a string with the appropriate direction indicator (E/W).
  static String formatLongitude(double longitude, CoordinateFormat format) {
    return _formatCoordinate(longitude, false, format);
  }

  /// Format a coordinate pair as a single string.
  ///
  /// Returns "lat, lon" formatted according to the specified format.
  static String formatPair(
    double latitude,
    double longitude,
    CoordinateFormat format,
  ) {
    return '${formatLatitude(latitude, format)}, ${formatLongitude(longitude, format)}';
  }

  /// Format a coordinate pair in a compact form (no direction indicators).
  ///
  /// Useful for input fields where direction is implied by sign.
  static String formatPairCompact(
    double latitude,
    double longitude,
    CoordinateFormat format,
  ) {
    return '${_formatValue(latitude, format)}, ${_formatValue(longitude, format)}';
  }

  /// Format a single coordinate value without direction indicator.
  ///
  /// Useful for displaying raw values in input fields.
  static String formatValue(double value, CoordinateFormat format) {
    return _formatValue(value, format);
  }

  static String _formatCoordinate(
    double value,
    bool isLatitude,
    CoordinateFormat format,
  ) {
    final direction = isLatitude
        ? (value >= 0 ? 'N' : 'S')
        : (value >= 0 ? 'E' : 'W');
    final absValue = value.abs();

    switch (format) {
      case CoordinateFormat.decimal:
        return '${absValue.toStringAsFixed(6)}° $direction';

      case CoordinateFormat.degreesMinutes:
        final degrees = absValue.floor();
        final minutes = (absValue - degrees) * 60;
        return "$degrees° ${minutes.toStringAsFixed(3)}' $direction";

      case CoordinateFormat.degreesMinutesSeconds:
        final degrees = absValue.floor();
        final minutesTotal = (absValue - degrees) * 60;
        final minutes = minutesTotal.floor();
        final seconds = (minutesTotal - minutes) * 60;
        return '$degrees° $minutes\' ${seconds.toStringAsFixed(2)}" $direction';
    }
  }

  static String _formatValue(double value, CoordinateFormat format) {
    final absValue = value.abs();
    final sign = value < 0 ? '-' : '';

    switch (format) {
      case CoordinateFormat.decimal:
        return '$sign${absValue.toStringAsFixed(6)}°';

      case CoordinateFormat.degreesMinutes:
        final degrees = absValue.floor();
        final minutes = (absValue - degrees) * 60;
        return "$sign$degrees° ${minutes.toStringAsFixed(3)}'";

      case CoordinateFormat.degreesMinutesSeconds:
        final degrees = absValue.floor();
        final minutesTotal = (absValue - degrees) * 60;
        final minutes = minutesTotal.floor();
        final seconds = (minutesTotal - minutes) * 60;
        return '$sign$degrees° $minutes\' ${seconds.toStringAsFixed(2)}"';
    }
  }
}
