import 'package:flutter/material.dart';

/// Desktop layout presets for consistent desktop UI patterns
class DesktopLayoutPresets {
  /// Standard desktop layout with navigation panel and content area
  static Widget standard({
    required Widget navigation,
    required Widget content,
    double navigationWidth = 280,
    Color? backgroundColor,
    Color? dividerColor,
  }) =>
      Row(
        children: [
          // Navigation panel
          Container(
            width: navigationWidth,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: BorderSide(
                  color: dividerColor ?? Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: navigation,
          ),

          // Content area
          Expanded(
            child: Container(
              color: backgroundColor,
              child: content,
            ),
          ),
        ],
      );

  /// Two-panel layout with sidebar and main content
  static Widget twoPanel({
    required Widget sidebar,
    required Widget content,
    double sidebarWidth = 320,
    Color? backgroundColor,
    Color? dividerColor,
  }) =>
      Row(
        children: [
          // Sidebar
          Container(
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: BorderSide(
                  color: dividerColor ?? Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: sidebar,
          ),

          // Main content
          Expanded(
            child: Container(
              color: backgroundColor,
              child: content,
            ),
          ),
        ],
      );

  /// Three-panel layout with navigation, sidebar, and content
  static Widget threePanel({
    required Widget navigation,
    required Widget sidebar,
    required Widget content,
    double navigationWidth = 240,
    double sidebarWidth = 280,
    Color? backgroundColor,
    Color? dividerColor,
  }) =>
      Row(
        children: [
          // Navigation panel
          Container(
            width: navigationWidth,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: BorderSide(
                  color: dividerColor ?? Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: navigation,
          ),

          // Sidebar
          Container(
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: BorderSide(
                  color: dividerColor ?? Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: sidebar,
          ),

          // Main content
          Expanded(
            child: Container(
              color: backgroundColor,
              child: content,
            ),
          ),
        ],
      );

  /// Master-detail layout for desktop
  static Widget masterDetail({
    required Widget master,
    required Widget detail,
    double masterWidth = 360,
    Color? backgroundColor,
    Color? dividerColor,
  }) =>
      Row(
        children: [
          // Master panel
          Container(
            width: masterWidth,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: BorderSide(
                  color: dividerColor ?? Colors.grey.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: master,
          ),

          // Detail panel
          Expanded(
            child: Container(
              color: backgroundColor,
              child: detail,
            ),
          ),
        ],
      );

  /// Full-width layout for desktop
  static Widget fullWidth({
    required Widget content,
    EdgeInsets padding = const EdgeInsets.all(24),
    Color? backgroundColor,
  }) =>
      Container(
        color: backgroundColor,
        padding: padding,
        child: content,
      );
}
