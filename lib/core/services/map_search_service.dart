import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/models/saved_location.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/services/offline_cache_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';
import 'package:uuid/uuid.dart';

/// Convert state code to full state name
String? getStateName(String? stateCode) {
  if (stateCode == null || stateCode.isEmpty) return null;

  const stateNames = {
    'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
    'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
    'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii', 'ID': 'Idaho',
    'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa', 'KS': 'Kansas',
    'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine', 'MD': 'Maryland',
    'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota', 'MS': 'Mississippi',
    'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska', 'NV': 'Nevada',
    'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico', 'NY': 'New York',
    'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio', 'OK': 'Oklahoma',
    'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island', 'SC': 'South Carolina',
    'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas', 'UT': 'Utah',
    'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington', 'WV': 'West Virginia',
    'WI': 'Wisconsin', 'WY': 'Wyoming',
  };

  return stateNames[stateCode.toUpperCase()];
}

/// Result from a map search query
class MapSearchResult {
  const MapSearchResult({
    required this.displayName,
    this.latitude,
    this.longitude,
    this.address,
    this.placeType,
    this.bbox,
    this.trailId,
    this.trailData,
    this.mapboxId,
    this.needsRetrieval = false,
  });

  final String displayName;
  /// Latitude - may be null if needsRetrieval is true (Mapbox suggestion not yet retrieved)
  final double? latitude;
  /// Longitude - may be null if needsRetrieval is true (Mapbox suggestion not yet retrieved)
  final double? longitude;
  final String? address;
  final String? placeType;
  final List<double>? bbox; // [minLon, minLat, maxLon, maxLat]
  final String? trailId; // For trail results
  final Map<String, dynamic>? trailData; // Complete trail data for selection
  /// Mapbox ID for deferred coordinate retrieval (Search Box API)
  final String? mapboxId;
  /// True if coordinates need to be fetched via /retrieve endpoint
  final bool needsRetrieval;

  /// Create from Mapbox Geocoding API response (v5 format)
  factory MapSearchResult.fromMapboxFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    // v5 API uses different field names than v6
    final placeName = feature['place_name'] as String? ?? 'Unknown Location';
    final text = feature['text'] as String?;

    // Get place type from place_type array
    String? placeType;
    if (feature['place_type'] != null) {
      final placeTypes = feature['place_type'] as List<dynamic>;
      if (placeTypes.isNotEmpty) {
        placeType = placeTypes.first as String;
      }
    }

    // Get bounding box if available
    List<double>? bbox;
    if (feature['bbox'] != null) {
      final bboxData = feature['bbox'] as List<dynamic>;
      bbox = bboxData.map((e) => (e as num).toDouble()).toList();
    }

