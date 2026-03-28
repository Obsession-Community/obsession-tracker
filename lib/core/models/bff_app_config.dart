/// App configuration fetched from BFF /config endpoint
/// This is database-independent and works during maintenance mode
class BFFAppConfig {
  final String apiVersion;
  final PlatformVersions minAppVersion;
  final PlatformVersions recommendedAppVersion;
  final MaintenanceConfig maintenance;
  final DataVersionConfig data;
  final LinksConfig links;
  final LegalConfig legal;
  final Map<String, dynamic> features;
  final List<Announcement> announcements;

  const BFFAppConfig({
    required this.apiVersion,
    required this.minAppVersion,
    required this.recommendedAppVersion,
    required this.maintenance,
    required this.data,
    required this.links,
    required this.legal,
    required this.features,
    required this.announcements,
  });

  factory BFFAppConfig.fromJson(Map<String, dynamic> json) {
    return BFFAppConfig(
      apiVersion: json['apiVersion'] as String? ?? '1.0.0',
      minAppVersion: PlatformVersions.fromJson(
        json['minAppVersion'] as Map<String, dynamic>? ?? {},
      ),
      recommendedAppVersion: PlatformVersions.fromJson(
        json['recommendedAppVersion'] as Map<String, dynamic>? ?? {},
      ),
      maintenance: MaintenanceConfig.fromJson(
        json['maintenance'] as Map<String, dynamic>? ?? {},
      ),
      data: DataVersionConfig.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      ),
      links: LinksConfig.fromJson(
        json['links'] as Map<String, dynamic>? ?? {},
      ),
      legal: LegalConfig.fromJson(
        json['legal'] as Map<String, dynamic>? ?? {},
      ),
      features: json['features'] as Map<String, dynamic>? ?? {},
      announcements: (json['announcements'] as List<dynamic>?)
              ?.map((e) => Announcement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiVersion': apiVersion,
      'minAppVersion': minAppVersion.toJson(),
      'recommendedAppVersion': recommendedAppVersion.toJson(),
      'maintenance': maintenance.toJson(),
      'data': data.toJson(),
      'links': links.toJson(),
      'legal': legal.toJson(),
      'features': features,
      'announcements': announcements.map((a) => a.toJson()).toList(),
    };
  }

  /// Default config when BFF is unreachable
  static BFFAppConfig defaults() {
    return const BFFAppConfig(
      apiVersion: '1.0.0',
      minAppVersion: PlatformVersions(),
      recommendedAppVersion: PlatformVersions(),
      maintenance: MaintenanceConfig(),
      data: DataVersionConfig(),
      links: LinksConfig(),
      legal: LegalConfig(),
      features: {},
      announcements: [],
    );
  }

  /// Check if a feature flag is enabled
  bool isFeatureEnabled(String feature) {
    final value = features[feature];
    if (value == null) return false;
    if (value is bool) return value;
    return false;
  }

  /// Get feature value as dynamic type
  T? getFeatureValue<T>(String feature) {
    final value = features[feature];
    if (value is T) return value;
    return null;
  }
}

/// Platform-specific version requirements
class PlatformVersions {
  final String ios;
  final String android;

  const PlatformVersions({
    this.ios = '1.0.0',
    this.android = '1.0.0',
  });

  factory PlatformVersions.fromJson(Map<String, dynamic> json) {
    return PlatformVersions(
      ios: json['ios'] as String? ?? '1.0.0',
      android: json['android'] as String? ?? '1.0.0',
    );
  }

  Map<String, dynamic> toJson() => {'ios': ios, 'android': android};
}

/// Maintenance mode configuration
class MaintenanceConfig {
  final bool active;
  final String? message;
  final DateTime? estimatedEnd;

  const MaintenanceConfig({
    this.active = false,
    this.message,
    this.estimatedEnd,
  });

