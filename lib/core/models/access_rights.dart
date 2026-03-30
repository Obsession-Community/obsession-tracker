import 'package:flutter/foundation.dart';

/// Property access rights and restrictions
@immutable
class AccessRights {
  const AccessRights({
    required this.publicAccess,
    required this.easementAccess,
    this.seasonalRestrictions = const [],
    required this.permitRequired,
    this.permitInfo,
    required this.huntingAccess,
    required this.recreationAccess,
  });

  final bool publicAccess;
  final bool easementAccess;
  final List<SeasonalRestriction> seasonalRestrictions;
  final bool permitRequired;
  final String? permitInfo;
  final bool huntingAccess;
  final bool recreationAccess;

  /// Create from GraphQL response data
  factory AccessRights.fromJson(Map<String, dynamic> json) {
    return AccessRights(
      publicAccess: (json['publicAccess'] as bool?) ?? false,
      easementAccess: (json['easementAccess'] as bool?) ?? false,
      seasonalRestrictions: (json['seasonalRestrictions'] as List<dynamic>?)
          ?.map((e) => SeasonalRestriction.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      permitRequired: (json['permitRequired'] as bool?) ?? false,
      permitInfo: json['permitInfo'] as String?,
      huntingAccess: (json['huntingAccess'] as bool?) ?? false,
      recreationAccess: (json['recreationAccess'] as bool?) ?? false,
    );
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'publicAccess': publicAccess,
      'easementAccess': easementAccess,
      'seasonalRestrictions': seasonalRestrictions.map((e) => e.toJson()).toList(),
      'permitRequired': permitRequired,
      'permitInfo': permitInfo,
      'huntingAccess': huntingAccess,
      'recreationAccess': recreationAccess,
    };
  }

  /// Get access level summary
  String get accessSummary {
    if (publicAccess && !permitRequired) {
      return 'Open Public Access';
    }
    if (publicAccess && permitRequired) {
      return 'Public Access - Permit Required';
    }
    if (easementAccess) {
      return 'Easement Access Only';
    }
    return 'No Public Access';
  }

  /// Get access status color
  int get accessColor {
    if (publicAccess && !permitRequired) {
      return 0xFF4CAF50; // Green - Open access
    }
    if (publicAccess && permitRequired) {
      return 0xFFFF9800; // Orange - Permit required
    }
    if (easementAccess) {
      return 0xFF2196F3; // Blue - Easement access
    }
    return 0xFFF44336; // Red - No access
  }

  /// Check if there are active seasonal restrictions
  bool get hasActiveRestrictions {
    final now = DateTime.now();
    return seasonalRestrictions.any((restriction) => 
        restriction.isActiveOn(now));
  }

  /// Get currently active seasonal restrictions
  List<SeasonalRestriction> get activeRestrictions {
    final now = DateTime.now();
    return seasonalRestrictions.where((restriction) => 
        restriction.isActiveOn(now)).toList();
  }

  AccessRights copyWith({
    bool? publicAccess,
    bool? easementAccess,
    List<SeasonalRestriction>? seasonalRestrictions,
    bool? permitRequired,
    String? permitInfo,
    bool? huntingAccess,
    bool? recreationAccess,
  }) {
    return AccessRights(
      publicAccess: publicAccess ?? this.publicAccess,
      easementAccess: easementAccess ?? this.easementAccess,
      seasonalRestrictions: seasonalRestrictions ?? this.seasonalRestrictions,
      permitRequired: permitRequired ?? this.permitRequired,
      permitInfo: permitInfo ?? this.permitInfo,
      huntingAccess: huntingAccess ?? this.huntingAccess,
      recreationAccess: recreationAccess ?? this.recreationAccess,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccessRights &&
        other.publicAccess == publicAccess &&
        other.easementAccess == easementAccess &&
        listEquals(other.seasonalRestrictions, seasonalRestrictions) &&
        other.permitRequired == permitRequired &&
        other.permitInfo == permitInfo &&
        other.huntingAccess == huntingAccess &&
        other.recreationAccess == recreationAccess;
  }

  @override
  int get hashCode {
    return Object.hash(
      publicAccess,
      easementAccess,
      seasonalRestrictions,
      permitRequired,
      permitInfo,
      huntingAccess,
      recreationAccess,
    );
  }

  @override
  String toString() {
    return 'AccessRights('
        'publicAccess: $publicAccess, '
        'easementAccess: $easementAccess, '
        'seasonalRestrictions: $seasonalRestrictions, '
        'permitRequired: $permitRequired, '
        'permitInfo: $permitInfo, '
        'huntingAccess: $huntingAccess, '
        'recreationAccess: $recreationAccess)';
  }
}

/// Seasonal restrictions on property access or activities
@immutable
class SeasonalRestriction {
  const SeasonalRestriction({
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.activities,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final List<String> activities;

  /// Create from GraphQL response data
  factory SeasonalRestriction.fromJson(Map<String, dynamic> json) {
    return SeasonalRestriction(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      reason: json['reason'] as String,
      activities: List<String>.from(json['activities'] as List<dynamic>),
    );
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String().split('T')[0],
      'endDate': endDate.toIso8601String().split('T')[0],
      'reason': reason,
      'activities': activities,
    };
  }

  /// Check if restriction is active on a given date
  bool isActiveOn(DateTime date) {
    return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
           date.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// Get formatted date range string
  String get dateRange {
    final startFormatted = '${startDate.month}/${startDate.day}';
    final endFormatted = '${endDate.month}/${endDate.day}';
    return '$startFormatted - $endFormatted';
  }

  /// Get activities summary
  String get activitiesSummary {
    if (activities.isEmpty) return 'All activities';
    if (activities.length == 1) return activities.first;
    if (activities.length <= 3) return activities.join(', ');
    return '${activities.take(2).join(', ')}, +${activities.length - 2} more';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SeasonalRestriction &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.reason == reason &&
        listEquals(other.activities, activities);
  }

  @override
  int get hashCode {
    return Object.hash(startDate, endDate, reason, activities);
  }

  @override
  String toString() {
    return 'SeasonalRestriction('
        'startDate: $startDate, '
        'endDate: $endDate, '
        'reason: $reason, '
        'activities: $activities)';
  }
}