import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/models/settings_models.dart';

/// Security and privacy models for Milestone 6

/// Authentication method types
enum AuthMethod {
  none,
  pin,
  biometric,
  pinAndBiometric;

  String get displayName {
    switch (this) {
      case AuthMethod.none:
        return 'None';
      case AuthMethod.pin:
        return 'PIN';
      case AuthMethod.biometric:
        return 'Biometric';
      case AuthMethod.pinAndBiometric:
        return 'PIN + Biometric';
    }
  }
}

/// Auto-lock timeout options
enum AutoLockTimeout {
  never,
  immediate,
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  thirtyMinutes,
  oneHour;

  String get displayName {
    switch (this) {
      case AutoLockTimeout.never:
        return 'Never';
      case AutoLockTimeout.immediate:
        return 'Immediately';
      case AutoLockTimeout.oneMinute:
        return '1 minute';
      case AutoLockTimeout.fiveMinutes:
        return '5 minutes';
      case AutoLockTimeout.fifteenMinutes:
        return '15 minutes';
      case AutoLockTimeout.thirtyMinutes:
        return '30 minutes';
      case AutoLockTimeout.oneHour:
        return '1 hour';
    }
  }

  Duration? get duration {
    switch (this) {
      case AutoLockTimeout.never:
        return null;
      case AutoLockTimeout.immediate:
        return Duration.zero;
      case AutoLockTimeout.oneMinute:
        return const Duration(minutes: 1);
      case AutoLockTimeout.fiveMinutes:
        return const Duration(minutes: 5);
      case AutoLockTimeout.fifteenMinutes:
        return const Duration(minutes: 15);
      case AutoLockTimeout.thirtyMinutes:
        return const Duration(minutes: 30);
      case AutoLockTimeout.oneHour:
        return const Duration(hours: 1);
    }
  }
}

/// Encryption strength levels
enum EncryptionStrength {
  standard,
  high,
  maximum;

  String get displayName {
    switch (this) {
      case EncryptionStrength.standard:
        return 'Standard (AES-128)';
      case EncryptionStrength.high:
        return 'High (AES-256)';
      case EncryptionStrength.maximum:
        return 'Maximum (AES-256 + RSA)';
    }
  }

  int get keyLength {
    switch (this) {
      case EncryptionStrength.standard:
        return 128;
      case EncryptionStrength.high:
      case EncryptionStrength.maximum:
        return 256;
    }
  }
}

/// Location fuzzing levels
enum LocationFuzzingLevel {
  none,
  low,
  medium,
  high,
  maximum;

  String get displayName {
    switch (this) {
      case LocationFuzzingLevel.none:
        return 'None (Exact location)';
      case LocationFuzzingLevel.low:
        return 'Low (~10m radius)';
      case LocationFuzzingLevel.medium:
        return 'Medium (~50m radius)';
      case LocationFuzzingLevel.high:
        return 'High (~100m radius)';
      case LocationFuzzingLevel.maximum:
        return 'Maximum (~500m radius)';
    }
  }

  double get radiusMeters {
    switch (this) {
      case LocationFuzzingLevel.none:
        return 0.0;
      case LocationFuzzingLevel.low:
        return 10.0;
      case LocationFuzzingLevel.medium:
        return 50.0;
      case LocationFuzzingLevel.high:
        return 100.0;
      case LocationFuzzingLevel.maximum:
        return 500.0;
    }
  }
}

/// Backup encryption types
enum BackupEncryptionType {
  none,
  password,
  keyFile,
  passwordAndKeyFile;

  String get displayName {
    switch (this) {
      case BackupEncryptionType.none:
        return 'None (Not recommended)';
      case BackupEncryptionType.password:
        return 'Password Protected';
      case BackupEncryptionType.keyFile:
        return 'Key File';
      case BackupEncryptionType.passwordAndKeyFile:
        return 'Password + Key File';
    }
  }
}

/// App security settings
@immutable
class AppSecuritySettings {
  const AppSecuritySettings({
    this.authMethod = AuthMethod.none,
    this.autoLockTimeout = AutoLockTimeout.fiveMinutes,
    this.requireAuthOnStart = true,
    this.requireAuthForSensitiveData = true,
    this.requireAuthForExport = true,
    this.requireAuthForSettings = false,
    this.enableFailedAttemptLockout = true,
    this.maxFailedAttempts = 5,
    this.lockoutDuration = const Duration(minutes: 5),
    this.enableScreenshotBlocking = false,
    this.enableAppSwitcherBlocking = false,
  });

