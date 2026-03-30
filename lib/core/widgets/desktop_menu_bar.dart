import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// macOS/Desktop menu bar for the application
///
/// Provides native menu bar integration for desktop platforms with
/// standard menu items like File, Edit, View, and Window.
class DesktopMenuBar extends StatelessWidget {
  const DesktopMenuBar({
    required this.child,
    this.onBackup,
    this.onRestore,
    this.onOpenSettings,
    super.key,
  });

  final Widget child;

  /// Callbacks for menu actions
  final VoidCallback? onBackup;
  final VoidCallback? onRestore;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    // Only show menu bar on desktop platforms
    if (kIsWeb || !(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return child;
    }

    return PlatformMenuBar(
      menus: _buildMenus(context),
      child: child,
    );
  }

  List<PlatformMenu> _buildMenus(BuildContext context) {
    final isMacOS = Platform.isMacOS;
    final menus = <PlatformMenu>[];

    // App Menu (macOS only - About, Settings, Quit)
    if (isMacOS) {
      menus.add(
        PlatformMenu(
          label: 'Obsession Tracker',
          menus: [
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.about,
            ),
            PlatformMenuItem(
              label: 'Settings...',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.comma,
                meta: true,
              ),
              onSelected: onOpenSettings,
            ),
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.quit,
            ),
          ],
        ),
      );
    }

    // File Menu
    menus.add(
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItem(
            label: 'Backup All Data...',
            onSelected: onBackup,
          ),
          PlatformMenuItem(
            label: 'Restore from Backup...',
            onSelected: onRestore,
          ),
        ],
      ),
    );

    // Edit Menu (standard edit commands)
    menus.add(
      PlatformMenu(
        label: 'Edit',
        menus: [
          PlatformMenuItem(
            label: 'Cut',
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyX,
              meta: isMacOS,
              control: !isMacOS,
            ),
            onSelected: () {},
          ),
          PlatformMenuItem(
            label: 'Copy',
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyC,
              meta: isMacOS,
              control: !isMacOS,
            ),
            onSelected: () {},
          ),
          PlatformMenuItem(
            label: 'Paste',
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyV,
              meta: isMacOS,
              control: !isMacOS,
            ),
            onSelected: () {},
          ),
          PlatformMenuItem(
            label: 'Select All',
            shortcut: SingleActivator(
              LogicalKeyboardKey.keyA,
              meta: isMacOS,
              control: !isMacOS,
            ),
            onSelected: () {},
          ),
        ],
      ),
    );

    // Window Menu
    menus.add(
      PlatformMenu(
        label: 'Window',
        menus: isMacOS
            ? const [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.minimizeWindow,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.zoomWindow,
                ),
              ]
            : [
                PlatformMenuItem(
                  label: 'Minimize',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyM,
                    control: true,
                  ),
                  onSelected: () {},
                ),
              ],
      ),
    );

    // Help Menu
    final helpMenuItems = <PlatformMenuItem>[
      PlatformMenuItem(
        label: 'Obsession Tracker Help',
        onSelected: () {
          // TODO(desktop): Open help URL or show help dialog
        },
      ),
    ];

    // Settings in Help menu for non-macOS platforms
    if (!isMacOS) {
      helpMenuItems.add(
        PlatformMenuItem(
          label: 'Settings...',
          shortcut: const SingleActivator(
            LogicalKeyboardKey.comma,
            control: true,
          ),
          onSelected: onOpenSettings,
        ),
      );
    }

    menus.add(
      PlatformMenu(
        label: 'Help',
        menus: helpMenuItems,
      ),
    );

    return menus;
  }
}