    return MapSearchResult(
      displayName: text ?? placeName,
      latitude: (coordinates[1] as num).toDouble(),
      longitude: (coordinates[0] as num).toDouble(),
      address: placeName,
      placeType: placeType,
      bbox: bbox,
    );
  }

  /// Create from Mapbox Search Box API response
  factory MapSearchResult.fromSearchBoxFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};

    // Get coordinates from geometry
    double latitude = 0;
    double longitude = 0;
    if (geometry != null) {
      final coordinates = geometry['coordinates'] as List<dynamic>?;
      if (coordinates != null && coordinates.length >= 2) {
        longitude = (coordinates[0] as num).toDouble();
        latitude = (coordinates[1] as num).toDouble();
      }
    }

    // Get name and address from properties
    final name = properties['name'] as String? ?? 'Unknown Location';
    final fullAddress = properties['full_address'] as String?;
    final placeFormatted = properties['place_formatted'] as String?;

    // Get place type from feature_type or poi_category
    String? placeType = properties['feature_type'] as String?;
    final poiCategory = properties['poi_category'] as List<dynamic>?;
    if (poiCategory != null && poiCategory.isNotEmpty) {
      // Use first POI category for more specific type
      placeType = poiCategory.first as String?;
    }

    return MapSearchResult(
      displayName: name,
      latitude: latitude,
      longitude: longitude,
      address: fullAddress ?? placeFormatted,
      placeType: placeType,
    );
  }

  /// Create from Mapbox Search Box suggestion (without coordinates)
  /// Coordinates will be fetched lazily when user selects this result
  factory MapSearchResult.fromSearchBoxSuggestion(Map<String, dynamic> suggestion) {
    final name = suggestion['name'] as String? ?? 'Unknown Location';
    final placeFormatted = suggestion['place_formatted'] as String?;
    final fullAddress = suggestion['full_address'] as String?;
    final mapboxId = suggestion['mapbox_id'] as String?;

    // Get place type from feature_type
    String? placeType = suggestion['feature_type'] as String?;
    final poiCategory = suggestion['poi_category'] as List<dynamic>?;
    if (poiCategory != null && poiCategory.isNotEmpty) {
      placeType = poiCategory.first as String?;
    }

    return MapSearchResult(
      displayName: name,
      address: fullAddress ?? placeFormatted,
      placeType: placeType,
      mapboxId: mapboxId,
      needsRetrieval: true, // Coordinates not yet fetched
    );
  }

  /// Create a copy with coordinates after retrieval
  MapSearchResult withCoordinates({
    required double latitude,
    required double longitude,
    List<double>? bbox,
  }) {
    return MapSearchResult(
      displayName: displayName,
      latitude: latitude,
      longitude: longitude,
      address: address,
      placeType: placeType,
      bbox: bbox,
      trailId: trailId,
      trailData: trailData,
      mapboxId: mapboxId,
      // needsRetrieval defaults to false
    );
  }

  /// Create from Trail object
  factory MapSearchResult.fromTrail(Trail trail) {
    // Calculate center point of trail from geometry
    final coordinates = trail.geometry.coordinates;
    double centerLat = 0;
    double centerLon = 0;

    if (coordinates.isNotEmpty) {
      // Use first coordinate as center for simplicity
      // For better accuracy, could calculate actual centroid
      centerLon = (coordinates.first[0] as num).toDouble();
      centerLat = (coordinates.first[1] as num).toDouble();
    }

    // Calculate bbox from all coordinates
    List<double>? bbox;
    if (coordinates.isNotEmpty) {
      double minLon = double.infinity;
      double minLat = double.infinity;
      double maxLon = double.negativeInfinity;
      double maxLat = double.negativeInfinity;

      for (final coord in coordinates) {
        final lon = (coord[0] as num).toDouble();
        final lat = (coord[1] as num).toDouble();
        if (lon < minLon) minLon = lon;
        if (lat < minLat) minLat = lat;
        if (lon > maxLon) maxLon = lon;
        if (lat > maxLat) maxLat = lat;
      }

      bbox = [minLon, minLat, maxLon, maxLat];
    }

    // Build descriptive address with location context
    final details = <String>[];

    // Add state name if available (helps distinguish trails with same name)
    final stateName = getStateName(trail.stateCode);
    if (stateName != null) {
      details.add(stateName);
    }

    if (trail.lengthMiles > 0) {
      details.add('${trail.lengthMiles.toStringAsFixed(1)} mi');
    }
    if (trail.difficulty != null && trail.difficulty!.isNotEmpty) {
      details.add(trail.difficulty!);
    }
    if (trail.managingAgency != null &&
        trail.managingAgency!.isNotEmpty &&
        trail.managingAgency != 'Community (OSM)') {
      details.add(trail.managingAgency!);
    }

    final address = details.join(' • ');

    return MapSearchResult(
      displayName: trail.trailName,
      latitude: centerLat,
      longitude: centerLon,
      address: address.isNotEmpty ? address : null,
      placeType: 'trail',
      bbox: bbox,
      trailId: trail.id,
      trailData: trail.toJson(),
    );
  }

  /// Create from HistoricalPlace object (GNIS data - mines, ghost towns, etc.)
  factory MapSearchResult.fromHistoricalPlace(HistoricalPlace place) {
    // Build descriptive address with location context
    final details = <String>[];
    final typeMeta = place.typeMetadata;

    // Add place type (Mine, Locale, Cemetery, etc.)
    details.add(typeMeta.name);

    // Add state name
    final stateName = getStateName(place.stateCode);
    if (stateName != null) {
      details.add(stateName);
    }

    // Add county if available
    if (place.countyName != null && place.countyName!.isNotEmpty) {
      details.add('${place.countyName} County');
    }

    // Add elevation if available
    if (place.elevationFormatted != null) {
      details.add(place.elevationFormatted!);
    }

    final address = details.join(' • ');

    return MapSearchResult(
      displayName: place.featureName,
      latitude: place.latitude,
      longitude: place.longitude,
      address: address.isNotEmpty ? address : null,
      placeType: 'historical_${place.typeCode.toLowerCase()}',
    );
  }

  @override
  String toString() => '$displayName ($latitude, $longitude)';
}

