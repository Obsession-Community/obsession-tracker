// External Device Integration Models for Milestone 10
// Supports Garmin devices, external GPS units, and other hardware integrations

import 'package:flutter/foundation.dart';

/// Represents different types of external devices that can be integrated
enum ExternalDeviceType {
  garmin,
  externalGps,
  heartRateMonitor,
  weatherStation,
  bluetoothBeacon,
  smartWatch,
  fitnessTracker,
}

/// Connection status for external devices
enum DeviceConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
  pairing,
  syncing,
}

/// Base class for all external devices
@immutable
abstract class ExternalDevice {
  const ExternalDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.connectionStatus,
    required this.lastConnected,
    required this.batteryLevel,
    required this.firmwareVersion,
    required this.capabilities,
  });

  final String id;
  final String name;
  final ExternalDeviceType type;
  final DeviceConnectionStatus connectionStatus;
  final DateTime? lastConnected;
  final int? batteryLevel; // 0-100 percentage
  final String? firmwareVersion;
  final List<DeviceCapability> capabilities;

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExternalDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Capabilities that external devices can support
enum DeviceCapability {
  gpsTracking,
  heartRateMonitoring,
  altitudeTracking,
  temperatureReading,
  weatherData,
  activityTracking,
  sleepTracking,
  stepCounting,
  calorieTracking,
  distanceTracking,
  speedTracking,
  cadenceTracking,
  powerMeter,
  navigationAlerts,
  dataSync,
  realTimeStreaming,
}

/// Garmin device specific implementation
@immutable
class GarminDevice extends ExternalDevice {
  const GarminDevice({
    required super.id,
    required super.name,
    required super.type,
    required super.connectionStatus,
    required super.lastConnected,
    required super.batteryLevel,
    required super.firmwareVersion,
    required super.capabilities,
    required this.deviceModel,
    required this.serialNumber,
    required this.connectIqVersion,
    required this.supportedActivities,
    required this.dataFields,
  });

  factory GarminDevice.fromJson(Map<String, dynamic> json) => GarminDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ExternalDeviceType.values[json['type'] as int],
        connectionStatus:
            DeviceConnectionStatus.values[json['connectionStatus'] as int],
        lastConnected: json['lastConnected'] != null
            ? DateTime.parse(json['lastConnected'] as String)
            : null,
        batteryLevel: json['batteryLevel'] as int?,
        firmwareVersion: json['firmwareVersion'] as String?,
        capabilities: (json['capabilities'] as List<dynamic>)
            .map((e) => DeviceCapability.values[e as int])
            .toList(),
        deviceModel: json['deviceModel'] as String,
        serialNumber: json['serialNumber'] as String?,
        connectIqVersion: json['connectIqVersion'] as String?,
        supportedActivities: (json['supportedActivities'] as List<dynamic>)
            .map((e) => GarminActivityType.values[e as int])
            .toList(),
        dataFields: (json['dataFields'] as List<dynamic>)
            .map((e) => GarminDataField.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String deviceModel;
  final String? serialNumber;
  final String? connectIqVersion;
  final List<GarminActivityType> supportedActivities;
  final List<GarminDataField> dataFields;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'connectionStatus': connectionStatus.index,
        'lastConnected': lastConnected?.toIso8601String(),
        'batteryLevel': batteryLevel,
        'firmwareVersion': firmwareVersion,
        'capabilities': capabilities.map((e) => e.index).toList(),
        'deviceModel': deviceModel,
        'serialNumber': serialNumber,
        'connectIqVersion': connectIqVersion,
        'supportedActivities': supportedActivities.map((e) => e.index).toList(),
        'dataFields': dataFields.map((e) => e.toJson()).toList(),
      };

  GarminDevice copyWith({
    String? id,
    String? name,
    ExternalDeviceType? type,
    DeviceConnectionStatus? connectionStatus,
    DateTime? lastConnected,
    int? batteryLevel,
    String? firmwareVersion,
    List<DeviceCapability>? capabilities,
    String? deviceModel,
    String? serialNumber,
    String? connectIqVersion,
    List<GarminActivityType>? supportedActivities,
    List<GarminDataField>? dataFields,
  }) =>
      GarminDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        connectionStatus: connectionStatus ?? this.connectionStatus,
        lastConnected: lastConnected ?? this.lastConnected,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        capabilities: capabilities ?? this.capabilities,
        deviceModel: deviceModel ?? this.deviceModel,
        serialNumber: serialNumber ?? this.serialNumber,
        connectIqVersion: connectIqVersion ?? this.connectIqVersion,
        supportedActivities: supportedActivities ?? this.supportedActivities,
        dataFields: dataFields ?? this.dataFields,
      );
}

