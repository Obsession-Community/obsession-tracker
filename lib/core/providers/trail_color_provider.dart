import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/session_statistics.dart';
import 'package:obsession_tracker/core/models/trail_color_scheme.dart';
import 'package:obsession_tracker/core/models/trail_segment.dart';
import 'package:obsession_tracker/core/services/trail_color_service.dart';

/// State for trail color coding
@immutable
class TrailColorState {
  const TrailColorState({
    this.currentScheme = const TrailColorScheme(
      name: 'Single - Blue',
      mode: TrailColorMode.single,
      colors: <Color>[Color(0xFF2196F3)],
      thresholds: <double>[],
    ),
    this.availableSchemes = const <TrailColorScheme>[],
    this.customSchemes = const <TrailColorScheme>[],
    this.coloredSegments = const <String, TrailSegmentCollection>{},
    this.isEnabled = true,
    this.showLegend = false,
    this.useAccessibilityColors = false,
    this.isLoading = false,
    this.error,
  });

  /// Currently selected color scheme
  final TrailColorScheme currentScheme;

  /// Available predefined color schemes
  final List<TrailColorScheme> availableSchemes;

  /// User-created custom color schemes
  final List<TrailColorScheme> customSchemes;

  /// Colored segments by session ID
  final Map<String, TrailSegmentCollection> coloredSegments;

  /// Whether color coding is enabled
  final bool isEnabled;

  /// Whether to show color legend
  final bool showLegend;

  /// Whether to use accessibility-friendly colors
  final bool useAccessibilityColors;

  /// Loading state
  final bool isLoading;

  /// Error message if any
  final String? error;

  /// Get all available schemes (predefined + custom)
  List<TrailColorScheme> get allSchemes => <TrailColorScheme>[
        ...availableSchemes,
        ...customSchemes,
      ];

  /// Get schemes for current accessibility setting
  List<TrailColorScheme> get filteredSchemes {
    if (useAccessibilityColors) {
      return allSchemes
          .where((TrailColorScheme scheme) => scheme.isAccessibilityFriendly)
          .toList();
    }
    return allSchemes;
  }

  /// Get segments for a specific session
  TrailSegmentCollection? getSegmentsForSession(String sessionId) =>
      coloredSegments[sessionId];

  TrailColorState copyWith({
    TrailColorScheme? currentScheme,
    List<TrailColorScheme>? availableSchemes,
    List<TrailColorScheme>? customSchemes,
    Map<String, TrailSegmentCollection>? coloredSegments,
    bool? isEnabled,
    bool? showLegend,
    bool? useAccessibilityColors,
    bool? isLoading,
    String? error,
  }) =>
      TrailColorState(
        currentScheme: currentScheme ?? this.currentScheme,
        availableSchemes: availableSchemes ?? this.availableSchemes,
        customSchemes: customSchemes ?? this.customSchemes,
        coloredSegments: coloredSegments ?? this.coloredSegments,
        isEnabled: isEnabled ?? this.isEnabled,
        showLegend: showLegend ?? this.showLegend,
        useAccessibilityColors:
            useAccessibilityColors ?? this.useAccessibilityColors,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrailColorState &&
          runtimeType == other.runtimeType &&
          currentScheme == other.currentScheme &&
          isEnabled == other.isEnabled &&
          showLegend == other.showLegend &&
          useAccessibilityColors == other.useAccessibilityColors;

  @override
  int get hashCode =>
      currentScheme.hashCode ^
      isEnabled.hashCode ^
      showLegend.hashCode ^
      useAccessibilityColors.hashCode;
}

/// Provider for trail color state
final trailColorProvider =
    NotifierProvider<TrailColorNotifier, TrailColorState>(
        TrailColorNotifier.new);

/// Notifier for trail color state management
class TrailColorNotifier extends Notifier<TrailColorState> {
  final TrailColorService _colorService = TrailColorService.instance;

  @override
  TrailColorState build() {
    _initialize();
    return const TrailColorState();
  }

  /// Initialize the provider
  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await _loadPreferences();
      await _loadAvailableSchemes();
      await _loadCustomSchemes();
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to initialize: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Load user preferences
  Future<void> _loadPreferences() async {
    // For now, use default preferences
    // In a full implementation, you would use SharedPreferences or another persistence solution
    state = state.copyWith(
      isEnabled: true,
      showLegend: false,
      useAccessibilityColors: false,
    );
  }

  /// Load available predefined schemes
  Future<void> _loadAvailableSchemes() async {
    final List<TrailColorScheme> schemes = PredefinedColorSchemes.all;
    state = state.copyWith(availableSchemes: schemes);
  }

  /// Load custom user schemes
  Future<void> _loadCustomSchemes() async {
    // For now, start with empty custom schemes
    // In a full implementation, you would load from persistent storage
    state = state.copyWith(customSchemes: <TrailColorScheme>[]);
  }

  /// Set the current color scheme
  Future<void> setColorScheme(TrailColorScheme scheme) async {
    state = state.copyWith(currentScheme: scheme);
    await _saveCurrentScheme();
    _colorService.clearCache(); // Clear cache when scheme changes
  }

  /// Toggle color coding enabled/disabled
  Future<void> toggleEnabled() async {
    final bool newEnabled = !state.isEnabled;
    state = state.copyWith(isEnabled: newEnabled);
    // In a full implementation, save to persistent storage
  }