/// Service for searching locations on the map by name or coordinates
class MapSearchService {
  MapSearchService({required this.mapboxAccessToken});

  final String mapboxAccessToken;

  static const String _baseUrl = 'https://api.mapbox.com';

  /// Search for locations by query string
  ///
  /// Supports:
  /// - Place names: "Black Hills National Forest"
  /// - Addresses: "123 Main St, Rapid City, SD"
  /// - Coordinates: "44.5, -103.5" or "44.5,-103.5" or "44°30'N 103°30'W"
  /// - Trail names: "Tea Kettle Trail", "George Mickelson Trail"
  ///
  /// If bounds are provided, trail search will first check local cache (instant),
  /// then optionally search online for more results.
  Future<List<MapSearchResult>> search(String query, {
    double? proximityLat,
    double? proximityLon,
    double? northBound,
    double? southBound,
    double? eastBound,
    double? westBound,
    int limit = 5,
    bool searchOnlineTrails = false, // Only search BFF if explicitly requested
    List<SavedLocation>? savedLocations,
  }) async {
    if (query.isEmpty) return [];

    // First try to parse as coordinates
    final coordResult = _parseCoordinates(query);
    if (coordResult != null) {
      return [coordResult];
    }

    // Filter saved locations matching query (instant, offline)
    final savedResults = <MapSearchResult>[];
    if (savedLocations != null && savedLocations.isNotEmpty) {
      final queryLower = query.toLowerCase();
      savedResults.addAll(
        savedLocations
            .where((loc) =>
                loc.displayName.toLowerCase().contains(queryLower) ||
                (loc.address?.toLowerCase().contains(queryLower) ?? false))
            .map((loc) => loc.toSearchResult()),
      );
    }
    final savedNames = savedResults
        .map((r) => r.displayName.toLowerCase())
        .toSet();

    // Search places, trails, and historical places concurrently
    final results = await Future.wait<List<MapSearchResult>>([
      _geocodeQuery(
        query,
        proximityLat: proximityLat,
        proximityLon: proximityLon,
        limit: limit,
      ),
      _searchTrails(
        query,
        limit: limit,
        northBound: northBound,
        southBound: southBound,
        eastBound: eastBound,
        westBound: westBound,
        searchOnline: searchOnlineTrails,
      ),
      _searchHistoricalPlaces(
        query,
        limit: limit,
      ),
    ]);

    final placeResults = results[0];
    final trailResults = results[1];
    final historicalResults = results[2];

    // De-duplicate: skip API results already in saved locations
    bool notDuplicate(MapSearchResult r) =>
        !savedNames.contains(r.displayName.toLowerCase());

    // Combine results: saved locations first, then historical,
    // trails, and general places
    final combined = <MapSearchResult>[
      ...savedResults,
      ...historicalResults.where(notDuplicate),
      ...trailResults.where(notDuplicate),
      ...placeResults.where(notDuplicate),
    ];

    // Limit total results
    return combined.take(limit + 5).toList(); // Allow extra for local results
  }

