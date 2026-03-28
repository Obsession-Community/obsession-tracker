import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/mapbox_config.dart';
import 'package:obsession_tracker/core/models/quadrangle_manifest.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/bff_mapping_service.dart';
import 'package:obsession_tracker/core/services/mock_data_loader_service.dart';
import 'package:obsession_tracker/core/services/offline_land_rights_service.dart';
import 'package:obsession_tracker/core/services/push_notification_service.dart';
import 'package:obsession_tracker/core/services/quadrangle_download_service.dart';
import 'package:obsession_tracker/core/services/subscription_service.dart';
import 'package:obsession_tracker/features/map/presentation/overlays/historical_map_overlay.dart';
import 'package:obsession_tracker/features/map/presentation/widgets/core_map_view.dart';
import 'package:obsession_tracker/main.dart' as app;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Integration test for generating App Store screenshots
///
/// Screenshots are taken directly by the test using IntegrationTestWidgetsFlutterBinding.
/// Run with: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshots_test.dart
///
/// Navigation Structure (January 2026):
/// - Tab 0: Map (default start screen)
/// - Tab 1: Sessions
/// - Tab 2: Journal (Field Journal)
/// - Tab 3: Routes
/// - Tab 4: More
/// Note: Hunts moved to More menu under "Your Journey"
///
/// Layout Differences:
/// - Phone: Bottom NavigationBar with icons
/// - Tablet (landscape): NavigationRail sidebar with icons and labels
/// - Tablet (portrait): Bottom NavigationBar (same as phone)