/// External GPS device implementation
@immutable
class ExternalGpsDevice extends ExternalDevice {
  const ExternalGpsDevice({
    required super.id,
    required super.name,
    required super.type,
    required super.connectionStatus,
    required super.lastConnected,
    required super.batteryLevel,
    required super.firmwareVersion,
    required super.capabilities,
    required this.accuracy,
    required this.updateRate,
    required this.satelliteCount,
    required this.supportedConstellations,
    required this.antennaType,
  });

  factory ExternalGpsDevice.fromJson(Map<String, dynamic> json) =>
      ExternalGpsDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ExternalDeviceType.values[json['type'] as int],
        connectionStatus:
            DeviceConnectionStatus.values[json['connectionStatus'] as int],
        lastConnected: json['lastConnected'] != null
            ? DateTime.parse(json['lastConnected'] as String)
            : null,
        batteryLevel: json['batteryLevel'] as int?,
        firmwareVersion: json['firmwareVersion'] as String?,
        capabilities: (json['capabilities'] as List<dynamic>)
            .map((e) => DeviceCapability.values[e as int])
            .toList(),
        accuracy: json['accuracy'] as double?,
        updateRate: json['updateRate'] as int,
        satelliteCount: json['satelliteCount'] as int?,
        supportedConstellations:
            (json['supportedConstellations'] as List<dynamic>)
                .map((e) => GnssConstellation.values[e as int])
                .toList(),
        antennaType: json['antennaType'] as String,
      );

  final double? accuracy; // meters
  final int updateRate; // Hz
  final int? satelliteCount;
  final List<GnssConstellation> supportedConstellations;
  final String antennaType;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'connectionStatus': connectionStatus.index,
        'lastConnected': lastConnected?.toIso8601String(),
        'batteryLevel': batteryLevel,
        'firmwareVersion': firmwareVersion,
        'capabilities': capabilities.map((e) => e.index).toList(),
        'accuracy': accuracy,
        'updateRate': updateRate,
        'satelliteCount': satelliteCount,
        'supportedConstellations':
            supportedConstellations.map((e) => e.index).toList(),
        'antennaType': antennaType,
      };

  ExternalGpsDevice copyWith({
    String? id,
    String? name,
    ExternalDeviceType? type,
    DeviceConnectionStatus? connectionStatus,
    DateTime? lastConnected,
    int? batteryLevel,
    String? firmwareVersion,
    List<DeviceCapability>? capabilities,
    double? accuracy,
    int? updateRate,
    int? satelliteCount,
    List<GnssConstellation>? supportedConstellations,
    String? antennaType,
  }) =>
      ExternalGpsDevice(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        connectionStatus: connectionStatus ?? this.connectionStatus,
        lastConnected: lastConnected ?? this.lastConnected,
        batteryLevel: batteryLevel ?? this.batteryLevel,
        firmwareVersion: firmwareVersion ?? this.firmwareVersion,
        capabilities: capabilities ?? this.capabilities,
        accuracy: accuracy ?? this.accuracy,
        updateRate: updateRate ?? this.updateRate,
        satelliteCount: satelliteCount ?? this.satelliteCount,
        supportedConstellations:
            supportedConstellations ?? this.supportedConstellations,
        antennaType: antennaType ?? this.antennaType,
      );
}

/// Garmin activity types
enum GarminActivityType {
  running,
  cycling,
  hiking,
  walking,
  swimming,
  skiing,
  climbing,
  kayaking,
  fishing,
  hunting,
  geocaching,
  mountaineering,
  trailRunning,
  ultraRunning,
  triathlon,
  adventure,
}

/// GNSS constellation types
enum GnssConstellation {
  gps,
  glonass,
  galileo,
  beidou,
  qzss,
  navic,
}

