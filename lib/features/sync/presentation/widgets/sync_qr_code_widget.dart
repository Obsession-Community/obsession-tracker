import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Widget to display a QR code for sync pairing
class SyncQrCodeWidget extends StatefulWidget {
  const SyncQrCodeWidget({
    super.key,
    required this.qrData,
    required this.deviceName,
    required this.expiresAt,
    this.onExpired,
  });

  /// The data to encode in the QR code
  final String qrData;

  /// Name of this device to display
  final String deviceName;

  /// When the QR code expires
  final DateTime expiresAt;

  /// Callback when the QR code expires
  final VoidCallback? onExpired;

  @override
  State<SyncQrCodeWidget> createState() => _SyncQrCodeWidgetState();
}

class _SyncQrCodeWidgetState extends State<SyncQrCodeWidget> {
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeRemaining() {
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      _timer?.cancel();
      widget.onExpired?.call();
      setState(() {
        _timeRemaining = Duration.zero;
      });
    } else {
      setState(() {
        _timeRemaining = remaining;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _timeRemaining <= Duration.zero;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // QR Code container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // QR Code
              QrImageView(
                data: widget.qrData,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  color: Colors.black,
                ),
              ),

              // Expired overlay
              if (isExpired)
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_off,
                        color: Colors.white,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Expired',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Device name
        Text(
          widget.deviceName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 8),

        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isExpired
                ? Colors.red.withValues(alpha: 0.1)
                : AppTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpired
                  ? Colors.red.withValues(alpha: 0.3)
                  : AppTheme.gold.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpired ? Icons.timer_off : Icons.timer,
                size: 18,
                color: isExpired ? Colors.red : AppTheme.gold,
              ),
              const SizedBox(width: 8),
              Text(
                isExpired ? 'Expired' : 'Expires in ${_formatDuration(_timeRemaining)}',
                style: TextStyle(
                  color: isExpired ? Colors.red : AppTheme.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Instructions
        Text(
          'Scan this code with the receiving device',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
