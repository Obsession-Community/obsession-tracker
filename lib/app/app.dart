import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/providers/announcements_provider.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/providers/theme_provider.dart';
import 'package:obsession_tracker/core/services/app_lifecycle_service.dart';
import 'package:obsession_tracker/core/services/biometric_lock_service.dart';
import 'package:obsession_tracker/core/services/incoming_file_service.dart';
import 'package:obsession_tracker/core/services/push_notification_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/core/utils/platform_optimizations.dart';
import 'package:obsession_tracker/core/widgets/biometric_lock_screen.dart';
import 'package:obsession_tracker/core/widgets/desktop_menu_bar.dart';
import 'package:obsession_tracker/features/achievements/presentation/widgets/achievement_notification_listener.dart';
import 'package:obsession_tracker/features/home/presentation/pages/adaptive_home_page.dart';
import 'package:obsession_tracker/features/hunts/presentation/pages/hunt_detail_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/announcements_history_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/data_management_page.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/general_settings_page.dart';

/// The root widget of the Obsession Tracker application.
///
/// This widget sets up the main MaterialApp with theming, routing,
/// and global configuration for the privacy-first GPS tracking app.
class ObsessionTrackerApp extends ConsumerStatefulWidget {
  const ObsessionTrackerApp({super.key});

  @override
  ConsumerState<ObsessionTrackerApp> createState() =>
      _ObsessionTrackerAppState();
}

