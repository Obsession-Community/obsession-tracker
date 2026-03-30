import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';

/// Service for generating and managing custom marker icons
///
/// Generates marker images at runtime using Flutter's Canvas API to match
/// the visual style of the detail sheet (emoji centered on a colored circle
/// with white border and subtle shadow).
///
/// Icons are cached by category to avoid regenerating on every map load.
class CustomMarkerIconService {
  CustomMarkerIconService._();

  static final CustomMarkerIconService instance = CustomMarkerIconService._();

  /// Cache of generated images by category name
  final Map<String, MbxImage> _imageCache = {};

  /// Track which images are registered in current map style
  final Set<String> _registeredImageIds = {};

  /// Base size for marker icons (before device pixel ratio scaling)
  /// Smaller size for cleaner map display (similar to Zillow style)
  static const double baseIconSize = 32.0;

  /// Get the image ID for a marker category
  String getImageId(CustomMarkerCategory category) =>
      'custom-marker-${category.name}';

  /// Get the image ID from category name string
  String getImageIdFromName(String categoryName) =>
      'custom-marker-$categoryName';

  /// Register marker images for all categories present in the data
  ///
  /// Call this before adding the SymbolLayer to ensure all icons are available.
  Future<void> registerImagesForCategories(
    MapboxMap map,
    Set<CustomMarkerCategory> categories,
  ) async {
    for (final category in categories) {
      final imageId = getImageId(category);

      try {
        // Skip if already registered in this style
        if (_registeredImageIds.contains(imageId)) {
          continue;
        }

        // Get or generate the image
        final image = await _getOrGenerateImage(category);

        // Register with Mapbox style
        await map.style.addStyleImage(
          imageId,
          1.0, // scale factor
          image,
          false, // sdf (signed distance field) - false for regular images
          [], // stretchX - not used
          [], // stretchY - not used
          null, // content - not used
        );

        _registeredImageIds.add(imageId);
        debugPrint('[SUCCESS] Registered custom marker image: $imageId');
      } catch (e) {
        debugPrint('[WARNING] Failed to register image for ${category.name}: $e');
        // Continue with other categories - overlay will still work
      }
    }
  }

  /// Get cached image or generate a new one
  Future<MbxImage> _getOrGenerateImage(CustomMarkerCategory category) async {
    final cacheKey = category.name;

    // Check cache first
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    // Generate new image
    final image = await _generateMarkerImage(category);
    _imageCache[cacheKey] = image;
    return image;
  }

  /// Generate a marker image with just the emoji icon
  ///
  /// Renders the emoji with a white outline/stroke for visibility
  /// on any map background. No colored circle - clean, minimal style.
  Future<MbxImage> _generateMarkerImage(CustomMarkerCategory category) async {
    // Use 2x scale for crisp rendering on high-DPI displays
    const scale = 2.0;
    const size = baseIconSize * scale;
    const center = Offset(size / 2, size / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw emoji with white outline for visibility on any background
    const emojiStyle = TextStyle(
      fontSize: size * 0.85, // Larger emoji since no circle
      height: 1.0,
    );

    final textSpan = TextSpan(text: category.emoji, style: emojiStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();

    // Center position for the emoji
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2,
    );

    // Draw a subtle drop shadow
    final shadowPainter = TextPainter(
      text: TextSpan(
        text: category.emoji,
        style: emojiStyle.copyWith(
          foreground: Paint()
            ..color = Colors.black.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    shadowPainter.layout();
    shadowPainter.paint(canvas, textOffset + const Offset(0, 2.0));

    // Draw white stroke/outline for visibility
    for (final offset in [
      const Offset(-1.5, -1.5),
      const Offset(1.5, -1.5),
      const Offset(-1.5, 1.5),
      const Offset(1.5, 1.5),
      const Offset(0, -2.0),
      const Offset(0, 2.0),
      const Offset(-2.0, 0),
      const Offset(2.0, 0),
    ]) {
      final outlineTextPainter = TextPainter(
        text: TextSpan(
          text: category.emoji,
          style: emojiStyle.copyWith(
            foreground: Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      outlineTextPainter.layout();
      outlineTextPainter.paint(canvas, textOffset + offset * scale);
    }

    // Draw the main emoji on top
    textPainter.paint(canvas, textOffset);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to convert image to bytes');
    }

    return MbxImage(
      width: size.toInt(),
      height: size.toInt(),
      data: byteData.buffer.asUint8List(),
    );
  }

  /// Clear registered image IDs (call when map style changes)
  void onStyleChanged() {
    _registeredImageIds.clear();
    debugPrint('[INFO] CustomMarkerIconService: Style changed, cleared registered IDs');
  }

  /// Clear the image cache (for memory management)
  void clearCache() {
    _imageCache.clear();
    _registeredImageIds.clear();
    debugPrint('[INFO] CustomMarkerIconService: Cache cleared');
  }

  /// Build a match expression for icon-image property
  ///
  /// Returns a Mapbox expression that maps category property to image IDs:
  /// ['match', ['get', 'category'], 'researchLead', 'custom-marker-researchLead', ..., 'custom-marker-researchLead']
  List<Object> buildIconImageExpression(Set<CustomMarkerCategory> categories) {
    final expression = <Object>[
      'match',
      ['get', 'category'],
    ];

    for (final category in categories) {
      expression.add(category.name);
      expression.add(getImageId(category));
    }

    // Default fallback to first category (researchLead)
    expression.add(getImageId(CustomMarkerCategory.researchLead));

    return expression;
  }
}
