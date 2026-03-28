import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/models/access_rights.dart';
import 'package:obsession_tracker/core/models/activity_permissions.dart';
import 'package:obsession_tracker/core/models/cell_tower.dart';
import 'package:obsession_tracker/core/models/comprehensive_land_ownership.dart';
import 'package:obsession_tracker/core/models/historical_place.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/trail.dart';
import 'package:obsession_tracker/core/services/device_registration_service.dart';
import 'package:obsession_tracker/core/services/nhp_download_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';
import 'package:path_provider/path_provider.dart';

/// Event broadcasted when maintenance mode is detected from GraphQL errors
class MaintenanceModeEvent {
  const MaintenanceModeEvent({
    required this.code,
    this.message,
    this.estimatedEnd,
  });

  /// Error code: MAINTENANCE_MODE or SERVICE_UNAVAILABLE
  final String code;

  /// User-friendly message from server
  final String? message;

  /// Estimated end time (only for MAINTENANCE_MODE)
  final DateTime? estimatedEnd;
}

// ============================================================================
// State Download Result Types (Bulk Download API)
// ============================================================================

/// Base class for state download results
sealed class StateDownloadResult {
  const StateDownloadResult();
}

/// Successful state download with land ownership data
class StateDownloadSuccess extends StateDownloadResult {
  const StateDownloadSuccess({
    required this.stateCode,
    required this.dataVersion,
    required this.recordCount,
    required this.estimatedSizeBytes,
    required this.landOwnerships,
  });

  /// State code that was downloaded
  final String stateCode;

  /// Data version (e.g., "PAD-US-4.1")
  final String dataVersion;

  /// Total number of properties
  final int recordCount;

  /// Estimated size in bytes
  final int estimatedSizeBytes;

  /// The actual land ownership data
  final List<ComprehensiveLandOwnership> landOwnerships;
}

/// Rate limited response - must wait before downloading again
class StateDownloadRateLimited extends StateDownloadResult {
  const StateDownloadRateLimited({
    required this.stateCode,
    required this.reason,
    required this.cooldownRemainingSeconds,
    required this.message,
  });

  /// State code requested
  final String stateCode;

  /// Reason for rate limiting
  final String reason;

  /// Seconds remaining until download is allowed
  final int cooldownRemainingSeconds;

  /// User-friendly message
  final String message;
}

/// Error response for state download
class StateDownloadError extends StateDownloadResult {
  const StateDownloadError({
    required this.code,
    required this.message,
  });

  /// Error code (e.g., "INVALID_STATE", "DATABASE_ERROR")
  final String code;

  /// Human-readable error message
  final String message;
}

/// Data version information from BFF
/// Used for version-based cache invalidation instead of time-based
class DataVersion {
  const DataVersion({
    required this.sourceType,
    required this.version,
    this.releaseDate,
    this.description,
    required this.updatedAt,
  });

  /// Data source type: 'land_ownership', 'trails', 'private_land'
  final String sourceType;

  /// Version string: 'PAD-US-4.1', 'OSM-2024-12', etc.
  final String version;

  /// When this version was released
  final DateTime? releaseDate;

  /// Human-readable description
  final String? description;

  /// When the version was last updated on the server
  final DateTime updatedAt;

