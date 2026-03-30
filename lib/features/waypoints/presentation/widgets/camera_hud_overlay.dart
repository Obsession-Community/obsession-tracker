import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';
import 'package:obsession_tracker/core/services/internationalization_service.dart';
import 'package:obsession_tracker/core/utils/coordinate_formatter.dart';
import 'package:obsession_tracker/core/utils/orientation_calculator.dart';

/// Simple text-based HUD overlay showing all camera metadata
class CameraHUDOverlay extends StatelessWidget {
  const CameraHUDOverlay({
    required this.pitch,
    required this.roll,
    required this.heading,
    required this.position,
    this.isVisible = true,
    this.useImperial = true,
    this.coordinateFormat = CoordinateFormat.decimal,
    super.key,
  });

  /// Pitch angle in degrees (-90 to +90)
  final double pitch;

  /// Roll angle in degrees (-180 to +180)
  final double roll;

  /// Heading in degrees (0-360)
  final double heading;

  /// GPS position
  final Position? position;

  /// Whether HUD is visible
  final bool isVisible;

  /// Use imperial units (feet) vs metric (meters)
  final bool useImperial;

  /// Coordinate display format
  final CoordinateFormat coordinateFormat;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              // More horizontal padding in landscape to avoid overlapping with side controls
              padding: isLandscape
                  ? const EdgeInsets.symmetric(horizontal: 100, vertical: 16)
                  : const EdgeInsets.all(16),
              child: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Device Orientation Section
        _buildSection(
          title: 'Device Orientation',
          items: [
            _buildMetadataRow('Pitch', '${pitch.toStringAsFixed(1)}°'),
            _buildMetadataRow('Roll', '${roll.toStringAsFixed(1)}°'),
            _buildMetadataRow('Heading (Yaw)', '${heading.toStringAsFixed(1)}°'),
            _buildMetadataRow(
              'Cardinal Direction',
              OrientationCalculator.getCardinalDirection(heading),
            ),
            _buildMetadataRow(
              'Formatted Heading',
              OrientationCalculator.formatHeading(heading),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // GPS Location Section
        if (position != null) ...[
          _buildSection(
            title: 'GPS Location',
            items: [
              _buildMetadataRow(
                'Latitude',
                CoordinateFormatter.formatLatitude(
                    position!.latitude, coordinateFormat),
              ),
              _buildMetadataRow(
                'Longitude',
                CoordinateFormatter.formatLongitude(
                    position!.longitude, coordinateFormat),
              ),
              _buildMetadataRow(
                'Altitude',
                InternationalizationService().formatAltitude(position!.altitude),
              ),
              _buildMetadataRow(
                'Accuracy',
                InternationalizationService().formatDistance(position!.accuracy),
              ),
              if (position!.speed > 0)
                _buildMetadataRow(
                  'Speed',
                  InternationalizationService().formatSpeed(position!.speed),
                ),
              if (position!.heading >= 0)
                _buildMetadataRow(
                  'GPS Heading',
                  '${position!.heading.toStringAsFixed(1)}°',
                ),
            ],
          ),
        ],

        const Spacer(),

        // Camera Tilt Info at Bottom
        _buildSection(
          title: 'Camera Info',
          items: [
            _buildMetadataRow(
              'Tilt Angle',
              '${_calculateTiltAngle().toStringAsFixed(1)}°',
            ),
            _buildMetadataRow(
              'Units',
              useImperial ? 'Imperial' : 'Metric',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Device Orientation & Camera Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: 'Device Orientation',
                items: [
                  _buildMetadataRow('Pitch', '${pitch.toStringAsFixed(1)}°'),
                  _buildMetadataRow('Roll', '${roll.toStringAsFixed(1)}°'),
                  _buildMetadataRow('Heading', '${heading.toStringAsFixed(1)}°'),
                  _buildMetadataRow(
                    'Direction',
                    OrientationCalculator.getCardinalDirection(heading),
                  ),
                ],
              ),
              const Spacer(),
              _buildSection(
                title: 'Camera Info',
                items: [
                  _buildMetadataRow(
                    'Tilt',
                    '${_calculateTiltAngle().toStringAsFixed(1)}°',
                  ),
                  _buildMetadataRow(
                    'Units',
                    useImperial ? 'Imperial' : 'Metric',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Right column - GPS Location
        if (position != null)
          Expanded(
            child: _buildSection(
              title: 'GPS Location',
              items: [
                _buildMetadataRow(
                  'Lat',
                  CoordinateFormatter.formatLatitude(
                      position!.latitude, coordinateFormat),
                ),
                _buildMetadataRow(
                  'Lon',
                  CoordinateFormatter.formatLongitude(
                      position!.longitude, coordinateFormat),
                ),
                _buildMetadataRow(
                  'Alt',
                  InternationalizationService().formatAltitude(position!.altitude),
                ),
                _buildMetadataRow(
                  'Acc',
                  InternationalizationService().formatDistance(position!.accuracy),
                ),
                if (position!.speed > 0)
                  _buildMetadataRow(
                    'Speed',
                    InternationalizationService().formatSpeed(position!.speed),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate combined tilt angle from pitch and roll
  double _calculateTiltAngle() {
    return (pitch * pitch + roll * roll).abs().clamp(0, 180);
  }
}