  factory AppSecuritySettings.fromJson(Map<String, dynamic> json) =>
      AppSecuritySettings(
        authMethod: AuthMethod.values.firstWhere(
          (e) => e.name == json['auth_method'],
          orElse: () => AuthMethod.none,
        ),
        autoLockTimeout: AutoLockTimeout.values.firstWhere(
          (e) => e.name == json['auto_lock_timeout'],
          orElse: () => AutoLockTimeout.fiveMinutes,
        ),
        requireAuthOnStart: json['require_auth_on_start'] as bool? ?? true,
        requireAuthForSensitiveData:
            json['require_auth_for_sensitive_data'] as bool? ?? true,
        requireAuthForExport: json['require_auth_for_export'] as bool? ?? true,
        requireAuthForSettings:
            json['require_auth_for_settings'] as bool? ?? false,
        enableFailedAttemptLockout:
            json['enable_failed_attempt_lockout'] as bool? ?? true,
        maxFailedAttempts: json['max_failed_attempts'] as int? ?? 5,
        lockoutDuration:
            Duration(minutes: json['lockout_duration_minutes'] as int? ?? 5),
        enableScreenshotBlocking:
            json['enable_screenshot_blocking'] as bool? ?? false,
        enableAppSwitcherBlocking:
            json['enable_app_switcher_blocking'] as bool? ?? false,
      );

  final AuthMethod authMethod;
  final AutoLockTimeout autoLockTimeout;
  final bool requireAuthOnStart;
  final bool requireAuthForSensitiveData;
  final bool requireAuthForExport;
  final bool requireAuthForSettings;
  final bool enableFailedAttemptLockout;
  final int maxFailedAttempts;
  final Duration lockoutDuration;
  final bool enableScreenshotBlocking;
  final bool enableAppSwitcherBlocking;

  AppSecuritySettings copyWith({
    AuthMethod? authMethod,
    AutoLockTimeout? autoLockTimeout,
    bool? requireAuthOnStart,
    bool? requireAuthForSensitiveData,
    bool? requireAuthForExport,
    bool? requireAuthForSettings,
    bool? enableFailedAttemptLockout,
    int? maxFailedAttempts,
    Duration? lockoutDuration,
    bool? enableScreenshotBlocking,
    bool? enableAppSwitcherBlocking,
  }) =>
      AppSecuritySettings(
        authMethod: authMethod ?? this.authMethod,
        autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
        requireAuthOnStart: requireAuthOnStart ?? this.requireAuthOnStart,
        requireAuthForSensitiveData:
            requireAuthForSensitiveData ?? this.requireAuthForSensitiveData,
        requireAuthForExport: requireAuthForExport ?? this.requireAuthForExport,
        requireAuthForSettings:
            requireAuthForSettings ?? this.requireAuthForSettings,
        enableFailedAttemptLockout:
            enableFailedAttemptLockout ?? this.enableFailedAttemptLockout,
        maxFailedAttempts: maxFailedAttempts ?? this.maxFailedAttempts,
        lockoutDuration: lockoutDuration ?? this.lockoutDuration,
        enableScreenshotBlocking:
            enableScreenshotBlocking ?? this.enableScreenshotBlocking,
        enableAppSwitcherBlocking:
            enableAppSwitcherBlocking ?? this.enableAppSwitcherBlocking,
      );

  Map<String, dynamic> toJson() => {
        'auth_method': authMethod.name,
        'auto_lock_timeout': autoLockTimeout.name,
        'require_auth_on_start': requireAuthOnStart,
        'require_auth_for_sensitive_data': requireAuthForSensitiveData,
        'require_auth_for_export': requireAuthForExport,
        'require_auth_for_settings': requireAuthForSettings,
        'enable_failed_attempt_lockout': enableFailedAttemptLockout,
        'max_failed_attempts': maxFailedAttempts,
        'lockout_duration_minutes': lockoutDuration.inMinutes,
        'enable_screenshot_blocking': enableScreenshotBlocking,
        'enable_app_switcher_blocking': enableAppSwitcherBlocking,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSecuritySettings &&
        other.authMethod == authMethod &&
        other.autoLockTimeout == autoLockTimeout &&
        other.requireAuthOnStart == requireAuthOnStart &&
        other.requireAuthForSensitiveData == requireAuthForSensitiveData &&
        other.requireAuthForExport == requireAuthForExport &&
        other.requireAuthForSettings == requireAuthForSettings &&
        other.enableFailedAttemptLockout == enableFailedAttemptLockout &&
        other.maxFailedAttempts == maxFailedAttempts &&
        other.lockoutDuration == lockoutDuration &&
        other.enableScreenshotBlocking == enableScreenshotBlocking &&
        other.enableAppSwitcherBlocking == enableAppSwitcherBlocking;
  }

