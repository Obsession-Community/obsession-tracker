import 'package:flutter/material.dart';

/// Service for managing global navigation and tab switching
class NavigationService {
  static final NavigationService _instance = NavigationService._();
  factory NavigationService() {
    debugPrint('🔧 NavigationService: Returning singleton instance (hashCode: ${_instance.hashCode})');
    return _instance;
  }
  NavigationService._() {
    debugPrint('🔧 NavigationService: Creating singleton instance');
  }

  /// Global navigator key for the MaterialApp
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Notifier for the selected tab index in the bottom navigation
  final ValueNotifier<int> selectedTabIndex = ValueNotifier<int>(0);

  /// Switch to a specific tab
  void switchToTab(int index) {
    debugPrint('🔄 NavigationService: Switching to tab $index (current: ${selectedTabIndex.value})');
    selectedTabIndex.value = index;
    debugPrint('✅ NavigationService: Switched to tab $index');
  }

  /// Switch to the Map tab (index 0)
  void switchToMapTab() {
    switchToTab(0);
  }

  /// Switch to the Sessions tab (index 1)
  void switchToSessionsTab() {
    switchToTab(1);
  }

  /// Switch to the Routes tab (index 3)
  void switchToRoutesTab() {
    switchToTab(3);
  }

  /// Get the current context
  BuildContext? get currentContext => navigatorKey.currentContext;

  /// Pop all routes until we reach the first route
  void popToRoot() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }
}
