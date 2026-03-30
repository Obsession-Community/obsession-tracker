import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:obsession_tracker/core/models/land_ownership.dart';
import 'package:obsession_tracker/core/models/map_overlay.dart';

/// Renders land ownership polygons on the map
///
/// This overlay displays land parcels with color-coding based on ownership type.
/// Supports filtering by land type and interactive parcels for details.
class LandOwnershipOverlay extends MapOverlay {
  LandOwnershipOverlay({
    required this.landParcels,
    this.filter,
    this.onParcelTap,
    this.fillOpacity = 0.3,
    this.strokeOpacity = 0.6,
    this.strokeWidth = 1.5,
  });

  final List<LandOwnership> landParcels;
  final LandOwnershipFilter? filter;
  final ValueChanged<LandOwnership>? onParcelTap;
  final double fillOpacity;
  final double strokeOpacity;
  final double strokeWidth;

  static const String sourceId = 'land-ownership-source';
  static const String fillLayerId = 'land-ownership-fill-layer';
  static const String lineLayerId = 'land-ownership-line-layer';

  /// Lock to prevent concurrent load operations that cause race conditions
  static bool _loadInProgress = false;

  @override
  String get id => 'land-ownership-overlay';

  bool _isVisible = true;

  @override
  bool get isVisible => _isVisible;

  /// Filter parcels based on current filter settings
  List<LandOwnership> get _filteredParcels {
    if (filter == null) return landParcels;
    return landParcels.where((parcel) => filter!.passes(parcel)).toList();
  }

  @override
  Future<void> load(MapboxMap map) async {
    final parcels = _filteredParcels;

    if (parcels.isEmpty) {
      debugPrint('⚠️ LandOwnershipOverlay: No parcels to display');
      return;
    }

    // Prevent concurrent loads - serialize access to avoid race conditions
    if (_loadInProgress) {
      debugPrint('⏳ LandOwnershipOverlay: Load already in progress, waiting...');
      // Wait a bit and retry once
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_loadInProgress) {
        debugPrint('⏳ LandOwnershipOverlay: Still busy, skipping duplicate load');
        return;
      }
    }

    _loadInProgress = true;

