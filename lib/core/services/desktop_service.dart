import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obsession_tracker/core/services/navigation_service.dart';
import 'package:obsession_tracker/features/settings/presentation/pages/general_settings_page.dart';

/// Service for desktop-specific functionality
class DesktopService {
  /// Check if running on desktop platform
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Get keyboard shortcuts for desktop navigation
  /// Uses Cmd on macOS, Ctrl on Windows/Linux
  static Map<ShortcutActivator, Intent> getKeyboardShortcuts() {
    final useMeta = Platform.isMacOS;
    return {
      SingleActivator(LogicalKeyboardKey.digit1,
          control: !useMeta, meta: useMeta): const NavigateToHomeIntent(),
      SingleActivator(LogicalKeyboardKey.digit2,
          control: !useMeta, meta: useMeta): const NavigateToPhotosIntent(),
      SingleActivator(LogicalKeyboardKey.digit3,
          control: !useMeta, meta: useMeta): const NavigateToSessionsIntent(),
      SingleActivator(LogicalKeyboardKey.digit4,
          control: !useMeta, meta: useMeta): const NavigateToTrackingIntent(),
      SingleActivator(LogicalKeyboardKey.keyN,
          control: !useMeta, meta: useMeta): const NewSessionIntent(),
      SingleActivator(LogicalKeyboardKey.keyP,
          control: !useMeta, meta: useMeta): const PrintSessionIntent(),
      SingleActivator(LogicalKeyboardKey.keyE,
          control: !useMeta, meta: useMeta): const ExportSessionIntent(),
      SingleActivator(LogicalKeyboardKey.comma,
          control: !useMeta, meta: useMeta): const OpenSettingsIntent(),
      SingleActivator(LogicalKeyboardKey.keyF,
          control: !useMeta, meta: useMeta): const SearchIntent(),
    };
  }

  /// Get keyboard actions for desktop navigation
  static Map<Type, Action<Intent>> getKeyboardActions(BuildContext context) => {
        NavigateToHomeIntent: CallbackAction<NavigateToHomeIntent>(
          onInvoke: (_) => _navigateToTab(context, 0),
        ),
        NavigateToPhotosIntent: CallbackAction<NavigateToPhotosIntent>(
          onInvoke: (_) => _navigateToTab(context, 1),
        ),
        NavigateToSessionsIntent: CallbackAction<NavigateToSessionsIntent>(
          onInvoke: (_) => _navigateToTab(context, 2),
        ),
        NavigateToTrackingIntent: CallbackAction<NavigateToTrackingIntent>(
          onInvoke: (_) => _navigateToTab(context, 3),
        ),
        NewSessionIntent: CallbackAction<NewSessionIntent>(
          onInvoke: (_) => _startNewSession(context),
        ),
        PrintSessionIntent: CallbackAction<PrintSessionIntent>(
          onInvoke: (_) => _showPrintDialog(context),
        ),
        ExportSessionIntent: CallbackAction<ExportSessionIntent>(
          onInvoke: (_) => _showExportDialog(context),
        ),
        OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
          onInvoke: (_) => _openSettings(context),
        ),
        SearchIntent: CallbackAction<SearchIntent>(
          onInvoke: (_) => _openSearch(context),
        ),
      };

  /// Navigate to a specific tab using NavigationService
  static void _navigateToTab(BuildContext context, int tabIndex) {
    debugPrint('⌨️ Keyboard shortcut: Navigate to tab $tabIndex');
    NavigationService().switchToTab(tabIndex);
  }

  /// Start a new session - navigate to sessions tab
  static void _startNewSession(BuildContext context) {
    debugPrint('⌨️ Keyboard shortcut: New session');
    // Navigate to sessions tab where user can start a new session
    NavigationService().switchToSessionsTab();
  }

  /// Show print dialog
  static void _showPrintDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Print functionality coming soon')),
    );
  }

  /// Show export dialog
  static void _showExportDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  /// Open settings page
  static void _openSettings(BuildContext context) {
    debugPrint('⌨️ Keyboard shortcut: Open settings');
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const GeneralSettingsPage(),
      ),
    );
  }

  /// Open search - navigate to map for location search
  static void _openSearch(BuildContext context) {
    debugPrint('⌨️ Keyboard shortcut: Open search');
    // Navigate to map tab where search is available
    NavigationService().switchToMapTab();
  }
}

/// Intent classes for keyboard shortcuts
class NavigateToHomeIntent extends Intent {
  const NavigateToHomeIntent();
}

class NavigateToPhotosIntent extends Intent {
  const NavigateToPhotosIntent();
}

class NavigateToSessionsIntent extends Intent {
  const NavigateToSessionsIntent();
}

class NavigateToTrackingIntent extends Intent {
  const NavigateToTrackingIntent();
}

class NewSessionIntent extends Intent {
  const NewSessionIntent();
}

class PrintSessionIntent extends Intent {
  const PrintSessionIntent();
}

class ExportSessionIntent extends Intent {
  const ExportSessionIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}