  @override
  int get hashCode => Object.hash(
        authMethod,
        autoLockTimeout,
        requireAuthOnStart,
        requireAuthForSensitiveData,
        requireAuthForExport,
        requireAuthForSettings,
        enableFailedAttemptLockout,
        maxFailedAttempts,
        lockoutDuration,
        enableScreenshotBlocking,
        enableAppSwitcherBlocking,
      );
}

/// Data encryption settings
@immutable
class DataEncryptionSettings {
  const DataEncryptionSettings({
    this.enableDatabaseEncryption = true,
    this.enablePhotoEncryption = true,
    this.enableBackupEncryption = true,
    this.encryptionStrength = EncryptionStrength.high,
    this.enableKeyRotation = true,
    this.keyRotationInterval = const Duration(days: 90),
    this.enableSecureDelete = true,
    this.enableMemoryProtection = true,
  });

  factory DataEncryptionSettings.fromJson(Map<String, dynamic> json) =>
      DataEncryptionSettings(
        enableDatabaseEncryption:
            json['enable_database_encryption'] as bool? ?? true,
        enablePhotoEncryption: json['enable_photo_encryption'] as bool? ?? true,
        enableBackupEncryption:
            json['enable_backup_encryption'] as bool? ?? true,
        encryptionStrength: EncryptionStrength.values.firstWhere(
          (e) => e.name == json['encryption_strength'],
          orElse: () => EncryptionStrength.high,
        ),
        enableKeyRotation: json['enable_key_rotation'] as bool? ?? true,
        keyRotationInterval:
            Duration(days: json['key_rotation_interval_days'] as int? ?? 90),
        enableSecureDelete: json['enable_secure_delete'] as bool? ?? true,
        enableMemoryProtection:
            json['enable_memory_protection'] as bool? ?? true,
      );

  final bool enableDatabaseEncryption;
  final bool enablePhotoEncryption;
  final bool enableBackupEncryption;
  final EncryptionStrength encryptionStrength;
  final bool enableKeyRotation;
  final Duration keyRotationInterval;
  final bool enableSecureDelete;
  final bool enableMemoryProtection;

  DataEncryptionSettings copyWith({
    bool? enableDatabaseEncryption,
    bool? enablePhotoEncryption,
    bool? enableBackupEncryption,
    EncryptionStrength? encryptionStrength,
    bool? enableKeyRotation,
    Duration? keyRotationInterval,
    bool? enableSecureDelete,
    bool? enableMemoryProtection,
  }) =>
      DataEncryptionSettings(
        enableDatabaseEncryption:
            enableDatabaseEncryption ?? this.enableDatabaseEncryption,
        enablePhotoEncryption:
            enablePhotoEncryption ?? this.enablePhotoEncryption,
        enableBackupEncryption:
            enableBackupEncryption ?? this.enableBackupEncryption,
        encryptionStrength: encryptionStrength ?? this.encryptionStrength,
        enableKeyRotation: enableKeyRotation ?? this.enableKeyRotation,
        keyRotationInterval: keyRotationInterval ?? this.keyRotationInterval,
        enableSecureDelete: enableSecureDelete ?? this.enableSecureDelete,
        enableMemoryProtection:
            enableMemoryProtection ?? this.enableMemoryProtection,
      );

  Map<String, dynamic> toJson() => {
        'enable_database_encryption': enableDatabaseEncryption,
        'enable_photo_encryption': enablePhotoEncryption,
        'enable_backup_encryption': enableBackupEncryption,
        'encryption_strength': encryptionStrength.name,
        'enable_key_rotation': enableKeyRotation,
        'key_rotation_interval_days': keyRotationInterval.inDays,
        'enable_secure_delete': enableSecureDelete,
        'enable_memory_protection': enableMemoryProtection,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataEncryptionSettings &&
        other.enableDatabaseEncryption == enableDatabaseEncryption &&
        other.enablePhotoEncryption == enablePhotoEncryption &&
        other.enableBackupEncryption == enableBackupEncryption &&
        other.encryptionStrength == encryptionStrength &&
        other.enableKeyRotation == enableKeyRotation &&
        other.keyRotationInterval == keyRotationInterval &&
        other.enableSecureDelete == enableSecureDelete &&
        other.enableMemoryProtection == enableMemoryProtection;
  }

