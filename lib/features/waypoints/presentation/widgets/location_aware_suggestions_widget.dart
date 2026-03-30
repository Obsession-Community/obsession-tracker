import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/providers/location_provider.dart';
import 'package:obsession_tracker/core/services/database_service.dart';

/// Widget that provides location-aware annotation suggestions
class LocationAwareSuggestionsWidget extends ConsumerStatefulWidget {
  const LocationAwareSuggestionsWidget({
    required this.onSuggestionSelected,
    super.key,
    this.currentNote,
    this.currentTags,
    this.maxSuggestions = 5,
  });

  final void Function(AnnotationSuggestion suggestion) onSuggestionSelected;
  final String? currentNote;
  final String? currentTags;
  final int maxSuggestions;

  @override
  ConsumerState<LocationAwareSuggestionsWidget> createState() =>
      _LocationAwareSuggestionsWidgetState();
}

class _LocationAwareSuggestionsWidgetState
    extends ConsumerState<LocationAwareSuggestionsWidget> {
  List<AnnotationSuggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(LocationAwareSuggestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentNote != widget.currentNote ||
        oldWidget.currentTags != widget.currentTags) {
      _loadSuggestions();
    }
  }

  Future<void> _loadSuggestions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final LocationState locationState = ref.read(locationProvider);
      final Position? currentPosition = locationState.currentPosition;

      if (currentPosition == null) {
        setState(() {
          _suggestions = _getGenericSuggestions();
          _isLoading = false;
        });
        return;
      }

      final List<AnnotationSuggestion> suggestions = await _generateSuggestions(
        currentPosition,
        widget.currentNote,
        widget.currentTags,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions.take(widget.maxSuggestions).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load suggestions: $e';
          _suggestions = _getGenericSuggestions();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Suggestions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_error != null) ...[
                  const Spacer(),
                  const Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.orange,
                    size: 14,
                  ),
                ],
              ],
            ),
          ),
          ...(_suggestions.map(_buildSuggestionTile)),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(AnnotationSuggestion suggestion) => InkWell(
        onTap: () => widget.onSuggestionSelected(suggestion),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: suggestion.type.color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  suggestion.type.icon,
                  color: suggestion.type.color,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (suggestion.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (suggestion.confidence > 0.7) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'High',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Future<List<AnnotationSuggestion>> _generateSuggestions(
    Position position,
    String? currentNote,
    String? currentTags,
  ) async {
    final List<AnnotationSuggestion> suggestions = <AnnotationSuggestion>[];

    // Get nearby annotations for context
    final List<AnnotationSuggestion> nearbyAnnotations =
        await _getNearbyAnnotations(position);
    suggestions.addAll(nearbyAnnotations);

    // Get time-based suggestions
    final List<AnnotationSuggestion> timeBasedSuggestions =
        _getTimeBasedSuggestions();
    suggestions.addAll(timeBasedSuggestions);

    // Get location-type suggestions
    final List<AnnotationSuggestion> locationSuggestions =
        _getLocationTypeSuggestions(position);
    suggestions.addAll(locationSuggestions);

    // Get weather-based suggestions
    final List<AnnotationSuggestion> weatherSuggestions =
        _getWeatherSuggestions();
    suggestions.addAll(weatherSuggestions);

    // Sort by confidence and relevance
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    return suggestions;
  }

  Future<List<AnnotationSuggestion>> _getNearbyAnnotations(
      Position position) async {
    try {
      final DatabaseService databaseService = DatabaseService();

      // Query for nearby photo metadata within 1km radius
      final List<Map<String, dynamic>> nearbyPhotos =
          await databaseService.database.then((db) => db.rawQuery('''
          SELECT pm.key, pm.value, pw.latitude, pw.longitude, COUNT(*) as usage_count
          FROM photo_metadata pm
          INNER JOIN photo_waypoints pw ON pm.photo_waypoint_id = pw.id
          WHERE pm.key IN (?, ?, ?)
          AND pw.latitude IS NOT NULL
          AND pw.longitude IS NOT NULL
          GROUP BY pm.key, pm.value
          ORDER BY usage_count DESC
          LIMIT 10
        ''', [
                CustomKeys.userNote,
                CustomKeys.tags,
                CustomKeys.weatherConditions
              ]));

      final List<AnnotationSuggestion> suggestions = <AnnotationSuggestion>[];

      for (final photo in nearbyPhotos) {
        final double photoLat = photo['latitude'] as double;
        final double photoLng = photo['longitude'] as double;
        final double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          photoLat,
          photoLng,
        );

        // Only include if within 1km
        if (distance <= 1000) {
          final String key = photo['key'] as String;
          final String value = photo['value'] as String;
          final int usageCount = photo['usage_count'] as int;

          // Calculate confidence based on distance and usage
          final double distanceScore = 1.0 - (distance / 1000.0);
          final double usageScore = (usageCount / 10.0).clamp(0.0, 1.0);
          final double confidence = distanceScore * 0.6 + usageScore * 0.4;

          SuggestionType type;
          String title;
          String? subtitle;

          switch (key) {
            case CustomKeys.userNote:
              type = SuggestionType.note;
              title =
                  value.length > 30 ? '${value.substring(0, 30)}...' : value;
              subtitle =
                  'Used $usageCount time${usageCount != 1 ? 's' : ''} nearby';
              break;
            case CustomKeys.tags:
              type = SuggestionType.tags;
              title = value;
              subtitle = 'Popular tag in this area';
              break;
            case CustomKeys.weatherConditions:
              type = SuggestionType.weather;
              title = value;
              subtitle = 'Common weather here';
              break;
            default:
              continue;
          }

          suggestions.add(AnnotationSuggestion(
            type: type,
            title: title,
            subtitle: subtitle,
            value: value,
            confidence: confidence,
          ));
        }
      }

      return suggestions;
    } catch (e) {
      debugPrint('Error getting nearby annotations: $e');
      return [];
    }
  }

  List<AnnotationSuggestion> _getTimeBasedSuggestions() {
    final DateTime now = DateTime.now();
    final List<AnnotationSuggestion> suggestions = <AnnotationSuggestion>[];

    // Time of day suggestions
    if (now.hour >= 5 && now.hour < 12) {
      suggestions.addAll([
        const AnnotationSuggestion(
          type: SuggestionType.tags,
          title: 'morning, sunrise',
          subtitle: 'Morning time tags',
          value: 'morning, sunrise',
          confidence: 0.8,
        ),
        const AnnotationSuggestion(
          type: SuggestionType.note,
          title: 'Beautiful morning light',
          subtitle: 'Common morning note',
          value: 'Beautiful morning light',
          confidence: 0.7,
        ),
      ]);
    } else if (now.hour >= 12 && now.hour < 17) {
      suggestions.addAll([
        const AnnotationSuggestion(
          type: SuggestionType.tags,
          title: 'afternoon, midday',
          subtitle: 'Afternoon time tags',
          value: 'afternoon, midday',
          confidence: 0.8,
        ),
      ]);
    } else if (now.hour >= 17 && now.hour < 21) {
      suggestions.addAll([
        const AnnotationSuggestion(
          type: SuggestionType.tags,
          title: 'sunset, golden hour',
          subtitle: 'Evening time tags',
          value: 'sunset, golden hour',
          confidence: 0.9,
        ),
        const AnnotationSuggestion(
          type: SuggestionType.note,
          title: 'Amazing sunset colors',
          subtitle: 'Popular sunset note',
          value: 'Amazing sunset colors',
          confidence: 0.8,
        ),
      ]);
    }

    // Season-based suggestions
    final int month = now.month;
    if (month >= 3 && month <= 5) {
      suggestions.add(const AnnotationSuggestion(
        type: SuggestionType.tags,
        title: 'spring, blooming',
        subtitle: 'Spring season tags',
        value: 'spring, blooming',
        confidence: 0.7,
      ));
    } else if (month >= 6 && month <= 8) {
      suggestions.add(const AnnotationSuggestion(
        type: SuggestionType.tags,
        title: 'summer, warm',
        subtitle: 'Summer season tags',
        value: 'summer, warm',
        confidence: 0.7,
      ));
    } else if (month >= 9 && month <= 11) {
      suggestions.add(const AnnotationSuggestion(
        type: SuggestionType.tags,
        title: 'autumn, fall colors',
        subtitle: 'Autumn season tags',
        value: 'autumn, fall colors',
        confidence: 0.7,
      ));
    } else {
      suggestions.add(const AnnotationSuggestion(
        type: SuggestionType.tags,
        title: 'winter, snow',
        subtitle: 'Winter season tags',
        value: 'winter, snow',
        confidence: 0.7,
      ));
    }

    return suggestions;
  }

  List<AnnotationSuggestion> _getLocationTypeSuggestions(Position position) {
    final List<AnnotationSuggestion> suggestions = <AnnotationSuggestion>[];

    // Altitude-based suggestions
    if (position.altitude > 2000) {
      suggestions.addAll([
        const AnnotationSuggestion(
          type: SuggestionType.tags,
          title: 'mountain, high altitude',
          subtitle: 'High elevation tags',
          value: 'mountain, high altitude',
          confidence: 0.8,
        ),
        const AnnotationSuggestion(
          type: SuggestionType.note,
          title: 'Great mountain views',
          subtitle: 'Mountain location note',
          value: 'Great mountain views',
          confidence: 0.7,
        ),
      ]);
    } else if (position.altitude > 1000) {
      suggestions.add(const AnnotationSuggestion(
        type: SuggestionType.tags,
        title: 'hills, elevated',
        subtitle: 'Hill elevation tags',
        value: 'hills, elevated',
        confidence: 0.7,
      ));
    }

    // Speed-based suggestions (if moving)
    if (position.speed > 1.0) {
      suggestions.add(const AnnotationSuggestion(
        type: SuggestionType.tags,
        title: 'hiking, trail',
        subtitle: 'Movement activity tags',
        value: 'hiking, trail',
        confidence: 0.6,
      ));
    }

    return suggestions;
  }

  List<AnnotationSuggestion> _getWeatherSuggestions() =>
      // In a real implementation, this would integrate with a weather API
      // For now, provide generic weather suggestions
      [
        const AnnotationSuggestion(
          type: SuggestionType.weather,
          title: 'Clear and sunny',
          subtitle: 'Common weather condition',
          value: 'Clear and sunny',
          confidence: 0.6,
        ),
        const AnnotationSuggestion(
          type: SuggestionType.weather,
          title: 'Partly cloudy',
          subtitle: 'Common weather condition',
          value: 'Partly cloudy',
          confidence: 0.6,
        ),
      ];

  List<AnnotationSuggestion> _getGenericSuggestions() => [
        const AnnotationSuggestion(
          type: SuggestionType.tags,
          title: 'adventure, nature',
          subtitle: 'Popular outdoor tags',
          value: 'adventure, nature',
          confidence: 0.5,
        ),
        const AnnotationSuggestion(
          type: SuggestionType.note,
          title: 'Beautiful scenery',
          subtitle: 'Common photo note',
          value: 'Beautiful scenery',
          confidence: 0.5,
        ),
        const AnnotationSuggestion(
          type: SuggestionType.tags,
          title: 'landscape, scenic',
          subtitle: 'Landscape photography tags',
          value: 'landscape, scenic',
          confidence: 0.5,
        ),
      ];
}