  factory MaintenanceConfig.fromJson(Map<String, dynamic> json) {
    return MaintenanceConfig(
      active: json['active'] as bool? ?? false,
      message: json['message'] as String?,
      estimatedEnd: json['estimatedEnd'] != null
          ? DateTime.tryParse(json['estimatedEnd'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      if (message != null) 'message': message,
      if (estimatedEnd != null) 'estimatedEnd': estimatedEnd!.toIso8601String(),
    };
  }
}

/// Data version configuration for offline ZIP files
/// Used to notify users when updated land/trail data is available
class DataVersionConfig {
  /// Current combined data version (legacy, e.g., "PAD-US-4.1-GNIS")
  final String currentVersion;

  /// Data source identifier (e.g., "PAD-US 4.1 + GNIS")
  final String source;

  /// Human-readable description of what's in this version
  final String? description;

  /// Per-type versions for selective updates (new architecture)
  final DataTypeVersions versions;

  /// Whether split downloads are available on the server
  final bool splitDownloadsAvailable;

  const DataVersionConfig({
    this.currentVersion = '',
    this.source = '',
    this.description,
    this.versions = const DataTypeVersions(),
    this.splitDownloadsAvailable = false,
  });

  factory DataVersionConfig.fromJson(Map<String, dynamic> json) {
    return DataVersionConfig(
      currentVersion: json['currentVersion'] as String? ?? '',
      source: json['source'] as String? ?? '',
      description: json['description'] as String?,
      versions: DataTypeVersions.fromJson(
        json['versions'] as Map<String, dynamic>? ?? {},
      ),
      splitDownloadsAvailable: json['splitDownloadsAvailable'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentVersion': currentVersion,
      'source': source,
      if (description != null) 'description': description,
      'versions': versions.toJson(),
      'splitDownloadsAvailable': splitDownloadsAvailable,
    };
  }

  /// Check if this version is newer than a local version (legacy comparison)
  /// Uses simple string comparison
  bool isNewerThan(String localVersion) {
    if (currentVersion.isEmpty || localVersion.isEmpty) return false;
    return currentVersion.compareTo(localVersion) > 0;
  }

  /// Check if we have valid version info
  bool get hasVersion => currentVersion.isNotEmpty || versions.hasAnyVersion;

  /// Check if a specific data type needs updating
  bool isDataTypeOutdated(DataType dataType, String localVersion) {
    final serverVersion = versions.getVersion(dataType);
    if (serverVersion.isEmpty || localVersion.isEmpty) return false;
    return serverVersion != localVersion;
  }
}

/// Enum for data types (land ownership, trails, historical places, cell coverage)
enum DataType {
  land,
  trails,
  historical,
  cell,
}

/// Per-type version tracking for selective updates
class DataTypeVersions {
  final String land;
  final String trails;
  final String historical;
  final String cell;

  const DataTypeVersions({
    this.land = '',
    this.trails = '',
    this.historical = '',
    this.cell = '',
  });

  factory DataTypeVersions.fromJson(Map<String, dynamic> json) {
    return DataTypeVersions(
      land: json['land'] as String? ?? '',
      trails: json['trails'] as String? ?? '',
      historical: json['historical'] as String? ?? '',
      cell: json['cell'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'land': land,
    'trails': trails,
    'historical': historical,
    'cell': cell,
  };

  /// Get version for a specific data type
  String getVersion(DataType dataType) {
    switch (dataType) {
      case DataType.land:
        return land;
      case DataType.trails:
        return trails;
      case DataType.historical:
        return historical;
      case DataType.cell:
        return cell;
    }
  }

  /// Check if we have any version info
  bool get hasAnyVersion => land.isNotEmpty || trails.isNotEmpty || historical.isNotEmpty || cell.isNotEmpty;
}

/// Dynamic links configuration
class LinksConfig {
  final String? discord;
  final String? support;
  final String? privacy;
  final String? terms;
  final String? appStoreIos;
  final String? appStoreAndroid;

  const LinksConfig({
    this.discord,
    this.support,
    this.privacy,
    this.terms,
    this.appStoreIos,
    this.appStoreAndroid,
  });

  factory LinksConfig.fromJson(Map<String, dynamic> json) {
    return LinksConfig(
      discord: json['discord'] as String?,
      support: json['support'] as String?,
      privacy: json['privacy'] as String?,
      terms: json['terms'] as String?,
      appStoreIos: json['appStoreIos'] as String?,
      appStoreAndroid: json['appStoreAndroid'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (discord != null) 'discord': discord,
      if (support != null) 'support': support,
      if (privacy != null) 'privacy': privacy,
      if (terms != null) 'terms': terms,
      if (appStoreIos != null) 'appStoreIos': appStoreIos,
      if (appStoreAndroid != null) 'appStoreAndroid': appStoreAndroid,
    };
  }
}

/// Legal document versioning configuration
/// Used to notify users when Terms of Service or Privacy Policy changes
class LegalConfig {
  /// Version string (e.g., "2025-12-14") - increment when legal docs change
  final String version;

  /// Date when legal docs were last updated (for display)
  final String lastUpdated;

  /// Brief summary of what changed (optional, for user context)
  final String? changeSummary;

  /// URL to privacy policy (can override links.privacy)
  final String? privacyUrl;

  /// URL to terms of service (can override links.terms)
  final String? termsUrl;

  const LegalConfig({
    this.version = '1.0.0',
    this.lastUpdated = '',
    this.changeSummary,
    this.privacyUrl,
    this.termsUrl,
  });

  factory LegalConfig.fromJson(Map<String, dynamic> json) {
    return LegalConfig(
      version: json['version'] as String? ?? '1.0.0',
      lastUpdated: json['lastUpdated'] as String? ?? '',
      changeSummary: json['changeSummary'] as String?,
      privacyUrl: json['privacyUrl'] as String?,
      termsUrl: json['termsUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastUpdated': lastUpdated,
      if (changeSummary != null) 'changeSummary': changeSummary,
      if (privacyUrl != null) 'privacyUrl': privacyUrl,
      if (termsUrl != null) 'termsUrl': termsUrl,
    };
  }

  /// Check if we have a valid version
  bool get hasVersion => version.isNotEmpty && version != '1.0.0';
}

/// In-app announcement
class Announcement {
  final String id;
  final String title;
  final String message;
  final AnnouncementType type;
  final bool dismissible;
  final DateTime? expiresAt;
  final AnnouncementAction? action;
  final String? imageUrl;
  final String? huntId;
  final AnnouncementPriority priority;

  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.type = AnnouncementType.general,
    this.dismissible = true,
    this.expiresAt,
    this.action,
    this.imageUrl,
    this.huntId,
    this.priority = AnnouncementPriority.medium,
  });

  /// Parse from /config endpoint format (uses 'message' field)
  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: AnnouncementType.fromString(json['type'] as String?),
      dismissible: json['dismissible'] as bool? ?? true,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      action: json['action'] != null
          ? AnnouncementAction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
      imageUrl: json['imageUrl'] as String?,
      huntId: json['huntId'] as String?,
      priority: AnnouncementPriority.fromString(json['priority'] as String?),
    );
  }

  /// Parse from /announcements API endpoint format (uses 'body' field)
  factory Announcement.fromApiJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['body'] as String? ?? '', // API uses 'body', not 'message'
      type: AnnouncementType.fromString(json['type'] as String?),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      action: json['action'] != null
          ? AnnouncementAction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
      imageUrl: json['imageUrl'] as String?,
      huntId: json['huntId'] as String?,
      priority: AnnouncementPriority.fromString(json['priority'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.value,
      'dismissible': dismissible,
      'priority': priority.value,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (action != null) 'action': action!.toJson(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (huntId != null) 'huntId': huntId,
    };
  }

  /// Check if announcement has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if this announcement has an actionable link
  bool get hasAction => action != null;
}

/// Action to perform when announcement is tapped
class AnnouncementAction {
  final AnnouncementActionType type;
  final String value;

  const AnnouncementAction({
    required this.type,
    required this.value,
  });

  factory AnnouncementAction.fromJson(Map<String, dynamic> json) {
    return AnnouncementAction(
      type: AnnouncementActionType.fromString(json['type'] as String?),
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.value,
        'value': value,
      };
}

/// Action types for announcements
enum AnnouncementActionType {
  openUrl('open_url'),
  openHunt('open_hunt'),
  openAppStore('open_app_store'),
  none('none');

  final String value;
  const AnnouncementActionType(this.value);

  static AnnouncementActionType fromString(String? value) {
    return AnnouncementActionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AnnouncementActionType.none,
    );
  }
}

/// Announcement type determines icon and styling
enum AnnouncementType {
  newHunt('new_hunt'),
  treasureFound('treasure_found'),
  appUpdate('app_update'),
  landData('land_data'),
  maintenance('maintenance'),
  huntUpdate('hunt_update'),
  general('general'),
  // Legacy types for backwards compatibility
  info('info'),
  warning('warning'),
  critical('critical');

  final String value;
  const AnnouncementType(this.value);

  static AnnouncementType fromString(String? value) {
    return AnnouncementType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AnnouncementType.general,
    );
  }
}

/// Announcement priority
enum AnnouncementPriority {
  low('low'),
  medium('medium'),
  high('high');

  final String value;
  const AnnouncementPriority(this.value);

  static AnnouncementPriority fromString(String? value) {
    return AnnouncementPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AnnouncementPriority.medium,
    );
  }
}