  @override
  int get hashCode => Object.hash(
        enableDatabaseEncryption,
        enablePhotoEncryption,
        enableBackupEncryption,
        encryptionStrength,
        enableKeyRotation,
        keyRotationInterval,
        enableSecureDelete,
        enableMemoryProtection,
      );
}

/// Privacy tools settings
@immutable
class PrivacyToolsSettings {
  const PrivacyToolsSettings({
    this.enableLocationFuzzing = false,
    this.locationFuzzingLevel = LocationFuzzingLevel.medium,
    this.enableExifStripping = true,
    this.enableSelectiveExport = true,
    this.enableDataAnonymization = true,
    this.enableLocationHistory = true,
    this.locationHistoryRetention = const Duration(days: 30),
    this.enableUsageAnalytics = false,
    this.enableCrashReporting = false,
  });

  factory PrivacyToolsSettings.fromJson(Map<String, dynamic> json) =>
      PrivacyToolsSettings(
        enableLocationFuzzing:
            json['enable_location_fuzzing'] as bool? ?? false,
        locationFuzzingLevel: LocationFuzzingLevel.values.firstWhere(
          (e) => e.name == json['location_fuzzing_level'],
          orElse: () => LocationFuzzingLevel.medium,
        ),
        enableExifStripping: json['enable_exif_stripping'] as bool? ?? true,
        enableSelectiveExport: json['enable_selective_export'] as bool? ?? true,
        enableDataAnonymization:
            json['enable_data_anonymization'] as bool? ?? true,
        enableLocationHistory: json['enable_location_history'] as bool? ?? true,
        locationHistoryRetention: Duration(
            days: json['location_history_retention_days'] as int? ?? 30),
        enableUsageAnalytics: json['enable_usage_analytics'] as bool? ?? false,
        enableCrashReporting: json['enable_crash_reporting'] as bool? ?? false,
      );

  final bool enableLocationFuzzing;
  final LocationFuzzingLevel locationFuzzingLevel;
  final bool enableExifStripping;
  final bool enableSelectiveExport;
  final bool enableDataAnonymization;
  final bool enableLocationHistory;
  final Duration locationHistoryRetention;
  final bool enableUsageAnalytics;
  final bool enableCrashReporting;

  PrivacyToolsSettings copyWith({
    bool? enableLocationFuzzing,
    LocationFuzzingLevel? locationFuzzingLevel,
    bool? enableExifStripping,
    bool? enableSelectiveExport,
    bool? enableDataAnonymization,
    bool? enableLocationHistory,
    Duration? locationHistoryRetention,
    bool? enableUsageAnalytics,
    bool? enableCrashReporting,
  }) =>
      PrivacyToolsSettings(
        enableLocationFuzzing:
            enableLocationFuzzing ?? this.enableLocationFuzzing,
        locationFuzzingLevel: locationFuzzingLevel ?? this.locationFuzzingLevel,
        enableExifStripping: enableExifStripping ?? this.enableExifStripping,
        enableSelectiveExport:
            enableSelectiveExport ?? this.enableSelectiveExport,
        enableDataAnonymization:
            enableDataAnonymization ?? this.enableDataAnonymization,
        enableLocationHistory:
            enableLocationHistory ?? this.enableLocationHistory,
        locationHistoryRetention:
            locationHistoryRetention ?? this.locationHistoryRetention,
        enableUsageAnalytics: enableUsageAnalytics ?? this.enableUsageAnalytics,
        enableCrashReporting: enableCrashReporting ?? this.enableCrashReporting,
      );

  Map<String, dynamic> toJson() => {
        'enable_location_fuzzing': enableLocationFuzzing,
        'location_fuzzing_level': locationFuzzingLevel.name,
        'enable_exif_stripping': enableExifStripping,
        'enable_selective_export': enableSelectiveExport,
        'enable_data_anonymization': enableDataAnonymization,
        'enable_location_history': enableLocationHistory,
        'location_history_retention_days': locationHistoryRetention.inDays,
        'enable_usage_analytics': enableUsageAnalytics,
        'enable_crash_reporting': enableCrashReporting,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrivacyToolsSettings &&
        other.enableLocationFuzzing == enableLocationFuzzing &&
        other.locationFuzzingLevel == locationFuzzingLevel &&
        other.enableExifStripping == enableExifStripping &&
        other.enableSelectiveExport == enableSelectiveExport &&
        other.enableDataAnonymization == enableDataAnonymization &&
        other.enableLocationHistory == enableLocationHistory &&
        other.locationHistoryRetention == locationHistoryRetention &&
        other.enableUsageAnalytics == enableUsageAnalytics &&
        other.enableCrashReporting == enableCrashReporting;
  }

