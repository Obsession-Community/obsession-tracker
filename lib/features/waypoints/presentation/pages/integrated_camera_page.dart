import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/photo_capture_data.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:obsession_tracker/core/services/photo_storage_service.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/photo_preview_page.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/pro_camera_page.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Integrated camera page that uses the new ProCameraPage but maintains
/// compatibility with the old PhotoCaptureService workflow
class IntegratedCameraPage extends ConsumerStatefulWidget {
  const IntegratedCameraPage({
    required this.sessionId,
    super.key,
    this.waypointType = WaypointType.photo,
    this.waypointName,
    this.waypointNotes,
    this.onPhotoCapture,
  });

  final String sessionId;
  final WaypointType waypointType;
  final String? waypointName;
  final String? waypointNotes;
  final void Function(PhotoCaptureResult result)? onPhotoCapture;

  @override
  ConsumerState<IntegratedCameraPage> createState() =>
      _IntegratedCameraPageState();
}

class _IntegratedCameraPageState extends ConsumerState<IntegratedCameraPage> {
  static const Uuid _uuid = Uuid();

  @override
  Widget build(BuildContext context) => ProCameraPage(
        sessionId: widget.sessionId,
        onPhotoCapture: _handlePhotoCapture,
        onVideoCapture: _handleVideoCapture,
      );

  Future<void> _handlePhotoCapture(PhotoCaptureData captureData) async {
    try {
      // Show preview page to let user add a note before saving
      final previewResult = await Navigator.of(context).push<PhotoPreviewResult>(
        MaterialPageRoute(
          builder: (context) => PhotoPreviewPage(
            captureData: captureData,
            sessionId: widget.sessionId,
          ),
        ),
      );

      // Check if still mounted after navigation
      if (!mounted) {
        debugPrint('Widget unmounted during photo preview - skipping');
        return;
      }

      // Handle preview result
      if (previewResult == null) {
        // User pressed back - cancel entirely
        Navigator.of(context).pop();
        return;
      }

      if (previewResult.action == PhotoPreviewAction.retake) {
        // User wants to retake - stay on camera (do nothing, returns to ProCameraPage)
        return;
      }

      // User wants to save - process photo and create waypoint
      final result = await _createPhotoWaypoint(captureData, note: previewResult.note);

      // IMPORTANT: Check mounted BEFORE using ref to avoid
      // "Using ref when widget is unmounted" error
      if (!mounted) {
        debugPrint('Widget unmounted during photo capture - skipping ref access');
        return;
      }

      // Notify callback
      widget.onPhotoCapture?.call(result);

      // Update waypoint provider state so map UI shows the new waypoint
      if (result.success && result.waypoint != null) {
        ref.read(waypointProvider.notifier).addWaypointToState(result.waypoint!);
      }

      // Refresh photo provider - only if still mounted
      if (mounted) {
        ref.invalidate(photoProvider);
      }

      // Return result to caller
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      debugPrint('Error handling photo capture: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleVideoCapture(XFile video) async {
    try {
      // For now, videos are not fully integrated with waypoints
      // This is a placeholder for future video waypoint support
      debugPrint('Video captured: ${video.path}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video recording saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error handling video capture: $e');
    }
  }

  Future<PhotoCaptureResult> _createPhotoWaypoint(
    PhotoCaptureData captureData, {
    String? note,
  }) async {
    try {
      // Get current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        debugPrint('Warning: Could not get current location: $e');
      }

      // Read photo data
      final Uint8List photoData = await captureData.photo.readAsBytes();

      // Generate unique IDs
      final String waypointId = _uuid.v4();
      final String photoWaypointId = _uuid.v4();
      final DateTime now = DateTime.now();

      // Save photo to app storage
      final storageService = PhotoStorageService();
      final String photoPath = await storageService.storePhoto(
        sessionId: widget.sessionId,
        photoData: photoData,
      );

      // Get file info
      final file = File(captureData.photo.path);
      final int fileSize = await file.length();

      // Create waypoint
      final Waypoint waypoint = Waypoint.fromLocation(
        id: waypointId,
        latitude: position?.latitude ?? 0.0,
        longitude: position?.longitude ?? 0.0,
        type: widget.waypointType,
        timestamp: now,
        sessionId: widget.sessionId,
        name: widget.waypointName,
        notes: note ?? widget.waypointNotes,
        altitude: position?.altitude,
        accuracy: position?.accuracy,
        speed: position?.speed,
        heading: position?.heading,
      );

      // Create photo waypoint with sensor data
      final PhotoWaypoint photoWaypoint = PhotoWaypoint(
        id: photoWaypointId,
        waypointId: waypointId,
        filePath: photoPath,
        createdAt: now,
        fileSize: fileSize,
        devicePitch: captureData.devicePitch,
        deviceRoll: captureData.deviceRoll,
        deviceYaw: captureData.deviceYaw,
        photoOrientation: captureData.photoOrientation,
      );

      debugPrint('💾 Saving photo with sensor data:');
      debugPrint('   Pitch: ${captureData.devicePitch}°');
      debugPrint('   Roll: ${captureData.deviceRoll}°');
      debugPrint('   Yaw: ${captureData.deviceYaw}°');
      debugPrint('   Orientation: ${captureData.photoOrientation}');

      // Save to database
      final databaseService = DatabaseService();
      await databaseService.insertWaypoint(waypoint);
      await _insertPhotoWaypoint(photoWaypoint);

      debugPrint('Successfully created photo waypoint: $photoWaypointId');

      return PhotoCaptureResult(
        success: true,
        photoWaypoint: photoWaypoint,
        waypoint: waypoint,
        locationData: position != null
            ? PhotoLocationData(
                position: position,
                timestamp: now,
              )
            : null,
      );
    } catch (e) {
      debugPrint('Error creating photo waypoint: $e');
      return PhotoCaptureResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _insertPhotoWaypoint(PhotoWaypoint photoWaypoint) async {
    final databaseService = DatabaseService();
    final Database db = await databaseService.database;
    await db.insert(
      'photo_waypoints',
      photoWaypoint.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
