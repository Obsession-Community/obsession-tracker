import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';

/// Page for scanning QR codes during sync pairing
class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _controller = MobileScannerController();

  bool _hasScanned = false;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        // Check if it looks like our sync QR code (base64 encoded JSON)
        final value = barcode.rawValue!;
        if (_isValidSyncQrCode(value)) {
          setState(() => _hasScanned = true);
          Navigator.pop(context, value);
          return;
        }
      }
    }
  }

  bool _isValidSyncQrCode(String value) {
    // Our QR codes are base64 encoded JSON
    // They should be reasonably long and contain only base64 characters
    if (value.length < 50) return false;

    // Check if it's valid base64 (our format uses base64url encoding)
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/=_-]+$');
    return base64Pattern.hasMatch(value);
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchEnabled = !_torchEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? AppTheme.gold : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay with scanning frame
          _buildScanOverlay(),

          // Instructions at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildInstructions(),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        final scanAreaTop = (constraints.maxHeight - scanAreaSize) / 2 - 50;

        return Stack(
          children: [
            // Dark overlay with transparent scan area
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.6),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    top: scanAreaTop,
                    left: (constraints.maxWidth - scanAreaSize) / 2,
                    child: Container(
                      width: scanAreaSize,
                      height: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scan area border
            Positioned(
              top: scanAreaTop,
              left: (constraints.maxWidth - scanAreaSize) / 2,
              child: Container(
                width: scanAreaSize,
                height: scanAreaSize,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.gold,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Corner decorations
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorner(Alignment alignment) {
    const size = 24.0;
    const thickness = 4.0;

    return Positioned(
      top: alignment == Alignment.topLeft || alignment == Alignment.topRight
          ? 0
          : null,
      bottom: alignment == Alignment.bottomLeft ||
              alignment == Alignment.bottomRight
          ? 0
          : null,
      left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
          ? 0
          : null,
      right: alignment == Alignment.topRight ||
              alignment == Alignment.bottomRight
          ? 0
          : null,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _CornerPainter(
            alignment: alignment,
            color: AppTheme.gold,
            thickness: thickness,
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              color: AppTheme.gold,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'Point your camera at the QR code',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The QR code is displayed on the sending device',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for corner decorations
class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.alignment,
    required this.color,
    required this.thickness,
  });

  final Alignment alignment;
  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomRight) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
