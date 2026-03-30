import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/services/map_search_service.dart';

/// Provider for Mapbox access token
/// Reads the token from compile-time --dart-define=MAPBOX_ACCESS_TOKEN
/// iOS: Also available via Debug.xcconfig and Release.xcconfig (ACCESS_TOKEN)
/// Android: Also available via build.gradle.kts manifest placeholder
final mapboxAccessTokenProvider = Provider<String>((ref) {
  const token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');
  return token;
});

/// Provider for the map search service
/// Automatically uses the same Mapbox token configured for your maps
final mapSearchServiceProvider = Provider<MapSearchService>((ref) {
  final token = ref.watch(mapboxAccessTokenProvider);
  return MapSearchService(mapboxAccessToken: token);
});