  factory DataVersion.fromJson(Map<String, dynamic> json) {
    return DataVersion(
      sourceType: json['sourceType'] as String,
      version: json['version'] as String,
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate'] as String)
          : null,
      description: json['description'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Service for fetching mapping data through the BFF GraphQL API
class BFFMappingService {
  BFFMappingService._internal();
  static final BFFMappingService _instance = BFFMappingService._internal();
  static BFFMappingService get instance => _instance;

  /// Stream controller for broadcasting maintenance mode events
  /// Broadcast controllers for app-lifetime singletons don't need explicit closing
  // ignore: close_sinks
  static final StreamController<MaintenanceModeEvent> _maintenanceController =
      StreamController<MaintenanceModeEvent>.broadcast();

  /// Stream of maintenance mode events - subscribe to detect maintenance mode
  static Stream<MaintenanceModeEvent> get maintenanceStream =>
      _maintenanceController.stream;

  final OfflineLandRightsService _sqliteCache = OfflineLandRightsService();

  /// In-memory cache for loaded state trails
  /// Key: state code (e.g., "SD"), Value: list of trails for that state
  /// This prevents re-querying SQLite when panning within the same state
  final Map<String, List<Trail>> _stateTrailsCache = {};

  /// Cached connectivity instance for more reliable checks
  static final Connectivity _connectivity = Connectivity();

  /// Check if device is online
  ///
  /// The connectivity plugin can return stale/incorrect results on first check,
  /// so we retry once after a short delay if we get "none" initially.
  Future<bool> get isOnline async {
    try {
      var connectivityResult = await _connectivity.checkConnectivity();

      // Empty result can happen during plugin initialization - assume online
      if (connectivityResult.isEmpty) {
        debugPrint('⚠️ Connectivity check returned empty - assuming online');
        return true;
      }

      // Check if we have a real connection
      bool hasConnection = connectivityResult.contains(ConnectivityResult.mobile) ||
             connectivityResult.contains(ConnectivityResult.wifi) ||
             connectivityResult.contains(ConnectivityResult.ethernet);

      // If "none", retry once after short delay - plugin may not be initialized
      if (!hasConnection && connectivityResult.contains(ConnectivityResult.none)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        connectivityResult = await _connectivity.checkConnectivity();
        hasConnection = connectivityResult.contains(ConnectivityResult.mobile) ||
             connectivityResult.contains(ConnectivityResult.wifi) ||
             connectivityResult.contains(ConnectivityResult.ethernet);
      }

      return hasConnection;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      // Assume online if connectivity check fails to avoid breaking app
      return true;
    }
  }

  /// Query zoom-aware land ownership data with appropriate level of detail
  /// Optimized for performance at different map zoom levels
  Future<List<LandOwnership>> getZoomAwareLandOwnershipData({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    required double zoomLevel,
    int? limit,
  }) async {
    // Determine appropriate limit and detail level based on zoom
    final effectiveLimit = limit ?? _getLimitForZoomLevel(zoomLevel);

    // Use the existing comprehensive method but with zoom-appropriate limits
    debugPrint('BFF Service: Fetching land data for zoom level $zoomLevel with limit $effectiveLimit');

    // Get comprehensive data with zoom level and convert to legacy format
    final comprehensiveResults = await getComprehensiveLandRightsData(
      northBound: northBound,
      southBound: southBound,
      eastBound: eastBound,
      westBound: westBound,
      limit: effectiveLimit,
    );

    // Convert comprehensive results to legacy format for backward compatibility
    return comprehensiveResults.map((property) {
      // Create bounds from property boundaries
      final bounds = _calculateBoundsFromCoordinates(property.bestBoundaries);
      final centroid = LandPoint(
        latitude: (bounds.north + bounds.south) / 2,
        longitude: (bounds.east + bounds.west) / 2,
      );

      return LandOwnership(
        id: property.id,
        ownershipType: _parseOwnershipType(property.ownershipType),
        ownerName: property.ownerName,
        agencyName: property.agencyName,
        unitName: property.unitName,
        designation: property.designation,
        accessType: _parseAccessType(property.accessType),
        allowedUses: property.allowedUses.map(_parseUseType).toList(),
        restrictions: property.restrictions,
        contactInfo: property.contactInfo,
        website: property.website,
        fees: property.fees,
        seasonalInfo: property.seasonalInfo,
        bounds: bounds,
        centroid: centroid,
        polygonCoordinates: property.bestBoundaries,
        dataSource: property.dataSource,
        dataSourceDate: property.lastUpdated,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();
  }

  /// Get appropriate query limit based on zoom level
  /// NOTE: Zoom-based limits are now handled in MapPage._loadLandDataForCurrentView()
  /// and MapPage._loadTrailsDataForCurrentView() for better control and UI feedback.
  /// This method is kept for backward compatibility with the zoom-aware query method.
  int _getLimitForZoomLevel(double zoomLevel) {
    // Progressive limits based on zoom level (matches map_page.dart logic)
    if (zoomLevel >= 14) {
      return 2000; // Street level - full detail
    } else if (zoomLevel >= 12) {
      return 1000; // Neighborhood level
    } else if (zoomLevel >= 10) {
      return 500; // City level - overview
    } else {
      return 100; // Very zoomed out - minimal data
    }
  }

  /// Query comprehensive land ownership data from federated mobile subgraph
  /// Optimized for GPS navigation with complete land rights information
  Future<List<LandOwnership>> getLandOwnershipData({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int limit = 50,
    double? zoomLevel,
  }) async {
    // Delegate to the comprehensive method and convert results
    final comprehensiveResults = await getComprehensiveLandRightsData(
      northBound: northBound,
      southBound: southBound,
      eastBound: eastBound,
      westBound: westBound,
      limit: limit,
      zoomLevel: zoomLevel,
    );
    
    // Convert comprehensive results to legacy format for backward compatibility
    return comprehensiveResults.map((property) {
      // Create bounds from property boundaries
      final bounds = _calculateBoundsFromCoordinates(property.bestBoundaries);
      final centroid = LandPoint(
        latitude: (bounds.north + bounds.south) / 2,
        longitude: (bounds.east + bounds.west) / 2,
      );

      return LandOwnership(
        id: property.id,
        ownershipType: _parseOwnershipType(property.ownershipType),
        ownerName: property.ownerName,
        agencyName: property.agencyName,
        unitName: property.unitName,
        designation: property.designation,
        accessType: _parseAccessType(property.accessType),
        allowedUses: property.allowedUses.map(_parseUseType).toList(),
        restrictions: property.restrictions,
        contactInfo: property.contactInfo,
        website: property.website,
        fees: property.fees,
        seasonalInfo: property.seasonalInfo,
        bounds: bounds,
        centroid: centroid,
        polygonCoordinates: property.bestBoundaries,
        dataSource: property.dataSource,
        dataSourceDate: property.lastUpdated,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        // Include activity permissions from comprehensive data
        activityPermissions: property.activityPermissions,
        ownerContact: property.ownerContact,
      );
    }).toList();
  }

  /// Query comprehensive land rights data for offline caching and permission alerts
  /// This is the primary method for production federated GraphQL integration
  ///
  /// CACHE PRIORITY:
  /// 1. SQLite state downloads (OfflineLandRightsService) - bulk state data
  /// 2. BFF live query if online and no local coverage
  ///
  /// NOTE: SharedPreferences cache (OfflineCacheService) is deprecated for land data.
  /// It's only used for trails now.
  Future<List<ComprehensiveLandOwnership>> getComprehensiveLandRightsData({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int limit = 50,
    double? zoomLevel,
  }) async {
    // ==========================================================================
    // PRIORITY 1: Check if ANY state data is downloaded (works in mock mode!)
    // ==========================================================================
    // Query by viewport bounds across ALL downloaded states.
    // No state filter needed - data is correctly assigned at generation time
    // using TIGER polygon boundaries (not bounding boxes).
    // ==========================================================================
    await _sqliteCache.initialize();

    // Check if any state data exists in SQLite
    final downloadedStates = await _sqliteCache.getDownloadedStates();

    if (downloadedStates.isNotEmpty) {
      // Query ALL properties in viewport bounds (from any downloaded state)
      // This allows viewing data from multiple states when on a border
      final sqliteData = await _sqliteCache.queryPropertiesForBounds(
        northBound: northBound,
        southBound: southBound,
        eastBound: eastBound,
        westBound: westBound,
        limit: limit,
        zoomLevel: zoomLevel,
        // No stateCode filter - data is correctly assigned via TIGER polygons
      );

      final stateList = downloadedStates.map((s) => s.stateCode).join(', ');
      debugPrint('💾 SQLite: Found ${sqliteData.length} properties in viewport (downloaded: $stateList, zoom: ${zoomLevel?.toStringAsFixed(1) ?? "?"})');
      return sqliteData;
    }

    // ==========================================================================
    // PRIORITY 2: Check if we're offline - return empty if no local data
    // ==========================================================================
    final online = await isOnline;
    if (!online) {
      debugPrint('📴 OFFLINE: No state downloads cover this area');
      return [];
    }

    // ==========================================================================
    // ZIP-ONLY MODE: No BFF fallback for land data
    // ==========================================================================
    // Live BFF queries for land data are disabled to prevent:
    // - Alaska massive geometry timeouts (11+ seconds)
    // - Memory issues with large polygons
    // - Poor UX when BFF is slow or unavailable
    //
    // Users must download state ZIP files for land data coverage.
    // Trails still use live BFF queries (they're fast and small).
    // ==========================================================================
    debugPrint('📥 No local land data - download state ZIP for coverage');
    debugPrint('   Viewport: N:$northBound, S:$southBound, E:$eastBound, W:$westBound');
    return [];
  }

  /// Get detailed land ownership information by ID
  /// NOTE: GraphQL removed - use local SQLite data instead
  Future<LandOwnership?> getLandOwnershipDetails(String id) async {
    debugPrint('⚠️ getLandOwnershipDetails: GraphQL removed, use local data');
    return null;
  }

  /// Search for land ownership by name or location
  /// NOTE: GraphQL removed - use local SQLite data instead
  Future<List<LandOwnership>> searchLandOwnership({
    required String query,
    double? latitude,
    double? longitude,
    int limit = 20,
  }) async {
    debugPrint('⚠️ searchLandOwnership: GraphQL removed, use local data');
    return [];
  }

  /// Get available data sources and their status
  /// NOTE: GraphQL removed - no longer available
  Future<List<Map<String, dynamic>>> getDataSourceStatus() async {
    debugPrint('⚠️ getDataSourceStatus: GraphQL removed');
    return [];
  }

  /// Get data versions for all data sources
  /// NOTE: GraphQL removed - versions tracked locally
  Future<List<DataVersion>> getDataVersions() async {
    debugPrint('⚠️ getDataVersions: GraphQL removed');
    return [];
  }

  /// Test connection to federated BFF system
  /// NOTE: GraphQL removed - use health endpoint instead
  Future<Map<String, dynamic>> testFederatedConnection() async {
    debugPrint('⚠️ testFederatedConnection: GraphQL removed');
    return {
      'success': false,
      'error': 'GraphQL removed - use REST health endpoint',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get comprehensive land rights data with retry logic for mobile reliability
  Future<List<ComprehensiveLandOwnership>> getComprehensiveLandRightsDataWithRetry({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int limit = 50,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < maxRetries) {
      try {
        attempt++;
        debugPrint('BFF Service: Attempt $attempt/$maxRetries for land rights query');
        
        final result = await getComprehensiveLandRightsData(
          northBound: northBound,
          southBound: southBound,
          eastBound: eastBound,
          westBound: westBound,
          limit: limit,
        );
        
        debugPrint('BFF Service: Successfully retrieved ${result.length} properties on attempt $attempt');
        return result;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint('BFF Service: Attempt $attempt failed: $e');
        
        if (attempt < maxRetries) {
          final delaySeconds = math.pow(2, attempt - 1).toInt(); // Exponential backoff
          debugPrint('BFF Service: Retrying in ${delaySeconds}s...');
          await Future<void>.delayed(Duration(seconds: delaySeconds));
        }
      }
    }
    
    debugPrint('BFF Service: All retry attempts failed, throwing last exception');
    throw lastException ?? Exception('Unknown error during land rights query');
  }

  /// Trigger data sync for a specific data source (admin operation)
  /// NOTE: GraphQL removed - no longer available
  Future<bool> triggerDataSync({
    required String dataSourceType,
    String? stateCode,
    Map<String, double>? bounds,
  }) async {
    debugPrint('⚠️ triggerDataSync: GraphQL removed');
    return false;
  }

  LandOwnershipType _parseOwnershipType(String? type) {
    switch (type?.toLowerCase()) {
      // ======================================================================
      // PAD-US Standard Ownership Codes (Own_Type field)
      // Reference: https://www.usgs.gov/programs/gap-analysis-project/pad-us-data-manual
      // ======================================================================

      // FED - Federal Land
      case 'fed':
      case 'federal':
      case 'federal_land':
      case 'federalland':
        return LandOwnershipType.federalLand;

      // STAT - State Land
      case 'stat':
      case 'stateland':
      case 'state_land':
      case 'state':
        return LandOwnershipType.stateLand;

      // LOC - Local Government (cities, counties, municipalities)
      case 'loc':
      case 'local_government':
        return LandOwnershipType.countyLand;

      // DIST - Special District (water, irrigation, school, utility districts)
      // These are quasi-governmental entities - map to county/local
      case 'dist':
      case 'district':
      case 'special_district':
        return LandOwnershipType.countyLand;

      // JNT - Joint Ownership (multiple agencies, often federal+state)
      // Map to federal since joint ownership typically involves federal management
      case 'jnt':
      case 'joint':
      case 'joint_ownership':
        return LandOwnershipType.federalLand;

      // PVT - Private Land
      case 'pvt':
      case 'privateland':
      case 'private':
      case 'private_land':
        return LandOwnershipType.privateLand;

      // TRIB - Tribal Land
      case 'trib':
      case 'triballand':
      case 'tribal':
      case 'tribal_land':
        return LandOwnershipType.tribalLand;

      // NGO - Non-Governmental Organization (conservation groups)
      case 'ngo':
      case 'ngos':
      case 'ngo_conservation':
      case 'conservation_org':
        return LandOwnershipType.ngoConservation;

      // UNK - Unknown ownership
      case 'unk':
      case 'unknown':
      case null:
      case '':
        return LandOwnershipType.unknown;

      // ======================================================================
      // Federal Agency-Specific Types
      // ======================================================================

      // National Forest (USFS)
      case 'nationalforest':
      case 'national_forest':
      case 'usfs':
      case 'fs':
        return LandOwnershipType.nationalForest;

      // National Park (NPS)
      case 'nationalpark':
      case 'national_park':
      case 'nps':
        return LandOwnershipType.nationalPark;

      // National Wildlife Refuge (USFWS)
      case 'nationalwildliferefuge':
      case 'national_wildlife_refuge':
      case 'nwr':
      case 'usfws':
      case 'fws':
        return LandOwnershipType.nationalWildlifeRefuge;

      // Bureau of Land Management
      case 'bureauoflandmanagement':
      case 'bureau_of_land_management':
      case 'blm':
        return LandOwnershipType.bureauOfLandManagement;

      // National Monument
      case 'nationalmonument':
      case 'national_monument':
        return LandOwnershipType.nationalMonument;

      // National Recreation Area
      case 'nationalrecreationarea':
      case 'national_recreation_area':
      case 'nra':
        return LandOwnershipType.nationalRecreationArea;

      // Wilderness Area
      case 'wilderness':
      case 'wilderness_area':
        return LandOwnershipType.wilderness;

      // Wildlife Management Area
      case 'wma':
      case 'wildlife_management_area':
        return LandOwnershipType.wildlifeManagementArea;

      // Conservation Easement
      case 'ce':
      case 'conservation_easement':
        return LandOwnershipType.conservationEasement;

      // ======================================================================
      // State Agency-Specific Types
      // ======================================================================

      // State Forest
      case 'stateforest':
      case 'state_forest':
        return LandOwnershipType.stateForest;

      // State Park
      case 'statepark':
      case 'state_park':
        return LandOwnershipType.statePark;

      // State Wildlife Area
      case 'statewildlifearea':
      case 'state_wildlife_area':
      case 'swa':
        return LandOwnershipType.stateWildlifeArea;

      // ======================================================================
      // Local Government Types
      // ======================================================================

      // County Land
      case 'countyland':
      case 'county':
      case 'county_land':
        return LandOwnershipType.countyLand;

      // City/Municipal Land
      case 'cityland':
      case 'city':
      case 'city_land':
      case 'municipal':
      case 'other': // BFF returns "other" for some unclassified local parcels
      case 'local': // BFF returns "local" for local government property
        return LandOwnershipType.cityLand;

      // Truly unexpected ownership types
      default:
        debugPrint('WARNING: Unknown ownership type: "$type" - defaulting to unknown');
        return LandOwnershipType.unknown;
    }
  }

  AccessType _parseAccessType(String? type) {
    switch (type?.toLowerCase()) {
      case 'public':
      case 'public_open':
        return AccessType.publicOpen;
      case 'restricted':
      case 'restricted_access':
        return AccessType.restrictedAccess;
      case 'private':
      case 'no_public_access':
        return AccessType.noPublicAccess;
      case 'permit_required':
        return AccessType.permitRequired;
      case 'fee_required':
        return AccessType.feeRequired;
      case 'seasonal_restrictions':
        return AccessType.seasonalRestrictions;
      default:
        return AccessType.publicOpen;
    }
  }

  LandUseType _parseUseType(String type) {
    switch (type.toLowerCase()) {
      case 'camping':
        return LandUseType.camping;
      case 'hunting':
        return LandUseType.hunting;
      case 'fishing':
        return LandUseType.fishing;
      case 'hiking':
        return LandUseType.hiking;
      case 'photography':
        return LandUseType.photography;
      case 'research':
        return LandUseType.research;
      case 'orv_use':
      case 'ohv_atv_use':
        return LandUseType.ohvUse;
      case 'rock_hounding':
        return LandUseType.rockHounding;
      case 'bird_watching':
        return LandUseType.birdWatching;
      default:
        return LandUseType.hiking; // Default fallback
    }
  }

  /// Calculate bounds from coordinate arrays
  LandBounds _calculateBoundsFromCoordinates(List<List<List<double>>>? coordinates) {
    if (coordinates == null || coordinates.isEmpty) {
      return const LandBounds(north: 0, south: 0, east: 0, west: 0);
    }
    
    double? north, south, east, west;
    
    for (final ring in coordinates) {
      for (final coord in ring) {
        if (coord.length >= 2) {
          final lon = coord[0];
          final lat = coord[1];
          
          // Initialize bounds with first valid coordinate
          if (north == null) {
            north = lat;
            south = lat;
            east = lon;
            west = lon;
          } else {
            north = math.max(north, lat);
            south = math.min(south!, lat);
            east = math.max(east!, lon);
            west = math.min(west!, lon);
          }
        }
      }
    }
    
    // If no valid coordinates were found, return zero bounds
    if (north == null) {
      return const LandBounds(north: 0, south: 0, east: 0, west: 0);
    }

    return LandBounds(north: north, south: south!, east: east!, west: west!);
  }

  /// Query trails data for treasure hunting and exploration
  /// Returns trails from locally downloaded state ZIP files
  ///
  /// ZIP-ONLY MODE: All trail data comes from downloaded state ZIPs.
  /// No live BFF queries - works fully offline once states are downloaded.
  ///
  /// STATE-BASED LOADING: Loads ALL trails for a state at once to prevent
  /// long trails that span the entire state from being cut off at viewport edges.
  Future<List<Trail>> getTrailsData({
    required double northBound,
    required double southBound,
    required double eastBound,
    required double westBound,
    int limit = 100,
  }) async {
    // ==========================================================================
    // STATE-BASED LOADING: Load ALL trails for states that intersect viewport
    // This prevents long trails from being cut off at viewport boundaries
    // Now loads from ALL states visible in viewport, not just the center state
    // ==========================================================================
    try {
      // Find all states that intersect with the viewport
      final intersectingStates = _getStatesIntersectingViewport(
        north: northBound,
        south: southBound,
        east: eastBound,
        west: westBound,
      );

      if (intersectingStates.isEmpty) {
        debugPrint('📍 Viewport not in any known US state');
        return [];
      }

      // Combine trails from all intersecting states
      final allTrails = <Trail>[];
      final missingStates = <String>[];
      final cachedStates = <String>[];
      final freshlyLoadedStates = <String>[];

      for (final stateCode in intersectingStates) {
        // Check if we already have this state's trails cached in memory
        if (_stateTrailsCache.containsKey(stateCode)) {
          allTrails.addAll(_stateTrailsCache[stateCode]!);
          cachedStates.add(stateCode);
          continue;
        }

        // Load ALL trails for this state from SQLite
        final trails = await _sqliteCache.queryAllTrailsForState(stateCode);

        if (trails.isNotEmpty) {
          // Cache in memory for subsequent pan/zoom operations
          _stateTrailsCache[stateCode] = trails;
          allTrails.addAll(trails);
          freshlyLoadedStates.add(stateCode);
        } else {
          missingStates.add(stateCode);
        }
      }

      // Only log when actually loading from SQLite (not memory cache hits)
      if (freshlyLoadedStates.isNotEmpty) {
        debugPrint('🥾 Loaded ${allTrails.length} trails from ${freshlyLoadedStates.join(", ")} (now cached in memory)');
      }
      if (missingStates.isNotEmpty) {
        debugPrint('📥 No local trail data for ${missingStates.join(", ")} - download state ZIPs for coverage');
      }

      return allTrails;
    } catch (e) {
      debugPrint('⚠️ Error querying trails from SQLite: $e');
      return [];
    }
  }

  /// Clear the in-memory trails cache (call when state download is updated)
  void clearTrailsCache([String? stateCode]) {
    if (stateCode != null) {
      _stateTrailsCache.remove(stateCode);
      debugPrint('🧹 Cleared trails cache for $stateCode');
    } else {
      _stateTrailsCache.clear();
      debugPrint('🧹 Cleared all trails cache');
    }
  }

  /// Get all states whose bounding boxes intersect with the given viewport
  /// Used for loading data from multiple states when on a border
  List<String> _getStatesIntersectingViewport({
    required double north,
    required double south,
    required double east,
    required double west,
  }) {
    // Comprehensive US state bounding boxes
    const stateBounds = {
      'AL': {'north': 35.01, 'south': 30.22, 'east': -84.89, 'west': -88.47},
      'AK': {'north': 71.50, 'south': 51.21, 'east': -129.99, 'west': -179.15},
      'AZ': {'north': 37.00, 'south': 31.33, 'east': -109.05, 'west': -114.82},
      'AR': {'north': 36.50, 'south': 33.00, 'east': -89.64, 'west': -94.62},
      'CA': {'north': 42.01, 'south': 32.53, 'east': -114.13, 'west': -124.48},
      'CO': {'north': 41.00, 'south': 36.99, 'east': -102.04, 'west': -109.06},
      'CT': {'north': 42.05, 'south': 40.99, 'east': -71.79, 'west': -73.73},
      'DE': {'north': 39.84, 'south': 38.45, 'east': -75.05, 'west': -75.79},
      'FL': {'north': 31.00, 'south': 24.52, 'east': -80.03, 'west': -87.63},
      'GA': {'north': 35.00, 'south': 30.36, 'east': -80.84, 'west': -85.61},
      'ID': {'north': 49.00, 'south': 41.99, 'east': -111.04, 'west': -117.24},
      'IL': {'north': 42.51, 'south': 36.97, 'east': -87.50, 'west': -91.51},
      'IN': {'north': 41.76, 'south': 37.77, 'east': -84.78, 'west': -88.10},
      'IA': {'north': 43.50, 'south': 40.38, 'east': -90.14, 'west': -96.64},
      'KS': {'north': 40.00, 'south': 36.99, 'east': -94.59, 'west': -102.05},
      'KY': {'north': 39.15, 'south': 36.50, 'east': -81.96, 'west': -89.57},
      'LA': {'north': 33.02, 'south': 28.93, 'east': -88.82, 'west': -94.04},
      'ME': {'north': 47.46, 'south': 43.06, 'east': -66.95, 'west': -71.08},
      'MD': {'north': 39.72, 'south': 37.91, 'east': -75.05, 'west': -79.49},
      'MA': {'north': 42.89, 'south': 41.24, 'east': -69.93, 'west': -73.51},
      'MI': {'north': 48.31, 'south': 41.70, 'east': -82.41, 'west': -90.42},
      'MN': {'north': 49.38, 'south': 43.50, 'east': -89.49, 'west': -97.24},
      'MS': {'north': 35.00, 'south': 30.17, 'east': -88.10, 'west': -91.66},
      'MO': {'north': 40.61, 'south': 35.99, 'east': -89.10, 'west': -95.77},
      'MT': {'north': 49.00, 'south': 44.36, 'east': -104.04, 'west': -116.05},
      'NE': {'north': 43.00, 'south': 40.00, 'east': -95.31, 'west': -104.05},
      'NV': {'north': 42.00, 'south': 35.00, 'east': -114.04, 'west': -120.00},
      'NH': {'north': 45.31, 'south': 42.70, 'east': -70.70, 'west': -72.56},
      'NJ': {'north': 41.36, 'south': 38.93, 'east': -73.89, 'west': -75.56},
      'NM': {'north': 37.00, 'south': 31.33, 'east': -103.00, 'west': -109.05},
      'NY': {'north': 45.02, 'south': 40.50, 'east': -71.86, 'west': -79.76},
      'NC': {'north': 36.59, 'south': 33.84, 'east': -75.46, 'west': -84.32},
      'ND': {'north': 49.00, 'south': 45.94, 'east': -96.55, 'west': -104.05},
      'OH': {'north': 42.33, 'south': 38.40, 'east': -80.52, 'west': -84.82},
      'OK': {'north': 37.00, 'south': 33.62, 'east': -94.43, 'west': -103.00},
      'OR': {'north': 46.29, 'south': 41.99, 'east': -116.46, 'west': -124.57},
      'PA': {'north': 42.27, 'south': 39.72, 'east': -74.69, 'west': -80.52},
      'RI': {'north': 42.02, 'south': 41.15, 'east': -71.12, 'west': -71.86},
      'SC': {'north': 35.22, 'south': 32.03, 'east': -78.54, 'west': -83.35},
      'SD': {'north': 45.95, 'south': 42.48, 'east': -96.44, 'west': -104.06},
      'TN': {'north': 36.68, 'south': 34.98, 'east': -81.65, 'west': -90.31},
      'TX': {'north': 36.50, 'south': 25.84, 'east': -93.51, 'west': -106.65},
      'UT': {'north': 42.00, 'south': 36.99, 'east': -109.05, 'west': -114.05},
      'VT': {'north': 45.02, 'south': 42.73, 'east': -71.46, 'west': -73.44},
      'VA': {'north': 39.47, 'south': 36.54, 'east': -75.24, 'west': -83.68},
      'WA': {'north': 49.00, 'south': 45.54, 'east': -116.92, 'west': -124.73},
      'WV': {'north': 40.64, 'south': 37.20, 'east': -77.72, 'west': -82.64},
      'WI': {'north': 47.08, 'south': 42.49, 'east': -86.25, 'west': -92.89},
      'WY': {'north': 45.01, 'south': 40.99, 'east': -104.05, 'west': -111.05},
    };

    final intersecting = <String>[];
    for (final entry in stateBounds.entries) {
      final sb = entry.value;
      // Check if state bounding box intersects with viewport
      // Two rectangles intersect if: NOT (one is completely to the left, right, above, or below the other)
      final stateNorth = sb['north']!;
      final stateSouth = sb['south']!;
      final stateEast = sb['east']!;
      final stateWest = sb['west']!;

      if (!(stateEast < west || stateWest > east || stateSouth > north || stateNorth < south)) {
        intersecting.add(entry.key);
      }
    }
    return intersecting;
  }

  /// Search for trails by name
  /// Returns trails matching the search query from locally downloaded state ZIPs
  ///
  /// ZIP-ONLY MODE: Searches downloaded trail data in SQLite
  Future<List<Trail>> searchTrails(String searchQuery, {int limit = 10}) async {
    // In mock mode (screenshots/testing), return empty
    if (DeviceRegistrationService.instance.isMockMode) {
      debugPrint('🎭 Mock mode: Skipping trail search');
      return [];
    }

    // ==========================================================================
    // ZIP-ONLY MODE: Search trails in SQLite (downloaded state ZIPs)
    // ==========================================================================
    try {
      final trails = await _sqliteCache.searchTrailsByName(
        searchQuery,
        limit: limit,
      );

      if (trails.isNotEmpty) {
        debugPrint('💾 SQLite: Found ${trails.length} trails matching "$searchQuery"');
      }

      return trails;
    } catch (e) {
      debugPrint('⚠️ Error searching trails in SQLite: $e');
      return [];
    }
  }

  // ============================================================================
  // Bulk State Download API (Premium Feature)
  // ============================================================================

  /// Download all land ownership data for a state using pre-generated ZIP files
  ///
  /// This downloads a pre-generated ZIP file containing state data, extracts it,
  /// and parses the JSON. This approach avoids memory exhaustion that occurred
  /// with large GraphQL responses.
  ///
  /// [onProgress] is called periodically with (bytesReceived, totalBytes) to
  /// allow UI to show download progress. totalBytes is -1 if content-length unknown.
  ///
  /// Returns: StateDownloadResult - Success/RateLimited/Error
  Future<StateDownloadResult> downloadStateData({
    required String stateCode,
    void Function(int bytesReceived, int totalBytes)? onProgress,
  }) async {
    // In mock mode, return error
    if (DeviceRegistrationService.instance.isMockMode) {
      debugPrint('🎭 Mock mode: Skipping BFF state download');
      return const StateDownloadError(
        code: 'MOCK_MODE',
        message: 'Bulk downloads not available in mock mode.',
      );
    }

    // Check if online
    final online = await isOnline;
    if (!online) {
      debugPrint('📴 OFFLINE: Cannot download state data');
      return const StateDownloadError(
        code: 'OFFLINE',
        message: 'Cannot download state data while offline.',
      );
    }

    File? tempZipFile;

    try {
      final upperStateCode = stateCode.toUpperCase();
      debugPrint('📥 BFF Service: Downloading state ZIP for $upperStateCode');
      final start = DateTime.now();

      // Get API configuration
      final baseUrl = BFFConfig.getBaseUrl();
      final apiKey = await DeviceRegistrationService.instance.getApiKey();

      // Download ZIP file from REST endpoint
      final zipUrl = '$baseUrl/api/v1/downloads/states/$upperStateCode';
      debugPrint('📥 Downloading from: $zipUrl');

      final client = http.Client();
      try {
        // Use streaming request to enable progress tracking
        final request = http.Request('GET', Uri.parse(zipUrl));
        request.headers['Accept'] = 'application/zip';
        if (apiKey != null) {
          request.headers['X-API-Key'] = apiKey;
        }
        // Use dev data prefix when enabled (debug builds only)
        if (BFFConfig.useDevData) {
          request.headers['X-Environment'] = 'dev';
          debugPrint('🔧 Using dev data prefix for download');
        }

        final streamedResponse = await client.send(request).timeout(
          const Duration(minutes: 10), // Longer timeout for large files
          onTimeout: () {
            debugPrint('📥 BFF Service: Request timeout after 10 minutes');
            throw TimeoutException('State download timed out', const Duration(minutes: 10));
          },
        );

        // Check response status before streaming
        if (streamedResponse.statusCode == 404) {
          return StateDownloadError(
            code: 'NOT_FOUND',
            message: 'State data not available for $upperStateCode',
          );
        }

        if (streamedResponse.statusCode == 401) {
          return const StateDownloadError(
            code: 'UNAUTHORIZED',
            message: 'API key required for state downloads',
          );
        }

        if (streamedResponse.statusCode != 200) {
          debugPrint('📥 BFF Service Error: HTTP ${streamedResponse.statusCode}');
          return StateDownloadError(
            code: 'HTTP_ERROR',
            message: 'Server returned status ${streamedResponse.statusCode}',
          );
        }

        // Get content length for progress calculation
        final totalBytes = streamedResponse.contentLength ?? -1;
        debugPrint('📥 Expected ZIP size: ${totalBytes > 0 ? '${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB' : 'unknown'}');

        // MEMORY-EFFICIENT: Stream download directly to file to avoid OOM on large states
        final tempDir = await getTemporaryDirectory();
        tempZipFile = File('${tempDir.path}/${upperStateCode}_land_data.zip');
        final sink = tempZipFile.openWrite();

        int bytesReceived = 0;
        int lastProgressUpdate = 0;

        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          bytesReceived += chunk.length;

          // Report progress (throttle to avoid too many updates)
          if (onProgress != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastProgressUpdate > 100) { // Update every 100ms max
              onProgress(bytesReceived, totalBytes);
              lastProgressUpdate = now;
            }
          }
        }

        await sink.close();
        onProgress?.call(bytesReceived, totalBytes);

        final elapsed = DateTime.now().difference(start);
        debugPrint('📥 BFF Service: ZIP download completed in ${elapsed.inSeconds}s');
        debugPrint('📥 ZIP size: ${(bytesReceived / 1024 / 1024).toStringAsFixed(2)} MB');
        debugPrint('📥 Saved ZIP to: ${tempZipFile.path}');

        // MEMORY-EFFICIENT: Extract ZIP to disk, not in memory
        debugPrint('📦 Extracting ZIP to disk...');
        final extractDir = Directory('${tempDir.path}/${upperStateCode}_extract');
        if (extractDir.existsSync()) {
          await extractDir.delete(recursive: true);
        }
        await extractDir.create();

        // Read ZIP file in chunks to avoid loading entirely into memory
        final zipFileBytes = await tempZipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(zipFileBytes);

        // Extract data.json and version.json to disk
        File? dataJsonFile;
        File? versionJsonFile;
        for (final file in archive) {
          if (file.name == 'data.json') {
            final extractPath = '${extractDir.path}/data.json';
            dataJsonFile = File(extractPath);
            await dataJsonFile.writeAsBytes(file.content as List<int>);
            debugPrint('📄 Extracted data.json (${file.size} bytes) to disk');
          } else if (file.name == 'version.json') {
            final extractPath = '${extractDir.path}/version.json';
            versionJsonFile = File(extractPath);
            await versionJsonFile.writeAsBytes(file.content as List<int>);
            debugPrint('📄 Extracted version.json to disk');
          }
        }

        // Clear archive from memory immediately
        // (Dart GC will handle this, but we're done with it now)

        if (dataJsonFile == null || !dataJsonFile.existsSync()) {
          return const StateDownloadError(
            code: 'INVALID_ZIP',
            message: 'ZIP file does not contain data.json',
          );
        }

        // MEMORY-EFFICIENT: Parse JSON file in streaming fashion
        // For large files (>100MB), use chunked parsing to avoid OOM
        final fileSize = await dataJsonFile.length();
        debugPrint('📄 Parsing data.json ($fileSize bytes) with streaming parser...');

        final landOwnerships = <ComprehensiveLandOwnership>[];
        final ownerNameCounts = <String, int>{};
        var nullGeometryCount = 0;
        var emptyBoundaryCount = 0;

        // For very large files (>50MB), use memory-efficient streaming
        if (fileSize > 50 * 1024 * 1024) {
          debugPrint('📄 Large file detected, using memory-efficient streaming parser...');

          // Read and parse in chunks to minimize memory usage
          final jsonString = await dataJsonFile.readAsString();
          final jsonData = jsonDecode(jsonString) as List<dynamic>;

          debugPrint('📄 Parsed ${jsonData.length} records, processing in batches...');

          // Process in batches of 50 to minimize peak memory
          const batchSize = 50;
          for (var i = 0; i < jsonData.length; i += batchSize) {
            final end = math.min(i + batchSize, jsonData.length);
            final batch = jsonData.sublist(i, end);

            for (final record in batch) {
              try {
                final ownership = _parseZipRecordToLandOwnership(record as Map<String, dynamic>);
                if (ownership != null) {
                  landOwnerships.add(ownership);
                  final owner = ownership.ownerName;
                  ownerNameCounts[owner] = (ownerNameCounts[owner] ?? 0) + 1;
                  if (ownership.bestBoundaries == null) {
                    nullGeometryCount++;
                  } else if (ownership.bestBoundaries!.isEmpty) {
                    emptyBoundaryCount++;
                  }
                }
              } catch (e) {
                debugPrint('⚠️ Failed to parse record: $e');
              }
            }

            // Log progress for large files
            if (jsonData.length > 100 && (i + batchSize) % 200 == 0) {
              debugPrint('📄 Processed ${math.min(i + batchSize, jsonData.length)}/${jsonData.length} records...');
            }
          }
        } else {
          // For smaller files, use standard parsing
          final jsonString = await dataJsonFile.readAsString();
          final jsonData = jsonDecode(jsonString) as List<dynamic>;
          debugPrint('📄 Parsed ${jsonData.length} records');

          for (final record in jsonData) {
            try {
              final ownership = _parseZipRecordToLandOwnership(record as Map<String, dynamic>);
              if (ownership != null) {
                landOwnerships.add(ownership);
                final owner = ownership.ownerName;
                ownerNameCounts[owner] = (ownerNameCounts[owner] ?? 0) + 1;
                if (ownership.bestBoundaries == null) {
                  nullGeometryCount++;
                } else if (ownership.bestBoundaries!.isEmpty) {
                  emptyBoundaryCount++;
                }
              }
            } catch (e) {
              debugPrint('⚠️ Failed to parse record: $e');
            }
          }
        }

        // Log owner name distribution summary
        debugPrint('📊 ZIP Owner Name Distribution:');
        final sortedOwners = ownerNameCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedOwners.take(10)) {
          debugPrint('   ${entry.key}: ${entry.value}');
        }
        if (sortedOwners.length > 10) {
          debugPrint('   ... and ${sortedOwners.length - 10} more owner types');
        }
        debugPrint('📊 Geometry issues: $nullGeometryCount null, $emptyBoundaryCount empty boundaries');

        debugPrint('📥 Successfully parsed ${landOwnerships.length} properties for $upperStateCode');

        // Read version from version.json (or use fallback)
        var dataVersion = 'PAD-US-4.1'; // Default fallback
        if (versionJsonFile != null && versionJsonFile.existsSync()) {
          try {
            final versionContent = await versionJsonFile.readAsString();
            final versionData = jsonDecode(versionContent) as Map<String, dynamic>;
            dataVersion = versionData['data_version'] as String? ?? dataVersion;
            debugPrint('📄 Read version from ZIP: $dataVersion');
          } catch (e) {
            debugPrint('⚠️ Failed to read version.json, using fallback: $e');
          }
        } else {
          debugPrint('⚠️ No version.json in ZIP, using fallback version: $dataVersion');
        }

        // Clean up temp files
        try {
          if (extractDir.existsSync()) {
            await extractDir.delete(recursive: true);
            debugPrint('🗑️ Cleaned up extracted files');
          }
          if (tempZipFile.existsSync()) {
            await tempZipFile.delete();
            debugPrint('🗑️ Cleaned up temp ZIP file');
          }
        } catch (e) {
          debugPrint('⚠️ Cleanup warning: $e');
        }

        return StateDownloadSuccess(
          stateCode: upperStateCode,
          dataVersion: dataVersion,
          recordCount: landOwnerships.length,
          estimatedSizeBytes: bytesReceived,
          landOwnerships: landOwnerships,
        );

      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      debugPrint('📥 BFF Service Exception: $e');
      debugPrint('Stack trace: $stackTrace');

      // Clean up temp file on error
      if (tempZipFile != null && tempZipFile.existsSync()) {
        try {
          await tempZipFile.delete();
        } catch (_) {}
      }

      return StateDownloadError(
        code: 'EXCEPTION',
        message: 'Download failed: $e',
      );
    }
  }

  /// Download state data and save directly to SQLite - MEMORY EFFICIENT
  ///
  /// Unlike [downloadStateData], this method saves records directly to SQLite
  /// in small batches, avoiding OOM crashes on large states like Alaska.
  ///
  /// This is the recommended method for downloading any state data.
  Future<StateDownloadResult> downloadStateDataToDatabase({
    required String stateCode,
    required OfflineLandRightsService offlineService,
    void Function(int bytesReceived, int totalBytes)? onDownloadProgress,
    void Function(int recordsProcessed, int totalRecords)? onProcessProgress,
  }) async {
    // In mock mode, return error
    if (DeviceRegistrationService.instance.isMockMode) {
      debugPrint('🎭 Mock mode: Skipping BFF state download');
      return const StateDownloadError(
        code: 'MOCK_MODE',
        message: 'Bulk downloads not available in mock mode.',
      );
    }

    // Check if online
    final online = await isOnline;
    if (!online) {
      debugPrint('📴 OFFLINE: Cannot download state data');
      return const StateDownloadError(
        code: 'OFFLINE',
        message: 'Cannot download state data while offline.',
      );
    }

    File? tempZipFile;
    Directory? extractDir;

    try {
      final upperStateCode = stateCode.toUpperCase();
      debugPrint('📥 BFF Service: Downloading state ZIP for $upperStateCode (streaming to DB)');
      final start = DateTime.now();

      // Get API configuration
      final baseUrl = BFFConfig.getBaseUrl();
      final apiKey = await DeviceRegistrationService.instance.getApiKey();

      // Download ZIP file from REST endpoint
      final zipUrl = '$baseUrl/api/v1/downloads/states/$upperStateCode';
      debugPrint('📥 Downloading from: $zipUrl');

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(zipUrl));
        request.headers['Accept'] = 'application/zip';
        if (apiKey != null) {
          request.headers['X-API-Key'] = apiKey;
        }
        // Use dev data prefix when enabled (debug builds only)
        if (BFFConfig.useDevData) {
          request.headers['X-Environment'] = 'dev';
          debugPrint('🔧 Using dev data prefix for download');
        }

        final streamedResponse = await client.send(request).timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            throw TimeoutException('State download timed out', const Duration(minutes: 10));
          },
        );

        // Check response status
        if (streamedResponse.statusCode == 404) {
          return StateDownloadError(
            code: 'NOT_FOUND',
            message: 'State data not available for $upperStateCode',
          );
        }
        if (streamedResponse.statusCode == 401) {
          return const StateDownloadError(
            code: 'UNAUTHORIZED',
            message: 'API key required for state downloads',
          );
        }
        if (streamedResponse.statusCode != 200) {
          return StateDownloadError(
            code: 'HTTP_ERROR',
            message: 'Server returned status ${streamedResponse.statusCode}',
          );
        }

        // Stream download directly to file
        final totalBytes = streamedResponse.contentLength ?? -1;
        debugPrint('📥 Expected ZIP size: ${totalBytes > 0 ? '${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB' : 'unknown'}');

        final tempDir = await getTemporaryDirectory();
        tempZipFile = File('${tempDir.path}/${upperStateCode}_land_data.zip');
        final sink = tempZipFile.openWrite();

        int bytesReceived = 0;
        int lastProgressUpdate = 0;

        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          bytesReceived += chunk.length;

          if (onDownloadProgress != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastProgressUpdate > 100) {
              onDownloadProgress(bytesReceived, totalBytes);
              lastProgressUpdate = now;
            }
          }
        }

        await sink.close();
        onDownloadProgress?.call(bytesReceived, totalBytes);

        final downloadElapsed = DateTime.now().difference(start);
        debugPrint('📥 ZIP download completed in ${downloadElapsed.inSeconds}s');
        debugPrint('📥 ZIP size: ${(bytesReceived / 1024 / 1024).toStringAsFixed(2)} MB');

        // Extract ZIP to disk using STREAMING extraction (memory-efficient)
        // This avoids loading the entire ZIP into memory
        debugPrint('📦 Extracting ZIP to disk (streaming)...');
        extractDir = Directory('${tempDir.path}/${upperStateCode}_extract');
        if (extractDir.existsSync()) {
          await extractDir.delete(recursive: true);
        }
        await extractDir.create();

        // Stream extract ZIP without loading entire file into memory
        // v3: Extract data.json (land), trails.json, historical_places.json (GNIS), and version.json
        File? dataJsonFile;
        File? trailsJsonFile;
        File? historicalPlacesJsonFile;
        File? versionJsonFile;
        try {
          final inputStream = InputFileStream(tempZipFile.path);
          final archive = ZipDecoder().decodeStream(inputStream);

          for (final file in archive) {
            if (!file.isFile) continue;

            if (file.name == 'data.json' || file.name == 'land_data.json') {
              final extractPath = '${extractDir.path}/data.json';
              final outputStream = OutputFileStream(extractPath);
              file.writeContent(outputStream);
              await outputStream.close();
              dataJsonFile = File(extractPath);
              final extractedSize = await dataJsonFile.length();
              debugPrint('📄 Stream-extracted ${file.name} ($extractedSize bytes) to disk');
            } else if (file.name == 'trails.json') {
              final extractPath = '${extractDir.path}/trails.json';
              final outputStream = OutputFileStream(extractPath);
              file.writeContent(outputStream);
              await outputStream.close();
              trailsJsonFile = File(extractPath);
              final extractedSize = await trailsJsonFile.length();
              debugPrint('📄 Stream-extracted trails.json ($extractedSize bytes) to disk');
            } else if (file.name == 'historical_places.json') {
              final extractPath = '${extractDir.path}/historical_places.json';
              final outputStream = OutputFileStream(extractPath);
              file.writeContent(outputStream);
              await outputStream.close();
              historicalPlacesJsonFile = File(extractPath);
              final extractedSize = await historicalPlacesJsonFile.length();
              debugPrint('📄 Stream-extracted historical_places.json ($extractedSize bytes) to disk');
            } else if (file.name == 'version.json') {
              final extractPath = '${extractDir.path}/version.json';
              final outputStream = OutputFileStream(extractPath);
              file.writeContent(outputStream);
              await outputStream.close();
              versionJsonFile = File(extractPath);
              debugPrint('📄 Stream-extracted version.json to disk');
            }
          }

          await inputStream.close();
        } catch (e) {
          debugPrint('⚠️ Streaming ZIP extraction failed, falling back to in-memory: $e');
          // Fallback to in-memory extraction for smaller ZIPs
          final zipFileBytes = await tempZipFile.readAsBytes();
          final archive = ZipDecoder().decodeBytes(zipFileBytes);

          for (final file in archive) {
            if (file.name == 'data.json' || file.name == 'land_data.json') {
              final extractPath = '${extractDir.path}/data.json';
              dataJsonFile = File(extractPath);
              await dataJsonFile.writeAsBytes(file.content as List<int>);
              debugPrint('📄 Extracted ${file.name} (${file.size} bytes) to disk (fallback)');
            } else if (file.name == 'trails.json') {
              final extractPath = '${extractDir.path}/trails.json';
              trailsJsonFile = File(extractPath);
              await trailsJsonFile.writeAsBytes(file.content as List<int>);
              debugPrint('📄 Extracted trails.json (${file.size} bytes) to disk (fallback)');
            } else if (file.name == 'historical_places.json') {
              final extractPath = '${extractDir.path}/historical_places.json';
              historicalPlacesJsonFile = File(extractPath);
              await historicalPlacesJsonFile.writeAsBytes(file.content as List<int>);
              debugPrint('📄 Extracted historical_places.json (${file.size} bytes) to disk (fallback)');
            } else if (file.name == 'version.json') {
              final extractPath = '${extractDir.path}/version.json';
              versionJsonFile = File(extractPath);
              await versionJsonFile.writeAsBytes(file.content as List<int>);
              debugPrint('📄 Extracted version.json to disk (fallback)');
            }
          }
        }

        if (dataJsonFile == null || !dataJsonFile.existsSync()) {
          return const StateDownloadError(
            code: 'INVALID_ZIP',
            message: 'ZIP file does not contain data.json',
          );
        }

        // MEMORY-EFFICIENT: Stream-parse JSON and save directly to SQLite
        final fileSize = await dataJsonFile.length();
        debugPrint('📄 Streaming JSON parsing for data.json ($fileSize bytes)...');

        // Prepare database for streaming insert (clears old data)
        await offlineService.prepareStateStreamingDownload(stateCode: upperStateCode);

        // Read version and record count from version.json (or use fallback)
        var dataVersion = 'PAD-US-4.1'; // Default fallback
        int? actualRecordCount; // For accurate progress reporting
        if (versionJsonFile != null && versionJsonFile.existsSync()) {
          try {
            final versionContent = await versionJsonFile.readAsString();
            final versionData = jsonDecode(versionContent) as Map<String, dynamic>;
            dataVersion = versionData['data_version'] as String? ?? dataVersion;
            actualRecordCount = versionData['record_count'] as int?;
            debugPrint('📄 Read version from ZIP: $dataVersion, record_count: $actualRecordCount');
          } catch (e) {
            debugPrint('⚠️ Failed to read version.json, using fallback: $e');
          }
        } else {
          debugPrint('⚠️ No version.json in ZIP, using fallback version: $dataVersion');
        }

        // Configuration
        const batchSize = 20;
        var recordsProcessed = 0;
        var recordsSaved = 0;

        // State name lookup (49 states - Hawaii excluded, no OSM trail data)
        final stateNames = {
          'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
          'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
          'FL': 'Florida', 'GA': 'Georgia', 'ID': 'Idaho',
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
        final stateName = stateNames[upperStateCode] ?? upperStateCode;

        // Use streaming JSON parser for large files (>50MB) to avoid OOM
        // This reads and parses one JSON object at a time without loading the full file
        const streamingThreshold = 50 * 1024 * 1024; // 50MB

        if (fileSize > streamingThreshold) {
          // STREAMING MODE: Read file in chunks, parse objects one at a time
          debugPrint('📄 Using STREAMING parser for large file ($fileSize bytes > 50MB threshold)');

          final fileStream = dataJsonFile.openRead();
          final stringBuffer = StringBuffer();
          int braceDepth = 0;
          bool inString = false;
          bool escaped = false;
          int objectStart = -1;
          final batchProperties = <ComprehensiveLandOwnership>[];

          // Use actual record count from version.json if available, otherwise estimate
          final int totalRecordsForProgress;
          if (actualRecordCount != null && actualRecordCount > 0) {
            totalRecordsForProgress = actualRecordCount;
            debugPrint('📄 Using actual record count from version.json: $actualRecordCount');
          } else {
            // Fallback: estimate based on average record size (~500KB for Alaska)
            totalRecordsForProgress = (fileSize / 500000).ceil().clamp(100, 100000);
            debugPrint('📄 Estimated ~$totalRecordsForProgress records based on file size');
          }

          await for (final chunk in fileStream.transform(utf8.decoder)) {
            for (int i = 0; i < chunk.length; i++) {
              final char = chunk[i];

              // Track string state (to ignore braces inside strings)
              if (!escaped && char == '"') {
                inString = !inString;
              }
              escaped = !escaped && char == r'\' && inString;

              if (!inString) {
                if (char == '{') {
                  if (braceDepth == 0) {
                    objectStart = stringBuffer.length;
                  }
                  braceDepth++;
                } else if (char == '}') {
                  braceDepth--;
                  if (braceDepth == 0 && objectStart >= 0) {
                    // Complete object found - extract and parse it
                    stringBuffer.write(char);
                    final objectStr = stringBuffer.toString().substring(objectStart);
                    stringBuffer.clear();
                    objectStart = -1;

                    try {
                      final record = jsonDecode(objectStr) as Map<String, dynamic>;
                      final ownership = _parseZipRecordToLandOwnership(record);
                      if (ownership != null) {
                        batchProperties.add(ownership);
                      }
                    } catch (e) {
                      debugPrint('⚠️ Failed to parse record: $e');
                    }

                    recordsProcessed++;

                    // Save batch when full
                    if (batchProperties.length >= batchSize) {
                      await offlineService.insertPropertyBatchStreaming(
                        stateCode: upperStateCode,
                        dataVersion: dataVersion,
                        batch: batchProperties,
                      );
                      recordsSaved += batchProperties.length;
                      batchProperties.clear();

                      // Report progress
                      onProcessProgress?.call(recordsProcessed, totalRecordsForProgress);

                      if (recordsProcessed % 100 == 0) {
                        debugPrint('📄 Streamed $recordsProcessed records, saved $recordsSaved to SQLite...');
                      }
                    }
                    continue;
                  }
                }
              }

              // Only accumulate characters when inside an object
              if (braceDepth > 0 || objectStart >= 0) {
                stringBuffer.write(char);
              }
            }
          }

          // Save any remaining records
          if (batchProperties.isNotEmpty) {
            await offlineService.insertPropertyBatchStreaming(
              stateCode: upperStateCode,
              dataVersion: dataVersion,
              batch: batchProperties,
            );
            recordsSaved += batchProperties.length;
          }

          debugPrint('📄 Streaming parse complete: $recordsProcessed records processed, $recordsSaved saved');

        } else {
          // STANDARD MODE: Load full JSON for smaller files (faster)
          debugPrint('📄 Using standard parser for file ($fileSize bytes < 50MB threshold)');

          final jsonString = await dataJsonFile.readAsString();
          final jsonData = jsonDecode(jsonString) as List<dynamic>;
          final totalRecords = jsonData.length;

          debugPrint('📄 Parsed $totalRecords records, processing in batches...');

          for (var i = 0; i < totalRecords; i += batchSize) {
            final end = math.min(i + batchSize, totalRecords);
            final batchRecords = jsonData.sublist(i, end);

            // Parse and convert this batch
            final batchProperties = <ComprehensiveLandOwnership>[];
            for (final record in batchRecords) {
              try {
                final ownership = _parseZipRecordToLandOwnership(record as Map<String, dynamic>);
                if (ownership != null) {
                  batchProperties.add(ownership);
                }
              } catch (e) {
                debugPrint('⚠️ Failed to parse record: $e');
              }
            }

            // Save this batch directly to SQLite
            if (batchProperties.isNotEmpty) {
              await offlineService.insertPropertyBatchStreaming(
                stateCode: upperStateCode,
                dataVersion: dataVersion,
                batch: batchProperties,
              );
              recordsSaved += batchProperties.length;
            }

            recordsProcessed = end;

            // Report progress
            onProcessProgress?.call(recordsProcessed, totalRecords);

            // Log progress for large files
            if (totalRecords > 100 && recordsProcessed % 100 == 0) {
              debugPrint('📄 Processed $recordsProcessed/$totalRecords records, saved $recordsSaved to SQLite...');
            }
          }
        }

        // ==========================================================================
        // v3: Process trails.json if present (ZIP-only architecture)
        // ==========================================================================
        var trailsSaved = 0;
        if (trailsJsonFile != null && trailsJsonFile.existsSync()) {
          debugPrint('🥾 Processing trails.json...');
          try {
            final trailsJson = await trailsJsonFile.readAsString();
            final trailsData = jsonDecode(trailsJson) as List<dynamic>;
            debugPrint('🥾 Found ${trailsData.length} trails to import');

            // Import trails in batches
            final trailBatch = <Map<String, dynamic>>[];
            for (final trail in trailsData) {
              trailBatch.add(trail as Map<String, dynamic>);

              if (trailBatch.length >= 50) {
                await offlineService.insertTrailBatch(
                  stateCode: upperStateCode,
                  trails: trailBatch,
                );
                trailsSaved += trailBatch.length;
                trailBatch.clear();
              }
            }

            // Save remaining trails
            if (trailBatch.isNotEmpty) {
              await offlineService.insertTrailBatch(
                stateCode: upperStateCode,
                trails: trailBatch,
              );
              trailsSaved += trailBatch.length;
            }

            debugPrint('🥾 Imported $trailsSaved trails to SQLite');
          } catch (e) {
            debugPrint('⚠️ Failed to process trails.json: $e');
            // Continue without trails - land data is more important
          }
        } else {
          debugPrint('ℹ️ No trails.json in ZIP (older format or no trails for state)');
        }

        // ==========================================================================
        // v4: Process historical_places.json if present (GNIS data)
        // ==========================================================================
        var historicalPlacesSaved = 0;
        if (historicalPlacesJsonFile != null && historicalPlacesJsonFile.existsSync()) {
          debugPrint('🏚️ Processing historical_places.json...');
          try {
            // Clear existing historical places for this state first
            await offlineService.clearHistoricalPlacesForState(upperStateCode);

            final historicalJson = await historicalPlacesJsonFile.readAsString();
            final historicalData = jsonDecode(historicalJson) as Map<String, dynamic>;
            final placesData = historicalData['places'] as List<dynamic>? ?? [];
            final dataVersion = historicalData['version'] as String? ?? 'unknown';
            final stateName = historicalData['state_name'] as String? ?? upperStateCode;

            debugPrint('🏚️ Found ${placesData.length} historical places to import');

            // Import historical places in batches
            final placeBatch = <HistoricalPlace>[];
            for (final placeJson in placesData) {
              try {
                final place = HistoricalPlace.fromJson(placeJson as Map<String, dynamic>);
                placeBatch.add(place);

                if (placeBatch.length >= 50) {
                  await offlineService.insertHistoricalPlacesBatch(
                    stateCode: upperStateCode,
                    batch: List.from(placeBatch),
                  );
                  historicalPlacesSaved += placeBatch.length;
                  placeBatch.clear();
                }
              } catch (e) {
                debugPrint('⚠️ Failed to parse historical place: $e');
              }
            }

            // Save remaining places
            if (placeBatch.isNotEmpty) {
              await offlineService.insertHistoricalPlacesBatch(
                stateCode: upperStateCode,
                batch: placeBatch,
              );
              historicalPlacesSaved += placeBatch.length;
            }

            // Finalize historical places download
            await offlineService.finalizeHistoricalPlacesDownload(
              stateCode: upperStateCode,
              stateName: stateName,
              dataVersion: dataVersion,
              placeCount: historicalPlacesSaved,
            );

            debugPrint('🏚️ Imported $historicalPlacesSaved historical places to SQLite');
          } catch (e) {
            debugPrint('⚠️ Failed to process historical_places.json: $e');
            // Continue without historical places - land data is more important
          }
        } else {
          debugPrint('ℹ️ No historical_places.json in ZIP (older format or not merged yet)');
        }

        // Finalize the download record
        await offlineService.finalizeStateStreamingDownload(
          stateCode: upperStateCode,
          stateName: stateName,
          dataVersion: dataVersion,
          totalPropertyCount: recordsSaved,
          totalTrailCount: trailsSaved,
          estimatedSizeBytes: bytesReceived,
        );

        final totalElapsed = DateTime.now().difference(start);
        debugPrint('✅ Streaming download complete: $recordsSaved properties + $trailsSaved trails + $historicalPlacesSaved historical places saved to SQLite in ${totalElapsed.inSeconds}s');

        // Clean up temp files
        try {
          if (extractDir.existsSync()) {
            await extractDir.delete(recursive: true);
          }
          if (tempZipFile.existsSync()) {
            await tempZipFile.delete();
          }
          debugPrint('🗑️ Cleaned up temp files');
        } catch (e) {
          debugPrint('⚠️ Cleanup warning: $e');
        }

        // Return success with empty landOwnerships list (data is in SQLite)
        return StateDownloadSuccess(
          stateCode: upperStateCode,
          dataVersion: dataVersion,
          recordCount: recordsSaved,
          estimatedSizeBytes: bytesReceived,
          landOwnerships: const [], // Data is in SQLite, not returned
        );

      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      debugPrint('📥 BFF Service Exception: $e');
      debugPrint('Stack trace: $stackTrace');

      // Clean up temp files on error
      if (tempZipFile != null && tempZipFile.existsSync()) {
        try {
          await tempZipFile.delete();
        } catch (_) {}
      }
      if (extractDir != null && extractDir.existsSync()) {
        try {
          await extractDir.delete(recursive: true);
        } catch (_) {}
      }

      return StateDownloadError(
        code: 'EXCEPTION',
        message: 'Download failed: $e',
      );
    }
  }

  // ============================================================================
  // PER-TYPE DOWNLOAD METHODS (New Architecture)
  // ============================================================================

  /// Download a specific data type for a state (land, trails, or historical)
  ///
  /// This enables selective updates where only changed data types are downloaded.
  /// Uses the new R2 structure: /states/{STATE}/{dataType}.zip
  Future<StateDownloadResult> downloadStateDataTypeToDatabase({
    required String stateCode,
    required DataTypeLocal dataType,
    required OfflineLandRightsService offlineService,
    void Function(int bytesReceived, int totalBytes)? onDownloadProgress,
    void Function(int recordsProcessed, int totalRecords)? onProcessProgress,
  }) async {
    // In mock mode, return error
    if (DeviceRegistrationService.instance.isMockMode) {
      debugPrint('🎭 Mock mode: Skipping BFF per-type download');
      return const StateDownloadError(
        code: 'MOCK_MODE',
        message: 'Per-type downloads not available in mock mode.',
      );
    }

    // Check if online
    final online = await isOnline;
    if (!online) {
      debugPrint('📴 OFFLINE: Cannot download state data');
      return const StateDownloadError(
        code: 'OFFLINE',
        message: 'Cannot download state data while offline.',
      );
    }

    File? tempZipFile;
    Directory? extractDir;

    try {
      final upperStateCode = stateCode.toUpperCase();
      final dataTypeName = dataType.name;
      debugPrint('📥 BFF Service: Downloading $dataTypeName for $upperStateCode (per-type)');
      final start = DateTime.now();

      // Get API configuration
      final apiKey = await DeviceRegistrationService.instance.getApiKey();
      final deviceId = await DeviceRegistrationService.instance.getDeviceId();

      // Determine download URL based on NHP availability
      String zipUrl;
      final nhpService = NhpDownloadService.instance;

      if (nhpService.isNhpDownloadsEnabled && apiKey != null && deviceId != null) {
        // Use NHP-protected download server
        debugPrint('🔐 NHP downloads enabled - knocking server first');

        final knockResult = await nhpService.knockForDownloads(
          deviceId: deviceId,
          apiKey: apiKey,
        );

        if (!knockResult.success) {
          debugPrint('❌ NHP knock failed: ${knockResult.errorMessage}');
          // NO FALLBACK - Return error so we know NHP isn't working
          // TODO(nhp): Re-enable BFF fallback after TestFlight validation
          return StateDownloadError(
            code: 'NHP_KNOCK_FAILED',
            message: knockResult.errorMessage ?? 'Premium subscription required',
          );
        }
        // Use NHP server URL (includes .zip extension)
        zipUrl = nhpService.getStateDownloadUrl(upperStateCode, dataTypeName);
        debugPrint('✅ NHP knock successful - downloading from: $zipUrl');
      } else {
        // Use BFF endpoint (legacy) - only when NHP disabled or missing credentials
        final baseUrl = BFFConfig.getBaseUrl();
        zipUrl = '$baseUrl/api/v1/downloads/states/$upperStateCode/$dataTypeName';
        debugPrint('📥 Using BFF endpoint: $zipUrl');
      }

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(zipUrl));
        request.headers['Accept'] = 'application/zip';
        if (apiKey != null) {
          request.headers['X-API-Key'] = apiKey;
        }
        // Use dev data prefix when enabled (debug builds only)
        if (BFFConfig.useDevData) {
          request.headers['X-Environment'] = 'dev';
          debugPrint('🔧 Using dev data prefix for download');
        }

        final streamedResponse = await client.send(request).timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            throw TimeoutException('Download timed out', const Duration(minutes: 10));
          },
        );

        // Check response status
        if (streamedResponse.statusCode == 404) {
          return StateDownloadError(
            code: 'NOT_FOUND',
            message: '$dataTypeName data not available for $upperStateCode',
          );
        }
        if (streamedResponse.statusCode == 401) {
          return const StateDownloadError(
            code: 'UNAUTHORIZED',
            message: 'API key required for downloads',
          );
        }
        if (streamedResponse.statusCode != 200) {
          return StateDownloadError(
            code: 'HTTP_ERROR',
            message: 'Server returned status ${streamedResponse.statusCode}',
          );
        }

        // Stream download to file
        final totalBytes = streamedResponse.contentLength ?? -1;
        debugPrint('📥 Expected ZIP size: ${totalBytes > 0 ? '${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB' : 'unknown'}');

        final tempDir = await getTemporaryDirectory();
        tempZipFile = File('${tempDir.path}/${upperStateCode}_$dataTypeName.zip');
        final sink = tempZipFile.openWrite();

        int bytesReceived = 0;
        int lastProgressUpdate = 0;

        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          bytesReceived += chunk.length;

          if (onDownloadProgress != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - lastProgressUpdate > 100) {
              onDownloadProgress(bytesReceived, totalBytes);
              lastProgressUpdate = now;
            }
          }
        }

        await sink.close();
        onDownloadProgress?.call(bytesReceived, totalBytes);

        final downloadElapsed = DateTime.now().difference(start);
        debugPrint('📥 ZIP download completed in ${downloadElapsed.inSeconds}s');

        // Extract ZIP
        debugPrint('📦 Extracting $dataTypeName ZIP...');
        extractDir = Directory('${tempDir.path}/${upperStateCode}_${dataTypeName}_extract');
        if (extractDir.existsSync()) {
          await extractDir.delete(recursive: true);
        }
        await extractDir.create();

        // Extract data.json and version.json
        File? dataJsonFile;
        File? versionJsonFile;
        String? dataVersion;

        try {
          final inputStream = InputFileStream(tempZipFile.path);
          final archive = ZipDecoder().decodeStream(inputStream);

          for (final file in archive) {
            if (!file.isFile) continue;

            if (file.name == 'data.json') {
              final extractPath = '${extractDir.path}/data.json';
              final outputStream = OutputFileStream(extractPath);
              file.writeContent(outputStream);
              await outputStream.close();
              dataJsonFile = File(extractPath);
              debugPrint('📄 Extracted data.json');
            } else if (file.name == 'version.json') {
              final extractPath = '${extractDir.path}/version.json';
              final outputStream = OutputFileStream(extractPath);
              file.writeContent(outputStream);
              await outputStream.close();
              versionJsonFile = File(extractPath);
              debugPrint('📄 Extracted version.json');
            }
          }

          await inputStream.close();
        } catch (e) {
          debugPrint('⚠️ Streaming extraction failed, using fallback: $e');
          final zipBytes = await tempZipFile.readAsBytes();
          final archive = ZipDecoder().decodeBytes(zipBytes);

          for (final file in archive) {
            if (file.name == 'data.json') {
              dataJsonFile = File('${extractDir.path}/data.json');
              await dataJsonFile.writeAsBytes(file.content as List<int>);
            } else if (file.name == 'version.json') {
              versionJsonFile = File('${extractDir.path}/version.json');
              await versionJsonFile.writeAsBytes(file.content as List<int>);
            }
          }
        }

        // Read version from version.json
        if (versionJsonFile != null && versionJsonFile.existsSync()) {
          try {
            final versionContent = await versionJsonFile.readAsString();
            final versionData = jsonDecode(versionContent) as Map<String, dynamic>;
            dataVersion = versionData['version'] as String?;
            debugPrint('📄 Version from ZIP: $dataVersion');
          } catch (e) {
            debugPrint('⚠️ Failed to read version.json: $e');
          }
        }

        if (dataJsonFile == null || !dataJsonFile.existsSync()) {
          return const StateDownloadError(
            code: 'INVALID_ZIP',
            message: 'ZIP does not contain data.json',
          );
        }

        // State name lookup (49 states - Hawaii excluded, no OSM trail data)
        final stateNames = {
          'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
          'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
          'FL': 'Florida', 'GA': 'Georgia', 'ID': 'Idaho',
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
        final stateName = stateNames[upperStateCode] ?? upperStateCode;

        // Process based on data type
        int recordsSaved = 0;

        switch (dataType) {
          case DataTypeLocal.land:
            recordsSaved = await _processLandDataJson(
              stateCode: upperStateCode,
              stateName: stateName,
              dataJsonFile: dataJsonFile,
              dataVersion: dataVersion ?? 'unknown',
              offlineService: offlineService,
              onProcessProgress: onProcessProgress,
            );
            break;

          case DataTypeLocal.trails:
            recordsSaved = await _processTrailsDataJson(
              stateCode: upperStateCode,
              dataJsonFile: dataJsonFile,
              dataVersion: dataVersion ?? 'unknown',
              offlineService: offlineService,
              onProcessProgress: onProcessProgress,
            );
            break;

          case DataTypeLocal.historical:
            recordsSaved = await _processHistoricalDataJson(
              stateCode: upperStateCode,
              stateName: stateName,
              dataJsonFile: dataJsonFile,
              dataVersion: dataVersion ?? 'unknown',
              offlineService: offlineService,
              onProcessProgress: onProcessProgress,
            );
            break;

          case DataTypeLocal.cell:
            recordsSaved = await _processCellDataJson(
              stateCode: upperStateCode,
              dataJsonFile: dataJsonFile,
              dataVersion: dataVersion ?? 'unknown',
              offlineService: offlineService,
              onProcessProgress: onProcessProgress,
            );
            break;
        }

        // Update the per-type version in the database
        if (dataVersion != null) {
          await offlineService.updateStateDataTypeVersion(
            stateCode: upperStateCode,
            dataType: dataType,
            version: dataVersion,
          );
        }

        // Update record counts from actual data (fixes property_count=0 issue)
        await offlineService.updateStateRecordCounts(upperStateCode);

        final totalElapsed = DateTime.now().difference(start);
        debugPrint('✅ Per-type download complete: $recordsSaved $dataTypeName records in ${totalElapsed.inSeconds}s');

        // Clean up
        try {
          if (extractDir.existsSync()) await extractDir.delete(recursive: true);
          if (tempZipFile.existsSync()) await tempZipFile.delete();
        } catch (_) {}

        return StateDownloadSuccess(
          stateCode: upperStateCode,
          dataVersion: dataVersion ?? 'unknown',
          recordCount: recordsSaved,
          estimatedSizeBytes: bytesReceived,
          landOwnerships: const [],
        );

      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      debugPrint('📥 Per-type download error: $e');
      debugPrint('Stack: $stackTrace');

      // Clean up on error
      if (tempZipFile != null && tempZipFile.existsSync()) {
        try { await tempZipFile.delete(); } catch (_) {}
      }
      if (extractDir != null && extractDir.existsSync()) {
        try { await extractDir.delete(recursive: true); } catch (_) {}
      }

      return StateDownloadError(
        code: 'EXCEPTION',
        message: 'Download failed: $e',
      );
    }
  }

  // ============================================================================
  // LOCAL FIXTURE LOADING (For Screenshots/Testing)
  // ============================================================================

  /// Load state data from a local ZIP file (for screenshots/testing)
  ///
  /// This allows loading pre-downloaded ZIP files from test fixtures
  /// without requiring network access or NHP authentication.
  ///
  /// [zipFilePath] should point to a local ZIP file containing:
  /// - land.zip: data.json + version.json
  /// - trails.zip: trails.json + version.json
  /// - historical.zip: historical_places.json + version.json
  ///
  /// Example usage in screenshot test:
  /// ```dart
  /// await BFFMappingService.instance.loadStateDataTypeFromLocalZip(
  ///   stateCode: 'UT',
  ///   dataType: DataTypeLocal.land,
  ///   zipFilePath: 'integration_test/fixtures/states/UT/land.zip',
  ///   offlineService: offlineService,
  /// );
  /// ```
  Future<StateDownloadResult> loadStateDataTypeFromLocalZip({
    required String stateCode,
    required DataTypeLocal dataType,
    required String zipFilePath,
    required OfflineLandRightsService offlineService,
    void Function(int recordsProcessed, int totalRecords)? onProcessProgress,
  }) async {
    Directory? extractDir;

    try {
      final upperStateCode = stateCode.toUpperCase();
      final dataTypeName = dataType.name;
      debugPrint('📦 Loading $dataTypeName for $upperStateCode from local ZIP: $zipFilePath');
      final start = DateTime.now();

      // Verify ZIP file exists
      final zipFile = File(zipFilePath);
      if (!zipFile.existsSync()) {
        debugPrint('❌ ZIP file not found: $zipFilePath');
        return StateDownloadError(
          code: 'FILE_NOT_FOUND',
          message: 'ZIP file not found: $zipFilePath',
        );
      }

      // Create temp directory for extraction
      final tempDir = await getTemporaryDirectory();
      extractDir = Directory('${tempDir.path}/${upperStateCode}_${dataTypeName}_fixture');
      if (extractDir.existsSync()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();

      // Extract ZIP
      debugPrint('📦 Extracting ZIP...');
      File? dataJsonFile;
      File? versionJsonFile;

      try {
        final inputStream = InputFileStream(zipFilePath);
        final archive = ZipDecoder().decodeStream(inputStream);

        for (final file in archive) {
          if (!file.isFile) continue;

          // Determine which JSON file this is based on data type
          // All data types use 'data.json' in the ZIP files
          String? targetName;
          if (file.name == 'data.json' ||
              file.name == 'land_data.json' ||
              file.name == 'trails.json' ||
              file.name == 'historical_places.json') {
            targetName = 'data.json';
          } else if (file.name == 'version.json') {
            targetName = 'version.json';
          }

          if (targetName != null) {
            final extractPath = '${extractDir.path}/$targetName';
            final outputStream = OutputFileStream(extractPath);
            file.writeContent(outputStream);
            await outputStream.close();

            if (targetName == 'version.json') {
              versionJsonFile = File(extractPath);
            } else {
              dataJsonFile = File(extractPath);
            }
            debugPrint('📄 Extracted $targetName');
          }
        }

        await inputStream.close();
      } catch (e) {
        debugPrint('⚠️ Streaming ZIP extraction failed, trying in-memory: $e');
        final zipFileBytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(zipFileBytes);

        for (final file in archive) {
          // All data types use 'data.json' in the ZIP files
          String? targetName;
          if (file.name == 'data.json' ||
              file.name == 'land_data.json' ||
              file.name == 'trails.json' ||
              file.name == 'historical_places.json') {
            targetName = 'data.json';
          } else if (file.name == 'version.json') {
            targetName = 'version.json';
          }

          if (targetName != null) {
            final extractPath = '${extractDir.path}/$targetName';
            final extractFile = File(extractPath);
            await extractFile.writeAsBytes(file.content as List<int>);

            if (targetName == 'version.json') {
              versionJsonFile = extractFile;
            } else {
              dataJsonFile = extractFile;
            }
            debugPrint('📄 Extracted $targetName (fallback)');
          }
        }
      }

      if (dataJsonFile == null || !dataJsonFile.existsSync()) {
        return const StateDownloadError(
          code: 'INVALID_ZIP',
          message: 'ZIP file does not contain expected data JSON',
        );
      }

      // Read version from version.json
      String? dataVersion;
      if (versionJsonFile != null && versionJsonFile.existsSync()) {
        try {
          final versionContent = await versionJsonFile.readAsString();
          final versionData = jsonDecode(versionContent) as Map<String, dynamic>;
          dataVersion = versionData['data_version'] as String? ??
              versionData['version'] as String?;
          debugPrint('📄 Version from ZIP: $dataVersion');
        } catch (e) {
          debugPrint('⚠️ Failed to read version.json: $e');
        }
      }

      // Use default version if not found
      dataVersion ??= switch (dataType) {
        DataTypeLocal.land => 'PAD-US-4.1',
        DataTypeLocal.trails => 'OSM-2024.12',
        DataTypeLocal.historical => 'GNIS-2024.2',
        DataTypeLocal.cell => 'OpenCelliD-2026.01',
      };

      // State name lookup
      final stateNames = {
        'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
        'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
        'FL': 'Florida', 'GA': 'Georgia', 'ID': 'Idaho',
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
      final stateName = stateNames[upperStateCode] ?? upperStateCode;

      // Process data using existing methods
      int recordsSaved = 0;

      switch (dataType) {
        case DataTypeLocal.land:
          recordsSaved = await _processLandDataJson(
            stateCode: upperStateCode,
            stateName: stateName,
            dataJsonFile: dataJsonFile,
            dataVersion: dataVersion,
            offlineService: offlineService,
            onProcessProgress: onProcessProgress,
          );
          break;

        case DataTypeLocal.trails:
          recordsSaved = await _processTrailsDataJson(
            stateCode: upperStateCode,
            dataJsonFile: dataJsonFile,
            dataVersion: dataVersion,
            offlineService: offlineService,
            onProcessProgress: onProcessProgress,
          );
          break;

        case DataTypeLocal.historical:
          recordsSaved = await _processHistoricalDataJson(
            stateCode: upperStateCode,
            stateName: stateName,
            dataJsonFile: dataJsonFile,
            dataVersion: dataVersion,
            offlineService: offlineService,
            onProcessProgress: onProcessProgress,
          );
          break;

        case DataTypeLocal.cell:
          recordsSaved = await _processCellDataJson(
            stateCode: upperStateCode,
            dataJsonFile: dataJsonFile,
            dataVersion: dataVersion,
            offlineService: offlineService,
            onProcessProgress: onProcessProgress,
          );
          break;
      }

      // Update version in database
      await offlineService.updateStateDataTypeVersion(
        stateCode: upperStateCode,
        dataType: dataType,
        version: dataVersion,
      );

      // Update record counts
      await offlineService.updateStateRecordCounts(upperStateCode);

      final totalElapsed = DateTime.now().difference(start);
      debugPrint('✅ Loaded $recordsSaved $dataTypeName records from fixture in ${totalElapsed.inSeconds}s');

      // Clean up
      try {
        if (extractDir.existsSync()) await extractDir.delete(recursive: true);
      } catch (_) {}

      return StateDownloadSuccess(
        stateCode: upperStateCode,
        dataVersion: dataVersion,
        recordCount: recordsSaved,
        estimatedSizeBytes: 0,
        landOwnerships: const [],
      );
    } catch (e, stackTrace) {
      debugPrint('📦 Fixture load error: $e');
      debugPrint('Stack: $stackTrace');

      // Clean up on error
      if (extractDir != null && extractDir.existsSync()) {
        try {
          await extractDir.delete(recursive: true);
        } catch (_) {}
      }

      return StateDownloadError(
        code: 'EXCEPTION',
        message: 'Failed to load fixture: $e',
      );
    }
  }

  /// Process land data JSON file
  Future<int> _processLandDataJson({
    required String stateCode,
    required String stateName,
    required File dataJsonFile,
    required String dataVersion,
    required OfflineLandRightsService offlineService,
    void Function(int, int)? onProcessProgress,
  }) async {
    // Clear existing land data for this state
    await offlineService.prepareStateStreamingDownload(stateCode: stateCode);

    final jsonContent = await dataJsonFile.readAsString();
    final data = jsonDecode(jsonContent);

    List<dynamic> features;
    if (data is Map && data['features'] != null) {
      features = data['features'] as List<dynamic>;
    } else if (data is List) {
      features = data;
    } else {
      debugPrint('⚠️ Unexpected land data format');
      return 0;
    }

    const batchSize = 20;
    var recordsSaved = 0;
    final batch = <ComprehensiveLandOwnership>[];

    for (var i = 0; i < features.length; i++) {
      final record = features[i] as Map<String, dynamic>;
      final ownership = _parseZipRecordToLandOwnership(record);
      if (ownership != null) {
        batch.add(ownership);
      }

      if (batch.length >= batchSize) {
        await offlineService.insertPropertyBatchStreaming(
          stateCode: stateCode,
          dataVersion: dataVersion,
          batch: batch,
        );
        recordsSaved += batch.length;
        batch.clear();
        onProcessProgress?.call(i + 1, features.length);
      }
    }

    // Save remaining
    if (batch.isNotEmpty) {
      await offlineService.insertPropertyBatchStreaming(
        stateCode: stateCode,
        dataVersion: dataVersion,
        batch: batch,
      );
      recordsSaved += batch.length;
    }

    // Finalize - note we don't call the full finalizeStateStreamingDownload
    // since we're only updating one data type
    debugPrint('📊 Processed $recordsSaved land records');
    return recordsSaved;
  }

  /// Process trails data JSON file
  Future<int> _processTrailsDataJson({
    required String stateCode,
    required File dataJsonFile,
    required String dataVersion,
    required OfflineLandRightsService offlineService,
    void Function(int, int)? onProcessProgress,
  }) async {
    // Clear existing trails for this state
    await offlineService.clearTrailsForState(stateCode);

    final jsonContent = await dataJsonFile.readAsString();
    final data = jsonDecode(jsonContent);

    List<dynamic> features;
    if (data is Map && data['features'] != null) {
      features = data['features'] as List<dynamic>;
    } else if (data is List) {
      features = data;
    } else {
      debugPrint('⚠️ Unexpected trails data format');
      return 0;
    }

    const batchSize = 50;
    var recordsSaved = 0;
    final batch = <Map<String, dynamic>>[];

    for (var i = 0; i < features.length; i++) {
      final feature = features[i] as Map<String, dynamic>;
      batch.add(feature);

      if (batch.length >= batchSize) {
        await offlineService.insertTrailBatch(
          stateCode: stateCode,
          trails: List.from(batch),
        );
        recordsSaved += batch.length;
        batch.clear();
        onProcessProgress?.call(i + 1, features.length);
      }
    }

    // Save remaining
    if (batch.isNotEmpty) {
      await offlineService.insertTrailBatch(
        stateCode: stateCode,
        trails: batch,
      );
      recordsSaved += batch.length;
    }

    debugPrint('🥾 Processed $recordsSaved trail records');
    return recordsSaved;
  }

  /// Process historical places data JSON file
  Future<int> _processHistoricalDataJson({
    required String stateCode,
    required String stateName,
    required File dataJsonFile,
    required String dataVersion,
    required OfflineLandRightsService offlineService,
    void Function(int, int)? onProcessProgress,
  }) async {
    // Clear existing historical places for this state
    await offlineService.clearHistoricalPlacesForState(stateCode);

    final jsonContent = await dataJsonFile.readAsString();
    final data = jsonDecode(jsonContent) as Map<String, dynamic>;

    // Support both 'features' (GeoJSON) and 'places' formats
    List<dynamic> places;
    if (data['features'] != null) {
      places = data['features'] as List<dynamic>;
    } else if (data['places'] != null) {
      places = data['places'] as List<dynamic>;
    } else {
      debugPrint('⚠️ Unexpected historical data format');
      return 0;
    }

    const batchSize = 50;
    var recordsSaved = 0;
    final batch = <HistoricalPlace>[];

    for (var i = 0; i < places.length; i++) {
      try {
        final placeJson = places[i] as Map<String, dynamic>;
        final place = HistoricalPlace.fromJson(placeJson);
        batch.add(place);

        if (batch.length >= batchSize) {
          await offlineService.insertHistoricalPlacesBatch(
            stateCode: stateCode,
            batch: List.from(batch),
          );
          recordsSaved += batch.length;
          batch.clear();
          onProcessProgress?.call(i + 1, places.length);
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse historical place: $e');
      }
    }

    // Save remaining
    if (batch.isNotEmpty) {
      await offlineService.insertHistoricalPlacesBatch(
        stateCode: stateCode,
        batch: batch,
      );
      recordsSaved += batch.length;
    }

    // Finalize historical places download
    await offlineService.finalizeHistoricalPlacesDownload(
      stateCode: stateCode,
      stateName: stateName,
      dataVersion: dataVersion,
      placeCount: recordsSaved,
    );

    debugPrint('🏚️ Processed $recordsSaved historical places');
    return recordsSaved;
  }

  /// Process cell tower data JSON file (OpenCelliD data)
  Future<int> _processCellDataJson({
    required String stateCode,
    required File dataJsonFile,
    required String dataVersion,
    required OfflineLandRightsService offlineService,
    void Function(int, int)? onProcessProgress,
  }) async {
    // Clear existing cell towers for this state
    await offlineService.deleteCellTowersForState(stateCode);

    final jsonContent = await dataJsonFile.readAsString();
    final data = jsonDecode(jsonContent) as Map<String, dynamic>;

    // Support 'towers' array format from our processing script
    final towers = data['towers'] as List<dynamic>?;
    if (towers == null || towers.isEmpty) {
      debugPrint('⚠️ No cell towers found in data');
      return 0;
    }

    final parsedTowers = <CellTower>[];

    for (var i = 0; i < towers.length; i++) {
      try {
        final towerJson = towers[i] as Map<String, dynamic>;
        final tower = CellTower.fromJson(towerJson, stateCode);
        parsedTowers.add(tower);

        // Report progress every 1000 records
        if (i % 1000 == 0) {
          onProcessProgress?.call(i, towers.length);
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse cell tower: $e');
      }
    }

    // Batch insert all towers
    final recordsSaved = await offlineService.insertCellTowers(stateCode, parsedTowers);

    // Update cell version in state downloads
    await offlineService.updateCellVersion(stateCode, dataVersion, recordsSaved);

    debugPrint('📶 Processed $recordsSaved cell towers');
    return recordsSaved;
  }

  /// Parse a record from the ZIP file's data.json to ComprehensiveLandOwnership
  ///
  /// The ZIP format uses snake_case and includes 5 levels of geometry detail:
  /// - geometry_full_geojson: Original survey-accurate boundaries (zoom 15+, 0m tolerance)
  /// - geometry_high_geojson: Property-level detail (zoom 12-14, ~5.5m tolerance)
  /// - geometry_medium_geojson: Neighborhood detail (zoom 10-11, ~22m tolerance)
  /// - geometry_low_geojson: County-level detail (zoom 8-9, ~111m tolerance)
  /// - geometry_overview_geojson: State/regional view (zoom 5-7, ~555m tolerance)
  ///
  /// Legacy support: geometry_geojson maps to medium boundaries
  ComprehensiveLandOwnership? _parseZipRecordToLandOwnership(Map<String, dynamic> record) {
    try {
      // Extract owner name early for debug logging
      final ownerName = record['owner_name']?.toString();

      // Parse FULL quality geometry (survey-accurate, zoom 15+)
      List<List<List<double>>>? fullBoundaries;
      final fullGeometryJson = record['geometry_full_geojson'] as String?;
      if (fullGeometryJson != null && fullGeometryJson.isNotEmpty) {
        try {
          final geom = jsonDecode(fullGeometryJson) as Map<String, dynamic>;
          final coords = geom['coordinates'];
          if (coords != null) {
            fullBoundaries = _parseGeoJsonCoordinates(coords, ownerName: ownerName);
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse full geometry: $e');
        }
      }

      // Parse HIGH quality geometry (zoom 12-14, ~5.5m tolerance)
      List<List<List<double>>>? highBoundaries;
      final highGeometryJson = record['geometry_high_geojson'] as String?;
      if (highGeometryJson != null && highGeometryJson.isNotEmpty) {
        try {
          final geom = jsonDecode(highGeometryJson) as Map<String, dynamic>;
          final coords = geom['coordinates'];
          if (coords != null) {
            highBoundaries = _parseGeoJsonCoordinates(coords, ownerName: ownerName);
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse high geometry: $e');
        }
      }

      // Parse MEDIUM quality geometry (zoom 10-11, ~22m tolerance)
      // Falls back to legacy 'geometry_geojson' if new field not present
      List<List<List<double>>>? mediumBoundaries;
      final mediumGeometryJson = record['geometry_medium_geojson'] as String?;
      final legacyGeometryJson = record['geometry_geojson'] as String?;
      final actualMediumJson = mediumGeometryJson ?? legacyGeometryJson;
      if (actualMediumJson != null && actualMediumJson.isNotEmpty) {
        try {
          final geom = jsonDecode(actualMediumJson) as Map<String, dynamic>;
          final geomType = geom['type'] as String?;
          final coords = geom['coordinates'];

          // Debug: Log geometry info for NPS
          if (ownerName == 'NPS') {
            final sample = actualMediumJson.length > 100 ? '${actualMediumJson.substring(0, 100)}...' : actualMediumJson;
            debugPrint('🔍 ZIP Parse: NPS property geomType=$geomType, coords is ${coords?.runtimeType}, len=${actualMediumJson.length}, sample=$sample');
          }

          if (coords != null) {
            mediumBoundaries = _parseGeoJsonCoordinates(coords, ownerName: ownerName);
            // Debug: Log if geometry parsing failed
            if (mediumBoundaries == null || mediumBoundaries.isEmpty) {
              if (ownerName == 'NPS') {
                debugPrint('⚠️ ZIP Parse: NPS property has null/empty boundaries after parsing $geomType geometry');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse medium geometry: $e');
        }
      } else if (ownerName == 'NPS') {
        debugPrint('⚠️ ZIP Parse: NPS property has no geometry_medium_geojson or geometry_geojson');
      }

      // Parse LOW quality geometry (zoom 8-9, ~111m tolerance)
      List<List<List<double>>>? lowBoundaries;
      final lowGeometryJson = record['geometry_low_geojson'] as String?;
      if (lowGeometryJson != null && lowGeometryJson.isNotEmpty) {
        try {
          final geom = jsonDecode(lowGeometryJson) as Map<String, dynamic>;
          final coords = geom['coordinates'];
          if (coords != null) {
            lowBoundaries = _parseGeoJsonCoordinates(coords, ownerName: ownerName);
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse low geometry: $e');
        }
      }

      // Parse OVERVIEW geometry (zoom 5-7, ~555m tolerance)
      List<List<List<double>>>? overviewBoundaries;
      final overviewJson = record['geometry_overview_geojson'] as String?;
      if (overviewJson != null && overviewJson.isNotEmpty) {
        try {
          final geom = jsonDecode(overviewJson) as Map<String, dynamic>;
          final coords = geom['coordinates'];
          if (coords != null) {
            overviewBoundaries = _parseGeoJsonCoordinates(coords, ownerName: ownerName);
          }
        } catch (e) {
          // Overview geometry parsing failed - not critical, will fall back
          debugPrint('⚠️ Failed to parse overview geometry: $e');
        }
      }

      // Parse activity permissions
      final activityPermsData = record['activity_permissions'];
      final activityPermissions = activityPermsData is Map<String, dynamic>
          ? activityPermsData
          : <String, dynamic>{};

      // Parse access rights
      final accessRightsData = record['access_rights'];
      final accessRights = accessRightsData is Map<String, dynamic>
          ? accessRightsData
          : <String, dynamic>{};

      return ComprehensiveLandOwnership(
        id: record['external_id']?.toString() ?? record['id']?.toString() ?? '',
        ownerName: record['owner_name']?.toString() ?? 'Unknown',
        ownershipType: record['ownership_type']?.toString() ?? 'unknown',
        acreage: (record['acreage'] as num?)?.toDouble(),
        dataSource: record['data_source']?.toString() ?? 'PAD-US',
        lastUpdated: record['source_updated_at'] != null
            ? DateTime.tryParse(record['source_updated_at'].toString())
            : null,
        boundaries: fullBoundaries,
        highBoundaries: highBoundaries,
        mediumBoundaries: mediumBoundaries,
        lowBoundaries: lowBoundaries,
        overviewBoundaries: overviewBoundaries,
        activityPermissions: ActivityPermissions.fromJson(activityPermissions),
        accessRights: AccessRights.fromJson(accessRights),
        agencyName: record['agency_name']?.toString(),
        unitName: record['unit_name']?.toString(),
        designation: record['designation']?.toString(),
        accessType: record['access_type']?.toString() ?? 'unknown',
      );
    } catch (e) {
      debugPrint('Error parsing ZIP record: $e');
      return null;
    }
  }

  /// Parse GeoJSON coordinates to the format expected by ComprehensiveLandOwnership
  ///
  /// Handles both Polygon and MultiPolygon geometries.
  /// For MultiPolygon, ALL polygons are included to ensure correct bounding box calculation.
  List<List<List<double>>>? _parseGeoJsonCoordinates(Object? coords, {String? ownerName}) {
    if (coords == null) {
      if (ownerName == 'NPS') debugPrint('🔍 ZIP GeoJSON: NPS coords is null');
      return null;
    }

    try {
      // Handle different GeoJSON geometry types
      // Polygon: [[[lon, lat], [lon, lat], ...]]
      // MultiPolygon: [[[[lon, lat], ...]], [[[lon, lat], ...]]]
      if (coords is List && coords.isNotEmpty) {
        final first = coords[0];

        // Check if this is a MultiPolygon (4 levels deep) or Polygon (3 levels deep)
        if (first is List && first.isNotEmpty && first[0] is List) {
          final innerFirst = first[0];
          if (innerFirst is List && innerFirst.isNotEmpty && innerFirst[0] is List) {
            // MultiPolygon - parse ALL polygons to get correct bounding box
            if (ownerName == 'NPS') {
              debugPrint('🔍 ZIP GeoJSON: NPS detected as MultiPolygon with ${coords.length} polygons');
            }
            return _parseMultiPolygonCoords(coords, ownerName: ownerName);
          } else {
            // Polygon
            if (ownerName == 'NPS') {
              debugPrint('🔍 ZIP GeoJSON: NPS detected as Polygon with ${coords.length} rings');
            }
            return _parsePolygonCoords(coords, ownerName: ownerName);
          }
        } else {
          if (ownerName == 'NPS') {
            final firstType = first is List
                ? (first.isNotEmpty ? 'List with first element ${first[0].runtimeType}' : 'empty list')
                : first.runtimeType.toString();
            debugPrint('🔍 ZIP GeoJSON: NPS coords structure not recognized - first is $firstType');
          }
        }
      } else {
        if (ownerName == 'NPS') {
          debugPrint('🔍 ZIP GeoJSON: NPS coords is ${coords is List ? 'empty list' : coords.runtimeType}');
        }
      }
    } catch (e) {
      debugPrint('Error parsing GeoJSON coordinates: $e');
    }
    return null;
  }

  /// Parse MultiPolygon coordinates - includes ALL polygons for correct bbox calculation
  List<List<List<double>>>? _parseMultiPolygonCoords(List<dynamic> coords, {String? ownerName}) {
    try {
      final allRings = <List<List<double>>>[];
      var totalPoints = 0;

      // Iterate through ALL polygons in the MultiPolygon
      for (final polygon in coords) {
        if (polygon is List) {
          // Each polygon contains rings (outer ring + optional holes)
          for (final ring in polygon) {
            if (ring is List) {
              final parsedRing = <List<double>>[];
              for (final point in ring) {
                if (point is List && point.length >= 2) {
                  parsedRing.add([
                    (point[0] as num).toDouble(),
                    (point[1] as num).toDouble(),
                  ]);
                }
              }
              if (parsedRing.isNotEmpty) {
                allRings.add(parsedRing);
                totalPoints += parsedRing.length;
              }
            }
          }
        }
      }

      if (ownerName == 'NPS') {
        debugPrint('🔍 ZIP GeoJSON: NPS _parseMultiPolygonCoords returned ${allRings.length} rings with $totalPoints total points');
      }
      return allRings.isNotEmpty ? allRings : null;
    } catch (e) {
      if (ownerName == 'NPS') debugPrint('🔍 ZIP GeoJSON: NPS _parseMultiPolygonCoords exception: $e');
      return null;
    }
  }

  /// Parse polygon coordinates
  List<List<List<double>>>? _parsePolygonCoords(List<dynamic> coords, {String? ownerName}) {
    try {
      final result = <List<List<double>>>[];
      for (final ring in coords) {
        if (ring is List) {
          final parsedRing = <List<double>>[];
          for (final point in ring) {
            if (point is List && point.length >= 2) {
              parsedRing.add([
                (point[0] as num).toDouble(),
                (point[1] as num).toDouble(),
              ]);
            }
          }
          if (parsedRing.isNotEmpty) {
            result.add(parsedRing);
          }
        }
      }
      if (ownerName == 'NPS') {
        debugPrint('🔍 ZIP GeoJSON: NPS _parsePolygonCoords returned ${result.length} rings with ${result.isNotEmpty ? result[0].length : 0} points in first ring');
      }
      return result.isNotEmpty ? result : null;
    } catch (e) {
      if (ownerName == 'NPS') debugPrint('🔍 ZIP GeoJSON: NPS _parsePolygonCoords exception: $e');
      return null;
    }
  }

  /// Get a complete trail group by OSM relation ID
  /// NOTE: GraphQL removed - trail data now comes from local SQLite
  Future<TrailGroup?> getTrailGroup({
    required String relationId,
    required Trail tappedSegment,
  }) async {
    debugPrint('⚠️ getTrailGroup: GraphQL removed, use local data');
    return null;
  }
}
