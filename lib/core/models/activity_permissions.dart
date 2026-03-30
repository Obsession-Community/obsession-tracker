import 'package:flutter/foundation.dart';

/// Activity permission status for treasure hunting and outdoor recreation
enum PermissionStatus {
  allowed('ALLOWED', 'Allowed', 0xFF4CAF50), // Green
  prohibited('PROHIBITED', 'Prohibited', 0xFFF44336), // Red  
  permitRequired('PERMIT_REQUIRED', 'Permit Required', 0xFFFF9800), // Orange
  ownerPermissionRequired('OWNER_PERMISSION_REQUIRED', 'Owner Permission Required', 0xFFFF5722), // Deep Orange
  unknown('UNKNOWN', 'Unknown', 0xFF9E9E9E); // Grey

  const PermissionStatus(this.value, this.displayName, this.color);
  
  final String value;
  final String displayName;
  final int color;

  /// Create from GraphQL string value
  static PermissionStatus fromString(String? value) {
    switch (value) {
      case 'ALLOWED':
        return PermissionStatus.allowed;
      case 'PROHIBITED':
        return PermissionStatus.prohibited;
      case 'PERMIT_REQUIRED':
        return PermissionStatus.permitRequired;
      case 'OWNER_PERMISSION_REQUIRED':
        return PermissionStatus.ownerPermissionRequired;
      case 'UNKNOWN':
      default:
        return PermissionStatus.unknown;
    }
  }

  /// Get icon for permission status
  String get icon {
    switch (this) {
      case PermissionStatus.allowed:
        return '✅';
      case PermissionStatus.prohibited:
        return '❌';
      case PermissionStatus.permitRequired:
        return '📋';
      case PermissionStatus.ownerPermissionRequired:
        return '📞';
      case PermissionStatus.unknown:
        return '❓';
    }
  }
}

/// Activity-specific permissions for treasure hunting applications
@immutable
class ActivityPermissions {
  const ActivityPermissions({
    required this.metalDetecting,
    required this.treasureHunting,
    required this.archaeology,
    required this.camping,
    required this.hunting,
    required this.fishing,
  });

  final PermissionStatus metalDetecting;
  final PermissionStatus treasureHunting;
  final PermissionStatus archaeology;
  final PermissionStatus camping;
  final PermissionStatus hunting;
  final PermissionStatus fishing;

  /// Create from GraphQL response data
  factory ActivityPermissions.fromJson(Map<String, dynamic> json) {
    return ActivityPermissions(
      metalDetecting: PermissionStatus.fromString(json['metalDetecting'] as String?),
      treasureHunting: PermissionStatus.fromString(json['treasureHunting'] as String?),
      archaeology: PermissionStatus.fromString(json['archaeology'] as String?),
      camping: PermissionStatus.fromString(json['camping'] as String?),
      hunting: PermissionStatus.fromString(json['hunting'] as String?),
      fishing: PermissionStatus.fromString(json['fishing'] as String?),
    );
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'metalDetecting': metalDetecting.value,
      'treasureHunting': treasureHunting.value,
      'archaeology': archaeology.value,
      'camping': camping.value,
      'hunting': hunting.value,
      'fishing': fishing.value,
    };
  }

  /// Get most restrictive permission for quick assessment
  PermissionStatus get mostRestrictive {
    final permissions = [metalDetecting, treasureHunting, archaeology, camping, hunting, fishing];
    
    if (permissions.any((p) => p == PermissionStatus.prohibited)) {
      return PermissionStatus.prohibited;
    }
    if (permissions.any((p) => p == PermissionStatus.ownerPermissionRequired)) {
      return PermissionStatus.ownerPermissionRequired;
    }
    if (permissions.any((p) => p == PermissionStatus.permitRequired)) {
      return PermissionStatus.permitRequired;
    }
    if (permissions.any((p) => p == PermissionStatus.allowed)) {
      return PermissionStatus.allowed;
    }
    return PermissionStatus.unknown;
  }

  /// Check if any treasure hunting activity is allowed
  bool get canTreasureHunt {
    return metalDetecting == PermissionStatus.allowed || 
           treasureHunting == PermissionStatus.allowed;
  }

  /// Check if permission is required for any treasure hunting
  bool get needsPermission {
    return metalDetecting == PermissionStatus.permitRequired ||
           treasureHunting == PermissionStatus.permitRequired ||
           metalDetecting == PermissionStatus.ownerPermissionRequired ||
           treasureHunting == PermissionStatus.ownerPermissionRequired;
  }

  ActivityPermissions copyWith({
    PermissionStatus? metalDetecting,
    PermissionStatus? treasureHunting,
    PermissionStatus? archaeology,
    PermissionStatus? camping,
    PermissionStatus? hunting,
    PermissionStatus? fishing,
  }) {
    return ActivityPermissions(
      metalDetecting: metalDetecting ?? this.metalDetecting,
      treasureHunting: treasureHunting ?? this.treasureHunting,
      archaeology: archaeology ?? this.archaeology,
      camping: camping ?? this.camping,
      hunting: hunting ?? this.hunting,
      fishing: fishing ?? this.fishing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityPermissions &&
        other.metalDetecting == metalDetecting &&
        other.treasureHunting == treasureHunting &&
        other.archaeology == archaeology &&
        other.camping == camping &&
        other.hunting == hunting &&
        other.fishing == fishing;
  }

  @override
  int get hashCode {
    return Object.hash(
      metalDetecting,
      treasureHunting,
      archaeology,
      camping,
      hunting,
      fishing,
    );
  }

  @override
  String toString() {
    return 'ActivityPermissions('
        'metalDetecting: $metalDetecting, '
        'treasureHunting: $treasureHunting, '
        'archaeology: $archaeology, '
        'camping: $camping, '
        'hunting: $hunting, '
        'fishing: $fishing)';
  }
}