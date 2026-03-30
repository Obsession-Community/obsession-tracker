import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/session_template_models.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:uuid/uuid.dart';

/// Service for managing session templates and quick-start functionality
class SessionTemplateService {
  SessionTemplateService._();
  static SessionTemplateService? _instance;
  static SessionTemplateService get instance =>
      _instance ??= SessionTemplateService._();

  final DatabaseService _databaseService = DatabaseService();
  final Uuid _uuid = const Uuid();

  /// Get all available session templates
  Future<List<SessionTemplate>> getAllTemplates() async {
    try {
      // Get custom templates from database
      final customTemplates = await _getCustomTemplates();

      // Get built-in templates
      final builtInTemplates = _getBuiltInTemplates();

      // Combine and sort by usage and category
      final allTemplates = [...builtInTemplates, ...customTemplates];
      allTemplates.sort((a, b) {
        // Sort by usage count (descending), then by name
        final usageComparison = b.usageCount.compareTo(a.usageCount);
        if (usageComparison != 0) return usageComparison;
        return a.name.compareTo(b.name);
      });

      return allTemplates;
    } catch (e) {
      debugPrint('Error getting templates: $e');
      return _getBuiltInTemplates(); // Fallback to built-in templates
    }
  }

  /// Get templates by category
  Future<List<SessionTemplate>> getTemplatesByCategory(
      TemplateCategory category) async {
    final allTemplates = await getAllTemplates();
    return allTemplates.where((t) => t.category == category).toList();
  }

  /// Get templates by activity type
  Future<List<SessionTemplate>> getTemplatesByActivity(
      ActivityType activityType) async {
    final allTemplates = await getAllTemplates();
    return allTemplates.where((t) => t.activityType == activityType).toList();
  }