/// Garmin data field configuration
@immutable
class GarminDataField {
  const GarminDataField({
    required this.id,
    required this.name,
    required this.type,
    required this.unit,
    required this.isEnabled,
    required this.displayOrder,
  });

  factory GarminDataField.fromJson(Map<String, dynamic> json) =>
      GarminDataField(
        id: json['id'] as String,
        name: json['name'] as String,
        type: GarminDataFieldType.values[json['type'] as int],
        unit: json['unit'] as String,
        isEnabled: json['isEnabled'] as bool,
        displayOrder: json['displayOrder'] as int,
      );

  final String id;
  final String name;
  final GarminDataFieldType type;
  final String unit;
  final bool isEnabled;
  final int displayOrder;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.index,
        'unit': unit,
        'isEnabled': isEnabled,
        'displayOrder': displayOrder,
      };

  GarminDataField copyWith({
    String? id,
    String? name,
    GarminDataFieldType? type,
    String? unit,
    bool? isEnabled,
    int? displayOrder,
  }) =>
      GarminDataField(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        unit: unit ?? this.unit,
        isEnabled: isEnabled ?? this.isEnabled,
        displayOrder: displayOrder ?? this.displayOrder,
      );
}

/// Types of data fields available from Garmin devices
enum GarminDataFieldType {
  heartRate,
  cadence,
  power,
  speed,
  distance,
  elevation,
  temperature,
  time,
  calories,
  steps,
  vo2Max,
  recoveryTime,
  trainingEffect,
  stressScore,
  bodyBattery,
}

/// Device data reading from external devices
@immutable
class DeviceDataReading {
  const DeviceDataReading({
    required this.deviceId,
    required this.timestamp,
    required this.dataType,
    required this.value,
    required this.unit,
    required this.accuracy,
  });

  factory DeviceDataReading.fromJson(Map<String, dynamic> json) =>
      DeviceDataReading(
        deviceId: json['deviceId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        dataType: json['dataType'] as String,
        value: json['value'] as double,
        unit: json['unit'] as String,
        accuracy: json['accuracy'] as double?,
      );

  final String deviceId;
  final DateTime timestamp;
  final String dataType;
  final double value;
  final String unit;
  final double? accuracy;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'timestamp': timestamp.toIso8601String(),
        'dataType': dataType,
        'value': value,
        'unit': unit,
        'accuracy': accuracy,
      };
}

/// Device synchronization status
@immutable
class DeviceSyncStatus {
  const DeviceSyncStatus({
    required this.deviceId,
    required this.lastSyncTime,
    required this.syncInProgress,
    required this.pendingDataCount,
    required this.lastSyncError,
    required this.totalDataSynced,
  });

  factory DeviceSyncStatus.fromJson(Map<String, dynamic> json) =>
      DeviceSyncStatus(
        deviceId: json['deviceId'] as String,
        lastSyncTime: json['lastSyncTime'] != null
            ? DateTime.parse(json['lastSyncTime'] as String)
            : null,
        syncInProgress: json['syncInProgress'] as bool,
        pendingDataCount: json['pendingDataCount'] as int,
        lastSyncError: json['lastSyncError'] as String?,
        totalDataSynced: json['totalDataSynced'] as int,
      );

  final String deviceId;
  final DateTime? lastSyncTime;
  final bool syncInProgress;
  final int pendingDataCount;
  final String? lastSyncError;
  final int totalDataSynced;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'syncInProgress': syncInProgress,
        'pendingDataCount': pendingDataCount,
        'lastSyncError': lastSyncError,
        'totalDataSynced': totalDataSynced,
      };

  DeviceSyncStatus copyWith({
    String? deviceId,
    DateTime? lastSyncTime,
    bool? syncInProgress,
    int? pendingDataCount,
    String? lastSyncError,
    int? totalDataSynced,
  }) =>
      DeviceSyncStatus(
        deviceId: deviceId ?? this.deviceId,
        lastSyncTime: lastSyncTime ?? this.lastSyncTime,
        syncInProgress: syncInProgress ?? this.syncInProgress,
        pendingDataCount: pendingDataCount ?? this.pendingDataCount,
        lastSyncError: lastSyncError ?? this.lastSyncError,
        totalDataSynced: totalDataSynced ?? this.totalDataSynced,
      );
}
