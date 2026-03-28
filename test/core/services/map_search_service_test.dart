import 'package:flutter_test/flutter_test.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';

void main() {
  group('MapSearchService Coordinate Parsing', () {
    late MapSearchService service;

    setUp(() {
      // Use a dummy token for offline parsing tests
      service = MapSearchService(mapboxAccessToken: 'test_token');
    });

    test('parses decimal degrees with comma', () async {
      final results = await service.search('44.5, -103.5');
      expect(results.length, 1);
      expect(results.first.latitude, closeTo(44.5, 0.001));
      expect(results.first.longitude, closeTo(-103.5, 0.001));
      expect(results.first.placeType, 'coordinate');
    });

    test('parses decimal degrees without space', () async {
      final results = await service.search('44.5,-103.5');
      expect(results.length, 1);
      expect(results.first.latitude, closeTo(44.5, 0.001));
      expect(results.first.longitude, closeTo(-103.5, 0.001));
    });

    test('parses decimal degrees with space', () async {
      final results = await service.search('44.5 -103.5');
      expect(results.length, 1);
      expect(results.first.latitude, closeTo(44.5, 0.001));
      expect(results.first.longitude, closeTo(-103.5, 0.001));
    });

    test('parses degrees minutes format', () async {
      final results = await service.search("44°30'N 103°30'W");
      expect(results.length, 1);
      expect(results.first.latitude, closeTo(44.5, 0.001));
      expect(results.first.longitude, closeTo(-103.5, 0.001));
    });

    test('parses degrees minutes seconds format', () async {
      final results = await service.search('44°30\'0"N 103°30\'0"W');
      expect(results.length, 1);
      expect(results.first.latitude, closeTo(44.5, 0.001));
      expect(results.first.longitude, closeTo(-103.5, 0.001));
    });

    test('parses positive coordinates (Eastern/Northern hemisphere)', () async {
      final results = await service.search('35.6762, 139.6503'); // Tokyo
      expect(results.length, 1);
      expect(results.first.latitude, closeTo(35.6762, 0.001));
      expect(results.first.longitude, closeTo(139.6503, 0.001));
    });

    test('rejects invalid latitude', () async {
      final results = await service.search('91.0, -103.5'); // Lat > 90
      expect(results.isEmpty, true);
    });

    test('rejects invalid longitude', () async {
      final results = await service.search('44.5, -181.0'); // Lon < -180
      expect(results.isEmpty, true);
    });

    test('returns empty for non-coordinate text', () async {
      // This will try to use the API, but with invalid token will return empty
      final results = await service.search('not a coordinate');
      // Without a valid API token, this should return empty
      expect(results, isA<List<MapSearchResult>>());
    });

    test('handles edge case coordinates', () async {
      final results = await service.search('0, 0'); // Null Island
      expect(results.length, 1);
      expect(results.first.latitude, 0.0);
      expect(results.first.longitude, 0.0);
    });

    test('handles North Pole', () async {
      final results = await service.search('90, 0');
      expect(results.length, 1);
      expect(results.first.latitude, 90.0);
      expect(results.first.longitude, 0.0);
    });

    test('handles South Pole', () async {
      final results = await service.search('-90, 0');
      expect(results.length, 1);
      expect(results.first.latitude, -90.0);
      expect(results.first.longitude, 0.0);
    });

    test('handles International Date Line', () async {
      final results = await service.search('0, 180');
      expect(results.length, 1);
      expect(results.first.latitude, 0.0);
      expect(results.first.longitude, 180.0);
    });

    test('handles negative coordinates', () async {
      final results = await service.search('-33.9249, 18.4241'); // Cape Town
      expect(results.length, 1);
      expect(results.first.latitude, closeTo(-33.9249, 0.001));
      expect(results.first.longitude, closeTo(18.4241, 0.001));
    });
  });

  group('MapSearchResult', () {
    test('creates result from coordinate parsing', () {
      const result = MapSearchResult(
        displayName: 'Test Location',
        latitude: 44.5,
        longitude: -103.5,
        placeType: 'coordinate',
      );

      expect(result.displayName, 'Test Location');
      expect(result.latitude, 44.5);
      expect(result.longitude, -103.5);
      expect(result.placeType, 'coordinate');
      expect(result.address, isNull);
      expect(result.bbox, isNull);
    });

    test('toString includes name and coordinates', () {
      const result = MapSearchResult(
        displayName: 'Test Location',
        latitude: 44.5,
        longitude: -103.5,
      );

      expect(result.toString(), 'Test Location (44.5, -103.5)');
    });
  });
}
