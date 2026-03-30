import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/imported_route.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/device_registration_service.dart';
import 'package:obsession_tracker/core/services/lifetime_statistics_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';
import 'package:obsession_tracker/core/services/route_planning_service.dart';
import 'package:obsession_tracker/features/journal/data/models/entry_type.dart';
import 'package:obsession_tracker/features/journal/data/models/journal_entry.dart';
import 'package:obsession_tracker/features/journal/data/models/mood.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Service for loading mock/demo data for screenshots and testing.
///
/// This service creates realistic tracking sessions, breadcrumbs, waypoints,
/// and routes that showcase the app's features for App Store screenshots
/// and development testing.
///
/// All data is set in Grand Staircase-Escalante, Utah area (BLM National Monument
/// adjacent to Capitol Reef NP and Glen Canyon NRA) to showcase land ownership boundaries.
class MockDataLoaderService {
  final DatabaseService _db = DatabaseService();
  final Random _random = Random(42); // Fixed seed for reproducibility

  /// Check if demo data already exists
  Future<bool> hasDemoData() async {
    final sessions = await _db.getAllSessions(limit: 1);
    return sessions.any((s) => s.id.startsWith('demo-session-'));
  }

  /// Clear all demo data (sessions with demo IDs)
  Future<void> clearDemoData() async {
    final sessions = await _db.getAllSessions();
    for (final session in sessions) {
      if (session.id.startsWith('demo-session-')) {
        await _db.deleteSession(session.id);
      }
    }
    debugPrint('🗑️ Cleared demo data');
  }

  /// Load all demo data for screenshots
  Future<void> loadDemoData() async {
    debugPrint('📦 Loading demo data...');

    // Enable mock mode for Pro entitlements (bypasses BFF registration)
    DeviceRegistrationService.instance.enableMockMode();

    // Clear existing demo data first
    await clearDemoData();

    // Create demo sessions - Grand Staircase-Escalante, Utah area
    await _createEscalanteSlotCanyonExpedition();
    await _createHoleInTheRockSearch();
    await _createDevilsGardenExploration();
    await _createActiveSession();

    // Create demo routes
    await _createDemoRoutes();

    // Create demo photos for waypoints
    await createDemoPhotos();

    // Create demo treasure hunts
    await _createDemoHunts();

    // Create demo journal entries
    await _createDemoJournalEntries();

    // Create demo achievements and statistics
    await loadAchievementsMockData();

    debugPrint('✅ Demo data loaded successfully');
  }

  /// Load mock land ownership data for screenshots.
  ///
  /// This creates sample BLM, NPS, and private land parcels in the demo area
  /// (Grand Staircase-Escalante, Utah) to showcase map overlays.
  ///
  /// Call this separately from loadDemoData since it requires an
  /// OfflineLandRightsService instance.
  Future<void> loadMockLandData(OfflineLandRightsService offlineService) async {
    debugPrint('🗺️ Loading mock land data for screenshots...');

    // Demo area center: Grand Staircase-Escalante, Utah
    // This matches MapboxPresets.screenshotCenter
    const centerLat = 37.75;
    const centerLon = -111.42;

    // Create sample land parcels around the demo area
    final landRecords = <Map<String, dynamic>>[
      // BLM Land - Large parcel southwest of center
      _createLandRecord(
        id: 'demo-blm-001',
        ownerName: 'Bureau of Land Management',
        ownershipType: 'federal',
        designation: 'BLM National Monument',
        accessType: 'public',
        centerLat: centerLat - 0.02,
        centerLon: centerLon - 0.03,
        size: 0.04, // ~4km
      ),
      // BLM Land - Northwest
      _createLandRecord(
        id: 'demo-blm-002',
        ownerName: 'Bureau of Land Management',
        ownershipType: 'federal',
        designation: 'BLM Public Land',
        accessType: 'public',
        centerLat: centerLat + 0.015,
        centerLon: centerLon - 0.025,
        size: 0.03,
      ),
      // NPS Land - Capitol Reef area (east)
      _createLandRecord(
        id: 'demo-nps-001',
        ownerName: 'National Park Service',
        ownershipType: 'federal',
        designation: 'Capitol Reef National Park',
        accessType: 'public',
        centerLat: centerLat + 0.01,
        centerLon: centerLon + 0.04,
        size: 0.05,
      ),
      // State Trust Land
      _createLandRecord(
        id: 'demo-state-001',
        ownerName: 'Utah School and Institutional Trust Lands',
        ownershipType: 'state',
        designation: 'State Trust Land',
        accessType: 'restricted',
        centerLat: centerLat - 0.01,
        centerLon: centerLon + 0.02,
        size: 0.02,
      ),
      // Private Land - Small parcel
      _createLandRecord(
        id: 'demo-private-001',
        ownerName: 'Private Owner',
        ownershipType: 'private',
        designation: 'Private Property',
        accessType: 'private',
        centerLat: centerLat + 0.005,
        centerLon: centerLon - 0.01,
        size: 0.015,
      ),
      // Private Land - Ranch
      _createLandRecord(
        id: 'demo-private-002',
        ownerName: 'Private Ranch',
        ownershipType: 'private',
        designation: 'Private Property',
        accessType: 'private',
        centerLat: centerLat - 0.025,
        centerLon: centerLon + 0.01,
        size: 0.018,
      ),
    ];

    // Insert records into the land cache database
    await offlineService.insertMockLandRecords(landRecords);

    debugPrint('🗺️ Inserted ${landRecords.length} mock land parcels');
  }