    try {
      // Create GeoJSON FeatureCollection from land parcels
      final features = <Map<String, dynamic>>[];

      for (final parcel in parcels) {
        // Skip parcels without polygon coordinates from BFF
        if (parcel.polygonCoordinates == null ||
            parcel.polygonCoordinates!.isEmpty) {
          continue;
        }

        // Get agency-specific color (not just ownership type color)
        final agencyColor = _getAgencyColor(parcel.ownerName, parcel.ownershipType);

        // Split MultiPolygon into separate Polygon features
        // This prevents rings 1-N from being rendered as "holes" in ring 0
        final polygons = _splitMultiPolygonCoordinates(parcel.polygonCoordinates!);

        for (int i = 0; i < polygons.length; i++) {
          // Use composite ID for MultiPolygon parts so we can map back to parcel
          final featureId = polygons.length > 1 ? '${parcel.id}_part_$i' : parcel.id;

          features.add({
            'type': 'Feature',
            'id': featureId,
            'geometry': {
              'type': 'Polygon',
              'coordinates': polygons[i],
            },
            'properties': {
              'id': parcel.id, // Always store original parcel ID in properties
              'owner_name': parcel.ownerName,
              'ownership_type': parcel.ownershipType.name,
              'access_type': parcel.accessType.name,
              'unit_name': parcel.unitName ?? '',
              'designation': parcel.designation ?? '',
              // Convert agency color to rgba format for Mapbox
              'color': _colorToRgba(agencyColor, fillOpacity),
            },
          });
        }
      }

      if (features.isEmpty) {
        debugPrint(
          '⚠️ LandOwnershipOverlay: No parcels with polygon coordinates',
        );
        return;
      }

      // Debug: Log ownership types and agency colors being rendered
      final ownershipTypeStats = <String, int>{};
      for (final parcel in landParcels) {
        final agencyColor = _getAgencyColor(parcel.ownerName, parcel.ownershipType);
        final colorHex = '#${(agencyColor & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
        final typeKey = '${parcel.ownerName} ($colorHex) - ${parcel.ownershipType.name}';
        ownershipTypeStats[typeKey] = (ownershipTypeStats[typeKey] ?? 0) + 1;
      }
      debugPrint('🎨 LandOwnershipOverlay: Agency colors (${features.length} features from ${parcels.length} parcels):');
      ownershipTypeStats.forEach((type, count) {
        debugPrint('   $count× $type');
      });

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      final geoJsonString = jsonEncode(geoJson);

      // Strategy: Check if source exists first, then update or create
      // We check explicitly to avoid PlatformException propagation issues
      bool sourceExists = false;
      try {
        final existingSource = await map.style.getSource(sourceId);
        sourceExists = existingSource != null;
      } catch (e) {
        // Source check failed - assume it doesn't exist
        sourceExists = false;
      }

      if (sourceExists) {
        try {
          // Update existing source (fast path if already loaded)
          await map.style.setStyleSourceProperty(
            sourceId,
            'data',
            geoJsonString,
          );
          debugPrint('✅ LandOwnershipOverlay updated existing source: ${features.length} parcels');
          return; // Early return - update successful
        } catch (e) {
          // Update failed - source might have been removed, recreate
          debugPrint('⚠️ LandOwnershipOverlay: Source update failed, will recreate: $e');
        }
      } else {
        debugPrint('📝 LandOwnershipOverlay: Source not found, creating new...');
      }

      // Create new source and layers
      // Clean up any partial/stale state
      await _removeExistingLayersAndSource(map);

      // Add GeoJSON source
      await map.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: geoJsonString,
        ),
      );

      // Add fill layer for polygon areas with per-feature colors
      // Use the color property from each feature's properties
      // Start with opacity 0 for fade-in effect
      await map.style.addLayer(
        FillLayer(
          id: fillLayerId,
          sourceId: sourceId,
          fillOpacity: 0.0, // Start invisible for fade-in
        ),
      );

      // Set fill color to use the color property from features
      // Mapbox expression: ["get", "color"] retrieves the color from feature properties
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'fill-color',
        ['get', 'color'],
      );

      // Add opacity transition for smooth fade-in (200ms)
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'fill-opacity-transition',
        {'duration': 200, 'delay': 0},
      );

      // Now set final opacity to trigger the fade-in animation
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'fill-opacity',
        fillOpacity,
      );

      // Add line layer for polygon borders (start invisible)
      await map.style.addLayer(
        LineLayer(
          id: lineLayerId,
          sourceId: sourceId,
          lineColor: 0xFF000000, // Black border
          lineWidth: strokeWidth,
          lineOpacity: 0.0, // Start invisible for fade-in
        ),
      );

      // Add opacity transition for line layer
      await map.style.setStyleLayerProperty(
        lineLayerId,
        'line-opacity-transition',
        {'duration': 200, 'delay': 0},
      );

      // Set final opacity to trigger fade-in
      await map.style.setStyleLayerProperty(
        lineLayerId,
        'line-opacity',
        strokeOpacity,
      );

      debugPrint(
        '✅ LandOwnershipOverlay loaded: ${features.length} parcels',
      );
    } catch (e) {
      debugPrint('❌ LandOwnershipOverlay load error: $e');
    } finally {
      _loadInProgress = false;
    }
  }

  /// Remove existing layers and source to prevent "already exists" errors
  Future<void> _removeExistingLayersAndSource(MapboxMap map) async {
    try {
      await map.style.removeStyleLayer(lineLayerId);
    } catch (_) {
      // Layer doesn't exist yet, ignore
    }
    try {
      await map.style.removeStyleLayer(fillLayerId);
    } catch (_) {
      // Layer doesn't exist yet, ignore
    }
    try {
      await map.style.removeStyleSource(sourceId);
    } catch (_) {
      // Source doesn't exist yet, ignore
    }
  }

  /// Handle map tap to detect if user tapped on a land parcel
  /// This should be called from the map widget's tap handler
  Future<LandOwnership?> handleTap(
    MapboxMap map,
    ScreenCoordinate screenCoordinate,
  ) async {
    try {
      // Query features at the tap location
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenCoordinate),
        RenderedQueryOptions(layerIds: [fillLayerId]),
      );

      if (features.isEmpty) return null;

      // Get the feature ID from the queried feature
      final feature = features.first;
      if (feature == null) return null;

      final featureId = feature.queriedFeature.feature['id'];
      if (featureId == null) return null;

      // Extract base parcel ID (handles composite IDs like "parcel_123_part_0")
      final baseParcelId = _extractBaseParcelId(featureId.toString());

      // Find the corresponding parcel
      // IMPORTANT: Return null if parcel not found to prevent showing wrong data
      // This can happen when user taps quickly after panning (old polygons still rendered)
      try {
        final parcel = landParcels.firstWhere(
          (p) => p.id == baseParcelId,
        );
        return parcel;
      } catch (e) {
        debugPrint('⚠️ Land parcel tap: Parcel ID $baseParcelId (from feature $featureId) not found in current data');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Land parcel tap detection error: $e');
      return null;
    }
  }

  @override
  Future<void> update(MapboxMap map) async {
    final parcels = _filteredParcels;

    if (parcels.isEmpty) {
      await unload(map);
      return;
    }

    try {
      // Build features list
      final features = <Map<String, dynamic>>[];

      for (final parcel in parcels) {
        if (parcel.polygonCoordinates == null ||
            parcel.polygonCoordinates!.isEmpty) {
          continue;
        }

        // Get agency-specific color (not just ownership type color)
        final agencyColor = _getAgencyColor(parcel.ownerName, parcel.ownershipType);

        // Split MultiPolygon into separate Polygon features
        // This prevents rings 1-N from being rendered as "holes" in ring 0
        final polygons = _splitMultiPolygonCoordinates(parcel.polygonCoordinates!);

        for (int i = 0; i < polygons.length; i++) {
          // Use composite ID for MultiPolygon parts so we can map back to parcel
          final featureId = polygons.length > 1 ? '${parcel.id}_part_$i' : parcel.id;

          features.add({
            'type': 'Feature',
            'id': featureId,
            'geometry': {
              'type': 'Polygon',
              'coordinates': polygons[i],
            },
            'properties': {
              'id': parcel.id, // Always store original parcel ID in properties
              'owner_name': parcel.ownerName,
              'ownership_type': parcel.ownershipType.name,
              'access_type': parcel.accessType.name,
              'unit_name': parcel.unitName ?? '',
              'designation': parcel.designation ?? '',
              // Convert agency color to rgba format for Mapbox
              'color': _colorToRgba(agencyColor, fillOpacity),
            },
          });
        }
      }

      if (features.isEmpty) {
        debugPrint(
          '⚠️ LandOwnershipOverlay: No parcels with polygon coordinates',
        );
        return;
      }

      final geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      // Strategy: Check if source exists first, then update or create
      bool sourceExists = false;
      try {
        final existingSource = await map.style.getSource(sourceId);
        sourceExists = existingSource != null;
      } catch (e) {
        sourceExists = false;
      }

      if (sourceExists) {
        try {
          await map.style.setStyleSourceProperty(
            sourceId,
            'data',
            jsonEncode(geoJson),
          );
          debugPrint(
            '✅ LandOwnershipOverlay updated smoothly: ${features.length} parcels',
          );
          return; // Update successful
        } catch (e) {
          // Fallback: remove and re-add if direct update fails
          debugPrint('⚠️ Smooth update failed, doing full reload: $e');
        }
      }

      // Source doesn't exist or update failed - recreate
      try {
        await map.style.removeStyleLayer(lineLayerId);
      } catch (_) {}
      try {
        await map.style.removeStyleLayer(fillLayerId);
      } catch (_) {}
      try {
        await map.style.removeStyleSource(sourceId);
      } catch (_) {}

      await map.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: jsonEncode(geoJson),
        ),
      );

      await map.style.addLayer(
        FillLayer(
          id: fillLayerId,
          sourceId: sourceId,
          fillOpacity: 0.0, // Start invisible for fade-in
        ),
      );

      // Set fill color to use the color property from features
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'fill-color',
        ['get', 'color'],
      );

      // Add opacity transition for smooth fade-in
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'fill-opacity-transition',
        {'duration': 200, 'delay': 0},
      );

      // Trigger fade-in
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'fill-opacity',
        fillOpacity,
      );

      await map.style.addLayer(
        LineLayer(
          id: lineLayerId,
          sourceId: sourceId,
          lineColor: 0xFF000000,
          lineWidth: strokeWidth,
          lineOpacity: 0.0, // Start invisible
        ),
      );

      // Add line opacity transition
      await map.style.setStyleLayerProperty(
        lineLayerId,
        'line-opacity-transition',
        {'duration': 200, 'delay': 0},
      );

      // Trigger fade-in
      await map.style.setStyleLayerProperty(
        lineLayerId,
        'line-opacity',
        strokeOpacity,
      );

      debugPrint(
        '✅ LandOwnershipOverlay updated via reload: ${features.length} parcels',
      );
    } catch (e) {
      debugPrint('❌ LandOwnershipOverlay update error: $e');
    }
  }

  @override
  Future<void> unload(MapboxMap map) async {
    try {
      // Remove layers first, then source
      try {
        await map.style.removeStyleLayer(lineLayerId);
      } catch (_) {}
      try {
        await map.style.removeStyleLayer(fillLayerId);
      } catch (_) {}
      try {
        await map.style.removeStyleSource(sourceId);
      } catch (_) {}
      debugPrint('✅ LandOwnershipOverlay unloaded');
    } catch (e) {
      debugPrint('❌ LandOwnershipOverlay unload error: $e');
    }
  }

  @override
  Future<void> setVisibility(MapboxMap map, {required bool visible}) async {
    _isVisible = visible;
    try {
      final visibility = visible ? 'visible' : 'none';
      await map.style.setStyleLayerProperty(
        fillLayerId,
        'visibility',
        visibility,
      );
      await map.style.setStyleLayerProperty(
        lineLayerId,
        'visibility',
        visibility,
      );
    } catch (e) {
      debugPrint('❌ LandOwnershipOverlay visibility error: $e');
    }
  }

  /// Split MultiPolygon coordinates into separate Polygon coordinate arrays
  ///
  /// When a parcel has multiple exterior rings (from a MultiPolygon), this method
  /// splits them into separate polygons so each renders as a visible filled area
  /// rather than treating rings 1-N as holes in ring 0.
  ///
  /// Returns a list of polygon coordinate arrays, each suitable for a GeoJSON Polygon.
  List<List<List<List<double>>>> _splitMultiPolygonCoordinates(
    List<List<List<double>>> coordinates,
  ) {
    // If only 1 ring, it's a simple polygon - keep as-is
    if (coordinates.length <= 1) {
      return [coordinates];
    }

    // Multiple rings: treat each as a separate polygon
    // This handles the common case of State Trust lands where each "ring"
    // is actually an exterior boundary of a separate parcel, not a hole.
    // For true MultiPolygons with holes, we'd need winding order detection,
    // but PAD-US State Trust data doesn't have interior holes.
    return coordinates.map((ring) => [ring]).toList();
  }

  /// Get agency-specific color based on owner name
  ///
  /// Follows onX Hunt/Gaia GPS industry conventions for maximum user familiarity.
  /// Falls back to ownership type default color if agency not recognized.
  int _getAgencyColor(String? ownerName, LandOwnershipType ownershipType) {
    switch (ownerName?.toUpperCase()) {
      // ========================================
      // Federal Agencies (onX-style colors)
      // ========================================
      case 'NPS':
        return 0xFF6B8E23; // Olive Drab (National Park Service)
      case 'BLM':
        return 0xFFDAA520; // Goldenrod/Tan (Bureau of Land Management)
      case 'USFS':
      case 'FS':
        return 0xFF228B22; // Forest Green (US Forest Service)
      case 'FWS':
      case 'USFWS':
        return 0xFF20B2AA; // Light Sea Green/Teal (Fish & Wildlife)
      case 'BOR':
      case 'USBR':
        return 0xFF87CEEB; // Sky Blue (Bureau of Reclamation)
      case 'USACE':
        return 0xFF4169E1; // Royal Blue (Army Corps of Engineers)
      case 'DOD':
        return 0xFF708090; // Slate Gray (Dept of Defense)
      case 'DOE':
        return 0xFFFF8C00; // Dark Orange (Dept of Energy)
      case 'TVA':
        return 0xFF008B8B; // Dark Cyan (Tennessee Valley Authority)
      case 'NASA':
        return 0xFF191970; // Midnight Blue
      case 'BIA':
        return 0xFF8B4513; // Saddle Brown (Bureau of Indian Affairs)
      case 'ARS':
        return 0xFF9ACD32; // Yellow Green (Agricultural Research)

      // ========================================
      // State Agencies (Blue tones)
      // ========================================
      case 'SDNR':
        return 0xFF4682B4; // Steel Blue (State DNR/Trust Lands)
      case 'SFW':
        return 0xFF5F9EA0; // Cadet Blue (State Fish & Wildlife)
      case 'SPR':
        return 0xFF6495ED; // Cornflower Blue (State Parks & Rec)
      case 'OTHS':
        return 0xFF4682B4; // Steel Blue (Other State)

      // ========================================
      // Local Government (Purple tones)
      // ========================================
      case 'CITY':
        return 0xFFBA55D3; // Medium Orchid (City/Municipal)
      case 'CNTY':
        return 0xFF9370DB; // Medium Purple (County)

      // ========================================
      // NGO/Conservation (Aqua tones)
      // ========================================
      case 'NGO':
        return 0xFF66CDAA; // Medium Aquamarine (Conservation orgs)
      case 'PVT':
        return 0xFFDC143C; // Crimson (Private - warning)

      // ========================================
      // Unknown/Other
      // ========================================
      case 'UNK':
      case 'UNKL':
        return 0xFF696969; // Dim Gray

      default:
        return ownershipType.defaultColor;
    }
  }

  /// Extract base parcel ID from a potentially composite feature ID
  ///
  /// Feature IDs may be composite (e.g., "parcel_123_part_0") for MultiPolygon
  /// parcels that were split into separate features. This extracts the base ID.
  String _extractBaseParcelId(String featureId) {
    // Check if this is a composite ID (contains "_part_")
    final partIndex = featureId.lastIndexOf('_part_');
    if (partIndex > 0) {
      return featureId.substring(0, partIndex);
    }
    return featureId;
  }

  /// Convert Flutter color (int) to RGBA string for Mapbox
  /// Example: 0xFFFF5733 with opacity 0.3 -> "rgba(255, 87, 51, 0.3)"
  String _colorToRgba(int colorValue, double opacity) {
    final r = (colorValue >> 16) & 0xFF;
    final g = (colorValue >> 8) & 0xFF;
    final b = colorValue & 0xFF;
    return 'rgba($r, $g, $b, $opacity)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LandOwnershipOverlay &&
          runtimeType == other.runtimeType &&
          landParcels.length == other.landParcels.length &&
          fillOpacity == other.fillOpacity;

  @override
  int get hashCode => landParcels.length.hashCode ^ fillOpacity.hashCode;
}
