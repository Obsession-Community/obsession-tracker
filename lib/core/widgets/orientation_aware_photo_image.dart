import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Widget to display a photo with correct orientation based on metadata
/// Does NOT use EXIF data - uses our saved orientation from database
///
/// Caches the file resolution to avoid unnecessary rebuilds during scrubbing.
class OrientationAwarePhotoImage extends StatefulWidget {
  const OrientationAwarePhotoImage({
    required this.photoPath,
    required this.photoOrientation,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  final String photoPath;
  final String? photoOrientation;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<OrientationAwarePhotoImage> createState() => _OrientationAwarePhotoImageState();
}

class _OrientationAwarePhotoImageState extends State<OrientationAwarePhotoImage> {
  File? _cachedFile;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveFile();
  }

  @override
  void didUpdateWidget(OrientationAwarePhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-resolve if the path changed
    if (oldWidget.photoPath != widget.photoPath) {
      _resolveFile();
    }
  }

  Future<void> _resolveFile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final file = await _resolvePhotoFile(widget.photoPath);
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade300,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasError || _cachedFile == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade300,
        child: Center(
          child: Icon(
            Icons.broken_image,
            size: 32,
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    // Create image widget with caching hints for better performance
    final imageWidget = Image.file(
      _cachedFile!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.width?.toInt(),
      cacheHeight: widget.height?.toInt(),
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey.shade300,
          child: Center(
            child: Icon(
              Icons.broken_image,
              size: 32,
              color: Colors.grey.shade500,
            ),
          ),
        );
      },
    );

    // For landscape photos, rotate 90 degrees counter-clockwise
    if (widget.photoOrientation == 'landscape') {
      return RotatedBox(
        quarterTurns: 3, // 270° clockwise = 90° counter-clockwise
        child: imageWidget,
      );
    }

    // Portrait or unknown - display as-is
    return imageWidget;
  }

  /// Resolve photo file path - converts relative paths to absolute
  Future<File> _resolvePhotoFile(String photoPath) async {
    if (photoPath.startsWith('/')) {
      return File(photoPath);
    }

    final Directory docs = await getApplicationDocumentsDirectory();
    final String absolutePath = path.join(docs.path, photoPath);
    return File(absolutePath);
  }
}