  /// Parse coordinate strings in various formats
  ///
  /// Supported formats:
  /// - "44.5, -103.5" or "44.5,-103.5" (decimal degrees with comma)
  /// - "44.5 -103.5" (decimal degrees with space)
  /// - "44°30'N 103°30'W" (degrees minutes)
  /// - "44°30'15\"N 103°30'45\"W" (degrees minutes seconds)
  MapSearchResult? _parseCoordinates(String query) {
    final trimmed = query.trim();

    // Try decimal degrees format: "44.5, -103.5" or "44.5,-103.5"
    final decimalRegex = RegExp(
      r'^(-?\d+\.?\d*)[,\s]+(-?\d+\.?\d*)$',
    );
    final decimalMatch = decimalRegex.firstMatch(trimmed);
    if (decimalMatch != null) {
      final lat = double.tryParse(decimalMatch.group(1)!);
      final lon = double.tryParse(decimalMatch.group(2)!);
      if (lat != null && lon != null && _isValidCoordinate(lat, lon)) {
        return MapSearchResult(
          displayName: 'Coordinates: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
          latitude: lat,
          longitude: lon,
          placeType: 'coordinate',
        );
      }
    }

    // Try DMS format: "44°30'15"N 103°30'45"W"
    final dmsRegex = RegExp(
      r'''(\d+)[°\s]+(\d+)['\s]+(\d+\.?\d*)["'\s]*([NS])\s+(\d+)[°\s]+(\d+)['\s]+(\d+\.?\d*)["'\s]*([EW])''',
    );
    final dmsMatch = dmsRegex.firstMatch(trimmed);
    if (dmsMatch != null) {
      final latDeg = int.parse(dmsMatch.group(1)!);
      final latMin = int.parse(dmsMatch.group(2)!);
      final latSec = double.parse(dmsMatch.group(3)!);
      final latDir = dmsMatch.group(4)!;

      final lonDeg = int.parse(dmsMatch.group(5)!);
      final lonMin = int.parse(dmsMatch.group(6)!);
      final lonSec = double.parse(dmsMatch.group(7)!);
      final lonDir = dmsMatch.group(8)!;

      var lat = latDeg + (latMin / 60.0) + (latSec / 3600.0);
      if (latDir == 'S') lat = -lat;

      var lon = lonDeg + (lonMin / 60.0) + (lonSec / 3600.0);
      if (lonDir == 'W') lon = -lon;

      if (_isValidCoordinate(lat, lon)) {
        return MapSearchResult(
          displayName: 'Coordinates: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
          latitude: lat,
          longitude: lon,
          placeType: 'coordinate',
        );
      }
    }

    // Try DM format (degrees and minutes): "44°30'N 103°30'W"
    final dmRegex = RegExp(
      r"(\d+)[°\s]+(\d+\.?\d*)['\s]*([NS])\s+(\d+)[°\s]+(\d+\.?\d*)['\s]*([EW])",
    );
    final dmMatch = dmRegex.firstMatch(trimmed);
    if (dmMatch != null) {
      final latDeg = int.parse(dmMatch.group(1)!);
      final latMin = double.parse(dmMatch.group(2)!);
      final latDir = dmMatch.group(3)!;

      final lonDeg = int.parse(dmMatch.group(4)!);
      final lonMin = double.parse(dmMatch.group(5)!);
      final lonDir = dmMatch.group(6)!;

      var lat = latDeg + (latMin / 60.0);
      if (latDir == 'S') lat = -lat;

      var lon = lonDeg + (lonMin / 60.0);
      if (lonDir == 'W') lon = -lon;

      if (_isValidCoordinate(lat, lon)) {
        return MapSearchResult(
          displayName: 'Coordinates: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
          latitude: lat,
          longitude: lon,
          placeType: 'coordinate',
        );
      }
    }

    return null;
  }

  /// Validate coordinate ranges
  bool _isValidCoordinate(double lat, double lon) {
    return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
  }

  /// Current session token for grouping suggest + retrieve calls
  /// This ensures a single search + selection = 1 billable session
  String? _currentSessionToken;