/// Represents a suggestion for photo annotation
@immutable
class AnnotationSuggestion {
  const AnnotationSuggestion({
    required this.type,
    required this.title,
    required this.value,
    required this.confidence,
    this.subtitle,
  });

  final SuggestionType type;
  final String title;
  final String? subtitle;
  final String value;
  final double confidence; // 0.0 to 1.0

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotationSuggestion &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          title == other.title &&
          value == other.value;

  @override
  int get hashCode => type.hashCode ^ title.hashCode ^ value.hashCode;
}

/// Types of annotation suggestions
enum SuggestionType {
  note,
  tags,
  weather,
  location,
}

extension SuggestionTypeExtension on SuggestionType {
  IconData get icon {
    switch (this) {
      case SuggestionType.note:
        return Icons.note_alt_outlined;
      case SuggestionType.tags:
        return Icons.label_outline;
      case SuggestionType.weather:
        return Icons.wb_sunny_outlined;
      case SuggestionType.location:
        return Icons.location_on_outlined;
    }
  }

  Color get color {
    switch (this) {
      case SuggestionType.note:
        return Colors.blue;
      case SuggestionType.tags:
        return Colors.green;
      case SuggestionType.weather:
        return Colors.orange;
      case SuggestionType.location:
        return Colors.purple;
    }
  }
}
