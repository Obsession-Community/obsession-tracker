import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:obsession_tracker/features/waypoints/presentation/pages/integrated_camera_page.dart';

/// Adaptive camera preview page that provides optimal experience on different screen sizes
/// Now uses the professional camera system with full orientation, multi-lens, and video support
class AdaptiveCameraPreviewPage extends ConsumerWidget {
  const AdaptiveCameraPreviewPage({
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
  Widget build(BuildContext context, WidgetRef ref) =>
      // Professional camera with full orientation support
      // Supports portrait/landscape, multi-lens switching, and video recording
      // Integrated with existing photo waypoint workflow
      IntegratedCameraPage(
        sessionId: sessionId,
        waypointType: waypointType,
        waypointName: waypointName,
        waypointNotes: waypointNotes,
        onPhotoCapture: onPhotoCapture,
      );
}

/// Helper function to navigate to camera preview
Future<PhotoCaptureResult?> showCameraPreview(
  BuildContext context, {
  required String sessionId,
  WaypointType waypointType = WaypointType.photo,
  String? waypointName,
  String? waypointNotes,
}) async =>
    Navigator.of(context).push<PhotoCaptureResult>(
      MaterialPageRoute<PhotoCaptureResult>(
        builder: (context) => AdaptiveCameraPreviewPage(
          sessionId: sessionId,
          waypointType: waypointType,
          waypointName: waypointName,
          waypointNotes: waypointNotes,
        ),
        fullscreenDialog: true,
      ),
    );
