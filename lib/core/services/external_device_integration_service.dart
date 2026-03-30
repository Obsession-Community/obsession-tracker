// External Device Integration Service for Milestone 10
// Handles Garmin devices, external GPS units, and other hardware integrations

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:obsession_tracker/core/models/external_device_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing external device integrations
class ExternalDeviceIntegrationService {
  factory ExternalDeviceIntegrationService() => _instance;

  ExternalDeviceIntegrationService._internal();
  static final ExternalDeviceIntegrationService _instance =
      ExternalDeviceIntegrationService._internal();

  final Logger _logger = Logger();
  final Map<String, ExternalDevice> _connectedDevices = {};
  final Map<String, StreamSubscription<dynamic>> _deviceStreams = {};
  final StreamController<List<ExternalDevice>> _devicesController =
      StreamController<List<ExternalDevice>>.broadcast();
  final StreamController<DeviceDataReading> _dataController =
      StreamController<DeviceDataReading>.broadcast();

  // Platform channels for native device communication
  static const MethodChannel _garminChannel =
      MethodChannel('obsessiontracker/garmin');
  static const MethodChannel _bluetoothChannel =
      MethodChannel('obsessiontracker/bluetooth');
  static const EventChannel _deviceDataChannel =
      EventChannel('obsessiontracker/device_data');

  bool _isInitialized = false;
  SharedPreferences? _prefs;

  /// Stream of connected devices
  Stream<List<ExternalDevice>> get devicesStream => _devicesController.stream;

  /// Stream of device data readings
  Stream<DeviceDataReading> get dataStream => _dataController.stream;

  /// List of currently connected devices
  List<ExternalDevice> get connectedDevices =>
      _connectedDevices.values.toList();

  /// Initialize the external device integration service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _logger.i('Initializing External Device Integration Service');

      _prefs = await SharedPreferences.getInstance();

      // Set up platform method call handlers
      _garminChannel.setMethodCallHandler(_handleGarminMethodCall);
      _bluetoothChannel.setMethodCallHandler(_handleBluetoothMethodCall);

      // Listen to device data stream
      _deviceDataChannel.receiveBroadcastStream().listen(
            _handleDeviceDataEvent,
            onError: (Object error) =>
                _logger.e('Device data stream error: $error'),
          );

      // Load saved device configurations
      await _loadSavedDevices();

      // Initialize platform-specific integrations
      await _initializePlatformIntegrations();