  /// Use Mapbox Search Box API to search for places and POIs
  /// This API has better coverage for parks, landmarks, and points of interest
  /// than the Geocoding API (which is primarily for addresses)
  ///
  /// Returns suggestions WITHOUT coordinates. Call [retrieveCoordinates] when
  /// user selects a result to get the full details. This optimizes billing by
  /// only calling /retrieve for the selected result (1 session = 1 suggest + 1 retrieve).
  Future<List<MapSearchResult>> _geocodeQuery(
    String query, {
    double? proximityLat,
    double? proximityLon,
    int limit = 5,
  }) async {
    try {
      // Generate session token for billing (groups suggest + retrieve calls)
      // Store it so retrieveCoordinates can use the same token
      _currentSessionToken = const Uuid().v4();

      // Build suggest query parameters
      // Note: Do NOT pre-encode the query — Uri.replace(queryParameters:)
      // handles encoding automatically. Double-encoding breaks searches
      // with commas/spaces (e.g., "Polaris, MT" → "Polaris%252C%2520MT").
      final params = <String, String>{
        'q': query,
        'access_token': mapboxAccessToken,
        'session_token': _currentSessionToken!,
        'limit': limit.toString(),
        'country': 'US',
        'types': 'poi,place,address,locality,neighborhood,region',
        'language': 'en',
      };

      // Add proximity bias if provided
      if (proximityLat != null && proximityLon != null) {
        params['proximity'] = '$proximityLon,$proximityLat';
      }

      // Call Search Box suggest endpoint
      final suggestUrl = Uri.parse('$_baseUrl/search/searchbox/v1/suggest')
          .replace(queryParameters: params);

      debugPrint('🔍 Search Box query: $query');
      final suggestResponse = await http.get(suggestUrl);

      if (suggestResponse.statusCode != 200) {
        debugPrint('❌ Search Box API error: ${suggestResponse.statusCode}');
        return [];
      }

      final suggestData = json.decode(suggestResponse.body) as Map<String, dynamic>;
      final suggestions = suggestData['suggestions'] as List<dynamic>?;

      if (suggestions == null || suggestions.isEmpty) {
        debugPrint('⚠️ No suggestions found for: $query');
        return [];
      }

      // Create results from suggestions WITHOUT calling retrieve
      // Coordinates will be fetched lazily when user selects a result
      final results = <MapSearchResult>[];
      for (final suggestion in suggestions) {
        final suggestionMap = suggestion as Map<String, dynamic>;
        final mapboxId = suggestionMap['mapbox_id'] as String?;
        if (mapboxId == null) continue;
        results.add(MapSearchResult.fromSearchBoxSuggestion(suggestionMap));
      }

      debugPrint('✅ Found ${results.length} suggestions for: $query (coordinates pending)');
      return results;
    } catch (e, stackTrace) {
      debugPrint('❌ Search Box error: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Retrieve coordinates for a Mapbox Search Box result
  ///
  /// Call this when user selects a result that has `needsRetrieval` = true.
  /// Uses the session token from the original search to ensure proper billing
  /// (1 session = suggest calls + 1 retrieve call).
  Future<MapSearchResult?> retrieveCoordinates(MapSearchResult result) async {
    if (!result.needsRetrieval || result.mapboxId == null) {
      // Already has coordinates or not a Mapbox result
      return result;
    }

    try {
      // Use stored session token, or generate new one if expired
      final sessionToken = _currentSessionToken ?? const Uuid().v4();

      final retrieveUrl = Uri.parse(
        '$_baseUrl/search/searchbox/v1/retrieve/${result.mapboxId}',
      ).replace(queryParameters: {
        'access_token': mapboxAccessToken,
        'session_token': sessionToken,
      });

      debugPrint('📍 Retrieving coordinates for: ${result.displayName}');
      final retrieveResponse = await http.get(retrieveUrl);

      if (retrieveResponse.statusCode != 200) {
        debugPrint('❌ Retrieve API error: ${retrieveResponse.statusCode}');
        return null;
      }

      final retrieveData = json.decode(retrieveResponse.body) as Map<String, dynamic>;
      final features = retrieveData['features'] as List<dynamic>?;

      if (features == null || features.isEmpty) {
        debugPrint('⚠️ No features in retrieve response');
        return null;
      }

      final feature = features[0] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>?;

      if (geometry == null) {
        debugPrint('⚠️ No geometry in retrieve response');
        return null;
      }

      final coordinates = geometry['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.length < 2) {
        debugPrint('⚠️ Invalid coordinates in retrieve response');
        return null;
      }

      final longitude = (coordinates[0] as num).toDouble();
      final latitude = (coordinates[1] as num).toDouble();

      // Get bbox if available
      List<double>? bbox;
      final properties = feature['properties'] as Map<String, dynamic>?;
      if (properties != null && properties['bbox'] != null) {
        final bboxData = properties['bbox'] as List<dynamic>;
        bbox = bboxData.map((e) => (e as num).toDouble()).toList();
      }

      debugPrint('✅ Retrieved coordinates: $latitude, $longitude');
      return result.withCoordinates(
        latitude: latitude,
        longitude: longitude,
        bbox: bbox,
      );
    } catch (e) {
      debugPrint('❌ Retrieve error: $e');
      return null;
    }
  }

  /// Get detailed information about a specific place
  /// Note: v5 API doesn't support place ID lookup, use search instead
  @Deprecated('Use search() instead - v5 API does not support place ID retrieval')
  Future<MapSearchResult?> getPlaceDetails(String placeId) async {
    debugPrint('⚠️ getPlaceDetails is not supported in Geocoding v5 API');
    return null;
  }

  /// Reverse geocode coordinates to get place name
  Future<MapSearchResult?> reverseGeocode(double lat, double lon) async {
    try {
      // v5 API format: /geocoding/v5/{endpoint}/{longitude},{latitude}.json
      final url = Uri.parse(
        '$_baseUrl/geocoding/v5/mapbox.places/$lon,$lat.json',
      ).replace(queryParameters: {
        'access_token': mapboxAccessToken,
      });

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;

        if (features != null && features.isNotEmpty) {
          return MapSearchResult.fromMapboxFeature(
            features.first as Map<String, dynamic>,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Reverse geocoding error: $e');
      return null;
    }
  }

  /// Search for trails by name
  /// First searches local cache if bounds are provided, then optionally searches BFF
  Future<List<MapSearchResult>> _searchTrails(
    String query, {
    int limit = 3,
    double? northBound,
    double? southBound,
    double? eastBound,
    double? westBound,
    bool searchOnline = false,
  }) async {
    try {
      debugPrint('🔍 Searching trails: "$query"');

      // If bounds provided, search local cache first (instant)
      if (northBound != null && southBound != null && eastBound != null && westBound != null) {
        final cacheService = OfflineCacheService();
        final localTrails = await cacheService.searchCachedTrailsByName(
          query: query,
          northBound: northBound,
          southBound: southBound,
          eastBound: eastBound,
          westBound: westBound,
          limit: limit,
        );

        if (localTrails.isNotEmpty) {
          debugPrint('✅ Found ${localTrails.length} trails locally for "$query"');
          return localTrails.map(MapSearchResult.fromTrail).toList();
        }

        // If no local results and not searching online, return empty
        if (!searchOnline) {
          debugPrint('📴 No local trails found for "$query" (online search disabled)');
          return [];
        }
      }

      // Search online via BFF (either no bounds, or searchOnline explicitly requested)
      if (!searchOnline && northBound != null) {
        // Don't hit BFF unless explicitly requested when we have bounds
        return [];
      }

      debugPrint('🌐 Searching trails online: "$query"');
      final trails = await BFFMappingService.instance.searchTrails(
        query,
        limit: limit,
      );

      debugPrint('✅ Found ${trails.length} trails online for "$query"');

      // Convert trails to search results
      return trails
          .map(MapSearchResult.fromTrail)
          .toList();
    } catch (e) {
      debugPrint('❌ Trail search error: $e');
      return [];
    }
  }

  /// Search for historical places by name (mines, ghost towns, cemeteries, etc.)
  /// Searches locally cached GNIS data
  Future<List<MapSearchResult>> _searchHistoricalPlaces(
    String query, {
    int limit = 5,
  }) async {
    try {
      debugPrint('🔍 Searching historical places: "$query"');

      final offlineService = OfflineLandRightsService();
      await offlineService.initialize();

      final places = await offlineService.searchHistoricalPlaces(
        query: query,
        limit: limit,
      );

      if (places.isNotEmpty) {
        debugPrint('✅ Found ${places.length} historical places for "$query"');
      } else {
        debugPrint('📴 No historical places found for "$query"');
      }

      return places.map(MapSearchResult.fromHistoricalPlace).toList();
    } catch (e) {
      debugPrint('❌ Historical places search error: $e');
      return [];
    }
  }
}
