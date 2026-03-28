import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/app/app.dart';
import 'package:obsession_tracker/core/config/bff_config.dart';
import 'package:obsession_tracker/core/services/app_settings_service.dart';
import 'package:obsession_tracker/core/services/bff_config_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/hunt_path_resolver.dart';
import 'package:obsession_tracker/core/services/push_notification_service.dart';
import 'package:obsession_tracker/core/services/subscription_service.dart';
import 'package:obsession_tracker/firebase_options.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Note: sqflite_sqlcipher has native macOS support, no FFI initialization needed

  // Initialize Mapbox with access token for proper map rendering
  // This is critical for Android to load map tiles correctly
  // Token is provided via --dart-define=MAPBOX_ACCESS_TOKEN=your_token
  const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  if (mapboxAccessToken.isEmpty) {
    debugPrint('⚠️ MAPBOX_ACCESS_TOKEN not set. Maps will not render.');
    debugPrint('   Run with: --dart-define=MAPBOX_ACCESS_TOKEN=your_token');
  }

  try {
    if (mapboxAccessToken.isNotEmpty) {
      MapboxOptions.setAccessToken(mapboxAccessToken);
    }
    // Privacy: Mapbox telemetry is disabled via platform configuration files:
    // - iOS: Info.plist MBXEventsEnabledInSimulator = false, MGLMapboxMetricsEnabled = false
    // - Android: AndroidManifest.xml com.mapbox.common.telemetry.enabled = false
    debugPrint('✅ Mapbox access token set successfully');
  } catch (e, stack) {
    debugPrint('❌ Mapbox initialization error: $e');
    debugPrint('Stack: $stack');
  }

  // Global error handler to catch and log all errors
  // Preserve existing error handler (for integration tests)
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorString = details.exception.toString();

    // Suppress Riverpod/Flutter lifecycle timing errors
    // These occur when a widget is disposed while Riverpod's scheduler still has
    // pending notifications. The widget is already gone, so the error is harmless.
    // This is a known issue with rapid state updates in async providers.
    if (errorString.contains('defunct') ||
        errorString.contains('_ElementLifecycle.defunct')) {
      // Log a brief message in debug mode only, don't spam the console
      debugPrint('📍 Suppressed defunct widget notification (Riverpod timing - harmless)');
      return; // Don't call original handler or log full error
    }

    // Call original handler first (test framework handler if running tests)
    if (originalOnError != null) {
      originalOnError(details);
    } else {
      FlutterError.presentError(details);
    }

    // Then log our custom error info
    debugPrint('══════ FLUTTER ERROR CAUGHT ══════');
    debugPrint('Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
    debugPrint('Context: ${details.context}');
    debugPrint('Library: ${details.library}');
    debugPrint('════════════════════════════════════');
  };

  // Lock orientation to portrait modes only for mobile platforms
  // Desktop platforms should support all orientations
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize hunt path resolver (for iOS container UUID changes)
  // Must be initialized before any database operations that involve file paths
  try {
    await HuntPathResolver.initialize();
    debugPrint('✅ Hunt path resolver initialized successfully');
  } catch (e, stack) {
    debugPrint('❌ Hunt path resolver initialization error: $e');
    debugPrint('Stack: $stack');
  }

  // Initialize app settings service (loads persisted settings from file)
  try {
    await AppSettingsService.instance.initialize();
    debugPrint('✅ App settings service initialized successfully');
  } catch (e, stack) {
    debugPrint('❌ App settings initialization error: $e');
    debugPrint('Stack: $stack');
  }

  // Initialize BFF dev data setting (debug builds only)
  try {
    await BFFConfig.initializeDevDataSetting();
  } catch (e, stack) {
    debugPrint('❌ BFF config dev setting error: $e');
    debugPrint('Stack: $stack');
  }

  // Fetch BFF app config (maintenance mode, version requirements, links)
  // This is database-independent and works even during BFF maintenance
  try {
    final config = await BFFConfigService.instance.fetchConfig();
    debugPrint('✅ BFF config fetched (API v${config.apiVersion})');

    // Check for maintenance mode
    if (config.maintenance.active) {
      debugPrint('⚠️ BFF is in maintenance mode: ${config.maintenance.message}');
    }

    // Check for required app update
    if (await BFFConfigService.instance.isUpdateRequired(config)) {
      debugPrint('⚠️ App update required! Current version is below minimum.');
      // Note: UI handling for force update should be done in the app widget
    }
  } catch (e, stack) {
    debugPrint('⚠️ BFF config fetch failed (using defaults): $e');
    debugPrint('Stack: $stack');
  }

  // Initialize in-app purchase subscription service
  // Connects directly to App Store / Play Store via bundle ID
  try {
    await SubscriptionService.instance.initialize();
    debugPrint('✅ In-app purchase initialized successfully');

    // Check for test mode flag (passed via --dart-define)
    // Usage: flutter run --dart-define=TEST_PREMIUM=true
    const testPremiumFlag = String.fromEnvironment('TEST_PREMIUM', defaultValue: 'false');
    if (testPremiumFlag == 'true') {
      SubscriptionService.testModePremium = true;
      debugPrint('⚠️ TEST MODE: Premium features enabled via --dart-define=TEST_PREMIUM=true');
    }
  } catch (e, stack) {
    debugPrint('❌ In-app purchase initialization error: $e');
    debugPrint('Stack: $stack');
  }

  // Initialize Firebase (for push notifications only - no analytics)
  // Skip in test mode to avoid hanging during integration tests
  debugPrint('🔍 PushNotificationService.testMode = ${PushNotificationService.testMode}');
  if (PushNotificationService.testMode) {
    debugPrint('⏭️ Skipping Firebase initialization (test mode)');
  } else {
    debugPrint('🔥 Starting Firebase initialization...');
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');

      // Set up background message handler (must be after Firebase.initializeApp)
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Initialize push notification service
      await PushNotificationService.instance.initialize();
    } catch (e, stack) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('Stack: $stack');
    }
  }

  // Check database accessibility before launching the app.
  // If the encryption key was lost (e.g. after an App Store app transfer),
  // show a recovery screen instead of letting every page fail individually.
  final dbAccessible = await DatabaseService().isDatabaseAccessible();
  if (!dbAccessible) {
    debugPrint('Database is not accessible - showing recovery screen');
    runApp(const ProviderScope(child: DatabaseRecoveryApp()));
    return;
  }

  runApp(const ProviderScope(child: ObsessionTrackerApp()));
}

/// Minimal app shown when the database cannot be opened (e.g. after an app transfer
/// that changed the Keychain team prefix, making the encryption key inaccessible).
class DatabaseRecoveryApp extends StatelessWidget {
  const DatabaseRecoveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Obsession Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _DatabaseRecoveryScreen(),
    );
  }
}

class _DatabaseRecoveryScreen extends StatelessWidget {
  const _DatabaseRecoveryScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storage, size: 64, color: Colors.orange[300]),
              const SizedBox(height: 24),
              const Text(
                'Database Recovery Needed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your data is encrypted but the encryption key is no longer '
                'accessible. This can happen after an App Store account transfer.\n\n'
                'You can reset the app to start fresh. If you have a backup '
                '(.obk file), you can restore it after resetting.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset App Data?'),
                      content: const Text(
                        'This will delete all local data and start fresh. '
                        'This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await DatabaseService().resetDatabase();
                    DatabaseService.resetInstance();
                    main();
                  }
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset App Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