  /// Toggle legend visibility
  Future<void> toggleLegend() async {
    final bool newShowLegend = !state.showLegend;
    state = state.copyWith(showLegend: newShowLegend);
    // In a full implementation, save to persistent storage
  }

  /// Toggle accessibility colors
  Future<void> toggleAccessibilityColors() async {
    final bool newUseAccessibility = !state.useAccessibilityColors;
    state = state.copyWith(useAccessibilityColors: newUseAccessibility);
    // In a full implementation, save to persistent storage

    // Switch to accessibility-friendly scheme if needed
    if (newUseAccessibility && !state.currentScheme.isAccessibilityFriendly) {
      final TrailColorScheme? accessibleScheme = state.availableSchemes
          .where((TrailColorScheme scheme) =>
              scheme.isAccessibilityFriendly &&
              scheme.mode == state.currentScheme.mode)
          .firstOrNull;

      if (accessibleScheme != null) {
        await setColorScheme(accessibleScheme);
      }
    }
  }

  /// Generate colored segments for a session
  Future<void> generateSegments(
    String sessionId,
    List<Breadcrumb> breadcrumbs,
    SessionStatistics? statistics,
  ) async {
    if (!state.isEnabled || breadcrumbs.length < 2) {
      return;
    }

    try {
      final List<TrailSegment> segments = _colorService.generateColoredSegments(
        breadcrumbs,
        state.currentScheme,
        statistics,
      );

      final TrailSegmentCollection collection = TrailSegmentCollection(
        sessionId: sessionId,
        segments: segments,
      );

      final Map<String, TrailSegmentCollection> updatedSegments =
          Map<String, TrailSegmentCollection>.from(state.coloredSegments);
      updatedSegments[sessionId] = collection;

      state = state.copyWith(coloredSegments: updatedSegments);
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to generate segments: $e');
    }
  }

  /// Update segments for new breadcrumb
  Future<void> updateSegmentsForNewBreadcrumb(
    String sessionId,
    Breadcrumb newBreadcrumb,
    List<Breadcrumb> allBreadcrumbs,
    SessionStatistics? statistics,
  ) async {
    if (!state.isEnabled || allBreadcrumbs.length < 2) {
      return;
    }

    final TrailSegmentCollection? existingCollection =
        state.coloredSegments[sessionId];
    if (existingCollection == null) {
      await generateSegments(sessionId, allBreadcrumbs, statistics);
      return;
    }

    // Add new segment for the latest breadcrumb
    if (allBreadcrumbs.length >= 2) {
      final Breadcrumb previousBreadcrumb =
          allBreadcrumbs[allBreadcrumbs.length - 2];

      final Color segmentColor = _colorService.calculateColor(
        newBreadcrumb,
        state.currentScheme,
        statistics,
        allBreadcrumbs,
      );

      final TrailSegment newSegment = TrailSegment.fromBreadcrumbs(
        id: '${previousBreadcrumb.id}_${newBreadcrumb.id}',
        startBreadcrumb: previousBreadcrumb,
        endBreadcrumb: newBreadcrumb,
        color: segmentColor,
      );

      existingCollection.addSegment(newSegment);

      final Map<String, TrailSegmentCollection> updatedSegments =
          Map<String, TrailSegmentCollection>.from(state.coloredSegments);
      updatedSegments[sessionId] = existingCollection;

      state = state.copyWith(coloredSegments: updatedSegments);
    }
  }

  /// Clear segments for a session
  void clearSegments(String sessionId) {
    final Map<String, TrailSegmentCollection> updatedSegments =
        Map<String, TrailSegmentCollection>.from(state.coloredSegments)
          ..remove(sessionId);
    state = state.copyWith(coloredSegments: updatedSegments);
  }

  /// Clear all segments
  void clearAllSegments() {
    state = state.copyWith(coloredSegments: <String, TrailSegmentCollection>{});
    _colorService.clearCache();
  }

  /// Add custom color scheme
  Future<void> addCustomScheme(TrailColorScheme scheme) async {
    if (!_colorService.validateColorScheme(scheme)) {
      state = state.copyWith(error: 'Invalid color scheme');
      return;
    }

    final List<TrailColorScheme> updatedCustomSchemes =
        List<TrailColorScheme>.from(state.customSchemes)..add(scheme);

    state = state.copyWith(customSchemes: updatedCustomSchemes);
    await _saveCustomSchemes();
  }

  /// Remove custom color scheme
  Future<void> removeCustomScheme(String schemeName) async {
    final List<TrailColorScheme> updatedCustomSchemes = state.customSchemes
        .where((TrailColorScheme scheme) => scheme.name != schemeName)
        .toList();

    state = state.copyWith(customSchemes: updatedCustomSchemes);
    await _saveCustomSchemes();
  }

  /// Get color legend for current scheme
  List<ColorLegendItem> getColorLegend(SessionStatistics? statistics) =>
      _colorService.getColorLegend(state.currentScheme, statistics);

  /// Save current scheme preference
  Future<void> _saveCurrentScheme() async {
    // In a full implementation, save to persistent storage
  }

  /// Save custom schemes
  Future<void> _saveCustomSchemes() async {
    // In a full implementation, save to persistent storage
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    state = const TrailColorState();

    // In a full implementation, clear persistent storage

    _colorService.clearCache();
    await _loadAvailableSchemes();
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith();
  }
}
