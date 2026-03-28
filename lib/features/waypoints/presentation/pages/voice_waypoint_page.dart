import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/providers/voice_note_provider.dart';
import 'package:obsession_tracker/core/providers/waypoint_provider.dart';
import 'package:obsession_tracker/core/services/voice_recording_service.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';
import 'package:obsession_tracker/features/waypoints/presentation/widgets/voice_recording_widget.dart';

/// Voice waypoint theme color (Deep Purple Accent)
const Color kVoiceColor = Color(0xFF7C4DFF);

/// Result returned from the voice waypoint page
class VoiceWaypointResult {
  const VoiceWaypointResult({
    required this.saved,
    this.waypoint,
    this.voiceNote,
  });

  final bool saved;
  final Waypoint? waypoint;
  final VoiceNote? voiceNote;

  factory VoiceWaypointResult.saved(Waypoint waypoint, VoiceNote voiceNote) =>
      VoiceWaypointResult(
        saved: true,
        waypoint: waypoint,
        voiceNote: voiceNote,
      );

  factory VoiceWaypointResult.cancelled() => const VoiceWaypointResult(
        saved: false,
      );
}

/// Page for creating a voice waypoint (audio recording)
class VoiceWaypointPage extends ConsumerStatefulWidget {
  const VoiceWaypointPage({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  ConsumerState<VoiceWaypointPage> createState() => _VoiceWaypointPageState();
}

class _VoiceWaypointPageState extends ConsumerState<VoiceWaypointPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;
  Position? _currentPosition;
  String? _locationError;
  VoiceRecordingResult? _recordingResult;
  bool _hasRecorded = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error getting location for voice waypoint: $e');
      if (mounted) {
        setState(() {
          _locationError = 'Could not get current location';
        });
      }
    }
  }

  void _onRecordingComplete(VoiceRecordingResult result) {
    setState(() {
      _recordingResult = result;
      _hasRecorded = result.success;
    });
  }

  Future<void> _save() async {
    if (!_hasRecorded || _recordingResult == null || !_recordingResult!.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please record a voice message first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waiting for GPS location...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();

      // Create the waypoint first
      final waypointNotifier = ref.read(waypointProvider.notifier);
      final waypoint = await waypointNotifier.createWaypointAtCoordinates(
        sessionId: widget.sessionId,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        type: WaypointType.voice,
        name: name.isEmpty ? 'Voice Note' : name,
        altitude: _currentPosition!.altitude,
        accuracy: _currentPosition!.accuracy,
      );

      if (waypoint == null) {
        throw Exception('Failed to create waypoint');
      }

      // Create the voice note and associate it with the waypoint
      final voiceRecordingService = ref.read(voiceRecordingServiceProvider);
      final voiceNote = voiceRecordingService.createVoiceNote(
        waypointId: waypoint.id,
        result: _recordingResult!,
      );

      // Save voice note to database
      final success =
          await ref.read(voiceNoteProvider.notifier).addVoiceNote(voiceNote);

      if (success && mounted) {
        Navigator.of(context)
            .pop(VoiceWaypointResult.saved(waypoint, voiceNote));
      } else if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save voice waypoint'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving voice waypoint: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save voice waypoint: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancel() {
    // Clean up any recorded file if we're canceling
    if (_recordingResult?.success == true && _recordingResult?.filePath != null) {
      final voiceRecordingService = ref.read(voiceRecordingServiceProvider);
      voiceRecordingService.deleteVoiceNoteFile(_recordingResult!.filePath!);
    }
    Navigator.of(context).pop(VoiceWaypointResult.cancelled());
  }

  void _clearRecording() {
    if (_recordingResult?.success == true && _recordingResult?.filePath != null) {
      final voiceRecordingService = ref.read(voiceRecordingServiceProvider);
      voiceRecordingService.deleteVoiceNoteFile(_recordingResult!.filePath!);
    }
    setState(() {
      _recordingResult = null;
      _hasRecorded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Voice Note'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancel,
        ),
        actions: [
          TextButton(
            onPressed: (_isSaving || !_hasRecorded) ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _hasRecorded
                          ? (isDark ? Colors.white : theme.primaryColor)
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: context.responsivePadding,
          child: ResponsiveContentBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Location status
              _buildLocationStatus(isDark),
              const SizedBox(height: 24),

              // Name field (optional)
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name (optional)',
                  hintText: 'Give this voice note a name...',
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 24),

              // Voice recording section
              if (_hasRecorded && _recordingResult != null)
                _buildRecordingComplete(isDark, kVoiceColor)
              else
                VoiceRecordingWidget(
                  onRecordingComplete: _onRecordingComplete,
                ),
              const SizedBox(height: 24),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kVoiceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kVoiceColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mic,
                      color: kVoiceColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Record a voice message up to 30 seconds. It will be saved with your current GPS location.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingComplete(bool isDark, Color kVoiceColor) {
    final duration = _recordingResult!.duration;
    final seconds = (duration / 1000).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kVoiceColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kVoiceColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kVoiceColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: kVoiceColor,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Recording Complete',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${seconds}s recorded',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _clearRecording,
            icon: const Icon(Icons.refresh),
            label: const Text('Record Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kVoiceColor,
              side: BorderSide(color: kVoiceColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStatus(bool isDark) {
    if (_locationError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _locationError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: _getCurrentLocation,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentPosition == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Getting GPS location...'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location acquired',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_currentPosition!.accuracy <= 10)
            const Icon(Icons.gps_fixed, color: Colors.green, size: 16)
          else
            const Icon(Icons.gps_not_fixed, color: Colors.orange, size: 16),
        ],
      ),
    );
  }
}