  @override
  int get hashCode => Object.hash(
        enableLocationFuzzing,
        locationFuzzingLevel,
        enableExifStripping,
        enableSelectiveExport,
        enableDataAnonymization,
        enableLocationHistory,
        locationHistoryRetention,
        enableUsageAnalytics,
        enableCrashReporting,
      );
}

/// Secure backup settings
@immutable
class SecureBackupSettings {
  const SecureBackupSettings({
    this.enableAutomaticBackup = true,
    this.backupFrequency = BackupFrequency.weekly,
    this.encryptionType = BackupEncryptionType.password,
    this.enableCloudBackup = false,
    this.maxBackupCount = 5,
    this.enableBackupVerification = true,
    this.enableIncrementalBackup = true,
    this.compressionLevel = 6,
  });

  factory SecureBackupSettings.fromJson(Map<String, dynamic> json) =>
      SecureBackupSettings(
        enableAutomaticBackup: json['enable_automatic_backup'] as bool? ?? true,
        backupFrequency: BackupFrequency.values.firstWhere(
          (e) => e.name == json['backup_frequency'],
          orElse: () => BackupFrequency.weekly,
        ),
        encryptionType: BackupEncryptionType.values.firstWhere(
          (e) => e.name == json['encryption_type'],
          orElse: () => BackupEncryptionType.password,
        ),
        enableCloudBackup: json['enable_cloud_backup'] as bool? ?? false,
        maxBackupCount: json['max_backup_count'] as int? ?? 5,
        enableBackupVerification:
            json['enable_backup_verification'] as bool? ?? true,
        enableIncrementalBackup:
            json['enable_incremental_backup'] as bool? ?? true,
        compressionLevel: json['compression_level'] as int? ?? 6,
      );

  final bool enableAutomaticBackup;
  final BackupFrequency backupFrequency;
  final BackupEncryptionType encryptionType;
  final bool enableCloudBackup;
  final int maxBackupCount;
  final bool enableBackupVerification;
  final bool enableIncrementalBackup;
  final int compressionLevel;

  SecureBackupSettings copyWith({
    bool? enableAutomaticBackup,
    BackupFrequency? backupFrequency,
    BackupEncryptionType? encryptionType,
    bool? enableCloudBackup,
    int? maxBackupCount,
    bool? enableBackupVerification,
    bool? enableIncrementalBackup,
    int? compressionLevel,
  }) =>
      SecureBackupSettings(
        enableAutomaticBackup:
            enableAutomaticBackup ?? this.enableAutomaticBackup,
        backupFrequency: backupFrequency ?? this.backupFrequency,
        encryptionType: encryptionType ?? this.encryptionType,
        enableCloudBackup: enableCloudBackup ?? this.enableCloudBackup,
        maxBackupCount: maxBackupCount ?? this.maxBackupCount,
        enableBackupVerification:
            enableBackupVerification ?? this.enableBackupVerification,
        enableIncrementalBackup:
            enableIncrementalBackup ?? this.enableIncrementalBackup,
        compressionLevel: compressionLevel ?? this.compressionLevel,
      );

  Map<String, dynamic> toJson() => {
        'enable_automatic_backup': enableAutomaticBackup,
        'backup_frequency': backupFrequency.name,
        'encryption_type': encryptionType.name,
        'enable_cloud_backup': enableCloudBackup,
        'max_backup_count': maxBackupCount,
        'enable_backup_verification': enableBackupVerification,
        'enable_incremental_backup': enableIncrementalBackup,
        'compression_level': compressionLevel,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecureBackupSettings &&
        other.enableAutomaticBackup == enableAutomaticBackup &&
        other.backupFrequency == backupFrequency &&
        other.encryptionType == encryptionType &&
        other.enableCloudBackup == enableCloudBackup &&
        other.maxBackupCount == maxBackupCount &&
        other.enableBackupVerification == enableBackupVerification &&
        other.enableIncrementalBackup == enableIncrementalBackup &&
        other.compressionLevel == compressionLevel;
  }

  @override
  int get hashCode => Object.hash(
        enableAutomaticBackup,
        backupFrequency,
        encryptionType,
        enableCloudBackup,
        maxBackupCount,
        enableBackupVerification,
        enableIncrementalBackup,
        compressionLevel,
      );
}