      _isInitialized = true;
      _logger.i('External Device Integration Service initialized successfully');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize External Device Integration Service',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Scan for available external devices
  Future<List<ExternalDevice>> scanForDevices({
    Duration timeout = const Duration(seconds: 30),
    List<ExternalDeviceType>? deviceTypes,
  }) async {
    try {
      _logger.i('Scanning for external devices');

      final List<ExternalDevice> discoveredDevices = <ExternalDevice>[];

      // Scan for Garmin devices
      if (deviceTypes == null ||
          deviceTypes.contains(ExternalDeviceType.garmin)) {
        final garminDevices = await _scanForGarminDevices(timeout);
        discoveredDevices.addAll(garminDevices);
      }

      // Scan for Bluetooth GPS devices
      if (deviceTypes == null ||
          deviceTypes.contains(ExternalDeviceType.externalGps)) {
        final gpsDevices = await _scanForBluetoothGpsDevices(timeout);
        discoveredDevices.addAll(gpsDevices);
      }

      // Scan for other Bluetooth devices
      final bluetoothDevices =
          await _scanForBluetoothDevices(timeout, deviceTypes);
      discoveredDevices.addAll(bluetoothDevices);

      _logger.i('Found ${discoveredDevices.length} external devices');
      return discoveredDevices;
    } catch (e, stackTrace) {
      _logger.e('Failed to scan for devices', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Connect to an external device
  Future<bool> connectToDevice(String deviceId) async {
    try {
      _logger.i('Connecting to device: $deviceId');

      final device = _connectedDevices[deviceId];
      if (device == null) {
        _logger.w('Device not found: $deviceId');
        return false;
      }

      bool success = false;

      switch (device.type) {
        case ExternalDeviceType.garmin:
          success = await _connectToGarminDevice(device as GarminDevice);
          break;
        case ExternalDeviceType.externalGps:
          success = await _connectToGpsDevice(device as ExternalGpsDevice);
          break;
        default:
          success = await _connectToBluetoothDevice(device);
          break;
      }

      if (success) {
        final updatedDevice = _updateDeviceConnectionStatus(
          device,
          DeviceConnectionStatus.connected,
        );
        _connectedDevices[deviceId] = updatedDevice;
        await _saveDeviceConfiguration(updatedDevice);
        _notifyDevicesChanged();

        // Start data streaming if supported
        await _startDeviceDataStream(deviceId);
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Failed to connect to device: $deviceId',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Disconnect from an external device
  Future<bool> disconnectFromDevice(String deviceId) async {
    try {
      _logger.i('Disconnecting from device: $deviceId');

      final device = _connectedDevices[deviceId];
      if (device == null) {
        _logger.w('Device not found: $deviceId');
        return false;
      }

      // Stop data streaming
      await _stopDeviceDataStream(deviceId);

      bool success = false;

      switch (device.type) {
        case ExternalDeviceType.garmin:
          success = await _disconnectFromGarminDevice(device as GarminDevice);
          break;
        case ExternalDeviceType.externalGps:
          success = await _disconnectFromGpsDevice(device as ExternalGpsDevice);
          break;
        default:
          success = await _disconnectFromBluetoothDevice(device);
          break;
      }

      if (success) {
        final updatedDevice = _updateDeviceConnectionStatus(
          device,
          DeviceConnectionStatus.disconnected,
        );
        _connectedDevices[deviceId] = updatedDevice;
        await _saveDeviceConfiguration(updatedDevice);
        _notifyDevicesChanged();
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Failed to disconnect from device: $deviceId',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Sync data from a connected device
  Future<DeviceSyncStatus> syncDeviceData(String deviceId) async {
    try {
      _logger.i('Syncing data from device: $deviceId');

      final device = _connectedDevices[deviceId];
      if (device == null) {
        throw Exception('Device not found: $deviceId');
      }

      if (device.connectionStatus != DeviceConnectionStatus.connected) {
        throw Exception('Device not connected: $deviceId');
      }

      DeviceSyncStatus syncStatus;

      switch (device.type) {
        case ExternalDeviceType.garmin:
          syncStatus = await _syncGarminData(device as GarminDevice);
          break;
        case ExternalDeviceType.externalGps:
          syncStatus = await _syncGpsData(device as ExternalGpsDevice);
          break;
        default:
          syncStatus = await _syncBluetoothDeviceData(device);
          break;
      }

      await _saveSyncStatus(syncStatus);
      return syncStatus;
    } catch (e, stackTrace) {
      _logger.e('Failed to sync device data: $deviceId',
          error: e, stackTrace: stackTrace);

      return DeviceSyncStatus(
        deviceId: deviceId,
        lastSyncTime: null,
        syncInProgress: false,
        pendingDataCount: 0,
        lastSyncError: e.toString(),
        totalDataSynced: 0,
      );
    }
  }

  /// Get device battery level
  Future<int?> getDeviceBatteryLevel(String deviceId) async {
    try {
      final device = _connectedDevices[deviceId];
      if (device == null ||
          device.connectionStatus != DeviceConnectionStatus.connected) {
        return null;
      }

      switch (device.type) {
        case ExternalDeviceType.garmin:
          return await _garminChannel
              .invokeMethod('getBatteryLevel', {'deviceId': deviceId});
        case ExternalDeviceType.externalGps:
          return await _bluetoothChannel
              .invokeMethod('getBatteryLevel', {'deviceId': deviceId});
        default:
          return await _bluetoothChannel
              .invokeMethod('getBatteryLevel', {'deviceId': deviceId});
      }
    } catch (e) {
      _logger.e('Failed to get battery level for device: $deviceId', error: e);
      return null;
    }
  }

  /// Configure device data fields (for Garmin devices)
  Future<bool> configureDeviceDataFields(
      String deviceId, List<GarminDataField> dataFields) async {
    try {
      final device = _connectedDevices[deviceId];
      if (device == null || device.type != ExternalDeviceType.garmin) {
        return false;
      }

      final result = await _garminChannel.invokeMethod('configureDataFields', {
        'deviceId': deviceId,
        'dataFields': dataFields.map((field) => field.toJson()).toList(),
      });

      if (result == true) {
        final garminDevice = device as GarminDevice;
        final updatedDevice = garminDevice.copyWith(dataFields: dataFields);
        _connectedDevices[deviceId] = updatedDevice;
        await _saveDeviceConfiguration(updatedDevice);
        _notifyDevicesChanged();
      }

      return result == true;
    } catch (e, stackTrace) {
      _logger.e('Failed to configure data fields for device: $deviceId',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Private methods

  Future<void> _initializePlatformIntegrations() async {
    if (Platform.isAndroid) {
      await _initializeAndroidIntegrations();
    } else if (Platform.isIOS) {
      await _initializeIOSIntegrations();
    }
  }

  Future<void> _initializeAndroidIntegrations() async {
    try {
      // Initialize Android-specific Garmin SDK
      await _garminChannel.invokeMethod('initializeGarminSDK');

      // Initialize Bluetooth adapter
      await _bluetoothChannel.invokeMethod('initializeBluetooth');
    } catch (e) {
      _logger.e('Failed to initialize Android integrations', error: e);
    }
  }

  Future<void> _initializeIOSIntegrations() async {
    try {
      // Initialize iOS-specific integrations
      await _garminChannel.invokeMethod('initializeGarminSDK');

      // Initialize Core Bluetooth
      await _bluetoothChannel.invokeMethod('initializeBluetooth');
    } catch (e) {
      _logger.e('Failed to initialize iOS integrations', error: e);
    }
  }

  Future<List<GarminDevice>> _scanForGarminDevices(Duration timeout) async {
    try {
      final result = await _garminChannel.invokeMethod('scanForDevices', {
        'timeout': timeout.inMilliseconds,
      });

      if (result is List) {
        return result
            .cast<Map<String, dynamic>>()
            .map(GarminDevice.fromJson)
            .toList();
      }

      return [];
    } catch (e) {
      _logger.e('Failed to scan for Garmin devices', error: e);
      return [];
    }
  }

  Future<List<ExternalGpsDevice>> _scanForBluetoothGpsDevices(
      Duration timeout) async {
    try {
      final result = await _bluetoothChannel.invokeMethod('scanForGpsDevices', {
        'timeout': timeout.inMilliseconds,
      });

      if (result is List) {
        return result
            .cast<Map<String, dynamic>>()
            .map(ExternalGpsDevice.fromJson)
            .toList();
      }

      return [];
    } catch (e) {
      _logger.e('Failed to scan for Bluetooth GPS devices', error: e);
      return [];
    }
  }

  Future<List<ExternalDevice>> _scanForBluetoothDevices(
    Duration timeout,
    List<ExternalDeviceType>? deviceTypes,
  ) async {
    try {
      final result = await _bluetoothChannel.invokeMethod('scanForDevices', {
        'timeout': timeout.inMilliseconds,
        'deviceTypes': deviceTypes?.map((type) => type.index).toList(),
      });

      if (result is List) {
        return result
            .cast<Map<String, dynamic>>()
            .map(_createDeviceFromJson)
            .where((device) => device != null)
            .cast<ExternalDevice>()
            .toList();
      }

      return [];
    } catch (e) {
      _logger.e('Failed to scan for Bluetooth devices', error: e);
      return [];
    }
  }

  ExternalDevice? _createDeviceFromJson(Map<String, dynamic> json) {
    try {
      final deviceType = ExternalDeviceType.values[json['type'] as int];

      switch (deviceType) {
        case ExternalDeviceType.garmin:
          return GarminDevice.fromJson(json);
        case ExternalDeviceType.externalGps:
          return ExternalGpsDevice.fromJson(json);
        default:
          // For other device types, create a basic implementation
          return _createBasicExternalDevice(json);
      }
    } catch (e) {
      _logger.e('Failed to create device from JSON', error: e);
      return null;
    }
  }

  ExternalDevice _createBasicExternalDevice(Map<String, dynamic> json) {
    // This would be implemented for other device types
    // For now, return a basic implementation
    throw UnimplementedError('Basic external device creation not implemented');
  }

  Future<bool> _connectToGarminDevice(GarminDevice device) async {
    try {
      final result = await _garminChannel.invokeMethod('connectToDevice', {
        'deviceId': device.id,
      });
      return result == true;
    } catch (e) {
      _logger.e('Failed to connect to Garmin device: ${device.id}', error: e);
      return false;
    }
  }

  Future<bool> _connectToGpsDevice(ExternalGpsDevice device) async {
    try {
      final result = await _bluetoothChannel.invokeMethod('connectToDevice', {
        'deviceId': device.id,
      });
      return result == true;
    } catch (e) {
      _logger.e('Failed to connect to GPS device: ${device.id}', error: e);
      return false;
    }
  }

  Future<bool> _connectToBluetoothDevice(ExternalDevice device) async {
    try {
      final result = await _bluetoothChannel.invokeMethod('connectToDevice', {
        'deviceId': device.id,
      });
      return result == true;
    } catch (e) {
      _logger.e('Failed to connect to Bluetooth device: ${device.id}',
          error: e);
      return false;
    }
  }

  Future<bool> _disconnectFromGarminDevice(GarminDevice device) async {
    try {
      final result = await _garminChannel.invokeMethod('disconnectFromDevice', {
        'deviceId': device.id,
      });
      return result == true;
    } catch (e) {
      _logger.e('Failed to disconnect from Garmin device: ${device.id}',
          error: e);
      return false;
    }
  }

  Future<bool> _disconnectFromGpsDevice(ExternalGpsDevice device) async {
    try {
      final result =
          await _bluetoothChannel.invokeMethod('disconnectFromDevice', {
        'deviceId': device.id,
      });
      return result == true;
    } catch (e) {
      _logger.e('Failed to disconnect from GPS device: ${device.id}', error: e);
      return false;
    }
  }

  Future<bool> _disconnectFromBluetoothDevice(ExternalDevice device) async {
    try {
      final result =
          await _bluetoothChannel.invokeMethod('disconnectFromDevice', {
        'deviceId': device.id,
      });
      return result == true;
    } catch (e) {
      _logger.e('Failed to disconnect from Bluetooth device: ${device.id}',
          error: e);
      return false;
    }
  }

  Future<DeviceSyncStatus> _syncGarminData(GarminDevice device) async {
    try {
      final result = await _garminChannel.invokeMethod('syncDeviceData', {
        'deviceId': device.id,
      });

      if (result is Map<String, dynamic>) {
        return DeviceSyncStatus.fromJson(result);
      }

      throw Exception('Invalid sync result format');
    } catch (e) {
      throw Exception('Failed to sync Garmin data: $e');
    }
  }

  Future<DeviceSyncStatus> _syncGpsData(ExternalGpsDevice device) async {
    try {
      final result = await _bluetoothChannel.invokeMethod('syncDeviceData', {
        'deviceId': device.id,
      });

      if (result is Map<String, dynamic>) {
        return DeviceSyncStatus.fromJson(result);
      }

      throw Exception('Invalid sync result format');
    } catch (e) {
      throw Exception('Failed to sync GPS data: $e');
    }
  }

  Future<DeviceSyncStatus> _syncBluetoothDeviceData(
      ExternalDevice device) async {
    try {
      final result = await _bluetoothChannel.invokeMethod('syncDeviceData', {
        'deviceId': device.id,
      });

      if (result is Map<String, dynamic>) {
        return DeviceSyncStatus.fromJson(result);
      }

      throw Exception('Invalid sync result format');
    } catch (e) {
      throw Exception('Failed to sync Bluetooth device data: $e');
    }
  }

  Future<void> _startDeviceDataStream(String deviceId) async {
    try {
      final device = _connectedDevices[deviceId];
      if (device == null ||
          !device.capabilities.contains(DeviceCapability.realTimeStreaming)) {
        return;
      }

      switch (device.type) {
        case ExternalDeviceType.garmin:
          await _garminChannel
              .invokeMethod('startDataStream', {'deviceId': deviceId});
          break;
        default:
          await _bluetoothChannel
              .invokeMethod('startDataStream', {'deviceId': deviceId});
          break;
      }
    } catch (e) {
      _logger.e('Failed to start data stream for device: $deviceId', error: e);
    }
  }

  Future<void> _stopDeviceDataStream(String deviceId) async {
    try {
      final subscription = _deviceStreams[deviceId];
      if (subscription != null) {
        await subscription.cancel();
        _deviceStreams.remove(deviceId);
      }

      final device = _connectedDevices[deviceId];
      if (device == null) return;

      switch (device.type) {
        case ExternalDeviceType.garmin:
          await _garminChannel
              .invokeMethod('stopDataStream', {'deviceId': deviceId});
          break;
        default:
          await _bluetoothChannel
              .invokeMethod('stopDataStream', {'deviceId': deviceId});
          break;
      }
    } catch (e) {
      _logger.e('Failed to stop data stream for device: $deviceId', error: e);
    }
  }

  ExternalDevice _updateDeviceConnectionStatus(
    ExternalDevice device,
    DeviceConnectionStatus status,
  ) {
    switch (device.type) {
      case ExternalDeviceType.garmin:
        return (device as GarminDevice).copyWith(
          connectionStatus: status,
          lastConnected: status == DeviceConnectionStatus.connected
              ? DateTime.now()
              : device.lastConnected,
        );
      case ExternalDeviceType.externalGps:
        return (device as ExternalGpsDevice).copyWith(
          connectionStatus: status,
          lastConnected: status == DeviceConnectionStatus.connected
              ? DateTime.now()
              : device.lastConnected,
        );
      default:
        throw UnimplementedError(
            'Device status update not implemented for ${device.type}');
    }
  }

  Future<void> _loadSavedDevices() async {
    try {
      final devicesJson = _prefs?.getString('external_devices');
      if (devicesJson != null) {
        final devicesList = jsonDecode(devicesJson) as List<dynamic>;
        for (final deviceData in devicesList) {
          final device =
              _createDeviceFromJson(deviceData as Map<String, dynamic>);
          if (device != null) {
            _connectedDevices[device.id] = device;
          }
        }
        _notifyDevicesChanged();
      }
    } catch (e) {
      _logger.e('Failed to load saved devices', error: e);
    }
  }

  Future<void> _saveDeviceConfiguration(ExternalDevice device) async {
    try {
      _connectedDevices[device.id] = device;
      final devicesList =
          _connectedDevices.values.map((d) => d.toJson()).toList();
      await _prefs?.setString('external_devices', jsonEncode(devicesList));
    } catch (e) {
      _logger.e('Failed to save device configuration', error: e);
    }
  }

  Future<void> _saveSyncStatus(DeviceSyncStatus syncStatus) async {
    try {
      final syncStatusKey = 'sync_status_${syncStatus.deviceId}';
      await _prefs?.setString(syncStatusKey, jsonEncode(syncStatus.toJson()));
    } catch (e) {
      _logger.e('Failed to save sync status', error: e);
    }
  }

  void _notifyDevicesChanged() {
    _devicesController.add(_connectedDevices.values.toList());
  }

  Future<void> _handleGarminMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onDeviceConnected':
          await _handleDeviceConnected(call.arguments as Map<String, dynamic>);
          break;
        case 'onDeviceDisconnected':
          await _handleDeviceDisconnected(
              call.arguments as Map<String, dynamic>);
          break;
        case 'onDeviceError':
          await _handleDeviceError(call.arguments as Map<String, dynamic>);
          break;
      }
    } catch (e) {
      _logger.e('Failed to handle Garmin method call: ${call.method}',
          error: e);
    }
  }

  Future<void> _handleBluetoothMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onDeviceConnected':
          await _handleDeviceConnected(call.arguments as Map<String, dynamic>);
          break;
        case 'onDeviceDisconnected':
          await _handleDeviceDisconnected(
              call.arguments as Map<String, dynamic>);
          break;
        case 'onDeviceError':
          await _handleDeviceError(call.arguments as Map<String, dynamic>);
          break;
      }
    } catch (e) {
      _logger.e('Failed to handle Bluetooth method call: ${call.method}',
          error: e);
    }
  }

  Future<void> _handleDeviceConnected(Map<String, dynamic> data) async {
    final deviceId = data['deviceId'] as String;
    final device = _connectedDevices[deviceId];
    if (device != null) {
      final updatedDevice = _updateDeviceConnectionStatus(
        device,
        DeviceConnectionStatus.connected,
      );
      _connectedDevices[deviceId] = updatedDevice;
      await _saveDeviceConfiguration(updatedDevice);
      _notifyDevicesChanged();
    }
  }

  Future<void> _handleDeviceDisconnected(Map<String, dynamic> data) async {
    final deviceId = data['deviceId'] as String;
    final device = _connectedDevices[deviceId];
    if (device != null) {
      final updatedDevice = _updateDeviceConnectionStatus(
        device,
        DeviceConnectionStatus.disconnected,
      );
      _connectedDevices[deviceId] = updatedDevice;
      await _saveDeviceConfiguration(updatedDevice);
      _notifyDevicesChanged();
    }
  }

  Future<void> _handleDeviceError(Map<String, dynamic> data) async {
    final deviceId = data['deviceId'] as String;
    final error = data['error'] as String;
    _logger.e('Device error for $deviceId: $error');

    final device = _connectedDevices[deviceId];
    if (device != null) {
      final updatedDevice = _updateDeviceConnectionStatus(
        device,
        DeviceConnectionStatus.error,
      );
      _connectedDevices[deviceId] = updatedDevice;
      await _saveDeviceConfiguration(updatedDevice);
      _notifyDevicesChanged();
    }
  }

  void _handleDeviceDataEvent(Object? event) {
    try {
      if (event is Map<String, dynamic>) {
        final dataReading = DeviceDataReading.fromJson(event);
        _dataController.add(dataReading);
      }
    } catch (e) {
      _logger.e('Failed to handle device data event', error: e);
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    try {
      // Cancel all device streams
      for (final subscription in _deviceStreams.values) {
        await subscription.cancel();
      }
      _deviceStreams.clear();

      // Disconnect all devices
      for (final deviceId in _connectedDevices.keys.toList()) {
        await disconnectFromDevice(deviceId);
      }

      // Close stream controllers
      await _devicesController.close();
      await _dataController.close();

      _isInitialized = false;
      _logger.i('External Device Integration Service disposed');
    } catch (e, stackTrace) {
      _logger.e('Failed to dispose External Device Integration Service',
          error: e, stackTrace: stackTrace);
    }
  }
}
