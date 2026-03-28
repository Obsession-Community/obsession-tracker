import 'package:camera/camera.dart';

/// Data passed when a photo is captured, including sensor readings
class PhotoCaptureData {
  const PhotoCaptureData({
    required this.photo,
    this.devicePitch,
    this.deviceRoll,
    this.deviceYaw,
    this.photoOrientation,
  });

  final XFile photo;
  final double? devicePitch;
  final double? deviceRoll;
  final double? deviceYaw;
  final String? photoOrientation;
}
