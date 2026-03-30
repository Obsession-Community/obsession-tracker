# Camera System Overhaul - Technical Documentation

## Overview

The Obsession Tracker camera system has been completely rebuilt to provide professional-grade camera functionality with proper orientation handling, multi-lens support, and video recording capabilities.

## Problem Statement

The previous camera implementation had several critical issues:

1. **Orientation Bug**: When the device was rotated to landscape, the camera was applying rotation transforms to the video stream instead of properly handling device orientation. This resulted in a rotated/transformed video instead of a native landscape camera view.

2. **Limited Camera Access**: Only basic front/back camera switching was supported. Multi-lens devices (with ultra-wide, telephoto, etc.) could not access different lenses.

3. **No Video Support**: Photo-only mode with no video recording capabilities.

4. **No Filter Control**: Users couldn't remove or control camera filters/effects.

5. **App-Wide Portrait Lock**: The app was locked to portrait mode in `main.dart`, preventing landscape camera use.

## Solution Architecture

### 1. Enhanced Camera Controller Service
**File**: `lib/core/services/enhanced_camera_controller_service.dart`

This is the core camera service that provides:

#### Camera Enumeration & Classification
- Automatically detects all available cameras on the device
- Classifies cameras by lens type:
  - Ultra Wide (0.5x)
  - Wide (1x) - Standard lens
  - Telephoto 2x
  - Telephoto 3x
  - Other telephoto lenses
- Platform-specific detection for iOS and Android
- Sorts cameras by direction (back first) and lens type

#### Orientation Handling
Three orientation modes:
- **Unlocked**: Device orientation controls camera (default)
- **Portrait Lock**: Camera locked to portrait
- **Landscape Lock**: Camera locked to landscape

Uses `lockCaptureOrientation()` API properly instead of applying transforms.

#### Capture Modes
- **Photo Mode**: High-resolution still images
- **Video Mode**: Video recording with audio

#### Settings Persistence
- Saves user preferences to SharedPreferences
- Remembers:
  - Preferred camera direction (front/back)
  - Preferred lens type
  - Capture mode (photo/video)
  - Orientation lock state
  - Flash mode

#### Video Recording
- Start/stop recording with `startVideoRecording()` and `stopVideoRecording()`
- Recording state tracking
- Returns `XFile` with video path

### 2. Riverpod State Management
**File**: `lib/core/providers/enhanced_camera_provider.dart`

Providers for:
- `enhancedCameraServiceProvider`: Singleton camera service
- `cameraStateStreamProvider`: Reactive state updates
- `currentCameraStateProvider`: Current camera state
- `availableCamerasProvider`: List of available cameras
- `cameraSettingsProvider`: Current settings

### 3. Professional Camera UI
**File**: `lib/features/waypoints/presentation/pages/pro_camera_page.dart`

Full-featured camera interface with:

#### Top Controls
- Close button
- Lens selector (shows all available lenses: 0.5x, 1x, 2x, 3x, etc.)
- Settings menu

#### Bottom Controls
- Mode selector (PHOTO / VIDEO)
- Flash toggle (Off / Auto / On)
- Capture button (changes shape when recording video)
- Camera flip (front/back)

#### Visual Feedback
- Recording indicator with timer (HH:MM:SS or MM:SS)
- Red pulsing dot during recording
- Smooth mode transitions
- Haptic feedback on all interactions

#### Settings Menu
- Orientation lock control
- Flash mode control
- Easy access via bottom sheet

### 4. Integration Layer
**File**: `lib/features/waypoints/presentation/pages/integrated_camera_page.dart`

Maintains backward compatibility with existing `PhotoCaptureService` workflow:
- Wraps `ProCameraPage`
- Converts `XFile` results to `PhotoCaptureResult`
- Creates waypoints and photo waypoints
- Saves to database using existing schema
- Integrates with location services

### 5. Updated Adaptive Camera
**File**: `lib/features/waypoints/presentation/pages/adaptive_camera_preview_page.dart`

Drop-in replacement for the old camera pages:
- Same API surface
- Uses new camera system under the hood
- No changes needed in calling code

## Key Features

### ✅ Proper Orientation Support
- Device orientation detection via accelerometer
- Native landscape/portrait camera modes
- No video transformation - actual orientation change
- Smooth rotation without preview jumps

### ✅ Multi-Lens Support
Automatically detects and exposes all device cameras:
- iPhone 15 Pro: Ultra Wide (0.5x), Wide (1x), Telephoto (3x)
- Samsung Galaxy S24: Ultra Wide, Wide, Telephoto (3x), Telephoto (10x)
- Pixel 8 Pro: Ultra Wide, Wide, Telephoto (5x)

Users can switch between lenses with a single tap.

### ✅ Video Recording
- Start/stop recording
- Live duration display
- Audio capture enabled in video mode
- Visual recording indicator
- Returns video file path

### ✅ No Filters
Clean camera implementation without color grading or effects.
Raw sensor data with proper exposure and white balance.

### ✅ Settings Persistence
User preferences saved between sessions:
- Last used lens
- Preferred camera (front/back)
- Capture mode
- Orientation preference

## Migration Guide

### For Existing Code

The new camera system is a **drop-in replacement**. No changes needed:

```dart
// Old code - still works!
showCameraPreview(
  context,
  sessionId: sessionId,
  waypointType: WaypointType.photo,
);
```

### For New Code

Use the `ProCameraPage` directly for advanced features:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ProCameraPage(
      sessionId: sessionId,
      onPhotoCapture: (photo) {
        // Handle photo
      },
      onVideoCapture: (video) {
        // Handle video
      },
    ),
  ),
);
```

### For Custom Implementations

Access the camera service directly:

```dart
final service = ref.read(enhancedCameraServiceProvider);