class _ObsessionTrackerAppState extends ConsumerState<ObsessionTrackerApp>
    with WidgetsBindingObserver {
  StreamSubscription<AppLifecycleState>? _lifecycleSubscription;
  StreamSubscription<NotificationTapEvent>? _notificationTapSubscription;
  StreamSubscription<IncomingFileEvent>? _incomingFileSubscription;

  // Biometric lock service for app-level security
  final BiometricLockService _lockService = BiometricLockService();

  // Track whether app is unlocked
  bool _isUnlocked = false;

  // Track initialization state
  bool _isInitialized = false;

  // Track whether to show privacy screen (covers content in app switcher)
  bool _showPrivacyScreen = false;

  @override
  void initState() {
    super.initState();
    // Initialize biometric lock service
    _initializeBiometricLock();

    // Initialize app lifecycle service for background location tracking
    AppLifecycleService().initialize();
    WidgetsBinding.instance.addObserver(this);

    // Listen to app lifecycle changes to handle biometric lock, privacy screen, and permission refresh
    _lifecycleSubscription = AppLifecycleService().addListener((state) {
      debugPrint('🔒 AppLifecycleService listener: $state');
      switch (state) {
        case AppLifecycleState.inactive:
        case AppLifecycleState.paused:
        case AppLifecycleState.hidden:
          // App going to background - show privacy screen immediately
          _showPrivacyScreenIfEnabled();
          break;
        case AppLifecycleState.resumed:
          // App returned to foreground - hide privacy screen, check lock, refresh permissions
          _hidePrivacyScreen();
          _handleAppResumed();
          break;
        case AppLifecycleState.detached:
          // App being terminated
          break;
      }
    });

    // Request location permission on first launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialLocationPermission();
    });

    // Listen for push notification taps for deep linking
    _notificationTapSubscription = PushNotificationService.instance
        .onNotificationTap
        .listen(_handleNotificationTap);

    // Initialize incoming file service for file associations (iOS and Android)
    _initializeIncomingFileService();
  }

  /// Handle notification tap for deep linking
  Future<void> _handleNotificationTap(NotificationTapEvent event) async {
    debugPrint('📬 Handling notification tap: ${event.type}');

    // Wait for app to be unlocked and ready
    if (!_isUnlocked || !_isInitialized) {
      debugPrint('📬 App not ready, queueing navigation');
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _handleNotificationTap(event);
      });
      return;
    }

    // Use the navigator key since we're above the MaterialApp in the widget tree
    final navigator = PushNotificationService.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('📬 Navigator not available yet');
      return;
    }

    // Navigate based on notification type
    if (event.huntId != null) {
      // Navigate to hunt detail page
      debugPrint('📬 Navigating to hunt: ${event.huntId}');
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => HuntDetailPage(huntId: event.huntId!),
        ),
      );
    } else if (event.announcementId != null || event.type == 'announcement') {
      // Refresh announcements first to ensure we have the latest data
      // (the push notification may reference a new announcement the device doesn't have yet)
      debugPrint('📬 Refreshing announcements before navigation...');
      await ref.read(announcementsProvider.notifier).refresh();

      // Navigate to announcements page
      debugPrint('📬 Navigating to announcements');
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const AnnouncementsHistoryPage(),
        ),
      );
    }
  }

  /// Initialize incoming file service for handling file associations
  Future<void> _initializeIncomingFileService() async {
    try {
      final incomingFileService = IncomingFileService();
      await incomingFileService.initialize();

      // Listen for incoming file events
      _incomingFileSubscription = incomingFileService.onIncomingFile.listen(
        _handleIncomingFile,
      );

      // Process any pending file after UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isUnlocked && _isInitialized) {
          incomingFileService.processPendingFile();
        }
      });

      debugPrint('📂 Incoming file service initialized');
    } catch (e) {
      debugPrint('📂 Failed to initialize incoming file service: $e');
    }
  }

  /// Handle incoming file from file association or deep link
  Future<void> _handleIncomingFile(IncomingFileEvent event) async {
    debugPrint('📂 Handling incoming file: ${event.filePath} (${event.fileType})');

    // Wait for app to be unlocked and ready
    if (!_isUnlocked || !_isInitialized) {
      debugPrint('📂 App not ready, queueing file handling');
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _handleIncomingFile(event);
      });
      return;
    }

    // Use the navigator key since we're above the MaterialApp in the widget tree
    final navigator = PushNotificationService.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('📂 Navigator not available yet');
      return;
    }

    // Navigate to data management page with the file path for import
    switch (event.fileType) {
      case IncomingFileType.obstrack:
      case IncomingFileType.obk:
        debugPrint('📂 Navigating to data management with file: ${event.filePath}');
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (context) => DataManagementPage(
              incomingFilePath: event.filePath,
            ),
          ),
        );
        break;
      case IncomingFileType.gpx:
      case IncomingFileType.kml:
        // GPX/KML import via deep link not yet implemented
        debugPrint('📂 GPX/KML import not yet implemented via deep link');
        break;
      case IncomingFileType.unknown:
        debugPrint('📂 Unknown file type, ignoring');
        break;
    }
  }

  /// Initialize biometric lock service and check lock status
  Future<void> _initializeBiometricLock() async {
    try {
      await _lockService.initialize();
      debugPrint('✅ Biometric lock service initialized');

      // Check if we should show lock screen
      final bool isEnabled = await _lockService.isEnabled();

      if (!mounted) return;

      if (isEnabled &&
          _lockService.status == BiometricLockStatus.locked) {
        // Keep app locked - UI will show lock screen
        setState(() {
          _isUnlocked = false;
          _isInitialized = true;
        });
        debugPrint('🔒 App locked - biometric authentication required');
      } else {
        // App is not locked or lock is disabled
        setState(() {
          _isUnlocked = true;
          _isInitialized = true;
        });
        debugPrint('✅ App unlocked - biometric lock disabled or not enrolled');
      }
    } catch (e) {
      debugPrint('⚠️ Error initializing biometric lock: $e');
      // On error, allow access (fail open for better UX)
      if (!mounted) return;
      setState(() {
        _isUnlocked = true;
        _isInitialized = true;
      });
    }
  }

  /// Request location permission on app launch for better first-time user experience
  Future<void> _requestInitialLocationPermission() async {
    final locationNotifier = ref.read(locationProvider.notifier);

    // Just request permission - don't try to get location yet
    // The LocationNotifier already handles getting position when permission is granted
    // in _checkInitialLocationStatus() which is event-driven
    await locationNotifier.requestLocationPermission();

    // Location will be acquired automatically by the provider when status changes to granted
  }

  @override
  void dispose() {
    _lifecycleSubscription?.cancel();
    _notificationTapSubscription?.cancel();
    _incomingFileSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('🔒 didChangeAppLifecycleState: $state');

    switch (state) {
      case AppLifecycleState.paused:
        // App going to true background - notify lock service
        debugPrint('🔒 Calling onAppPaused (paused)...');
        _lockService.onAppPaused();
        _showPrivacyScreenIfEnabled();
        debugPrint('🔒 App paused - biometric lock notified');
        break;

      case AppLifecycleState.inactive:
        // App inactive (app switcher, notifications, etc.)
        // Show privacy screen immediately to cover sensitive content in app switcher
        // But DON'T lock - this also happens during biometric authentication
        debugPrint('🔒 App inactive - showing privacy screen');
        _showPrivacyScreenIfEnabled();
        break;

      case AppLifecycleState.resumed:
        // App returning to foreground - hide privacy screen and check lock
        debugPrint('🔒 Calling _handleAppResumed...');
        _hidePrivacyScreen();
        _handleAppResumed();
        break;

      case AppLifecycleState.detached:
        // App being terminated - lock
        _lockService.onAppDetached();
        break;

      case AppLifecycleState.hidden:
        // App hidden (iOS app switcher) - show privacy screen and notify lock
        _showPrivacyScreenIfEnabled();
        _lockService.onAppPaused();
        break;
    }
  }

  /// Show privacy screen if biometric lock is enabled
  Future<void> _showPrivacyScreenIfEnabled() async {
    // Skip if already showing privacy screen or authentication is in progress
    if (_showPrivacyScreen || _lockService.isAuthenticating) {
      debugPrint('🔒 Privacy screen: skipping (already showing or authenticating)');
      return;
    }

    final isEnabled = await _lockService.isEnabled();
    if (isEnabled && mounted) {
      setState(() {
        _showPrivacyScreen = true;
      });
      debugPrint('🔒 Privacy screen: SHOWN');
    }
  }

  /// Hide the privacy screen
  void _hidePrivacyScreen() {
    if (_showPrivacyScreen && mounted) {
      setState(() {
        _showPrivacyScreen = false;
      });
      debugPrint('🔒 Privacy screen: HIDDEN');
    }
  }

  /// Handle app resuming from background
  Future<void> _handleAppResumed() async {
    debugPrint('🔒 _handleAppResumed: calling onAppResumed... (_isUnlocked=$_isUnlocked)');
    await _lockService.onAppResumed();

    // Check if we should lock the app
    final bool isEnabled = await _lockService.isEnabled();
    final status = _lockService.status;
    debugPrint('🔒 _handleAppResumed: isEnabled=$isEnabled, status=$status, _isUnlocked=$_isUnlocked');

    if (isEnabled && status == BiometricLockStatus.locked) {
      // Lock the app
      debugPrint('🔒 Setting _isUnlocked to false (was $_isUnlocked)');
      if (mounted) {
        setState(() {
          _isUnlocked = false;
        });
        debugPrint('🔒 App locked on resume - _isUnlocked now=$_isUnlocked');
      } else {
        debugPrint('🔒 NOT calling setState - widget not mounted!');
      }
    } else {
      debugPrint('🔒 Not locking: isEnabled=$isEnabled, status=$status');

      // If unlocked and on iOS, check the Inbox folder for shared files
      if (Platform.isIOS && _isUnlocked) {
        _checkInboxForFiles();
      }
    }

    // Also refresh permission status
    _refreshPermissionStatus();
  }

  /// Check the Inbox folder for files shared via iOS share sheet
  Future<void> _checkInboxForFiles() async {
    try {
      debugPrint('📂 Checking Inbox folder for shared files...');
      final incomingFileService = IncomingFileService();
      await incomingFileService.checkInboxFolder();
    } catch (e) {
      debugPrint('📂 Error checking Inbox folder: $e');
    }
  }

  /// Refresh permission status when app resumes (e.g., returning from settings)
  Future<void> _refreshPermissionStatus() async {
    try {
      await ref.read(locationProvider.notifier).refreshPermissionStatus();
      debugPrint('✅ Permission status refreshed after app resume');
    } catch (e) {
      debugPrint('⚠️ Failed to refresh permission status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    debugPrint('🔒 BUILD: _isInitialized=$_isInitialized, _isUnlocked=$_isUnlocked, _showPrivacyScreen=$_showPrivacyScreen');

    return DesktopMenuBar(
      onOpenSettings: () {
        debugPrint('📱 Menu: Open Settings');
        final navigator = PushNotificationService.navigatorKey.currentState;
        navigator?.push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const GeneralSettingsPage(),
          ),
        );
      },
      onBackup: () {
        debugPrint('📱 Menu: Backup');
        // Navigate to data management page
        final navigator = PushNotificationService.navigatorKey.currentState;
        navigator?.push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const DataManagementPage(),
          ),
        );
      },
      onRestore: () {
        debugPrint('📱 Menu: Restore');
        final navigator = PushNotificationService.navigatorKey.currentState;
        navigator?.push<void>(
          MaterialPageRoute<void>(
            builder: (context) => const DataManagementPage(),
          ),
        );
      },
      child: MaterialApp(
        title: 'Obsession Tracker',
        debugShowCheckedModeBanner: false,
        navigatorKey: PushNotificationService.navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        home: !_isInitialized
            ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : _isUnlocked
                ? Stack(
                    children: [
                      Builder(
                        builder: (context) {
                          // Apply platform-specific optimizations
                          context.applyPlatformOptimizations();
                          return const AchievementNotificationListener(
                            child: AdaptiveHomePage(),
                          );
                        },
                      ),
                      // Privacy screen overlay - covers content in app switcher
                      if (_showPrivacyScreen)
                        const _PrivacyScreenOverlay(),
                    ],
                  )
                : BiometricLockScreen(
                    lockService: _lockService,
                    onUnlocked: () {
                      setState(() {
                        _isUnlocked = true;
                      });
                      debugPrint('✅ App unlocked successfully');
                    },
                  ),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          // Apply responsive text scaling based on device type
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(context.optimalTextScaleFactor),
          ),
          child: child!,
        ),
      ),
    );
  }
}

/// Privacy screen overlay that covers sensitive content when app goes to background.
/// This appears in the app switcher instead of the actual app content.
class _PrivacyScreenOverlay extends StatelessWidget {
  const _PrivacyScreenOverlay();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'Obsession Tracker',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Content protected',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
