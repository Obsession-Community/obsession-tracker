import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/services/gpx_parser_service.dart';

void main() {
  group('GPXParserService', () {
    late GPXParserService parser;

    setUp(() {
      parser = GPXParserService();
    });

    test('should parse sample GPX file correctly', () async {
      // Read the sample GPX file
      final file = File('test_data/sample_route.gpx');
      expect(file.existsSync(), true, reason: 'Sample GPX file should exist');

      // Parse the file
      final route = await parser.parseGPXFile(file);

      // Verify basic route properties
      expect(route.name, 'Sample Mountain Trail');
      expect(route.description, 'A test route for GPX import functionality');
      expect(route.sourceFormat, 'gpx');

      // Verify points
      expect(route.points.length, 21);
      expect(route.points.first.latitude, 37.7749);
      expect(route.points.first.longitude, -122.4194);
      expect(route.points.first.elevation, 100);

      expect(route.points.last.latitude, 37.7950);
      expect(route.points.last.longitude, -122.4000);
      expect(route.points.last.elevation, 500);

      // Verify waypoints
      expect(route.waypoints.length, 3);
      expect(route.waypoints.first.name, 'Trailhead');
      expect(route.waypoints.first.latitude, 37.7749);
      expect(route.waypoints.first.longitude, -122.4194);

      expect(route.waypoints.last.name, 'Summit');
      expect(route.waypoints.last.type, 'summit');

      // Verify calculated distance is reasonable (should be > 0)
      expect(route.totalDistance, greaterThan(0));

      // Verify estimated duration is calculated
      expect(route.estimatedDuration, isNotNull);
      expect(route.estimatedDuration, greaterThan(0));
    });

    test('should validate GPX content correctly', () {
      const validGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test">
          <trk><trkseg><trkpt lat="37.7749" lon="-122.4194"/></trkseg></trk>
        </gpx>''';

      const invalidGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
        <kml><Document></Document></kml>''';

      expect(parser.validateGPXContent(validGpx), true);
      expect(parser.validateGPXContent(invalidGpx), false);
    });

    test('should handle minimal GPX content', () {
      const minimalGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test">
          <trk>
            <name>Test Track</name>
            <trkseg>
              <trkpt lat="37.7749" lon="-122.4194">
                <time>2024-08-29T10:00:00Z</time>
              </trkpt>
              <trkpt lat="37.7750" lon="-122.4195">
                <time>2024-08-29T10:01:00Z</time>
              </trkpt>
            </trkseg>
          </trk>
        </gpx>''';

      final route = parser.parseGPXContent(minimalGpx, 'test.gpx');

      expect(route.name, 'Test Track');
      expect(route.points.length, 2);
      expect(route.waypoints.length, 0);
      expect(route.totalDistance, greaterThan(0));
    });

    test('should throw exception for invalid GPX', () {
      const invalidGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
        <invalid>Not a GPX file</invalid>''';

      expect(
        () => parser.parseGPXContent(invalidGpx, 'invalid.gpx'),
        throwsA(isA<GPXParseException>()),
      );
    });

    test('should throw exception for GPX without track points', () {
      const emptyGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="test">
          <metadata><name>Empty Route</name></metadata>
        </gpx>''';

      final route = parser.parseGPXContent(emptyGpx, 'empty.gpx');
      expect(route.points.length, 0);
    });

    test('should simplify route with too many points', () async {
      // Create a route with many points
      final points = List.generate(
          100,
          (i) => RoutePoint(
                id: 'point-$i',
                routeId: 'test-route',
                latitude: 37.7749 + (i * 0.001),
                longitude: -122.4194 + (i * 0.001),
                sequenceNumber: i,
              ));

      final simplified = parser.simplifyRoute(points, toleranceMeters: 50.0);

      // Should reduce the number of points
      expect(simplified.length, lessThan(points.length));
      expect(
          simplified.length, greaterThanOrEqualTo(2)); // At least start and end

      // First and last points should be preserved
      expect(simplified.first.latitude, points.first.latitude);
      expect(simplified.first.longitude, points.first.longitude);
      expect(simplified.last.latitude, points.last.latitude);
      expect(simplified.last.longitude, points.last.longitude);
    });
  });
}