// Initialize
await service.initialize();

// Switch to telephoto
await service.switchToLens(CameraLensType.telephoto2x);

// Take photo
final photo = await service.takePicture();

// Start video recording
await service.startVideoRecording();
await Future.delayed(Duration(seconds: 5));
final video = await service.stopVideoRecording();
```

## Technical Details

### Camera Detection Algorithm

**iOS Detection**:
```dart
if (name.contains('ultra wide') || name.contains('0.5')) {
  return CameraLensType.ultraWide;
}
if (name.contains('telephoto')) {
  if (name.contains('3x')) return CameraLensType.telephoto3x;
  if (name.contains('2x')) return CameraLensType.telephoto2x;
  return CameraLensType.telephotoOther;
}
```

**Android Detection**:
- First back camera: Wide (1x)
- Cameras with "ultra" in name: Ultra Wide
- Cameras with "tele" in name: Telephoto

### Orientation Lock Implementation

Uses the camera plugin's native orientation lock:

```dart
// Unlocked - device orientation controls camera
await controller.lockCaptureOrientation(null);

// Portrait lock
await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

// Landscape lock
await controller.lockCaptureOrientation(DeviceOrientation.landscapeRight);
```

**NOT** using CSS transforms, rotation matrices, or post-processing.

### Video Recording Flow

1. User switches to VIDEO mode
2. Camera controller recreated with `enableAudio: true`
3. User taps capture button
4. `startVideoRecording()` called
5. Timer starts, UI shows recording indicator
6. User taps again to stop
7. `stopVideoRecording()` returns `XFile`
8. Video saved to device

### State Management

Camera state is reactive via Riverpod streams:

```dart
ref.watch(cameraStateStreamProvider).when(
  data: (state) {
    // state.isRecording
    // state.currentCamera
    // state.settings
    // state.availableLenses
  },
);
```

## Performance Considerations

### Memory Management
- Single camera controller instance
- Proper disposal on app lifecycle changes
- Automatic cleanup on provider disposal

### Battery Impact
- Camera only active when page is visible
- Background pause/resume support
- Efficient lens switching (disposes old controller)

### Storage
- Settings: <1KB in SharedPreferences
- No caching of camera frames
- Minimal overhead

## Testing Recommendations

### Unit Tests
- Camera enumeration logic
- Lens type detection
- Settings persistence
- Orientation lock state machine

### Integration Tests
- Photo capture workflow
- Video recording workflow
- Camera switching
- Orientation changes

### Device Tests
**Priority Devices**:
1. iPhone 15 Pro (3 lenses)
2. Samsung Galaxy S24 Ultra (4+ lenses)
3. Google Pixel 8 Pro (3 lenses)
4. Budget Android (single lens)

**Test Scenarios**:
- Rotate device while previewing
- Switch lenses while recording
- Rapid camera flipping
- Low light conditions
- Airplane mode (no location)

## Known Limitations

1. **Zoom Levels**: Currently only switches physical lenses. Digital zoom within a lens not yet implemented.

2. **Video Waypoints**: Videos are captured but not fully integrated into waypoint schema (photos only).

3. **Lens Detection**: Android lens detection is heuristic-based. May not detect all lens types on every device.

4. **Settings UI**: Full settings menu is basic. Advanced controls (exposure, ISO, etc.) not exposed.

5. **Orientation Lock UI**: Settings menu for orientation lock. No on-screen lock button yet.

## Future Enhancements

### Planned Features
- [ ] Digital zoom within lens range
- [ ] Exposure compensation slider
- [ ] Focus/exposure lock
- [ ] Grid overlay options
- [ ] Level indicator
- [ ] Histogram display
- [ ] RAW capture support
- [ ] Video waypoint integration
- [ ] Slow motion recording
- [ ] Time-lapse mode

### Wishlist
- Manual focus control
- Manual exposure (ISO, shutter speed)
- HDR mode toggle
- Night mode
- Portrait mode
- Macro mode
- Pro mode with full manual controls

## Troubleshooting

### Camera Won't Initialize
- Check camera permissions in device settings
- Verify camera hardware is functional
- Check for conflicting camera apps
- Restart app

### Wrong Lens Selected
- Manually switch using lens selector
- Preferred lens saved automatically
- Check camera classification in logs

### Orientation Not Working
- Verify app allows landscape (removed portrait lock)
- Check device rotation lock is off
- Try orientation lock settings

### Video Recording Fails
- Check storage space
- Verify microphone permissions
- Ensure device supports video recording

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      ProCameraPage                          │
│  (Full UI with controls, preview, recording indicator)     │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├──> CameraStateStreamProvider (Riverpod)
                  │
┌─────────────────▼───────────────────────────────────────────┐
│        EnhancedCameraControllerService                      │
│  • Camera enumeration & classification                      │
│  • Lens type detection (0.5x, 1x, 2x, 3x)                  │
│  • Orientation lock (unlocked/portrait/landscape)           │
│  • Capture modes (photo/video)                              │
│  • Settings persistence (SharedPreferences)                 │
│  • Video recording state management                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              CameraController (camera plugin)               │
│  • Native camera access                                     │
│  • Orientation control                                      │
│  • Photo/video capture                                      │
│  • Flash control                                            │
└─────────────────────────────────────────────────────────────┘
```

## Credits

Built for Obsession Tracker by Claude (Anthropic)
Date: October 5, 2025
Version: 1.0.0

## License

Part of Obsession Tracker - Privacy-first GPS tracking app
See main LICENSE file for details