  /// Search templates by name, description, or tags
  Future<List<SessionTemplate>> searchTemplates(String query) async {
    if (query.trim().isEmpty) return getAllTemplates();

    final allTemplates = await getAllTemplates();
    final lowerQuery = query.toLowerCase();

    return allTemplates
        .where((template) =>
            template.name.toLowerCase().contains(lowerQuery) ||
            template.description.toLowerCase().contains(lowerQuery) ||
            template.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)))
        .toList();
  }

  /// Get a specific template by ID
  Future<SessionTemplate?> getTemplate(String templateId) async {
    final allTemplates = await getAllTemplates();
    try {
      return allTemplates.firstWhere((t) => t.id == templateId);
    } catch (e) {
      return null;
    }
  }

  /// Create a new custom template
  Future<SessionTemplate> createCustomTemplate({
    required String name,
    required String description,
    required TemplateCategory category,
    required ActivityType activityType,
    required SessionTemplateSettings settings,
    String? icon,
    Duration? estimatedDuration,
    double? estimatedDistance,
    DifficultyLevel difficultyLevel = DifficultyLevel.moderate,
    List<String> tags = const [],
  }) async {
    final template = SessionTemplate(
      id: _uuid.v4(),
      name: name,
      description: description,
      category: category,
      activityType: activityType,
      settings: settings,
      icon: icon,
      estimatedDuration: estimatedDuration,
      estimatedDistance: estimatedDistance,
      difficultyLevel: difficultyLevel,
      tags: tags,
      isCustom: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _saveCustomTemplate(template);
    return template;
  }

  /// Update an existing custom template
  Future<SessionTemplate> updateCustomTemplate(SessionTemplate template) async {
    if (!template.isCustom) {
      throw Exception('Cannot update built-in templates');
    }

    final updatedTemplate = template.copyWith(
      updatedAt: DateTime.now(),
    );

    await _saveCustomTemplate(updatedTemplate);
    return updatedTemplate;
  }

  /// Delete a custom template
  Future<bool> deleteCustomTemplate(String templateId) async {
    try {
      final template = await getTemplate(templateId);
      if (template == null || !template.isCustom) {
        return false;
      }

      await _deleteCustomTemplate(templateId);
      return true;
    } catch (e) {
      debugPrint('Error deleting template: $e');
      return false;
    }
  }

  /// Create a session from a template
  Future<SessionCreationResult> createSessionFromTemplate(
    String templateId, {
    String? customName,
    String? customDescription,
    Map<String, dynamic>? settingsOverrides,
  }) async {
    try {
      final template = await getTemplate(templateId);
      if (template == null) {
        return const SessionCreationResult(
          success: false,
          errors: ['Template not found'],
        );
      }

      // Apply settings overrides if provided
      var settings = template.settings;
      if (settingsOverrides != null) {
        settings = _applySettingsOverrides(settings, settingsOverrides);
      }

      // Create the session
      final sessionId = _uuid.v4();
      final session = TrackingSession.create(
        id: sessionId,
        name: customName ?? template.name,
        description: customDescription ?? template.description,
        accuracyThreshold: settings.accuracyThreshold,
        recordingInterval: settings.recordingInterval,
        minimumSpeed: settings.minimumSpeed,
        recordAltitude: settings.recordAltitude,
        recordSpeed: settings.recordSpeed,
        recordHeading: settings.recordHeading,
      );

      // Save the session
      await _databaseService.insertSession(session);

      // Update template usage statistics
      await _updateTemplateUsage(templateId);

      return SessionCreationResult(
        success: true,
        sessionId: sessionId,
      );
    } catch (e) {
      debugPrint('Error creating session from template: $e');
      return SessionCreationResult(
        success: false,
        errors: ['Failed to create session: $e'],
      );
    }
  }

  /// Get quick-start configurations
  Future<List<QuickStartConfig>> getQuickStartConfigs() async =>
      // For now, return some default quick-start configs
      // In a full implementation, these would be stored in the database
      [
        const QuickStartConfig(
          templateId: 'hiking_basic',
          name: 'Quick Hike',
          description: 'Start a basic hiking session with standard settings',
          icon: 'hiking',
          sortOrder: 1,
        ),
        const QuickStartConfig(
          templateId: 'running_fitness',
          name: 'Fitness Run',
          description: 'Start a fitness-focused running session',
          icon: 'running',
          sortOrder: 2,
        ),
        const QuickStartConfig(
          templateId: 'walking_leisure',
          name: 'Casual Walk',
          description: 'Start a leisurely walking session',
          icon: 'walking',
          autoStart: true,
          confirmBeforeStart: false,
          sortOrder: 3,
        ),
      ];

  /// Get template usage statistics
  Future<TemplateUsageStats?> getTemplateStats(String templateId) async {
    try {
      // This would query the database for usage statistics
      // For now, return a simplified implementation
      final template = await getTemplate(templateId);
      if (template == null) return null;

      return TemplateUsageStats(
        templateId: templateId,
        totalUsage: template.usageCount,
        lastUsed: template.lastUsed,
        averageSessionDuration: template.estimatedDuration ?? Duration.zero,
        averageSessionDistance: template.estimatedDistance ?? 0.0,
        successRate: 85.0, // Would calculate from actual session data
        userRating: 4.2, // Would get from user ratings
      );
    } catch (e) {
      debugPrint('Error getting template stats: $e');
      return null;
    }
  }

  /// Create a template from an existing session
  Future<SessionTemplate> createTemplateFromSession(
    String sessionId, {
    required String templateName,
    required String templateDescription,
    required TemplateCategory category,
    required ActivityType activityType,
    List<String> tags = const [],
  }) async {
    final session = await _databaseService.getSession(sessionId);
    if (session == null) {
      throw Exception('Session not found');
    }

    // Create template settings from session
    final settings = SessionTemplateSettings(
      accuracyThreshold: session.accuracyThreshold,
      recordingInterval: session.recordingInterval,
      minimumSpeed: session.minimumSpeed,
      recordAltitude: session.recordAltitude,
      recordSpeed: session.recordSpeed,
      recordHeading: session.recordHeading,
    );

    return createCustomTemplate(
      name: templateName,
      description: templateDescription,
      category: category,
      activityType: activityType,
      settings: settings,
      estimatedDuration: Duration(milliseconds: session.totalDuration),
      estimatedDistance: session.totalDistance,
      tags: tags,
    );
  }

  // Private helper methods

  Future<List<SessionTemplate>> _getCustomTemplates() async {
    try {
      // This would query the database for custom templates
      // For now, return an empty list
      return [];
    } catch (e) {
      debugPrint('Error getting custom templates: $e');
      return [];
    }
  }

  List<SessionTemplate> _getBuiltInTemplates() => [
        // Hiking templates
        const SessionTemplate(
          id: 'hiking_basic',
          name: 'Basic Hiking',
          description:
              'Standard hiking session with balanced settings for most trails',
          category: TemplateCategory.hiking,
          activityType: ActivityType.hiking,
          settings: SessionTemplateSettings(
            accuracyThreshold: 10.0,
            recordingInterval: 5,
            minimumSpeed: 0.5,
            recordAltitude: true,
            recordSpeed: true,
            recordHeading: true,
            autoPause: true,
            pauseThreshold: 0.3,
          ),
          icon: 'hiking',
          estimatedDuration: Duration(hours: 3),
          estimatedDistance: 8000,
          tags: ['hiking', 'trail', 'outdoor'],
          isBuiltIn: true,
        ),

        const SessionTemplate(
          id: 'hiking_precision',
          name: 'Precision Hiking',
          description:
              'High-accuracy hiking for detailed trail mapping and research',
          category: TemplateCategory.hiking,
          activityType: ActivityType.hiking,
          settings: SessionTemplateSettings(
            accuracyThreshold: 5.0,
            recordingInterval: 3,
            minimumSpeed: 0.2,
            recordAltitude: true,
            recordSpeed: true,
            recordHeading: true,
            batteryOptimization: BatteryOptimization.performance,
            waypointSettings: WaypointTemplateSettings(
              autoCreateWaypoints: true,
              waypointInterval: Duration(minutes: 5),
            ),
          ),
          icon: 'precision',
          estimatedDuration: Duration(hours: 4),
          estimatedDistance: 10000,
          difficultyLevel: DifficultyLevel.hard,
          tags: ['hiking', 'precision', 'mapping', 'research'],
          isBuiltIn: true,
        ),

        // Running templates
        const SessionTemplate(
          id: 'running_fitness',
          name: 'Fitness Running',
          description:
              'Optimized for fitness tracking with performance metrics',
          category: TemplateCategory.running,
          activityType: ActivityType.running,
          settings: SessionTemplateSettings(
            accuracyThreshold: 8.0,
            recordingInterval: 2,
            minimumSpeed: 1.5,
            recordAltitude: true,
            recordSpeed: true,
            recordHeading: false,
            autoPause: true,
            pauseThreshold: 1.0,
            autoStop: true,
            stopThreshold: Duration(minutes: 3),
            batteryOptimization: BatteryOptimization.performance,
            notificationSettings: NotificationTemplateSettings(
              enableDistanceNotifications: true,
              enableTimeNotifications: true,
              timeInterval: Duration(minutes: 5),
            ),
          ),
          icon: 'running',
          estimatedDuration: Duration(minutes: 45),
          estimatedDistance: 8000,
          tags: ['running', 'fitness', 'cardio'],
          isBuiltIn: true,
        ),

        // Walking templates
        const SessionTemplate(
          id: 'walking_leisure',
          name: 'Leisure Walking',
          description: 'Casual walking with battery-optimized settings',
          category: TemplateCategory.walking,
          activityType: ActivityType.walking,
          settings: SessionTemplateSettings(
            accuracyThreshold: 15.0,
            recordingInterval: 10,
            minimumSpeed: 0.3,
            recordAltitude: false,
            recordSpeed: true,
            recordHeading: false,
            autoPause: true,
            pauseThreshold: 0.2,
            batteryOptimization: BatteryOptimization.maximum,
            gpsMode: GpsMode.balanced,
          ),
          icon: 'walking',
          estimatedDuration: Duration(hours: 1),
          estimatedDistance: 3000,
          difficultyLevel: DifficultyLevel.easy,
          tags: ['walking', 'leisure', 'casual'],
          isBuiltIn: true,
        ),

        // Cycling templates
        const SessionTemplate(
          id: 'cycling_road',
          name: 'Road Cycling',
          description: 'Optimized for road cycling with speed tracking',
          category: TemplateCategory.cycling,
          activityType: ActivityType.cycling,
          settings: SessionTemplateSettings(
            accuracyThreshold: 12.0,
            recordingInterval: 3,
            minimumSpeed: 2.0,
            recordAltitude: true,
            recordSpeed: true,
            recordHeading: true,
            autoPause: true,
            pauseThreshold: 1.5,
            notificationSettings: NotificationTemplateSettings(
              enableSpeedAlerts: true,
              speedAlertThreshold: 15.0,
            ),
          ),
          icon: 'cycling',
          estimatedDuration: Duration(hours: 2),
          estimatedDistance: 40000,
          tags: ['cycling', 'road', 'speed'],
          isBuiltIn: true,
        ),

        // Photography templates
        const SessionTemplate(
          id: 'photography_nature',
          name: 'Nature Photography',
          description:
              'Designed for photography sessions with automatic waypoints',
          category: TemplateCategory.photography,
          activityType: ActivityType.photography,
          settings: SessionTemplateSettings(
            accuracyThreshold: 8.0,
            recordingInterval: 15,
            minimumSpeed: 0.1,
            recordAltitude: true,
            recordSpeed: false,
            recordHeading: true,
            waypointSettings: WaypointTemplateSettings(
              autoPhotoWaypoints: true,
              photoInterval: Duration(minutes: 2),
              quickWaypointTypes: ['photo', 'interest'],
            ),
          ),
          icon: 'camera',
          estimatedDuration: Duration(hours: 3),
          estimatedDistance: 5000,
          difficultyLevel: DifficultyLevel.easy,
          tags: ['photography', 'nature', 'scenic'],
          isBuiltIn: true,
        ),

        // Urban exploration
        const SessionTemplate(
          id: 'urban_exploration',
          name: 'Urban Exploration',
          description: 'City walking and exploration with landmark tracking',
          category: TemplateCategory.urban,
          activityType: ActivityType.walking,
          settings: SessionTemplateSettings(
            accuracyThreshold: 10.0,
            recordingInterval: 8,
            minimumSpeed: 0.5,
            recordAltitude: false,
            recordSpeed: true,
            recordHeading: true,
            autoPause: true,
            pauseThreshold: 0.3,
            gpsMode: GpsMode.balanced,
            waypointSettings: WaypointTemplateSettings(
              quickWaypointTypes: ['interest', 'photo'],
            ),
          ),
          icon: 'city',
          estimatedDuration: Duration(hours: 2),
          estimatedDistance: 6000,
          difficultyLevel: DifficultyLevel.easy,
          tags: ['urban', 'city', 'exploration'],
          isBuiltIn: true,
        ),
      ];

  Future<void> _saveCustomTemplate(SessionTemplate template) async {
    // This would save the template to the database
    // For now, just log the action
    debugPrint('Saving custom template: ${template.name}');
  }

  Future<void> _deleteCustomTemplate(String templateId) async {
    // This would delete the template from the database
    debugPrint('Deleting custom template: $templateId');
  }

  Future<void> _updateTemplateUsage(String templateId) async {
    try {
      final template = await getTemplate(templateId);
      if (template != null && template.isCustom) {
        final updatedTemplate = template.copyWith(
          usageCount: template.usageCount + 1,
          lastUsed: DateTime.now(),
        );
        await _saveCustomTemplate(updatedTemplate);
      }
    } catch (e) {
      debugPrint('Error updating template usage: $e');
    }
  }

  SessionTemplateSettings _applySettingsOverrides(
          SessionTemplateSettings settings, Map<String, dynamic> overrides) =>
      // Apply any settings overrides
      SessionTemplateSettings(
        accuracyThreshold: overrides['accuracyThreshold'] as double? ??
            settings.accuracyThreshold,
        recordingInterval: overrides['recordingInterval'] as int? ??
            settings.recordingInterval,
        minimumSpeed:
            overrides['minimumSpeed'] as double? ?? settings.minimumSpeed,
        recordAltitude:
            overrides['recordAltitude'] as bool? ?? settings.recordAltitude,
        recordSpeed: overrides['recordSpeed'] as bool? ?? settings.recordSpeed,
        recordHeading:
            overrides['recordHeading'] as bool? ?? settings.recordHeading,
        autoStart: overrides['autoStart'] as bool? ?? settings.autoStart,
        autoPause: overrides['autoPause'] as bool? ?? settings.autoPause,
        autoStop: overrides['autoStop'] as bool? ?? settings.autoStop,
        pauseThreshold:
            overrides['pauseThreshold'] as double? ?? settings.pauseThreshold,
        stopThreshold: overrides['stopThreshold'] != null
            ? Duration(milliseconds: overrides['stopThreshold'] as int)
            : settings.stopThreshold,
        batteryOptimization: overrides['batteryOptimization'] != null
            ? BatteryOptimization.values.firstWhere(
                (e) => e.name == overrides['batteryOptimization'],
                orElse: () => settings.batteryOptimization)
            : settings.batteryOptimization,
        gpsMode: overrides['gpsMode'] != null
            ? GpsMode.values.firstWhere((e) => e.name == overrides['gpsMode'],
                orElse: () => settings.gpsMode)
            : settings.gpsMode,
        waypointSettings: settings.waypointSettings,
        notificationSettings: settings.notificationSettings,
        exportSettings: settings.exportSettings,
      );
}