/// Helper to find navigation destination by icon or text label
/// Works for both NavigationBar (phone) and NavigationRail (tablet landscape)
Finder findNavDestination(WidgetTester tester, IconData icon, String label) {
  // First try by icon (works for all layouts)
  final byIcon = find.byIcon(icon);
  if (byIcon.evaluate().isNotEmpty) {
    debugPrint('  ✓ Found by icon: $label');
    return byIcon;
  }

  // If icon not found, try by text label (NavigationRail always shows labels)
  final byLabel = find.text(label);
  if (byLabel.evaluate().isNotEmpty) {
    debugPrint('  ✓ Found by label: $label');
    return byLabel;
  }

  debugPrint('  ✗ Not found: $label (tried icon and label)');
  return byIcon; // Return icon finder (will be empty, handled by caller)
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  group('App Store Screenshots', () {
    testWidgets('Navigate through key features for screenshots',
        (WidgetTester tester) async {
      // Enable test mode to show premium features without subscription
      SubscriptionService.testModePremium = true;
      debugPrint('🔐 Premium test mode enabled');

      // Skip push notification permission dialog in test mode
      PushNotificationService.testMode = true;
      debugPrint('🔕 Push notification test mode enabled (skipping permission dialog)');


      // Load demo data for realistic screenshots
      // Hunt images are loaded from Flutter assets bundle (fastlane/btme/)
      debugPrint('📦 Loading demo data for screenshots...');
      final mockDataLoader = MockDataLoaderService();
      await mockDataLoader.loadDemoData();
      debugPrint('✅ Demo data loaded');

      // Pre-configure settings to enable land overlay and BFF data
      // Note: Trails and historical places are loaded automatically when zoomed in
      // at the appropriate level and data is available in the SQLite cache
      debugPrint('⚙️ Configuring map settings (land overlay enabled, BFF data)...');
      final settingsService = AppSettingsService();
      await settingsService.initialize();
      final currentSettings = settingsService.currentSettings;

      // Enable land overlay, BFF data, and HUD for screenshots
      final updatedMapSettings = currentSettings.map.copyWith(
        showLandOverlay: true,
        useBFFData: true,
        // Enable HUD to show coordinates, elevation, speed, and heading overlay
        hudShowCoordinates: true,
        hudShowElevation: true,
        hudShowSpeed: true,
        hudShowHeading: true,
      );
      await settingsService.updateMapSettings(updatedMapSettings);
      debugPrint('✅ Map settings configured (land overlay + HUD enabled)');

      // Load UT state data from fixture ZIP files
      debugPrint('📦 Loading UT state data from fixtures...');
      final offlineService = OfflineLandRightsService();
      await offlineService.initialize();

      // Get fixtures path based on platform
      String fixturesPath;
      if (Platform.isAndroid) {
        // Android: Load fixtures from bundled assets and copy to writable directory
        // Assets are bundled with the app, so they're always available
        debugPrint('📦 Android: Loading fixtures from bundled assets...');
        final tempDir = await getTemporaryDirectory();
        fixturesPath = '${tempDir.path}/obsession-fixtures/states/UT';
        final fixturesDir = Directory(fixturesPath);
        if (!fixturesDir.existsSync()) {
          fixturesDir.createSync(recursive: true);
        }

        // Copy each fixture from assets to temp directory
        for (final fixtureName in ['land.zip', 'trails.zip', 'historical.zip']) {
          final assetPath = 'integration_test/fixtures/states/UT/$fixtureName';
          final targetFile = File('$fixturesPath/$fixtureName');
          if (!targetFile.existsSync()) {
            try {
              debugPrint('📦 Copying asset: $assetPath');
              final byteData = await rootBundle.load(assetPath);
              await targetFile.writeAsBytes(
                byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
              );
              debugPrint('✅ Copied $fixtureName (${targetFile.lengthSync()} bytes)');
            } catch (e) {
              debugPrint('⚠️ Failed to copy $fixtureName: $e');
            }
          } else {
            debugPrint('📂 $fixtureName already exists at $fixturesPath');
          }
        }
      } else if (Platform.isMacOS) {
        // macOS: Fastlane copies fixtures to /tmp before test (outside sandbox)
        // This mirrors the iOS approach of using a known temp location
        fixturesPath = '/tmp/obsession-fixtures/states/UT';
        debugPrint('📦 macOS: Looking for fixtures at $fixturesPath');
      } else {
        // iOS: Fastlane copies fixtures to app's temp directory before test
        final tempDir = Directory.systemTemp;
        fixturesPath = '${tempDir.path}/obsession-fixtures/states/UT';
      }
      debugPrint('📂 Looking for fixtures at: $fixturesPath');
      final landZip = File('$fixturesPath/land.zip');
      final trailsZip = File('$fixturesPath/trails.zip');
      final historicalZip = File('$fixturesPath/historical.zip');

      var fixturesLoaded = false;

      if (landZip.existsSync()) {
        debugPrint('📦 Loading UT land data from fixture...');
        final result = await BFFMappingService.instance.loadStateDataTypeFromLocalZip(
          stateCode: 'UT',
          dataType: DataTypeLocal.land,
          zipFilePath: landZip.path,
          offlineService: offlineService,
        );
        debugPrint('✅ Land data loaded: ${result is StateDownloadSuccess ? "${result.recordCount} records" : "failed"}');
        fixturesLoaded = true;
      } else {
        debugPrint('⚠️ No land fixture found at ${landZip.path}');
      }

      if (trailsZip.existsSync()) {
        debugPrint('📦 Loading UT trails data from fixture...');
        final result = await BFFMappingService.instance.loadStateDataTypeFromLocalZip(
          stateCode: 'UT',
          dataType: DataTypeLocal.trails,
          zipFilePath: trailsZip.path,
          offlineService: offlineService,
        );
        debugPrint('✅ Trails data loaded: ${result is StateDownloadSuccess ? "${result.recordCount} records" : "failed"}');
        fixturesLoaded = true;
      } else {
        debugPrint('⚠️ No trails fixture found at ${trailsZip.path}');
      }

      if (historicalZip.existsSync()) {
        debugPrint('📦 Loading UT historical places from fixture...');
        final result = await BFFMappingService.instance.loadStateDataTypeFromLocalZip(
          stateCode: 'UT',
          dataType: DataTypeLocal.historical,
          zipFilePath: historicalZip.path,
          offlineService: offlineService,
        );
        debugPrint('✅ Historical data loaded: ${result is StateDownloadSuccess ? "${result.recordCount} records" : "failed"}');
        fixturesLoaded = true;
      } else {
        debugPrint('⚠️ No historical fixture found at ${historicalZip.path}');
      }

      // Fall back to mock data if no fixtures were loaded
      if (!fixturesLoaded) {
        debugPrint('⚠️ No fixture files found - using mock land data instead');
        await mockDataLoader.loadMockLandData(offlineService);
      }

      // Insert state download record for version tracking
      await offlineService.insertMockStateDownload('UT', 'Utah');
      debugPrint('✅ UT state data setup complete');

      // Load WY historical map fixture (Gallatin 1885 quadrangle)
      debugPrint('📦 Loading WY historical map fixture...');
      String wyHistoricalMapPath;
      if (Platform.isAndroid) {
        // Android: Copy from bundled assets to temp directory
        final tempDir = await getTemporaryDirectory();
        wyHistoricalMapPath = '${tempDir.path}/historical_maps/WY/early_topo/gallatin_1885.mbtiles';
        final wyMapFile = File(wyHistoricalMapPath);
        if (!wyMapFile.existsSync()) {
          await wyMapFile.parent.create(recursive: true);
          try {
            final byteData = await rootBundle.load(
              'integration_test/fixtures/states/WY/historical_maps/gallatin_1885.mbtiles',
            );
            await wyMapFile.writeAsBytes(
              byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
            );
            debugPrint('✅ Copied WY historical map fixture (${wyMapFile.lengthSync()} bytes)');
          } catch (e) {
            debugPrint('⚠️ Failed to copy WY historical map: $e');
          }
        }
      } else if (Platform.isMacOS) {
        wyHistoricalMapPath = '/tmp/obsession-fixtures/states/WY/historical_maps/gallatin_1885.mbtiles';
      } else {
        // iOS
        final tempDir = Directory.systemTemp;
        wyHistoricalMapPath = '${tempDir.path}/obsession-fixtures/states/WY/historical_maps/gallatin_1885.mbtiles';
      }

      // Register the historical map with QuadrangleDownloadService if it exists
      final wyMapFile = File(wyHistoricalMapPath);
      if (wyMapFile.existsSync()) {
        debugPrint('📦 Registering WY Gallatin 1885 quadrangle...');
        final quadService = QuadrangleDownloadService.instance;
        await quadService.initialize();
        await quadService.registerTestQuadrangle(
          stateCode: 'WY',
          eraId: 'early_topo',
          quadId: 'gallatin_1885',
          name: 'Gallatin',
          filePath: wyHistoricalMapPath,
          sizeBytes: wyMapFile.lengthSync(),
          bounds: const QuadrangleBounds(
            west: -111.0674087,
            south: 44.4630784,
            east: -110.4193921,
            north: 45.0325221,
          ),
          year: 1885,
        );

        // Enable the historical map via SharedPreferences
        // The key format is: historical_maps_enabled -> list of 'STATE_layerId' strings
        // For quadrangles, layerId format is: quad_{eraId}_{quadId}
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('historical_maps_enabled', ['WY_quad_early_topo_gallatin_1885']);
        await prefs.setDouble('historical_maps_opacity_WY_quad_early_topo_gallatin_1885', 0.8);
        debugPrint('✅ WY historical map registered and enabled');
      } else {
        debugPrint('⚠️ WY historical map fixture not found at $wyHistoricalMapPath');
      }

      // Enable screenshot mode BEFORE launching app so map uses correct center/zoom
      // This centers near Zion/Bryce area to show varied land types (BLM, USFS, NPS, state)
      MapboxPresets.screenshotMode = true;
      MapboxPresets.screenshotHistoricalMapMode = false; // Start with land overlay, switch later for historical screenshot
      debugPrint('🗺️ Screenshot mode enabled - map will center near Zion/Bryce at zoom 12');

      // Launch the app
      app.main();

      // Pump multiple times to let app initialize
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Wait for app to fully load
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Refresh subscription status
      await SubscriptionService.instance.refreshSubscriptionStatus();
      await tester.pump();
      debugPrint('✅ App main() called, waiting for initialization...');

      // Wait for app to fully initialize (biometric lock check is async)
      // Poll for navigation widgets to appear - they only render after _isInitialized = true
      debugPrint('⏳ Waiting for navigation to appear (app async initialization)...');
      var navFound = false;
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        final navBar = find.byType(NavigationBar);
        final navRail = find.byType(NavigationRail);
        if (navBar.evaluate().isNotEmpty || navRail.evaluate().isNotEmpty) {
          navFound = true;
          debugPrint('✅ Navigation found after ${(i + 1) * 500}ms');
          break;
        }
        if (i % 4 == 0) {
          debugPrint('  Still waiting... (${(i + 1) * 500}ms)');
        }
      }

      if (!navFound) {
        debugPrint('⚠️ Navigation not found after 15 seconds - checking widget tree...');
      }

      // Final settle after navigation appears
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Debug: Check what navigation widgets are present
      debugPrint('🔍 DEBUG: Checking navigation widgets...');
      final navBar = find.byType(NavigationBar);
      final navRail = find.byType(NavigationRail);
      debugPrint('  NavigationBar found: ${navBar.evaluate().length}');
      debugPrint('  NavigationRail found: ${navRail.evaluate().length}');

      // Debug: Check for specific icons
      debugPrint('🔍 DEBUG: Checking for navigation icons...');
      debugPrint('  Icons.map_outlined: ${find.byIcon(Icons.map_outlined).evaluate().length}');
      debugPrint('  Icons.map: ${find.byIcon(Icons.map).evaluate().length}');
      debugPrint('  Icons.history: ${find.byIcon(Icons.history).evaluate().length}');
      debugPrint('  Icons.book_outlined: ${find.byIcon(Icons.book_outlined).evaluate().length}');
      debugPrint('  Icons.route_outlined: ${find.byIcon(Icons.route_outlined).evaluate().length}');
      debugPrint('  Icons.more_horiz: ${find.byIcon(Icons.more_horiz).evaluate().length}');

      debugPrint('✅ App fully initialized');

      // Convert Flutter surface to image early (required for screenshots with Impeller)
      // This must be called before any screenshots, and calling it early avoids hangs
      // during complex rendering operations
      debugPrint('🖼️ Preparing screenshot surface...');
      await binding.convertFlutterSurfaceToImage();
      debugPrint('✅ Screenshot surface ready');

      // ===== SCREEN 1: FULL MAP WITH LAND DATA, TRAILS, AND HISTORICAL PLACES =====
      // App starts on Map tab (index 0) - no navigation needed!
      // The map shows land ownership, trails, and historical places circles
      debugPrint('🗺️ Capturing map view (app starts on Map tab)...');

      // BFF mode already set before download, just refresh subscription
      await SubscriptionService.instance.refreshSubscriptionStatus();

      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Wait for Mapbox tiles to load (data is already in SQLite from test setup)
      debugPrint('⏳ Waiting for Mapbox tiles...');
      await tester.pump(const Duration(seconds: 3));

      // IMPORTANT: The map doesn't automatically re-render when overlay data finishes loading.
      // A quick fling gesture triggers camera change which loads historical places
      // and refreshes all overlays. Fling is faster than drag so won't trigger long-press.
      debugPrint('🔄 Triggering map refresh with fling gesture...');
      // Get screen size to target the center of the map area (above nav bar, below app bar)
      final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      final mapCenter = Offset(screenSize.width / 2, screenSize.height / 3);

      // Use fling with specific location - faster than drag, won't trigger long-press
      await tester.flingFrom(mapCenter, const Offset(50, 0), 500);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      // Fling back to approximately original position
      await tester.flingFrom(mapCenter, const Offset(-50, 0), 500);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      debugPrint('✅ Map fling gesture complete');

      // Wait for overlay reload triggered by pan to complete
      // The pan triggers a reload which may queue if already loading
      // pumpAndSettle only waits for Flutter animations, not async Mapbox operations
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Critical: Mapbox overlay loading is async and continues after pumpAndSettle
      // The land overlay takes ~1-2 seconds to create source and add to map
      debugPrint('⏳ Waiting for Mapbox overlays to finish async loading...');
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pump();

      // Dismiss any bottom sheet that may have opened (e.g., "New Marker" from touch-to-mark)
      final cancelButton = find.text('Cancel');
      if (cancelButton.evaluate().isNotEmpty) {
        debugPrint('🔙 Dismissing marker creation bottom sheet...');
        await tester.tap(cancelButton);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        // Wait for overlays to re-render after bottom sheet dismissal
        await Future<void>.delayed(const Duration(seconds: 2));
        await tester.pump();
      }

      debugPrint('✅ Map ready');

      debugPrint('📸 Taking screenshot 1: Map with land, trails, and historical places');
      await binding.takeScreenshot('01_map');

      // ===== SCREEN 2: SESSIONS LIST =====
      debugPrint('🔍 Looking for Sessions tab...');
      final sessionsTab = findNavDestination(tester, Icons.history, 'Sessions');
      if (sessionsTab.evaluate().isNotEmpty) {
        await tester.tap(sessionsTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        debugPrint('📸 Taking screenshot 2: Sessions list');
        await binding.takeScreenshot('02_sessions');

        // ===== SCREEN 3: SESSION DETAIL WITH PHOTOS =====
        final sessionCards = find.byType(Card);
        if (sessionCards.evaluate().isNotEmpty) {
          await tester.tap(sessionCards.first);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          // Wait for session details, map, and photos to load
          await Future<void>.delayed(const Duration(seconds: 3));
          await tester.pumpAndSettle();

          debugPrint('📸 Taking screenshot 3: Session detail with track and photos');
          await binding.takeScreenshot('03_session_detail');

          // ===== SCREEN 4: SESSION PLAYBACK =====
          debugPrint('🔍 Looking for Play Session button...');
          final playButton = find.byIcon(Icons.play_circle);
          if (playButton.evaluate().isNotEmpty) {
            await tester.tap(playButton);
            await tester.pumpAndSettle(const Duration(seconds: 3));

            // Wait for playback view to load (map, breadcrumbs, photos)
            // Photo appears at start since waypoint is at breadcrumb index 5
            // Extended wait time to ensure Mapbox tiles fully load
            await tester.pump(const Duration(seconds: 6));
            await Future<void>.delayed(const Duration(seconds: 3));
            await tester.pumpAndSettle();

            debugPrint('📸 Taking screenshot 4: Session playback view');
            await binding.takeScreenshot('04_session_playback');

            // Go back to session detail using Material back button
            final playbackBackButton = find.byTooltip('Back');
            if (playbackBackButton.evaluate().isNotEmpty) {
              await tester.tap(playbackBackButton.first);
            } else {
              final arrowBack = find.byIcon(Icons.arrow_back);
              if (arrowBack.evaluate().isNotEmpty) {
                await tester.tap(arrowBack.first);
              }
            }
            await tester.pumpAndSettle(const Duration(seconds: 1));
          } else {
            debugPrint('⚠️ Play Session button not found');
          }

          // Go back to sessions list using Material back button
          final sessionBackButton = find.byTooltip('Back');
          if (sessionBackButton.evaluate().isNotEmpty) {
            await tester.tap(sessionBackButton.first);
          } else {
            final arrowBack = find.byIcon(Icons.arrow_back);
            if (arrowBack.evaluate().isNotEmpty) {
              await tester.tap(arrowBack.first);
            }
          }
          await tester.pumpAndSettle(const Duration(seconds: 1));
        } else {
          debugPrint('⚠️ No session cards found');
        }
      } else {
        debugPrint('⚠️ Sessions tab not found');
      }

      // ===== SCREEN 5: JOURNAL LIST =====
      debugPrint('🔍 Looking for Journal tab...');
      final journalTab = findNavDestination(tester, Icons.book_outlined, 'Journal');
      if (journalTab.evaluate().isNotEmpty) {
        await tester.tap(journalTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Wait for journal entries to load
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        debugPrint('📸 Taking screenshot 5: Field Journal list');
        await binding.takeScreenshot('05_journal');
      } else {
        debugPrint('⚠️ Journal tab not found');
      }

      // ===== SCREEN 6: HISTORICAL MAP (1885 USGS TOPO) =====
      // Navigate back to Map tab (it's already built from first screenshot)
      debugPrint('🗺️ Navigating to Map tab for historical map screenshot...');
      final mapTabForHistorical = findNavDestination(tester, Icons.map_outlined, 'Map');
      if (mapTabForHistorical.evaluate().isEmpty) {
        // Try filled map icon
        final mapTabFilled = find.byIcon(Icons.map);
        if (mapTabFilled.evaluate().isNotEmpty) {
          await tester.tap(mapTabFilled);
        }
      } else {
        await tester.tap(mapTabForHistorical);
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Programmatically fly the camera to Wyoming (Gallatin quad location)
      // The map widget is already built, so we use the testMapInstance to move the camera
      debugPrint('🗺️ Flying camera to Wyoming/Gallatin (44.75N, 110.74W)...');
      final mapInstance = CoreMapViewState.testMapInstance;
      if (mapInstance != null) {
        // Wyoming coordinates for the 1885 Gallatin USGS topo
        // Bounds: west -111.07, south 44.46, east -110.42, north 45.03
        // Center is approximately 44.745N, 110.745W
        final wyomingCenter = Point(
          coordinates: Position(-110.74, 44.75),
        );

        await mapInstance.flyTo(
          CameraOptions(
            center: wyomingCenter,
            zoom: 11.5,
            bearing: 0,
            pitch: 0,
          ),
          MapAnimationOptions(duration: 2000),
        );

        // Wait for camera animation to complete
        debugPrint('⏳ Waiting for camera animation...');
        await Future<void>.delayed(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Load the historical map overlay FIRST (so route draws on top)
        debugPrint('🗺️ Loading historical map overlay directly...');
        String wyMbtilesPath;
        if (Platform.isAndroid) {
          // On Android, fixtures are pushed to /data/local/tmp by fastlane
          wyMbtilesPath = '/data/local/tmp/historical_maps/WY/early_topo/gallatin_1885.mbtiles';
        } else if (Platform.isMacOS) {
          wyMbtilesPath = '/tmp/obsession-fixtures/states/WY/historical_maps/gallatin_1885.mbtiles';
        } else {
          // iOS
          final tempDir = Directory.systemTemp;
          wyMbtilesPath = '${tempDir.path}/obsession-fixtures/states/WY/historical_maps/gallatin_1885.mbtiles';
        }

        final mbtilesFile = File(wyMbtilesPath);
        if (mbtilesFile.existsSync()) {
          debugPrint('🗺️ MBTiles file found at: $wyMbtilesPath');
          try {
            final historicalOverlay = HistoricalMapOverlay(
              stateCode: 'WY',
              layerId: 'quad_early_topo_gallatin_1885',
              layerName: 'Gallatin (1885)',
              filePath: wyMbtilesPath,
              opacity: 0.8,
              era: 'early_topo',
            );
            await historicalOverlay.load(mapInstance);
            debugPrint('✅ Historical map overlay loaded');

            // Wait for tiles to load before adding route
            await Future<void>.delayed(const Duration(seconds: 2));
          } catch (e) {
            debugPrint('⚠️ Failed to load historical map overlay: $e');
          }
        } else {
          debugPrint('⚠️ MBTiles file not found at: $wyMbtilesPath');
          // List files in parent directory to debug
          final parentDir = mbtilesFile.parent;
          if (parentDir.existsSync()) {
            debugPrint('📂 Files in ${parentDir.path}:');
            for (final file in parentDir.listSync()) {
              debugPrint('  - ${file.path}');
            }
          } else {
            debugPrint('📂 Parent directory does not exist: ${parentDir.path}');
          }
        }

        // Add route polyline AFTER historical map (so it draws on top)
        debugPrint('🛤️ Adding Gallatin Mining Trail route overlay...');
        try {
          final polylineManager = await mapInstance.annotations.createPolylineAnnotationManager();

          // Gallatin Mining Trail coordinates (matching mock_data_loader_service route6)
          final routeCoordinates = [
            Position(-110.7800, 44.7800), // Survey Marker Start
            Position(-110.7650, 44.7725), // Interpolated point
            Position(-110.7500, 44.7650), // Old Mine Shaft
            Position(-110.7350, 44.7525), // Interpolated point
            Position(-110.7200, 44.7400), // Pack Trail Junction
            Position(-110.7050, 44.7300), // Interpolated point
            Position(-110.6900, 44.7200), // Miner Cabin Ruins
          ];

          await polylineManager.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: routeCoordinates),
              lineColor: 0xFF2196F3.toInt(), // Blue color (like GPS track)
              lineWidth: 4.0,
            ),
          );
          debugPrint('✅ Route overlay added');
        } catch (e) {
          debugPrint('⚠️ Failed to add route overlay: $e');
        }
      } else {
        debugPrint('⚠️ Map instance not available - camera not moved');
      }

      // Wait for historical map tiles to render
      debugPrint('⏳ Waiting for historical map tiles to render...');
      await tester.pump(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      debugPrint('📸 Taking screenshot 6: Historical map (1885 Gallatin USGS topo)');
      await binding.takeScreenshot('06_historical_map');

      // Reset historical map mode for remaining screenshots
      MapboxPresets.screenshotHistoricalMapMode = false;

      // ===== SCREEN 7: ROUTES LIST =====
      debugPrint('🔍 Looking for Routes tab...');
      final routesTab = findNavDestination(tester, Icons.route_outlined, 'Routes');
      if (routesTab.evaluate().isNotEmpty) {
        await tester.tap(routesTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        debugPrint('📸 Taking screenshot 7: Routes list');
        await binding.takeScreenshot('07_routes');

        // ===== SCREEN 8: ROUTE DETAIL =====
        // TODO(dev): Re-enable once Android screenshot hanging issue is resolved
        // The route detail screen has a map that may cause hangs with Impeller
        // final routeCards = find.byType(Card);
        // if (routeCards.evaluate().isNotEmpty) {
        //   await tester.tap(routeCards.first);
        //   await tester.pumpAndSettle(const Duration(seconds: 3));
        //
        //   // Wait for route details and map to load
        //   await Future<void>.delayed(const Duration(seconds: 3));
        //   await tester.pumpAndSettle();
        //
        //   debugPrint('📸 Taking screenshot 8: Route detail');
        //   await binding.takeScreenshot('08_route_detail');
        // } else {
        //   debugPrint('⚠️ No route cards found');
        // }
        debugPrint('⚠️ Skipping screenshot 8 (route detail) - needs investigation');
      } else {
        debugPrint('⚠️ Routes tab not found');
      }

      // ===== SCREEN 8: ACHIEVEMENTS PAGE =====
      debugPrint('🔍 Looking for More tab...');
      final moreTab = findNavDestination(tester, Icons.more_horiz, 'More');
      if (moreTab.evaluate().isNotEmpty) {
        await tester.tap(moreTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Find and tap on Achievements
        debugPrint('🔍 Looking for Achievements menu item...');
        final achievementsTile = find.text('Achievements');
        if (achievementsTile.evaluate().isNotEmpty) {
          await tester.tap(achievementsTile);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Wait for achievements page to load (statistics, badges, state map)
          await Future<void>.delayed(const Duration(seconds: 2));
          await tester.pumpAndSettle();

          debugPrint('📸 Taking screenshot 8: Achievements Statistics tab');
          await binding.takeScreenshot('08_achievements_stats');

          // Note: Android only supports 8 screenshots, so we stop here
          // Badges and States tabs are accessible from the Statistics tab

          // Go back to More tab using Material back button
          final achievementsBackButton = find.byTooltip('Back');
          if (achievementsBackButton.evaluate().isNotEmpty) {
            await tester.tap(achievementsBackButton.first);
          } else {
            final arrowBack = find.byIcon(Icons.arrow_back);
            if (arrowBack.evaluate().isNotEmpty) {
              await tester.tap(arrowBack.first);
            }
          }
          await tester.pumpAndSettle(const Duration(seconds: 1));
        } else {
          debugPrint('⚠️ Achievements menu item not found');
        }
      } else {
        debugPrint('⚠️ More tab not found');
      }

      debugPrint('✅ Screenshot capture complete');
    });
  });
}