  /// Create a land record map for insertion
  Map<String, dynamic> _createLandRecord({
    required String id,
    required String ownerName,
    required String ownershipType,
    required String designation,
    required String accessType,
    required double centerLat,
    required double centerLon,
    required double size, // Size in degrees (roughly)
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expires = now + const Duration(days: 36500).inMilliseconds;

    // Create a simple rectangular boundary
    final halfSize = size / 2;
    final boundary = [
      [
        [centerLon - halfSize, centerLat - halfSize],
        [centerLon + halfSize, centerLat - halfSize],
        [centerLon + halfSize, centerLat + halfSize],
        [centerLon - halfSize, centerLat + halfSize],
        [centerLon - halfSize, centerLat - halfSize], // Close the polygon
      ]
    ];

    return {
      'id': id,
      'owner_name': ownerName,
      'ownership_type': ownershipType,
      'legal_description': null,
      'acreage': (size * 111) * (size * 111) * 247.105, // Rough acres calculation
      'data_source': 'PAD-US',
      'last_updated': DateTime.now().toIso8601String(),
      'activity_permissions': '{"metalDetecting":"unknown","treasureHunting":"unknown","archaeology":"prohibited","camping":"allowed","hunting":"restricted","fishing":"unknown"}',
      'access_rights': '{"publicAccess":${accessType == 'public'},"easementAccess":false,"permitRequired":${accessType == 'restricted'},"huntingAccess":false,"recreationAccess":${accessType != 'private'}}',
      'owner_contact': null,
      'agency_name': ownerName,
      'unit_name': designation,
      'designation': designation,
      'access_type': accessType,
      'allowed_uses': '[]',
      'restrictions': '[]',
      'contact_info': null,
      'website': null,
      'fees': null,
      'seasonal_info': null,
      'cached_at': now,
      'cache_expires': expires,
      'state_code': 'UT',
      'data_version': 'PAD-US-4.1',
      'center_lat': centerLat,
      'center_lon': centerLon,
      'bbox_north': centerLat + halfSize,
      'bbox_south': centerLat - halfSize,
      'bbox_east': centerLon + halfSize,
      'bbox_west': centerLon - halfSize,
      'boundary': boundary, // Will be inserted into boundaries table
    };
  }

  /// Load mock data for achievements screenshots
  ///
  /// Creates impressive lifetime statistics, explored states, and achievement
  /// progress to showcase the achievements feature in screenshots.
  Future<void> loadAchievementsMockData() async {
    debugPrint('🏆 Loading achievements mock data...');

    final now = DateTime.now();
    final Database db = await _db.database;

    // Initialize achievement service to seed achievement definitions
    final achievementService = AchievementService();
    await achievementService.initialize();

    // Create impressive lifetime statistics
    final lifetimeStats = {
      'id': 1,
      'total_distance': 523847.0, // ~325 miles in meters
      'total_duration': 187200000, // ~52 hours in milliseconds
      'total_sessions': 47,
      'total_waypoints': 156,
      'total_photos': 89,
      'total_voice_notes': 23,
      'total_hunts_created': 8,
      'total_hunts_solved': 2,
      'total_elevation_gain': 12450.0, // meters
      'states_explored': 7,
      'current_streak': 5,
      'longest_streak': 14,
      'last_activity_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'pr_longest_session_distance': 28500.0, // ~17.7 miles
      'pr_longest_session_duration': 21600000, // 6 hours
      'pr_most_elevation_gain': 1850.0, // meters
      'pr_longest_session_id': 'demo-session-escalante-001',
      'pr_elevation_session_id': 'demo-session-escalante-001',
      'updated_at': now.millisecondsSinceEpoch,
    };

    await db.insert(
      'lifetime_statistics',
      lifetimeStats,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Verify the insert succeeded
    final verifyResult = await db.query('lifetime_statistics', where: 'id = ?', whereArgs: [1]);
    if (verifyResult.isNotEmpty) {
      final sessions = verifyResult.first['total_sessions'];
      debugPrint('  📊 Created lifetime statistics (verified: $sessions sessions)');
    } else {
      debugPrint('  ⚠️ Lifetime statistics insert may have failed!');
    }

    // Create explored states (7 states visited)
    final exploredStates = [
      {
        'id': 'state_UT',
        'state_code': 'UT',
        'state_name': 'Utah',
        'first_visited_at': now.subtract(const Duration(days: 180)).millisecondsSinceEpoch,
        'last_visited_at': now.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
        'session_count': 28,
        'total_distance': 312500.0,
        'total_duration': 108000000,
      },
      {
        'id': 'state_CO',
        'state_code': 'CO',
        'state_name': 'Colorado',
        'first_visited_at': now.subtract(const Duration(days: 120)).millisecondsSinceEpoch,
        'last_visited_at': now.subtract(const Duration(days: 45)).millisecondsSinceEpoch,
        'session_count': 8,
        'total_distance': 89000.0,
        'total_duration': 32400000,
      },
      {
        'id': 'state_NM',
        'state_code': 'NM',
        'state_name': 'New Mexico',
        'first_visited_at': now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
        'last_visited_at': now.subtract(const Duration(days: 60)).millisecondsSinceEpoch,
        'session_count': 5,
        'total_distance': 56000.0,
        'total_duration': 21600000,
      },
      {
        'id': 'state_AZ',
        'state_code': 'AZ',
        'state_name': 'Arizona',
        'first_visited_at': now.subtract(const Duration(days: 75)).millisecondsSinceEpoch,
        'last_visited_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'session_count': 3,
        'total_distance': 34000.0,
        'total_duration': 14400000,
      },
      {
        'id': 'state_WY',
        'state_code': 'WY',
        'state_name': 'Wyoming',
        'first_visited_at': now.subtract(const Duration(days: 60)).millisecondsSinceEpoch,
        'last_visited_at': now.subtract(const Duration(days: 55)).millisecondsSinceEpoch,
        'session_count': 2,
        'total_distance': 18000.0,
        'total_duration': 7200000,
      },
      {
        'id': 'state_MT',
        'state_code': 'MT',
        'state_name': 'Montana',
        'first_visited_at': now.subtract(const Duration(days: 45)).millisecondsSinceEpoch,
        'last_visited_at': now.subtract(const Duration(days: 40)).millisecondsSinceEpoch,
        'session_count': 1,
        'total_distance': 8500.0,
        'total_duration': 3600000,
      },
      {
        'id': 'state_ID',
        'state_code': 'ID',
        'state_name': 'Idaho',
        'first_visited_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'last_visited_at': now.subtract(const Duration(days: 28)).millisecondsSinceEpoch,
        'session_count': 1,
        'total_distance': 5847.0,
        'total_duration': 2400000,
      },
    ];

    for (final state in exploredStates) {
      await db.insert(
        'explored_states',
        state,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    debugPrint('  🗺️ Created ${exploredStates.length} explored states');

    // Create user achievement progress
    // Mix of completed, in-progress, and locked achievements
    final userAchievements = <Map<String, dynamic>>[
      // Completed achievements (badges earned!)
      {
        'id': 'ua_first_session',
        'achievement_id': 'first_session',
        'status': 'completed',
        'current_progress': 47.0,
        'unlocked_at': now.subtract(const Duration(days: 180)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 180)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_sessions_10',
        'achievement_id': 'sessions_10',
        'status': 'completed',
        'current_progress': 47.0,
        'unlocked_at': now.subtract(const Duration(days: 150)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 150)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_sessions_25',
        'achievement_id': 'sessions_25',
        'status': 'completed',
        'current_progress': 47.0,
        'unlocked_at': now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_distance_10mi',
        'achievement_id': 'distance_10mi',
        'status': 'completed',
        'current_progress': 523847.0,
        'unlocked_at': now.subtract(const Duration(days: 170)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 170)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_distance_50mi',
        'achievement_id': 'distance_50mi',
        'status': 'completed',
        'current_progress': 523847.0,
        'unlocked_at': now.subtract(const Duration(days: 120)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 120)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_distance_100mi',
        'achievement_id': 'distance_100mi',
        'status': 'completed',
        'current_progress': 523847.0,
        'unlocked_at': now.subtract(const Duration(days: 60)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 60)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_states_1',
        'achievement_id': 'states_1',
        'status': 'completed',
        'current_progress': 7.0,
        'unlocked_at': now.subtract(const Duration(days: 180)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 180)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_states_5',
        'achievement_id': 'states_5',
        'status': 'completed',
        'current_progress': 7.0,
        'unlocked_at': now.subtract(const Duration(days: 45)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 45)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_streak_3',
        'achievement_id': 'streak_3',
        'status': 'completed',
        'current_progress': 14.0,
        'unlocked_at': now.subtract(const Duration(days: 100)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 100)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_streak_7',
        'achievement_id': 'streak_7',
        'status': 'completed',
        'current_progress': 14.0,
        'unlocked_at': now.subtract(const Duration(days: 80)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 80)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_streak_14',
        'achievement_id': 'streak_14',
        'status': 'completed',
        'current_progress': 14.0,
        'unlocked_at': now.subtract(const Duration(days: 50)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 50)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_photos_10',
        'achievement_id': 'photos_10',
        'status': 'completed',
        'current_progress': 89.0,
        'unlocked_at': now.subtract(const Duration(days: 140)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 140)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_photos_50',
        'achievement_id': 'photos_50',
        'status': 'completed',
        'current_progress': 89.0,
        'unlocked_at': now.subtract(const Duration(days: 70)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 70)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_voice_10',
        'achievement_id': 'voice_10',
        'status': 'completed',
        'current_progress': 23.0,
        'unlocked_at': now.subtract(const Duration(days: 100)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 100)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_hunt_first',
        'achievement_id': 'hunt_first',
        'status': 'completed',
        'current_progress': 8.0,
        'unlocked_at': now.subtract(const Duration(days: 160)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 160)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_hunt_5',
        'achievement_id': 'hunt_5',
        'status': 'completed',
        'current_progress': 8.0,
        'unlocked_at': now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 90)).millisecondsSinceEpoch,
      },
      {
        'id': 'ua_hunt_solved',
        'achievement_id': 'hunt_solved',
        'status': 'completed',
        'current_progress': 2.0,
        'unlocked_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'completed_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
      },

      // In-progress achievements (working towards these)
      {
        'id': 'ua_sessions_50',
        'achievement_id': 'sessions_50',
        'status': 'in_progress',
        'current_progress': 47.0,
        'unlocked_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'completed_at': null,
      },
      {
        'id': 'ua_distance_500mi',
        'achievement_id': 'distance_500mi',
        'status': 'in_progress',
        'current_progress': 523847.0, // 65% of 500 miles
        'unlocked_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'completed_at': null,
      },
      {
        'id': 'ua_states_10',
        'achievement_id': 'states_10',
        'status': 'in_progress',
        'current_progress': 7.0,
        'unlocked_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'completed_at': null,
      },
      {
        'id': 'ua_photos_100',
        'achievement_id': 'photos_100',
        'status': 'in_progress',
        'current_progress': 89.0,
        'unlocked_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'completed_at': null,
      },
      {
        'id': 'ua_voice_50',
        'achievement_id': 'voice_50',
        'status': 'in_progress',
        'current_progress': 23.0,
        'unlocked_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'completed_at': null,
      },
      {
        'id': 'ua_streak_30',
        'achievement_id': 'streak_30',
        'status': 'in_progress',
        'current_progress': 14.0,
        'unlocked_at': now.subtract(const Duration(days: 20)).millisecondsSinceEpoch,
        'completed_at': null,
      },
      {
        'id': 'ua_hunt_solved_5',
        'achievement_id': 'hunt_solved_5',
        'status': 'in_progress',
        'current_progress': 2.0,
        'unlocked_at': now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
        'completed_at': null,
      },
    ];

    for (final achievement in userAchievements) {
      await db.insert(
        'user_achievements',
        achievement,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final completedCount = userAchievements.where((a) => a['status'] == 'completed').length;
    final inProgressCount = userAchievements.where((a) => a['status'] == 'in_progress').length;
    debugPrint('  🏅 Created $completedCount completed + $inProgressCount in-progress achievements');

    // Force LifetimeStatisticsService to reload from database
    // (it may have cached empty stats before mock data was inserted)
    final statsService = LifetimeStatisticsService();
    await statsService.reloadStats();

    debugPrint('✅ Achievements mock data loaded');
  }

  /// Session 1: Completed Escalante slot canyon expedition (6+ hours, lots of waypoints)
  Future<void> _createEscalanteSlotCanyonExpedition() async {
    const sessionId = 'demo-session-escalante-001';
    final now = DateTime.now();
    final sessionStart = now.subtract(const Duration(days: 3, hours: 14));
    final sessionEnd = sessionStart.add(const Duration(hours: 6, minutes: 45));

    // Grand Staircase-Escalante - BLM land near Capitol Reef boundary
    const startLat = 37.7734;
    const startLon = -111.4567;

    // Generate a hiking trail pattern
    final breadcrumbs = _generateHikingTrail(
      sessionId: sessionId,
      startLat: startLat,
      startLon: startLon,
      startTime: sessionStart,
      durationMinutes: 405, // 6h 45m
      pointCount: 486, // ~5 second intervals
      trailType: TrailType.exploration,
    );

    final totalDistance = _calculateTotalDistance(breadcrumbs);
    final endLocation = breadcrumbs.last.coordinates;

    final session = TrackingSession(
      id: sessionId,
      name: 'Escalante Slot Canyon Expedition',
      description: 'Full day exploring slot canyons in Grand Staircase-Escalante. Found petroglyph panel and historic cattle trail.',
      status: SessionStatus.completed,
      createdAt: sessionStart.subtract(const Duration(minutes: 15)),
      startedAt: sessionStart,
      completedAt: sessionEnd,
      totalDistance: totalDistance,
      totalDuration: const Duration(hours: 6, minutes: 45).inMilliseconds,
      breadcrumbCount: breadcrumbs.length,
      startLocation: const LatLng(startLat, startLon),
      endLocation: endLocation,
    );

    await _db.insertSession(session);

    // Insert breadcrumbs in batches
    await _db.insertBreadcrumbs(breadcrumbs);

    // Create varied waypoints along the trail
    final waypoints = [
      Waypoint(
        id: '$sessionId-wp-001',
        sessionId: sessionId,
        coordinates: breadcrumbs[50].coordinates,
        type: WaypointType.interest,
        timestamp: breadcrumbs[50].timestamp,
        name: 'BLM Trailhead Parking',
        notes: 'BLM land boundary marker here - public access begins. Good parking.',
        altitude: 1680.0,
        accuracy: 5.2,
      ),
      Waypoint(
        id: '$sessionId-wp-002',
        sessionId: sessionId,
        coordinates: breadcrumbs[0].coordinates, // At start so photo shows immediately
        type: WaypointType.photo, // Must be photo type for playback controller to show image
        timestamp: breadcrumbs[0].timestamp,
        name: 'Slot Canyon Entrance',
        notes: 'Narrow slot canyon begins here. Watch for flash flood warnings.',
        altitude: 1720.0,
        accuracy: 4.8,
      ),
      Waypoint(
        id: '$sessionId-wp-003',
        sessionId: sessionId,
        coordinates: breadcrumbs[180].coordinates,
        type: WaypointType.photo,
        timestamp: breadcrumbs[180].timestamp,
        name: 'Petroglyph Panel',
        notes: 'Ancestral Puebloan petroglyphs on canyon wall. Do not touch - protected.',
        altitude: 1650.0,
        accuracy: 6.1,
      ),
      Waypoint(
        id: '$sessionId-wp-004',
        sessionId: sessionId,
        coordinates: breadcrumbs[250].coordinates,
        type: WaypointType.warning,
        timestamp: breadcrumbs[250].timestamp,
        name: 'Capitol Reef NPS Boundary',
        notes: 'National Park boundary ahead - no treasure hunting beyond this point.',
        altitude: 1780.0,
        accuracy: 3.5,
      ),
      Waypoint(
        id: '$sessionId-wp-005',
        sessionId: sessionId,
        coordinates: breadcrumbs[320].coordinates,
        type: WaypointType.interest,
        timestamp: breadcrumbs[320].timestamp,
        name: 'Historic Cattle Trail',
        notes: 'Old Mormon cattle trail from 1880s. Stone markers still visible.',
        altitude: 1850.0,
        accuracy: 4.2,
      ),
      Waypoint(
        id: '$sessionId-wp-006',
        sessionId: sessionId,
        coordinates: breadcrumbs[400].coordinates,
        type: WaypointType.photo,
        timestamp: breadcrumbs[400].timestamp,
        name: 'Scenic Overlook',
        notes: 'Stunning view of Waterpocket Fold. Great photo opportunity.',
        altitude: 1920.0,
        accuracy: 5.8,
      ),
    ];

    for (final waypoint in waypoints) {
      await _db.insertWaypoint(waypoint);
    }

    // Save statistics
    await _db.saveSessionStatistics(SessionStatistics(
      sessionId: sessionId,
      timestamp: sessionEnd,
      totalDistance: totalDistance,
      totalDuration: const Duration(hours: 6, minutes: 45),
      movingDuration: const Duration(hours: 5, minutes: 30),
      stationaryDuration: const Duration(hours: 1, minutes: 15),
      averageSpeed: totalDistance / (6.75 * 3600),
      movingAverageSpeed: totalDistance / (5.5 * 3600),
      maxSpeed: 2.8,
      currentAltitude: 2060,
      minAltitude: 1980,
      maxAltitude: 2280,
      totalElevationGain: 520,
      totalElevationLoss: 480,
      currentHeading: 145,
      waypointCount: waypoints.length,
      waypointsByType: const {'treasure': 2, 'interest': 2, 'camp': 1, 'warning': 1},
      waypointDensity: waypoints.length / (totalDistance / 1000),
      lastLocationAccuracy: 5.2,
      averageAccuracy: 6.8,
      goodAccuracyPercentage: 92.5,
    ));

    debugPrint('✅ Created Escalante Slot Canyon session');
  }

  /// Session 2: Hole-in-the-Rock Road historic pioneer trail (3 hours, moderate waypoints)
  Future<void> _createHoleInTheRockSearch() async {
    const sessionId = 'demo-session-hole-rock-002';
    final now = DateTime.now();
    final sessionStart = now.subtract(const Duration(days: 7, hours: 10));
    final sessionEnd = sessionStart.add(const Duration(hours: 3, minutes: 15));

    // Hole-in-the-Rock Road - historic Mormon pioneer emigrant trail on BLM land
    const startLat = 37.6521;
    const startLon = -111.4345;

    final breadcrumbs = _generateHikingTrail(
      sessionId: sessionId,
      startLat: startLat,
      startLon: startLon,
      startTime: sessionStart,
      durationMinutes: 195, // 3h 15m
      pointCount: 234,
      trailType: TrailType.prospecting,
    );

    final totalDistance = _calculateTotalDistance(breadcrumbs);

    final session = TrackingSession(
      id: sessionId,
      name: 'Hole-in-the-Rock Trail',
      description: 'Following the historic 1879 Mormon pioneer emigrant trail on BLM land. Incredible history and inscriptions.',
      status: SessionStatus.completed,
      createdAt: sessionStart.subtract(const Duration(minutes: 10)),
      startedAt: sessionStart,
      completedAt: sessionEnd,
      totalDistance: totalDistance,
      totalDuration: const Duration(hours: 3, minutes: 15).inMilliseconds,
      breadcrumbCount: breadcrumbs.length,
      startLocation: const LatLng(startLat, startLon),
      endLocation: breadcrumbs.last.coordinates,
    );

    await _db.insertSession(session);
    await _db.insertBreadcrumbs(breadcrumbs);

    final waypoints = [
      Waypoint(
        id: '$sessionId-wp-001',
        sessionId: sessionId,
        coordinates: breadcrumbs[40].coordinates,
        type: WaypointType.interest,
        timestamp: breadcrumbs[40].timestamp,
        name: 'Dance Hall Rock',
        notes: 'Historic gathering place where Mormon pioneers held dances during the 1879 expedition. Amazing acoustics!',
        altitude: 1680.0,
        accuracy: 4.5,
      ),
      Waypoint(
        id: '$sessionId-wp-002',
        sessionId: sessionId,
        coordinates: breadcrumbs[100].coordinates,
        type: WaypointType.treasure,
        timestamp: breadcrumbs[100].timestamp,
        name: 'Pioneer Inscription Panel',
        notes: 'Found names and dates carved by 1879 pioneers. Some artifacts may remain in area.',
        altitude: 1720.0,
        accuracy: 5.8,
      ),
      Waypoint(
        id: '$sessionId-wp-003',
        sessionId: sessionId,
        coordinates: breadcrumbs[160].coordinates,
        type: WaypointType.photo,
        timestamp: breadcrumbs[160].timestamp,
        name: 'Old Wagon Ruts',
        notes: 'Original wagon wheel ruts still visible in sandstone! 145 years of history.',
        altitude: 1650.0,
        accuracy: 3.9,
      ),
      Waypoint(
        id: '$sessionId-wp-004',
        sessionId: sessionId,
        coordinates: breadcrumbs[200].coordinates,
        type: WaypointType.warning,
        timestamp: breadcrumbs[200].timestamp,
        name: 'Glen Canyon NRA Boundary',
        notes: 'NPS land begins here - no searching allowed beyond this point. Turn back to BLM.',
        altitude: 1580.0,
        accuracy: 4.2,
      ),
    ];

    for (final waypoint in waypoints) {
      await _db.insertWaypoint(waypoint);
    }

    await _db.saveSessionStatistics(SessionStatistics(
      sessionId: sessionId,
      timestamp: sessionEnd,
      totalDistance: totalDistance,
      totalDuration: const Duration(hours: 3, minutes: 15),
      movingDuration: const Duration(hours: 2, minutes: 45),
      stationaryDuration: const Duration(minutes: 30),
      averageSpeed: totalDistance / (3.25 * 3600),
      movingAverageSpeed: totalDistance / (2.75 * 3600),
      maxSpeed: 2.2,
      currentAltitude: 1580,
      minAltitude: 1520,
      maxAltitude: 1720,
      totalElevationGain: 180,
      totalElevationLoss: 210,
      currentHeading: 230,
      waypointCount: waypoints.length,
      waypointsByType: const {'treasure': 1, 'interest': 1, 'photo': 1, 'warning': 1},
      waypointDensity: waypoints.length / (totalDistance / 1000),
      lastLocationAccuracy: 4.2,
      averageAccuracy: 5.5,
      goodAccuracyPercentage: 95.2,
    ));

    debugPrint('✅ Created Hole-in-the-Rock Trail session');
  }

  /// Session 3: Devils Garden hoodoos and arches area (1.5 hours, scenic)
  Future<void> _createDevilsGardenExploration() async {
    const sessionId = 'demo-session-devils-003';
    final now = DateTime.now();
    final sessionStart = now.subtract(const Duration(days: 14, hours: 8));
    final sessionEnd = sessionStart.add(const Duration(hours: 1, minutes: 30));

    // Devils Garden - unique rock formations on BLM land near Escalante
    const startLat = 37.8156;
    const startLon = -111.6267;

    final breadcrumbs = _generateHikingTrail(
      sessionId: sessionId,
      startLat: startLat,
      startLon: startLon,
      startTime: sessionStart,
      durationMinutes: 90,
      pointCount: 108,
      trailType: TrailType.canyon,
    );

    final totalDistance = _calculateTotalDistance(breadcrumbs);

    final session = TrackingSession(
      id: sessionId,
      name: 'Devils Garden Exploration',
      description: 'Exploring the unique hoodoos and natural arches on BLM land. Amazing photo opportunities!',
      status: SessionStatus.completed,
      createdAt: sessionStart.subtract(const Duration(minutes: 5)),
      startedAt: sessionStart,
      completedAt: sessionEnd,
      totalDistance: totalDistance,
      totalDuration: const Duration(hours: 1, minutes: 30).inMilliseconds,
      breadcrumbCount: breadcrumbs.length,
      startLocation: const LatLng(startLat, startLon),
      endLocation: breadcrumbs.last.coordinates,
    );

    await _db.insertSession(session);
    await _db.insertBreadcrumbs(breadcrumbs);

    final waypoints = [
      Waypoint(
        id: '$sessionId-wp-001',
        sessionId: sessionId,
        coordinates: breadcrumbs[30].coordinates,
        type: WaypointType.photo,
        timestamp: breadcrumbs[30].timestamp,
        name: 'Metate Arch',
        notes: 'Beautiful natural arch with amazing sunset lighting. Perfect for photos!',
        altitude: 1720.0,
        accuracy: 6.2,
      ),
      Waypoint(
        id: '$sessionId-wp-002',
        sessionId: sessionId,
        coordinates: breadcrumbs[70].coordinates,
        type: WaypointType.interest,
        timestamp: breadcrumbs[70].timestamp,
        name: 'Mano Arch',
        notes: 'Smaller arch nearby, named for its hand-like shape. Incredible geology!',
        altitude: 1680.0,
        accuracy: 4.8,
      ),
    ];

    for (final waypoint in waypoints) {
      await _db.insertWaypoint(waypoint);
    }

    await _db.saveSessionStatistics(SessionStatistics(
      sessionId: sessionId,
      timestamp: sessionEnd,
      totalDistance: totalDistance,
      totalDuration: const Duration(hours: 1, minutes: 30),
      movingDuration: const Duration(hours: 1, minutes: 20),
      stationaryDuration: const Duration(minutes: 10),
      averageSpeed: totalDistance / (1.5 * 3600),
      movingAverageSpeed: totalDistance / (1.33 * 3600),
      maxSpeed: 1.8,
      currentAltitude: 1680,
      minAltitude: 1640,
      maxAltitude: 1760,
      totalElevationGain: 120,
      totalElevationLoss: 140,
      currentHeading: 180,
      waypointCount: waypoints.length,
      waypointsByType: const {'photo': 1, 'interest': 1},
      waypointDensity: waypoints.length / (totalDistance / 1000),
      lastLocationAccuracy: 4.8,
      averageAccuracy: 5.2,
      goodAccuracyPercentage: 97.5,
    ));

    debugPrint('✅ Created Devils Garden session');
  }

  /// Session 4: Currently active/paused session in Calf Creek area (shows in Map tab)
  Future<void> _createActiveSession() async {
    const sessionId = 'demo-session-active-004';
    final now = DateTime.now();
    final sessionStart = now.subtract(const Duration(hours: 2, minutes: 15));

    // Calf Creek area - popular recreation area on BLM land near Escalante
    const startLat = 37.8167;
    const startLon = -111.4144;

    final breadcrumbs = _generateHikingTrail(
      sessionId: sessionId,
      startLat: startLat,
      startLon: startLon,
      startTime: sessionStart,
      durationMinutes: 135, // 2h 15m so far
      pointCount: 162,
      trailType: TrailType.exploration,
    );

    final totalDistance = _calculateTotalDistance(breadcrumbs);

    final session = TrackingSession(
      id: sessionId,
      name: 'Calf Creek Search',
      description: 'Exploring side canyons near Lower Calf Creek Falls. Currently paused for lunch break.',
      status: SessionStatus.paused,
      createdAt: sessionStart.subtract(const Duration(minutes: 10)),
      startedAt: sessionStart,
      totalDistance: totalDistance,
      totalDuration: const Duration(hours: 2, minutes: 15).inMilliseconds,
      breadcrumbCount: breadcrumbs.length,
      startLocation: const LatLng(startLat, startLon),
      endLocation: breadcrumbs.last.coordinates,
    );

    await _db.insertSession(session);
    await _db.insertBreadcrumbs(breadcrumbs);

    final waypoints = [
      Waypoint(
        id: '$sessionId-wp-001',
        sessionId: sessionId,
        coordinates: breadcrumbs[45].coordinates,
        type: WaypointType.interest,
        timestamp: breadcrumbs[45].timestamp,
        name: 'Lower Calf Creek Trailhead',
        notes: 'BLM recreation area. Popular trail but good research site off main path.',
        altitude: 1720.0,
        accuracy: 4.5,
      ),
      Waypoint(
        id: '$sessionId-wp-002',
        sessionId: sessionId,
        coordinates: breadcrumbs[100].coordinates,
        type: WaypointType.treasure,
        timestamp: breadcrumbs[100].timestamp,
        name: 'Research Site Alpha',
        notes: 'Promising area based on clue research. Need to spend more time here.',
        altitude: 1680.0,
        accuracy: 5.1,
      ),
      Waypoint(
        id: '$sessionId-wp-003',
        sessionId: sessionId,
        coordinates: breadcrumbs[140].coordinates,
        type: WaypointType.camp,
        timestamp: breadcrumbs[140].timestamp,
        name: 'Shady Lunch Spot',
        notes: 'Taking a break by the creek. Beautiful red rock canyon walls!',
        altitude: 1640.0,
        accuracy: 4.8,
      ),
    ];

    for (final waypoint in waypoints) {
      await _db.insertWaypoint(waypoint);
    }

    debugPrint('✅ Created Active (Paused) session');
  }

  /// Create sample imported routes AND planned routes (for Routes tab)
  Future<void> _createDemoRoutes() async {
    final now = DateTime.now();
    final routePlanningService = RoutePlanningService();

    // Route 1: Escalante River Trail - canyon exploration loop on BLM land
    const route1Id = 'demo-route-escalante-river-001';
    final route1Points = _generateRoutePoints(
      routeId: route1Id,
      startLat: 37.7800,
      startLon: -111.5200,
      pointCount: 85,
      isLoop: true,
    );

    final route1 = ImportedRoute(
      id: route1Id,
      name: 'Escalante River Trail',
      description: 'Canyon exploration loop following the Escalante River on BLM land. Ancient pictographs and slot canyons.',
      points: route1Points,
      waypoints: const [
        RouteWaypoint(
          id: '$route1Id-rwp-001',
          routeId: route1Id,
          name: 'Escalante Trailhead',
          latitude: 37.7800,
          longitude: -111.5200,
          elevation: 1700,
          type: 'start',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route1Id-rwp-002',
          routeId: route1Id,
          name: 'River Crossing',
          latitude: 37.7850,
          longitude: -111.5100,
          elevation: 1650,
          type: 'water',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route1Id-rwp-003',
          routeId: route1Id,
          name: 'Pictograph Panel',
          description: 'Ancient Fremont culture rock art',
          latitude: 37.7880,
          longitude: -111.5050,
          elevation: 1680,
          type: 'poi',
          properties: {},
        ),
      ],
      totalDistance: 8200,
      estimatedDuration: 4 * 3600,
      importedAt: now.subtract(const Duration(days: 30)),
      sourceFormat: 'gpx',
      metadata: const {
        'difficulty': 'moderate',
        'terrain': 'canyon and river',
        'season': 'march-november',
      },
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now.subtract(const Duration(days: 30)),
    );

    await _db.insertImportedRoute(route1);

    // Route 2: Hole-in-the-Rock Road - historic Mormon pioneer trail on BLM land
    const route2Id = 'demo-route-hole-rock-002';
    final route2Points = _generateRoutePoints(
      routeId: route2Id,
      startLat: 37.6520,
      startLon: -111.4100,
      pointCount: 60,
      isLoop: false,
    );

    final route2 = ImportedRoute(
      id: route2Id,
      name: 'Hole-in-the-Rock Road',
      description: 'Historic 1879 Mormon pioneer emigrant trail on BLM land. Dance Hall Rock and wagon ruts visible.',
      points: route2Points,
      waypoints: const [
        RouteWaypoint(
          id: '$route2Id-rwp-001',
          routeId: route2Id,
          name: 'Dance Hall Rock',
          latitude: 37.6520,
          longitude: -111.4100,
          elevation: 1680,
          type: 'start',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route2Id-rwp-002',
          routeId: route2Id,
          name: 'Sooner Wash',
          latitude: 37.6350,
          longitude: -111.3950,
          elevation: 1620,
          type: 'water',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route2Id-rwp-003',
          routeId: route2Id,
          name: 'Devils Garden Turnoff',
          latitude: 37.6200,
          longitude: -111.3800,
          elevation: 1580,
          type: 'turn',
          properties: {},
        ),
      ],
      totalDistance: 12000,
      estimatedDuration: 5 * 3600,
      importedAt: now.subtract(const Duration(days: 15)),
      sourceFormat: 'gpx',
      metadata: const {
        'difficulty': 'easy',
        'terrain': 'dirt road and desert',
        'historicSites': 3,
      },
      createdAt: now.subtract(const Duration(days: 15)),
      updatedAt: now.subtract(const Duration(days: 15)),
    );

    await _db.insertImportedRoute(route2);

    // Route 3: Boulder Mail Trail - historic pack trail through canyons
    const route3Id = 'demo-route-boulder-mail-003';
    final route3Points = _generateRoutePoints(
      routeId: route3Id,
      startLat: 37.8500,
      startLon: -111.4800,
      pointCount: 120,
      isLoop: false,
    );

    final route3 = ImportedRoute(
      id: route3Id,
      name: 'Boulder Mail Trail',
      description: 'Historic pack mule mail route from 1902-1935. Challenging canyon traverse with stunning views. Experienced hikers only.',
      points: route3Points,
      waypoints: const [
        RouteWaypoint(
          id: '$route3Id-rwp-001',
          routeId: route3Id,
          name: 'Boulder Town Trailhead',
          latitude: 37.8500,
          longitude: -111.4800,
          elevation: 1980,
          type: 'start',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route3Id-rwp-002',
          routeId: route3Id,
          name: 'Sand Creek Crossing',
          latitude: 37.8380,
          longitude: -111.4650,
          elevation: 1750,
          type: 'water',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route3Id-rwp-003',
          routeId: route3Id,
          name: 'Death Hollow Overlook',
          description: 'Dramatic canyon viewpoint - careful near edge',
          latitude: 37.8250,
          longitude: -111.4550,
          elevation: 1850,
          type: 'viewpoint',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route3Id-rwp-004',
          routeId: route3Id,
          name: 'Escalante Terminus',
          description: 'Historic mail route endpoint',
          latitude: 37.7720,
          longitude: -111.6000,
          elevation: 1720,
          type: 'destination',
          properties: {},
        ),
      ],
      totalDistance: 15200,
      estimatedDuration: 6 * 3600,
      importedAt: now.subtract(const Duration(days: 7)),
      sourceFormat: 'kml',
      metadata: const {
        'difficulty': 'challenging',
        'terrain': 'canyon and slickrock',
        'elevationGain': 450,
        'season': 'april-october',
      },
      createdAt: now.subtract(const Duration(days: 7)),
      updatedAt: now.subtract(const Duration(days: 7)),
    );

    await _db.insertImportedRoute(route3);

    // Route 4: Petrified Forest Loop - geological exploration on BLM land
    const route4Id = 'demo-route-petrified-004';
    final route4Points = _generateRoutePoints(
      routeId: route4Id,
      startLat: 37.7650,
      startLon: -111.5400,
      pointCount: 95,
      isLoop: true,
    );

    final route4 = ImportedRoute(
      id: route4Id,
      name: 'Petrified Forest Loop',
      description: 'Geological exploration loop through ancient petrified wood sites on BLM land. Fossils visible but protected.',
      points: route4Points,
      waypoints: const [
        RouteWaypoint(
          id: '$route4Id-rwp-001',
          routeId: route4Id,
          name: 'Parking Area',
          latitude: 37.7650,
          longitude: -111.5400,
          elevation: 1720,
          type: 'start',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route4Id-rwp-002',
          routeId: route4Id,
          name: 'Petrified Log Site 1',
          description: 'Large exposed petrified log',
          latitude: 37.7700,
          longitude: -111.5350,
          elevation: 1750,
          type: 'poi',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route4Id-rwp-003',
          routeId: route4Id,
          name: 'Fossil Bed',
          description: 'Triassic period fossils in sandstone',
          latitude: 37.7750,
          longitude: -111.5280,
          elevation: 1780,
          type: 'poi',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route4Id-rwp-004',
          routeId: route4Id,
          name: 'Colorful Layers',
          description: 'Chinle Formation - purple and red bands',
          latitude: 37.7780,
          longitude: -111.5320,
          elevation: 1760,
          type: 'viewpoint',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route4Id-rwp-005',
          routeId: route4Id,
          name: 'Petrified Stump',
          description: 'Standing petrified tree stump',
          latitude: 37.7750,
          longitude: -111.5380,
          elevation: 1740,
          type: 'poi',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route4Id-rwp-006',
          routeId: route4Id,
          name: 'Wash Crossing',
          latitude: 37.7720,
          longitude: -111.5420,
          elevation: 1710,
          type: 'water',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route4Id-rwp-007',
          routeId: route4Id,
          name: 'Photo Spot',
          description: 'Best light in afternoon',
          latitude: 37.7680,
          longitude: -111.5450,
          elevation: 1700,
          type: 'viewpoint',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route4Id-rwp-008',
          routeId: route4Id,
          name: 'Return Trail',
          latitude: 37.7660,
          longitude: -111.5420,
          elevation: 1715,
          type: 'turn',
          properties: {},
        ),
      ],
      totalDistance: 6800,
      estimatedDuration: 3.5 * 3600,
      importedAt: now.subtract(const Duration(days: 2)),
      sourceFormat: 'gpx',
      metadata: const {
        'difficulty': 'moderate',
        'terrain': 'desert and wash',
        'geologicalSites': 5,
        'season': 'march-november',
      },
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    );

    await _db.insertImportedRoute(route4);

    // Route 5: Burr Trail Scenic - access road to Capitol Reef boundary
    const route5Id = 'demo-route-burr-trail-005';
    final route5Points = _generateRoutePoints(
      routeId: route5Id,
      startLat: 37.8580,
      startLon: -111.4050,
      pointCount: 35,
      isLoop: false,
    );

    final route5 = ImportedRoute(
      id: route5Id,
      name: 'Burr Trail Scenic',
      description: 'Scenic access road through Waterpocket Fold to Capitol Reef NPS boundary. BLM land along route.',
      points: route5Points,
      waypoints: const [
        RouteWaypoint(
          id: '$route5Id-rwp-001',
          routeId: route5Id,
          name: 'Boulder Intersection',
          latitude: 37.8580,
          longitude: -111.4050,
          elevation: 1950,
          type: 'start',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route5Id-rwp-002',
          routeId: route5Id,
          name: 'Switchbacks Viewpoint',
          description: 'Dramatic views of Waterpocket Fold',
          latitude: 37.8700,
          longitude: -111.3800,
          elevation: 1850,
          type: 'viewpoint',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route5Id-rwp-003',
          routeId: route5Id,
          name: 'Capitol Reef Boundary',
          description: 'NPS land begins - no searching beyond',
          latitude: 37.8850,
          longitude: -111.3600,
          elevation: 1700,
          type: 'warning',
          properties: {},
        ),
      ],
      totalDistance: 10000,
      estimatedDuration: 2 * 3600,
      importedAt: now.subtract(const Duration(hours: 6)),
      sourceFormat: 'gpx',
      metadata: const {
        'difficulty': 'easy',
        'terrain': 'paved and gravel road',
        'vehicleAccess': true,
        'scenicDrive': true,
      },
      createdAt: now.subtract(const Duration(hours: 6)),
      updatedAt: now.subtract(const Duration(hours: 6)),
    );

    await _db.insertImportedRoute(route5);

    // Route 6: Gallatin Mining Trail - historic survey route in Wyoming
    // This route appears on the 1885 USGS Gallatin quadrangle for historical map screenshots
    const route6Id = 'demo-route-gallatin-mining-006';
    final route6Points = _generateRoutePoints(
      routeId: route6Id,
      startLat: 44.7800,
      startLon: -110.7800,
      pointCount: 75,
      isLoop: false,
    );

    final route6 = ImportedRoute(
      id: route6Id,
      name: 'Gallatin Mining Trail',
      description: 'Historic 1880s mining survey route through the Gallatin Range. Follows old pack trails documented on original USGS topographic maps.',
      points: route6Points,
      waypoints: const [
        RouteWaypoint(
          id: '$route6Id-rwp-001',
          routeId: route6Id,
          name: 'Survey Marker Start',
          description: 'Original USGS survey marker from 1885',
          latitude: 44.7800,
          longitude: -110.7800,
          elevation: 2400,
          type: 'start',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route6Id-rwp-002',
          routeId: route6Id,
          name: 'Old Mine Shaft',
          description: 'Abandoned gold prospect from 1880s mining boom',
          latitude: 44.7650,
          longitude: -110.7500,
          elevation: 2550,
          type: 'poi',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route6Id-rwp-003',
          routeId: route6Id,
          name: 'Pack Trail Junction',
          description: 'Historic trail intersection shown on 1885 topo',
          latitude: 44.7400,
          longitude: -110.7200,
          elevation: 2650,
          type: 'turn',
          properties: {},
        ),
        RouteWaypoint(
          id: '$route6Id-rwp-004',
          routeId: route6Id,
          name: 'Miner Cabin Ruins',
          description: 'Foundation remains of 1880s prospector cabin',
          latitude: 44.7200,
          longitude: -110.6900,
          elevation: 2750,
          type: 'poi',
          properties: {},
        ),
      ],
      totalDistance: 9500,
      estimatedDuration: 5 * 3600,
      importedAt: now.subtract(const Duration(days: 45)),
      sourceFormat: 'gpx',
      metadata: const {
        'difficulty': 'moderate',
        'terrain': 'mountain trail and old mining roads',
        'historicSites': 4,
        'historicalPeriod': '1880s mining era',
      },
      createdAt: now.subtract(const Duration(days: 45)),
      updatedAt: now.subtract(const Duration(days: 45)),
    );

    await _db.insertImportedRoute(route6);

    // Also create PlannedRoutes for the Routes tab (RouteLibraryPage)
    // The Routes tab displays PlannedRoutes, not ImportedRoutes
    final plannedRoutes = [
      _convertToPlannedRoute(route1),
      _convertToPlannedRoute(route2),
      _convertToPlannedRoute(route3),
      _convertToPlannedRoute(route4),
      _convertToPlannedRoute(route5),
      _convertToPlannedRoute(route6),
    ];

    for (final plannedRoute in plannedRoutes) {
      await routePlanningService.saveRoute(plannedRoute);
    }

    debugPrint('✅ Created demo routes (6 imported + 6 planned)');
  }

  /// Convert ImportedRoute to PlannedRoute for display in Routes tab
  PlannedRoute _convertToPlannedRoute(ImportedRoute importedRoute) {
    // Convert route points to LatLng
    final routePoints = importedRoute.points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    if (routePoints.isEmpty) {
      throw Exception('Imported route has no points');
    }

    final startPoint = routePoints.first;
    final endPoint = routePoints.last;

    // Convert intermediate waypoints
    final List<Waypoint> waypoints = [];
    for (int i = 0; i < importedRoute.waypoints.length; i++) {
      final rw = importedRoute.waypoints[i];
      waypoints.add(Waypoint(
        id: rw.id,
        sessionId: importedRoute.id,
        coordinates: LatLng(rw.latitude, rw.longitude),
        timestamp: DateTime.now(),
        type: WaypointType.custom,
        notes: rw.description,
      ));
    }

    // Create a single segment with all the route points
    final segment = RouteSegment(
      startPoint: startPoint,
      endPoint: endPoint,
      distance: importedRoute.totalDistance,
      duration: Duration(
        seconds: (importedRoute.estimatedDuration ??
                 (importedRoute.totalDistance / 1.4)).round(),
      ),
      type: RouteSegmentType.walking,
      waypoints: routePoints.sublist(1, routePoints.length - 1),
    );

    // Calculate difficulty based on distance
    int difficulty = 1;
    if (importedRoute.totalDistance > 5000) difficulty = 2;
    if (importedRoute.totalDistance > 10000) difficulty = 3;
    if (importedRoute.totalDistance > 20000) difficulty = 4;
    if (importedRoute.totalDistance > 30000) difficulty = 5;

    return PlannedRoute(
      id: importedRoute.id,
      name: importedRoute.name,
      description: importedRoute.description,
      startPoint: startPoint,
      endPoint: endPoint,
      segments: [segment],
      algorithm: RoutePlanningAlgorithm.straightLine,
      createdAt: importedRoute.createdAt,
      totalDistance: importedRoute.totalDistance,
      totalDuration: segment.duration,
      difficulty: difficulty,
      waypoints: waypoints,
    );
  }

  /// Generate realistic hiking trail breadcrumbs
  List<Breadcrumb> _generateHikingTrail({
    required String sessionId,
    required double startLat,
    required double startLon,
    required DateTime startTime,
    required int durationMinutes,
    required int pointCount,
    required TrailType trailType,
  }) {
    final breadcrumbs = <Breadcrumb>[];
    final intervalSeconds = (durationMinutes * 60) ~/ pointCount;

    double lat = startLat;
    double lon = startLon;
    double altitude = 1800.0 + _random.nextDouble() * 200;
    double heading = _random.nextDouble() * 360;

    for (int i = 0; i < pointCount; i++) {
      final timestamp = startTime.add(Duration(seconds: i * intervalSeconds));

      // Simulate realistic movement patterns
      final speed = _getRealisticSpeed(trailType, i, pointCount);
      final movement = _getMovementVector(trailType, heading, speed, intervalSeconds);

      lat += movement.latDelta;
      lon += movement.lonDelta;
      heading = movement.newHeading;
      altitude += movement.altitudeDelta;

      // Add some GPS noise
      final noisyLat = lat + (_random.nextDouble() - 0.5) * 0.00003;
      final noisyLon = lon + (_random.nextDouble() - 0.5) * 0.00003;

      breadcrumbs.add(Breadcrumb(
        id: '$sessionId-bc-${i.toString().padLeft(5, '0')}',
        sessionId: sessionId,
        coordinates: LatLng(noisyLat, noisyLon),
        altitude: altitude,
        accuracy: 3.0 + _random.nextDouble() * 8.0, // 3-11m accuracy
        speed: speed,
        heading: heading,
        timestamp: timestamp,
      ));
    }

    return breadcrumbs;
  }

  /// Get realistic walking speed based on trail type and position
  double _getRealisticSpeed(TrailType type, int index, int total) {
    // Base speed in m/s
    double baseSpeed;
    switch (type) {
      case TrailType.exploration:
        baseSpeed = 0.8; // Slow, careful exploration
      case TrailType.prospecting:
        baseSpeed = 0.5; // Very slow, stopping often
      case TrailType.canyon:
        baseSpeed = 1.0; // Moderate hiking pace
    }

    // Add variation - slower at start, middle rest, slower at end
    final progress = index / total;
    double modifier = 1.0;

    if (progress < 0.1) {
      modifier = 0.7; // Starting out
    } else if (progress > 0.4 && progress < 0.6) {
      modifier = 0.6; // Mid-trip slowdown/rest
    } else if (progress > 0.9) {
      modifier = 0.8; // Tired near end
    }

    // Random variation
    modifier *= 0.8 + _random.nextDouble() * 0.4;

    // Occasional stops
    if (_random.nextDouble() < 0.05) {
      return 0.0;
    }

    return baseSpeed * modifier;
  }

  /// Calculate movement vector for next point
  _MovementVector _getMovementVector(
    TrailType type,
    double currentHeading,
    double speed,
    int intervalSeconds,
  ) {
    // Distance traveled in this interval (meters)
    final distance = speed * intervalSeconds;

    // Heading changes based on trail type
    double headingChange;
    switch (type) {
      case TrailType.exploration:
        // Wandering pattern - larger heading changes
        headingChange = (_random.nextDouble() - 0.5) * 60;
      case TrailType.prospecting:
        // Following creek/terrain - smoother curves
        headingChange = (_random.nextDouble() - 0.5) * 30;
      case TrailType.canyon:
        // Canyon walls constrain movement - occasional sharp turns
        if (_random.nextDouble() < 0.1) {
          headingChange = (_random.nextDouble() - 0.5) * 90;
        } else {
          headingChange = (_random.nextDouble() - 0.5) * 20;
        }
    }

    final newHeading = (currentHeading + headingChange) % 360;
    final headingRad = newHeading * pi / 180;

    // Convert distance to lat/lon delta (approximate)
    // 1 degree lat ≈ 111km, 1 degree lon ≈ 85km at SD latitude
    final latDelta = (distance * cos(headingRad)) / 111000;
    final lonDelta = (distance * sin(headingRad)) / 85000;

    // Altitude changes
    double altitudeDelta;
    switch (type) {
      case TrailType.exploration:
        altitudeDelta = (_random.nextDouble() - 0.5) * 3;
      case TrailType.prospecting:
        altitudeDelta = (_random.nextDouble() - 0.6) * 2; // Tends downward
      case TrailType.canyon:
        altitudeDelta = (_random.nextDouble() - 0.5) * 4;
    }

    return _MovementVector(
      latDelta: latDelta,
      lonDelta: lonDelta,
      newHeading: newHeading,
      altitudeDelta: altitudeDelta,
    );
  }

  /// Generate route points for imported routes
  List<RoutePoint> _generateRoutePoints({
    required String routeId,
    required double startLat,
    required double startLon,
    required int pointCount,
    required bool isLoop,
  }) {
    final points = <RoutePoint>[];
    double lat = startLat;
    double lon = startLon;
    double elevation = 1750.0;
    double heading = _random.nextDouble() * 360;

    for (int i = 0; i < pointCount; i++) {
      // For loops, curve back towards start in second half
      if (isLoop && i > pointCount ~/ 2) {
        final targetLat = startLat;
        final targetLon = startLon;
        // Use progress to gradually increase curve-back strength
        final progress = (i - pointCount ~/ 2) / (pointCount ~/ 2);
        final curveStrength = 0.05 + progress * 0.15; // 5% to 20%
        lat = lat + (targetLat - lat) * curveStrength;
        lon = lon + (targetLon - lon) * curveStrength;
        heading = atan2(targetLon - lon, targetLat - lat) * 180 / pi;
      } else {
        heading += (_random.nextDouble() - 0.5) * 30;
        final headingRad = heading * pi / 180;
        lat += cos(headingRad) * 0.001;
        lon += sin(headingRad) * 0.001;
      }

      elevation += (_random.nextDouble() - 0.5) * 10;

      points.add(RoutePoint(
        id: '$routeId-pt-${i.toString().padLeft(4, '0')}',
        routeId: routeId,
        latitude: lat,
        longitude: lon,
        elevation: elevation,
        sequenceNumber: i,
      ));
    }

    return points;
  }

  /// Calculate total distance from breadcrumbs
  double _calculateTotalDistance(List<Breadcrumb> breadcrumbs) {
    if (breadcrumbs.length < 2) return 0;

    double total = 0;
    for (int i = 1; i < breadcrumbs.length; i++) {
      total += breadcrumbs[i - 1].distanceTo(breadcrumbs[i]);
    }
    return total;
  }

  /// Create demo photos for waypoints to show in session detail
  Future<void> createDemoPhotos() async {
    debugPrint('📷 Creating demo photos...');

    // Get the app's documents directory
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory photosDir = Directory('${appDir.path}/demo_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    // Load real session photos from Flutter assets (fastlane/btme/)
    await _loadSessionPhotosFromAssets(photosDir.path);

    // Define photo scenes for different waypoints (fallback generated photos)
    final List<_DemoPhotoConfig> photoConfigs = [
      // Madison River session photos
      _DemoPhotoConfig(
        waypointId: 'demo-session-madison-002-wp-001',
        name: 'river_gravel_bar',
        skyColor: img.ColorRgb8(135, 206, 250), // Light sky blue
        groundColor: img.ColorRgb8(192, 192, 192), // Silver (gravel)
        accentColor: img.ColorRgb8(70, 130, 180), // Steel blue (water)
      ),
      _DemoPhotoConfig(
        waypointId: 'demo-session-madison-002-wp-003',
        name: 'eagle_nest',
        skyColor: img.ColorRgb8(100, 149, 237), // Cornflower blue
        groundColor: img.ColorRgb8(34, 139, 34), // Forest green
        accentColor: img.ColorRgb8(139, 69, 19), // Saddle brown (tree)
      ),
      // Hebgen Lake session photos
      _DemoPhotoConfig(
        waypointId: 'demo-session-hebgen-003-wp-001',
        name: 'earthquake_scarp',
        skyColor: img.ColorRgb8(135, 206, 235), // Sky blue
        groundColor: img.ColorRgb8(160, 82, 45), // Sienna (earth)
        accentColor: img.ColorRgb8(105, 105, 105), // Dim gray (rocks)
      ),
    ];

    for (final config in photoConfigs) {
      await _createDemoPhoto(photosDir.path, config);
    }

    debugPrint('✅ Created demo photos');
  }

  /// Load real session photos from Flutter assets for Gallatin session
  Future<void> _loadSessionPhotosFromAssets(String photosDir) async {
    const sessionId = 'demo-session-gallatin-001';

    // Session photo 1 - associated with Old Logging Camp waypoint
    try {
      final session1Data = await rootBundle.load('fastlane/btme/session1.JPG');
      final destPath = '$photosDir/session1.jpg';
      final bytes = session1Data.buffer.asUint8List();
      await File(destPath).writeAsBytes(bytes);

      // Create thumbnail
      final image = img.decodeImage(bytes);
      if (image != null) {
        final thumbnail = img.copyResize(image, width: 200, height: 150);
        final thumbPath = '$photosDir/session1_thumb.jpg';
        await File(thumbPath).writeAsBytes(img.encodeJpg(thumbnail, quality: 75));

        // Insert photo waypoint into database
        final photoWaypoint = PhotoWaypoint(
          id: 'demo-photo-session1',
          waypointId: '$sessionId-wp-002', // Old Logging Camp
          filePath: destPath,
          thumbnailPath: thumbPath,
          createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 13)),
          fileSize: bytes.length,
          width: image.width,
          height: image.height,
          photoOrientation: image.width > image.height ? 'landscape' : 'portrait',
        );

        final Database db = await _db.database;
        await db.insert(
          'photo_waypoints',
          photoWaypoint.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('  📸 Loaded session1.JPG for Old Logging Camp');
      }
    } catch (e) {
      debugPrint('  ⚠️ Could not load session1.JPG: $e');
    }

    // Session photo 2 - associated with Prospector Cabin waypoint
    try {
      final session2Data = await rootBundle.load('fastlane/btme/session2.JPG');
      final destPath = '$photosDir/session2.jpg';
      final bytes = session2Data.buffer.asUint8List();
      await File(destPath).writeAsBytes(bytes);

      // Create thumbnail
      final image = img.decodeImage(bytes);
      if (image != null) {
        final thumbnail = img.copyResize(image, width: 200, height: 150);
        final thumbPath = '$photosDir/session2_thumb.jpg';
        await File(thumbPath).writeAsBytes(img.encodeJpg(thumbnail, quality: 75));

        // Insert photo waypoint into database
        final photoWaypoint = PhotoWaypoint(
          id: 'demo-photo-session2',
          waypointId: '$sessionId-wp-005', // Prospector Cabin Ruins
          filePath: destPath,
          thumbnailPath: thumbPath,
          createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 10)),
          fileSize: bytes.length,
          width: image.width,
          height: image.height,
          photoOrientation: image.width > image.height ? 'landscape' : 'portrait',
        );

        final Database db = await _db.database;
        await db.insert(
          'photo_waypoints',
          photoWaypoint.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('  📸 Loaded session2.JPG for Prospector Cabin');
      }
    } catch (e) {
      debugPrint('  ⚠️ Could not load session2.JPG: $e');
    }
  }

  /// Create a single demo photo with landscape gradient
  Future<void> _createDemoPhoto(String dirPath, _DemoPhotoConfig config) async {
    // Create a landscape-oriented image (800x600)
    final image = img.Image(width: 800, height: 600);

    // Draw sky gradient (top half)
    for (int y = 0; y < 300; y++) {
      final ratio = y / 300.0;
      final r = (config.skyColor.r * (1 - ratio * 0.3)).round();
      final g = (config.skyColor.g * (1 - ratio * 0.2)).round();
      final b = (config.skyColor.b * (1 - ratio * 0.1)).round();
      for (int x = 0; x < 800; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Draw ground/terrain (bottom half)
    for (int y = 300; y < 600; y++) {
      final ratio = (y - 300) / 300.0;
      final r = (config.groundColor.r * (1 - ratio * 0.3)).round();
      final g = (config.groundColor.g * (1 - ratio * 0.3)).round();
      final b = (config.groundColor.b * (1 - ratio * 0.3)).round();
      for (int x = 0; x < 800; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Add some accent elements (simple shapes to simulate features)
    // Draw a triangular mountain/hill shape
    for (int y = 200; y < 350; y++) {
      final width = ((350 - y) * 2).clamp(0, 400);
      final startX = 400 - width ~/ 2;
      for (int x = startX; x < startX + width && x < 800; x++) {
        if (x >= 0) {
          image.setPixelRgb(
            x,
            y,
            config.accentColor.r.toInt(),
            config.accentColor.g.toInt(),
            config.accentColor.b.toInt(),
          );
        }
      }
    }

    // Save the image
    final filePath = '$dirPath/${config.name}.jpg';
    final file = File(filePath);
    await file.writeAsBytes(img.encodeJpg(image, quality: 85));

    // Create thumbnail (200x150)
    final thumbnail = img.copyResize(image, width: 200, height: 150);
    final thumbnailPath = '$dirPath/${config.name}_thumb.jpg';
    final thumbFile = File(thumbnailPath);
    await thumbFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 75));

    // Insert photo waypoint into database
    final photoWaypoint = PhotoWaypoint(
      id: 'demo-photo-${config.name}',
      waypointId: config.waypointId,
      filePath: filePath,
      thumbnailPath: thumbnailPath,
      createdAt: DateTime.now().subtract(Duration(days: _random.nextInt(14))),
      fileSize: await file.length(),
      width: 800,
      height: 600,
      photoOrientation: 'landscape',
    );

    // Insert into database
    final Database db = await _db.database;
    await db.insert(
      'photo_waypoints',
      photoWaypoint.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('  📸 Created photo: ${config.name}');
  }

  /// Create demo treasure hunts with documents, notes, and locations
  /// Create demo journal entries showcasing the Field Journal feature
  ///
  /// Creates entries that span different types, moods, and relationships:
  /// - Entries linked to sessions (field notes during tracking)
  /// - Entries linked to hunts (research theories)
  /// - Standalone entries (general thoughts)
  /// - Highlighted and pinned entries
  Future<void> _createDemoJournalEntries() async {
    debugPrint('📓 Creating demo journal entries...');

    final now = DateTime.now();

    // Entry 1: Highlighted find during Escalante session - PINNED
    final entry1 = JournalEntry(
      id: 'demo-journal-001',
      title: 'Found the hidden canyon!',
      content:
          'After hours of searching, finally found a narrow slot canyon that matches the poem clues. '
          'The rock formations here are incredible - red sandstone walls tower above, '
          'and there\'s a small alcove that could be "where secrets of the past still hold." '
          'Need to come back with better gear to explore further.',
      entryType: JournalEntryType.find,
      sessionId: 'demo-session-escalante-001',
      huntId: 'demo-hunt-beyond-maps-001',
      latitude: 37.7856,
      longitude: -111.4012,
      locationName: 'Escalante Slot Canyon',
      timestamp: now.subtract(const Duration(days: 3, hours: 10)),
      mood: JournalMood.excited,
      weatherNotes: 'Clear skies, 72°F, light breeze',
      tags: const ['discovery', 'slot-canyon', 'btme'],
      isPinned: true,
      isHighlight: true,
      createdAt: now.subtract(const Duration(days: 3, hours: 10)),
    );
    await _db.insertJournalEntry(entry1);

    // Entry 2: Theory about the poem clues - linked to hunt only
    final entry2 = JournalEntry(
      id: 'demo-journal-002',
      title: 'Theory: "ursa east" interpretation',
      content:
          'Been thinking about the line "In ursa east his realm awaits" - '
          'I believe this refers to Bear Creek canyon east of Escalante. '
          'The topographic maps show a distinctive formation that could be '
          'the "ancient gates" mentioned in the poem.\n\n'
          'Key observations:\n'
          '• Bear Creek flows eastward through BLM land\n'
          "• There's a natural arch formation at the canyon entrance\n"
          '• Elevation matches the "foot of three at twenty degree" clue\n\n'
          'Planning a session next week to investigate.',
      entryType: JournalEntryType.theory,
      huntId: 'demo-hunt-beyond-maps-001',
      timestamp: now.subtract(const Duration(days: 5, hours: 14)),
      mood: JournalMood.curious,
      tags: const ['theory', 'btme', 'research'],
      isHighlight: true,
      createdAt: now.subtract(const Duration(days: 5, hours: 14)),
    );
    await _db.insertJournalEntry(entry2);

    // Entry 3: Observation during Hole-in-the-Rock session
    final entry3 = JournalEntry(
      id: 'demo-journal-003',
      title: 'Pioneer inscriptions discovery',
      content:
          'Incredible day on the Hole-in-the-Rock trail! Found a panel of '
          'pioneer inscriptions from the 1879 expedition. Names and dates '
          'carved into the sandstone, still clearly legible after 145 years.\n\n'
          'This area is rich with history - the wagon ruts are still visible '
          'in the rock. Makes me wonder what other secrets this landscape holds.',
      entryType: JournalEntryType.observation,
      sessionId: 'demo-session-hole-rock-002',
      latitude: 37.6521,
      longitude: -111.4200,
      locationName: 'Pioneer Inscription Panel',
      timestamp: now.subtract(const Duration(days: 7, hours: 11)),
      mood: JournalMood.satisfied,
      weatherNotes: 'Sunny, warm afternoon',
      tags: const ['history', 'pioneers', 'inscriptions'],
      createdAt: now.subtract(const Duration(days: 7, hours: 11)),
    );
    await _db.insertJournalEntry(entry3);

    // Entry 4: Standalone note - trip preparation
    final entry4 = JournalEntry(
      id: 'demo-journal-004',
      title: 'Gear checklist for next expedition',
      content:
          'Prep notes for the upcoming multi-day search:\n\n'
          '☑ GPS device + extra batteries\n'
          '☑ Topographic maps (printed)\n'
          '☑ Water (3L minimum)\n'
          '☑ First aid kit\n'
          '☑ Headlamp\n'
          '☐ Rope for scrambling sections\n'
          '☐ Camera with macro lens\n\n'
          'Need to check BLM permit requirements for overnight camping.',
      entryType: JournalEntryType.note,
      timestamp: now.subtract(const Duration(days: 1, hours: 20)),
      mood: JournalMood.determined,
      createdAt: now.subtract(const Duration(days: 1, hours: 20)),
    );
    await _db.insertJournalEntry(entry4);

    // Entry 5: Field note from Devils Garden session
    final entry5 = JournalEntry(
      id: 'demo-journal-005',
      content:
          'The hoodoos at Devils Garden are otherworldly. Spent an hour just '
          'photographing Metate Arch from different angles. The late afternoon '
          'light creates amazing shadows on the rock formations.\n\n'
          'This would make a great location for a future hunt clue!',
      entryType: JournalEntryType.note,
      sessionId: 'demo-session-devils-003',
      latitude: 37.8156,
      longitude: -111.6267,
      locationName: 'Devils Garden, Escalante',
      timestamp: now.subtract(const Duration(days: 14, hours: 9)),
      mood: JournalMood.peaceful,
      weatherNotes: 'Perfect weather, golden hour light',
      tags: const ['photography', 'hoodoos', 'arches'],
      createdAt: now.subtract(const Duration(days: 14, hours: 9)),
    );
    await _db.insertJournalEntry(entry5);

    // Entry 6: Recent note during active session
    final entry6 = JournalEntry(
      id: 'demo-journal-006',
      title: 'Interesting rock formation',
      content:
          'Just spotted an unusual rock formation in this side canyon. '
          'The shape reminds me of the "double arcs on granite bold" line '
          'from the poem. Marking this spot for further investigation.',
      entryType: JournalEntryType.observation,
      sessionId: 'demo-session-active-004',
      latitude: 37.8190,
      longitude: -111.4100,
      locationName: 'Calf Creek Side Canyon',
      timestamp: now.subtract(const Duration(hours: 1, minutes: 30)),
      mood: JournalMood.curious,
      tags: const ['formation', 'potential-clue'],
      createdAt: now.subtract(const Duration(hours: 1, minutes: 30)),
    );
    await _db.insertJournalEntry(entry6);

    // Entry 7: Highlight from a past discovery
    final entry7 = JournalEntry(
      id: 'demo-journal-007',
      title: 'The moment it all clicked',
      content:
          "Had an epiphany today while reviewing my notes. The poem's reference "
          'to "wisdom waits in shadowed sight" suddenly makes sense - '
          "it's not about physical shadows, but about looking at the landscape "
          'from a different perspective.\n\n'
          'The key is in the topographic maps. When you trace the contour lines, '
          "they reveal a pattern that matches the poem's description perfectly. "
          "This changes everything about where I've been searching!",
      entryType: JournalEntryType.highlight,
      huntId: 'demo-hunt-beyond-maps-001',
      timestamp: now.subtract(const Duration(days: 10, hours: 16)),
      mood: JournalMood.excited,
      isHighlight: true,
      createdAt: now.subtract(const Duration(days: 10, hours: 16)),
    );
    await _db.insertJournalEntry(entry7);

    // Entry 8: Location-only entry (interesting spot found on map)
    final entry8 = JournalEntry(
      id: 'demo-journal-008',
      title: 'Potential search area - Box Canyon',
      content:
          "Marked this location after studying satellite imagery. There's a "
          "box canyon here that's not well-documented. Access looks challenging "
          'but doable from the northeast ridge. BLM land confirmed.',
      entryType: JournalEntryType.note,
      latitude: 37.7920,
      longitude: -111.4500,
      locationName: 'Box Canyon (unmarked)',
      timestamp: now.subtract(const Duration(days: 2, hours: 15)),
      mood: JournalMood.determined,
      tags: const ['research', 'satellite', 'access-route'],
      createdAt: now.subtract(const Duration(days: 2, hours: 15)),
    );
    await _db.insertJournalEntry(entry8);

    debugPrint('✅ Created 8 demo journal entries');
  }

  Future<void> _createDemoHunts() async {
    debugPrint('🔍 Creating demo treasure hunts...');

    final now = DateTime.now();
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory huntsDir = Directory('${appDir.path}/demo_hunts');
    if (!await huntsDir.exists()) {
      await huntsDir.create(recursive: true);
    }

    // Hunt images are loaded from Flutter assets (fastlane/btme/)
    debugPrint('📁 Loading hunt images from Flutter assets...');

    // Hunt 1: Beyond the Maps Edge - Active hunt with lots of documents
    const hunt1Id = 'demo-hunt-beyond-maps-001';
    final hunt1 = TreasureHunt(
      id: hunt1Id,
      name: 'Beyond the Maps Edge',
      author: 'Justin Posey',
      description: 'A treasure hunt adventure set in the American West. Follow the clues through the canyonlands of Utah.',
      tags: const ['Utah', 'Grand Staircase', 'Adventure', 'Active'],
      createdAt: now.subtract(const Duration(days: 45)),
      startedAt: now.subtract(const Duration(days: 40)),
    );
    await _db.insertTreasureHunt(hunt1);

    // Create/copy cover image for hunt 1 from Flutter assets
    String? coverImagePath;
    try {
      // Load treasure.jpeg from Flutter assets bundle
      final assetData = await rootBundle.load('fastlane/btme/treasure.jpeg');
      final destPath = '${huntsDir.path}/beyond_maps_cover.jpg';
      await File(destPath).writeAsBytes(assetData.buffer.asUint8List());
      coverImagePath = destPath;
      debugPrint('  📷 Loaded treasure.jpeg from assets as cover');
    } catch (e) {
      debugPrint('  ⚠️ Could not load treasure.jpeg from assets: $e');
      // Generate fallback cover image
      await _createHuntCoverImage(huntsDir.path, hunt1Id, 'beyond_maps_cover',
        topColor: img.ColorRgb8(139, 90, 43),
        bottomColor: img.ColorRgb8(34, 139, 34),
      );
      coverImagePath = '${huntsDir.path}/beyond_maps_cover.jpg';
    }

    // Update hunt with cover image path
    final hunt1Updated = hunt1.copyWith(coverImagePath: coverImagePath);
    await _db.updateTreasureHunt(hunt1Updated);

    // Add the poem as the first document
    const poemContent = '''
Beyond the Map's Edge

Can you find what lives in time,
Flowing through each measured rhyme?
Wisdom waits in shadowed sight—
For those who read these words just right.

As hope surges, clear and bright,
Walk near waters' silent flight.
Round the bend, past the Hole,
I wait for you to cast your pole.

In ursa east his realm awaits;
His bride stands guard at ancient gates.
Her foot of three at twenty degree,
Return her face to find the place.

Double arcs on granite bold,
Where secrets of the past still hold.
Beyond the reach of time's swift race,
Wonder guards this sacred space.

Truth rests not in clever minds,
Not in tangled, twisted finds.
Like a river's steady flow—
What you seek, you already know.''';

    await _db.insertHuntDocument(HuntDocument(
      id: '$hunt1Id-doc-poem',
      huntId: hunt1Id,
      name: 'The Poem',
      type: HuntDocumentType.note,
      content: poemContent,
      createdAt: now.subtract(const Duration(days: 45)),
    ));

    // Add research notes
    await _db.insertHuntDocument(HuntDocument(
      id: '$hunt1Id-doc-001',
      huntId: hunt1Id,
      name: 'Research Notes - Chapter 1',
      type: HuntDocumentType.note,
      content: 'Initial analysis of the poem:\n\n"In ursa east his realm awaits" could refer to:\n- Bear-related locations in southern Utah\n- Escalante River canyons\n- Capitol Reef boundary area\n\nNeed to investigate further the BLM land boundaries.',
      createdAt: now.subtract(const Duration(days: 38)),
    ));

    await _db.insertHuntDocument(HuntDocument(
      id: '$hunt1Id-doc-002',
      huntId: hunt1Id,
      name: 'Topographic Analysis',
      type: HuntDocumentType.note,
      content: 'Elevation analysis:\n- Starting point ~5,700 ft (Escalante town)\n- Canyon descent to ~5,200 ft\n- Slot canyon areas promising\n\nPossible routes identified on USGS quad maps. BLM land allows searching.',
      createdAt: now.subtract(const Duration(days: 30)),
    ));

    await _db.insertHuntDocument(HuntDocument(
      id: '$hunt1Id-doc-003',
      huntId: hunt1Id,
      name: 'Historical Mining Claims',
      type: HuntDocumentType.link,
      url: 'https://glorecords.blm.gov',
      createdAt: now.subtract(const Duration(days: 25)),
    ));

    // Add image documents from Flutter assets
    bool loadedMapImage = false;
    bool loadedBookImage = false;

    // Load map.jpeg from assets
    try {
      final mapData = await rootBundle.load('fastlane/btme/map.jpeg');
      final destPath = '${huntsDir.path}/search_area_map.jpg';
      final mapBytes = mapData.buffer.asUint8List();
      await File(destPath).writeAsBytes(mapBytes);
      // Create thumbnail
      final mapImage = img.decodeImage(mapBytes);
      if (mapImage != null) {
        final thumbnail = img.copyResize(mapImage, width: 200, height: 150);
        final thumbPath = '${huntsDir.path}/search_area_map_thumb.jpg';
        await File(thumbPath).writeAsBytes(img.encodeJpg(thumbnail, quality: 75));
      }
      await _db.insertHuntDocument(HuntDocument(
        id: '$hunt1Id-img-map',
        huntId: hunt1Id,
        name: 'Search Area Map',
        type: HuntDocumentType.image,
        filePath: destPath,
        thumbnailPath: '${huntsDir.path}/search_area_map_thumb.jpg',
        createdAt: now.subtract(const Duration(days: 20)),
      ));
      loadedMapImage = true;
      debugPrint('  📷 Loaded map.jpeg from assets');
    } catch (e) {
      debugPrint('  ⚠️ Could not load map.jpeg from assets: $e');
    }

    // Load book_cover.jpeg from assets
    try {
      final bookData = await rootBundle.load('fastlane/btme/book_cover.jpeg');
      final destPath = '${huntsDir.path}/book_cover.jpg';
      final bookBytes = bookData.buffer.asUint8List();
      await File(destPath).writeAsBytes(bookBytes);
      // Create thumbnail
      final bookImage = img.decodeImage(bookBytes);
      if (bookImage != null) {
        final thumbnail = img.copyResize(bookImage, width: 200, height: 150);
        final thumbPath = '${huntsDir.path}/book_cover_thumb.jpg';
        await File(thumbPath).writeAsBytes(img.encodeJpg(thumbnail, quality: 75));
      }
      await _db.insertHuntDocument(HuntDocument(
        id: '$hunt1Id-img-book',
        huntId: hunt1Id,
        name: 'Book Cover Reference',
        type: HuntDocumentType.image,
        filePath: destPath,
        thumbnailPath: '${huntsDir.path}/book_cover_thumb.jpg',
        createdAt: now.subtract(const Duration(days: 15)),
      ));
      loadedBookImage = true;
      debugPrint('  📷 Loaded book_cover.jpeg from assets');
    } catch (e) {
      debugPrint('  ⚠️ Could not load book_cover.jpeg from assets: $e');
    }

    // Generate placeholder if neither real image loaded
    if (!loadedMapImage && !loadedBookImage) {
      await _createHuntDocumentImage(huntsDir.path, '$hunt1Id-img-001', 'clue_photo_1',
        skyColor: img.ColorRgb8(135, 206, 235),
        groundColor: img.ColorRgb8(139, 69, 19),
        accentColor: img.ColorRgb8(105, 105, 105),
      );
      await _db.insertHuntDocument(HuntDocument(
        id: '$hunt1Id-img-001',
        huntId: hunt1Id,
        name: 'Potential Blaze Location',
        type: HuntDocumentType.image,
        filePath: '${huntsDir.path}/clue_photo_1.jpg',
        thumbnailPath: '${huntsDir.path}/clue_photo_1_thumb.jpg',
        createdAt: now.subtract(const Duration(days: 12)),
      ));
    }

    // Add locations to hunt 1 - all in Grand Staircase-Escalante area
    await _db.insertHuntLocation(HuntLocation(
      id: '$hunt1Id-loc-001',
      huntId: hunt1Id,
      name: 'Escalante Canyon Area',
      latitude: 37.7700,
      longitude: -111.5800,
      notes: 'Primary search area based on poem analysis. BLM land - accessible.',
      status: HuntLocationStatus.searched,
      createdAt: now.subtract(const Duration(days: 20)),
      searchedAt: now.subtract(const Duration(days: 18)),
    ));

    await _db.insertHuntLocation(HuntLocation(
      id: '$hunt1Id-loc-002',
      huntId: hunt1Id,
      name: 'Hole-in-the-Rock Road',
      latitude: 37.6500,
      longitude: -111.4200,
      notes: 'Secondary target. Good match for "Round the bend, past the Hole" clue.',
      createdAt: now.subtract(const Duration(days: 10)),
    ));

    await _db.insertHuntLocation(HuntLocation(
      id: '$hunt1Id-loc-003',
      huntId: hunt1Id,
      name: 'Capitol Reef NPS Border',
      latitude: 37.8500,
      longitude: -111.2500,
      notes: 'NPS land - cannot search here. Eliminated due to land restrictions.',
      status: HuntLocationStatus.eliminated,
      createdAt: now.subtract(const Duration(days: 35)),
    ));

    // Hunt 2: Lost Rhodes Mine - Famous Utah treasure legend
    const hunt2Id = 'demo-hunt-lost-rhodes-002';
    final hunt2 = TreasureHunt(
      id: hunt2Id,
      name: 'Lost Rhodes Mine',
      author: 'Historical Records',
      description: 'The legendary Lost Rhodes Mine, said to contain vast quantities of Spanish gold in the Uinta Mountains. A Utah treasure mystery since the 1850s.',
      tags: const ['Utah', 'Mining', 'Legend', 'Historical'],
      createdAt: now.subtract(const Duration(days: 180)),
      startedAt: now.subtract(const Duration(days: 175)),
    );
    await _db.insertTreasureHunt(hunt2);

    // Create cover image for hunt 2
    await _createHuntCoverImage(huntsDir.path, hunt2Id, 'rhodes_cover',
      topColor: img.ColorRgb8(218, 165, 32), // Gold
      bottomColor: img.ColorRgb8(139, 90, 43), // Brown mountain
    );
    final hunt2Updated = hunt2.copyWith(
      coverImagePath: '${huntsDir.path}/rhodes_cover.jpg',
    );
    await _db.updateTreasureHunt(hunt2Updated);

    await _db.insertHuntDocument(HuntDocument(
      id: '$hunt2Id-doc-001',
      huntId: hunt2Id,
      name: 'Historical Account',
      type: HuntDocumentType.note,
      content: 'Thomas Rhodes befriended the Ute tribe in the 1850s. According to legend:\n- Utes showed him a secret gold source in the Uintas\n- Spanish conquistadors had mined it centuries before\n- Location was carefully guarded by the tribe\n\nMultiple expeditions have searched since the 1870s.',
      createdAt: now.subtract(const Duration(days: 65)),
    ));

    await _db.insertHuntDocument(HuntDocument(
      id: '$hunt2Id-doc-002',
      huntId: hunt2Id,
      name: 'Topographic Research',
      type: HuntDocumentType.note,
      content: 'Key areas of interest:\n- Rock Creek drainage\n- Moon Lake region\n- Upper Uinta wilderness\n\nMust obtain permits for Uinta-Wasatch-Cache NF areas.',
      createdAt: now.subtract(const Duration(days: 60)),
    ));

    await _db.insertHuntLocation(HuntLocation(
      id: '$hunt2Id-loc-001',
      huntId: hunt2Id,
      name: 'Rock Creek Area',
      latitude: 40.5200,
      longitude: -110.6800,
      notes: 'Traditional search area based on Thomas Rhodes diary. National Forest land.',
      createdAt: now.subtract(const Duration(days: 50)),
    ));

    // Hunt 3: Butch Cassidy Cache - Utah outlaw treasure legend
    const hunt3Id = 'demo-hunt-cassidy-003';
    final hunt3 = TreasureHunt(
      id: hunt3Id,
      name: 'Butch Cassidy Cache',
      description: 'Legend says Butch Cassidy and the Wild Bunch hid loot from bank robberies near their Robbers Roost hideout in southeastern Utah.',
      status: HuntStatus.paused,
      tags: const ['Utah', 'Outlaw', 'History', 'Legend'],
      createdAt: now.subtract(const Duration(days: 90)),
      startedAt: now.subtract(const Duration(days: 85)),
    );
    await _db.insertTreasureHunt(hunt3);

    // Create cover image for hunt 3
    await _createHuntCoverImage(huntsDir.path, hunt3Id, 'cassidy_cover',
      topColor: img.ColorRgb8(139, 69, 19), // Saddle brown
      bottomColor: img.ColorRgb8(205, 133, 63), // Peru (desert)
    );
    final hunt3Updated = hunt3.copyWith(
      coverImagePath: '${huntsDir.path}/cassidy_cover.jpg',
    );
    await _db.updateTreasureHunt(hunt3Updated);

    await _db.insertHuntDocument(HuntDocument(
      id: '$hunt3Id-doc-001',
      huntId: hunt3Id,
      name: 'Historical Research',
      type: HuntDocumentType.note,
      content: 'Butch Cassidy (Robert LeRoy Parker) and the Wild Bunch:\n- Used Robbers Roost as hideout 1890s-1900s\n- Multiple bank and train robberies in region\n- Loot allegedly hidden in remote canyons\n\nPaused: Need to verify BLM access to Robbers Roost area.',
      createdAt: now.subtract(const Duration(days: 80)),
    ));

    await _db.insertHuntDocument(HuntDocument(
      id: '$hunt3Id-doc-002',
      huntId: hunt3Id,
      name: 'Newspaper Clippings',
      type: HuntDocumentType.note,
      content: '1897 Salt Lake Tribune: "Wild Bunch Strikes Again"\n1899 Emery County Progress: "Bandits Escape into Canyonlands"\n\nReferences suggest they knew the terrain intimately and had multiple cache sites.',
      createdAt: now.subtract(const Duration(days: 75)),
    ));

    await _db.insertHuntLocation(HuntLocation(
      id: '$hunt3Id-loc-001',
      huntId: hunt3Id,
      name: 'Robbers Roost Canyon',
      latitude: 38.4500,
      longitude: -110.3000,
      notes: 'Main hideout area. Difficult access, need 4WD and hiking.',
      status: HuntLocationStatus.searched,
      createdAt: now.subtract(const Duration(days: 82)),
      searchedAt: now.subtract(const Duration(days: 80)),
    ));

    await _db.insertHuntLocation(HuntLocation(
      id: '$hunt3Id-loc-002',
      huntId: hunt3Id,
      name: 'Horseshoe Canyon',
      latitude: 38.4600,
      longitude: -110.2000,
      notes: 'Secondary hideout mentioned in old accounts. BLM land accessible.',
      createdAt: now.subtract(const Duration(days: 75)),
    ));

    debugPrint('✅ Created 3 demo treasure hunts');
  }

  /// Create a cover image for a hunt
  Future<void> _createHuntCoverImage(
    String dirPath,
    String huntId,
    String fileName, {
    required img.ColorRgb8 topColor,
    required img.ColorRgb8 bottomColor,
  }) async {
    // Create a gradient image (600x400)
    final image = img.Image(width: 600, height: 400);

    // Draw gradient
    for (int y = 0; y < 400; y++) {
      final ratio = y / 400.0;
      final r = (topColor.r * (1 - ratio) + bottomColor.r * ratio).round();
      final g = (topColor.g * (1 - ratio) + bottomColor.g * ratio).round();
      final b = (topColor.b * (1 - ratio) + bottomColor.b * ratio).round();
      for (int x = 0; x < 600; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Add a subtle "X marks the spot" pattern
    const centerX = 300;
    const centerY = 200;
    final xColor = img.ColorRgb8(218, 175, 55); // Gold
    for (int i = -30; i <= 30; i++) {
      // Draw X
      if (centerX + i >= 0 && centerX + i < 600 && centerY + i >= 0 && centerY + i < 400) {
        image.setPixelRgb(centerX + i, centerY + i, xColor.r.toInt(), xColor.g.toInt(), xColor.b.toInt());
        image.setPixelRgb(centerX + i + 1, centerY + i, xColor.r.toInt(), xColor.g.toInt(), xColor.b.toInt());
      }
      if (centerX - i >= 0 && centerX - i < 600 && centerY + i >= 0 && centerY + i < 400) {
        image.setPixelRgb(centerX - i, centerY + i, xColor.r.toInt(), xColor.g.toInt(), xColor.b.toInt());
        image.setPixelRgb(centerX - i - 1, centerY + i, xColor.r.toInt(), xColor.g.toInt(), xColor.b.toInt());
      }
    }

    // Save the image
    final filePath = '$dirPath/$fileName.jpg';
    final file = File(filePath);
    await file.writeAsBytes(img.encodeJpg(image, quality: 85));
  }

  /// Create a document image for a hunt
  Future<void> _createHuntDocumentImage(
    String dirPath,
    String docId,
    String fileName, {
    required img.ColorRgb8 skyColor,
    required img.ColorRgb8 groundColor,
    required img.ColorRgb8 accentColor,
  }) async {
    // Create a landscape-oriented image (800x600)
    final image = img.Image(width: 800, height: 600);

    // Draw sky gradient (top half)
    for (int y = 0; y < 300; y++) {
      final ratio = y / 300.0;
      final r = (skyColor.r * (1 - ratio * 0.3)).round();
      final g = (skyColor.g * (1 - ratio * 0.2)).round();
      final b = (skyColor.b * (1 - ratio * 0.1)).round();
      for (int x = 0; x < 800; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Draw ground/terrain (bottom half)
    for (int y = 300; y < 600; y++) {
      final ratio = (y - 300) / 300.0;
      final r = (groundColor.r * (1 - ratio * 0.3)).round();
      final g = (groundColor.g * (1 - ratio * 0.3)).round();
      final b = (groundColor.b * (1 - ratio * 0.3)).round();
      for (int x = 0; x < 800; x++) {
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Add accent feature (rock formation)
    for (int y = 250; y < 380; y++) {
      final width = ((380 - y) * 1.5).clamp(0, 200).toInt();
      final startX = 400 - width ~/ 2;
      for (int x = startX; x < startX + width && x < 800; x++) {
        if (x >= 0) {
          image.setPixelRgb(x, y, accentColor.r.toInt(), accentColor.g.toInt(), accentColor.b.toInt());
        }
      }
    }

    // Save the image
    final filePath = '$dirPath/$fileName.jpg';
    final file = File(filePath);
    await file.writeAsBytes(img.encodeJpg(image, quality: 85));

    // Create thumbnail
    final thumbnail = img.copyResize(image, width: 200, height: 150);
    final thumbnailPath = '$dirPath/${fileName}_thumb.jpg';
    final thumbFile = File(thumbnailPath);
    await thumbFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 75));
  }
}

/// Types of trail patterns for generating realistic data
enum TrailType {
  exploration, // Wandering, covering area
  prospecting, // Following water/terrain features
  canyon, // Constrained by canyon walls
}

/// Movement vector for trail generation
class _MovementVector {
  final double latDelta;
  final double lonDelta;
  final double newHeading;
  final double altitudeDelta;

  const _MovementVector({
    required this.latDelta,
    required this.lonDelta,
    required this.newHeading,
    required this.altitudeDelta,
  });
}

/// Configuration for generating demo photos
class _DemoPhotoConfig {
  final String waypointId;
  final String name;
  final img.ColorRgb8 skyColor;
  final img.ColorRgb8 groundColor;
  final img.ColorRgb8 accentColor;

  const _DemoPhotoConfig({
    required this.waypointId,
    required this.name,
    required this.skyColor,
    required this.groundColor,
    required this.accentColor,
  });
}
