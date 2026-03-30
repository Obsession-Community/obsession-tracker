import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Local HTTP server that serves tiles from MBTiles files.
///
/// MBTiles is a SQLite database with a specific schema for storing map tiles.
/// This server reads tiles from the database and serves them via HTTP,
/// allowing Mapbox SDK to use them as a regular tile source.
class MBTilesTileServer {
  MBTilesTileServer._();
  static final MBTilesTileServer instance = MBTilesTileServer._();

  HttpServer? _server;
  int _port = 0;
  final Map<String, Database> _openDatabases = {};

  /// Whether the server is currently running
  bool get isRunning => _server != null;

  /// The port the server is running on (0 if not running)
  int get port => _port;

  /// Get the base URL for the tile server
  String get baseUrl => isRunning ? 'http://127.0.0.1:$_port' : '';

  /// Start the tile server on an available port
  Future<void> start() async {
    if (_server != null) {
      debugPrint('🌐 MBTiles tile server already running on port $_port');
      return;
    }

    final router = Router();

    // Health check endpoint
    router.get('/health', (Request request) {
      return Response.ok('MBTiles Tile Server OK');
    });

    // Tile endpoint: /<mbtiles_id>/<z>/<x>/<y>.png
    // mbtiles_id is the filename without extension
    router.get('/<mbtiles_id>/<z|[0-9]+>/<x|[0-9]+>/<y|[0-9]+>.png',
        (Request request, String mbtilesId, String z, String x, String y) async {
      return _serveTile(mbtilesId, int.parse(z), int.parse(x), int.parse(y));
    });

    // Also support .jpg extension
    router.get('/<mbtiles_id>/<z|[0-9]+>/<x|[0-9]+>/<y|[0-9]+>.jpg',
        (Request request, String mbtilesId, String z, String x, String y) async {
      return _serveTile(mbtilesId, int.parse(z), int.parse(x), int.parse(y));
    });

    // TileJSON endpoint for source metadata
    router.get('/<mbtiles_id>/tilejson.json',
        (Request request, String mbtilesId) async {
      return _serveTileJson(mbtilesId);
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    // Bind to localhost on any available port
    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    debugPrint('🌐 MBTiles tile server started on http://127.0.0.1:$_port');
  }

  /// Stop the tile server
  Future<void> stop() async {
    if (_server == null) return;

    await _server!.close(force: true);
    _server = null;
    _port = 0;

    // Close all open databases
    for (final db in _openDatabases.values) {
      await db.close();
    }
    _openDatabases.clear();

    debugPrint('🌐 MBTiles tile server stopped');
  }

  /// CORS middleware to allow cross-origin requests from WebView
  ///
  /// WebView loads HTML via loadHtmlString which has a different origin
  /// than the localhost tile server, so we need to allow CORS.
  Middleware _corsMiddleware() {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Max-Age': '86400', // Cache preflight for 24 hours
    };

    return (Handler innerHandler) {
      return (Request request) async {
        // Handle preflight OPTIONS request
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: corsHeaders);
        }

        // Add CORS headers to all responses
        final response = await innerHandler(request);
        return response.change(headers: {...response.headers, ...corsHeaders});
      };
    };
  }

  /// Register an MBTiles file to be served
  Future<void> registerMBTiles(String id, String filePath) async {
    if (_openDatabases.containsKey(id)) {
      debugPrint('🌐 MBTiles already registered: $id');
      return;
    }

    try {
      final db = await openDatabase(filePath, readOnly: true);
      _openDatabases[id] = db;
      debugPrint('🌐 Registered MBTiles: $id -> $filePath');

      // Log metadata to help debug coverage
      await _logMBTilesMetadata(id, db);
    } catch (e) {
      debugPrint('❌ Failed to register MBTiles $id: $e');
    }
  }

  /// Log MBTiles metadata to help debug coverage issues
  Future<void> _logMBTilesMetadata(String id, Database db) async {
    try {
      final metadata = await db.rawQuery('SELECT name, value FROM metadata');
      final metaMap = <String, String>{};
      for (final row in metadata) {
        final name = row['name'];
        final value = row['value'];
        if (name is String && value is String) {
          metaMap[name] = value;
        }
      }

      debugPrint('🗺️ MBTiles metadata for $id:');
      debugPrint('   Name: ${metaMap['name'] ?? 'unknown'}');
      debugPrint('   Bounds: ${metaMap['bounds'] ?? 'not specified'}');
      debugPrint('   Center: ${metaMap['center'] ?? 'not specified'}');
      debugPrint('   Min zoom: ${metaMap['minzoom'] ?? 'not specified'}');
      debugPrint('   Max zoom: ${metaMap['maxzoom'] ?? 'not specified'}');
      debugPrint('   Format: ${metaMap['format'] ?? 'not specified'}');

      // Count tiles at each zoom level
      final tileCounts = await db.rawQuery('''
        SELECT zoom_level, COUNT(*) as count
        FROM tiles
        GROUP BY zoom_level
        ORDER BY zoom_level
      ''');
      debugPrint('   Tile counts by zoom:');
      for (final row in tileCounts) {
        debugPrint('     z${row['zoom_level']}: ${row['count']} tiles');
      }
    } catch (e) {
      debugPrint('⚠️ Could not read MBTiles metadata: $e');
    }
  }

  /// Unregister an MBTiles file
  Future<void> unregisterMBTiles(String id) async {
    final db = _openDatabases.remove(id);
    if (db != null) {
      await db.close();
      debugPrint('🌐 Unregistered MBTiles: $id');
    }
  }

  /// Get the tile URL template for a registered MBTiles
  String getTileUrlTemplate(String mbtilesId) {
    if (!isRunning) return '';
    return '$baseUrl/$mbtilesId/{z}/{x}/{y}.png';
  }

  /// Get the TileJSON URL for a registered MBTiles
  String getTileJsonUrl(String mbtilesId) {
    if (!isRunning) return '';
    return '$baseUrl/$mbtilesId/tilejson.json';
  }

  /// Check if an MBTiles is registered
  bool isRegistered(String id) {
    return _openDatabases.containsKey(id);
  }

  /// Get list of all registered MBTiles IDs
  List<String> getRegisteredIds() {
    return _openDatabases.keys.toList();
  }

  /// Get the maxzoom level for a registered MBTiles file
  /// Returns null if not registered or metadata unavailable
  Future<int?> getMaxZoom(String id) async {
    final db = _openDatabases[id];
    if (db == null) return null;

    try {
      final result = await db.rawQuery(
        "SELECT value FROM metadata WHERE name = 'maxzoom'",
      );
      if (result.isNotEmpty) {
        final value = result.first['value'];
        if (value is String) {
          return int.tryParse(value);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not read maxzoom for $id: $e');
    }
    return null;
  }

  /// Register a quadrangle MBTiles with a standardized ID
  /// Returns the registration ID used for tile URLs
  Future<String> registerQuadrangle({
    required String stateCode,
    required String eraId,
    required String quadId,
    required String filePath,
  }) async {
    final registrationId = 'quad_${stateCode.toLowerCase()}_${eraId}_$quadId';
    await registerMBTiles(registrationId, filePath);
    return registrationId;
  }

  /// Unregister a quadrangle MBTiles
  Future<void> unregisterQuadrangle({
    required String stateCode,
    required String eraId,
    required String quadId,
  }) async {
    final registrationId = 'quad_${stateCode.toLowerCase()}_${eraId}_$quadId';
    await unregisterMBTiles(registrationId);
  }

  /// Get tile URL template for a quadrangle
  String getQuadrangleTileUrl({
    required String stateCode,
    required String eraId,
    required String quadId,
  }) {
    final registrationId = 'quad_${stateCode.toLowerCase()}_${eraId}_$quadId';
    return getTileUrlTemplate(registrationId);
  }

  /// Check if a quadrangle is registered
  bool isQuadrangleRegistered({
    required String stateCode,
    required String eraId,
    required String quadId,
  }) {
    final registrationId = 'quad_${stateCode.toLowerCase()}_${eraId}_$quadId';
    return isRegistered(registrationId);
  }

  /// Serve a tile from the MBTiles database
  Future<Response> _serveTile(String mbtilesId, int z, int x, int y) async {
    debugPrint('🎯 TILE REQUEST: $mbtilesId/$z/$x/$y');

    final db = _openDatabases[mbtilesId];
    if (db == null) {
      debugPrint('❌ TILE ERROR: MBTiles not found: $mbtilesId');
      debugPrint('❌   Registered IDs: ${_openDatabases.keys.toList()}');
      return Response.notFound('MBTiles not found: $mbtilesId');
    }

    try {
      // MBTiles uses TMS scheme where Y is flipped
      final tmsY = (1 << z) - 1 - y;

      final result = await db.rawQuery(
        'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
        [z, x, tmsY],
      );

      if (result.isEmpty) {
        // Return transparent 1x1 PNG for missing tiles
        return Response.ok(
          _transparentPng,
          headers: {
            'Content-Type': 'image/png',
            'Cache-Control': 'max-age=3600',
          },
        );
      }

      final rawTileData = result.first['tile_data'];
      if (rawTileData is! Uint8List) {
        return Response.internalServerError(body: 'Invalid tile data');
      }

      // Check if tile is gzip compressed (common in MBTiles)
      // Gzip magic bytes: 0x1f 0x8b
      Uint8List tileData = rawTileData;
      if (rawTileData.length >= 2 && rawTileData[0] == 0x1f && rawTileData[1] == 0x8b) {
        debugPrint('🗜️ Tile is gzip compressed, decompressing...');
        try {
          tileData = Uint8List.fromList(gzip.decode(rawTileData));
          debugPrint('🗜️ Decompressed to ${tileData.length} bytes');
        } catch (e) {
          debugPrint('❌ Failed to decompress tile: $e');
        }
      }

      // Detect content type from tile data
      final contentType = _detectContentType(tileData);

      // Debug: Log tile info to help diagnose rendering issues
      debugPrint('🎨 Tile $mbtilesId/$z/$x/$y: ${tileData.length} bytes, type: $contentType');
      if (tileData.length >= 4) {
        debugPrint('   Magic bytes: ${tileData.sublist(0, 4).map((int b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      }

      return Response.ok(
        tileData,
        headers: {
          'Content-Type': contentType,
          'Cache-Control': 'max-age=3600',
        },
      );
    } catch (e) {
      debugPrint('❌ Error serving tile $mbtilesId/$z/$x/$y: $e');
      return Response.internalServerError(body: 'Error reading tile: $e');
    }
  }

  /// Serve TileJSON metadata for an MBTiles file
  Future<Response> _serveTileJson(String mbtilesId) async {
    final db = _openDatabases[mbtilesId];
    if (db == null) {
      return Response.notFound('MBTiles not found: $mbtilesId');
    }

    try {
      final metadata = await db.rawQuery('SELECT name, value FROM metadata');
      final metaMap = <String, String>{};
      for (final row in metadata) {
        final name = row['name'];
        final value = row['value'];
        if (name is String && value is String) {
          metaMap[name] = value;
        }
      }

      final tileJson = {
        'tilejson': '2.2.0',
        'name': metaMap['name'] ?? mbtilesId,
        'description': metaMap['description'] ?? '',
        'version': metaMap['version'] ?? '1.0.0',
        'attribution': metaMap['attribution'] ?? '',
        'tiles': [getTileUrlTemplate(mbtilesId)],
        'minzoom': int.tryParse(metaMap['minzoom'] ?? '0') ?? 0,
        'maxzoom': int.tryParse(metaMap['maxzoom'] ?? '22') ?? 22,
        'bounds': _parseBounds(metaMap['bounds']),
        'center': _parseCenter(metaMap['center']),
      };

      return Response.ok(
        tileJson.toString(),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'max-age=3600',
        },
      );
    } catch (e) {
      debugPrint('❌ Error serving TileJSON for $mbtilesId: $e');
      return Response.internalServerError(body: 'Error reading metadata: $e');
    }
  }

  /// Detect content type from tile data magic bytes
  String _detectContentType(Uint8List data) {
    if (data.length < 4) return 'application/octet-stream';

    // PNG magic bytes: 89 50 4E 47
    if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
      return 'image/png';
    }

    // JPEG magic bytes: FF D8 FF
    if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
      return 'image/jpeg';
    }

    // WebP magic bytes: 52 49 46 46 ... 57 45 42 50
    if (data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46) {
      return 'image/webp';
    }

    return 'application/octet-stream';
  }

  /// Parse bounds string "minlon,minlat,maxlon,maxlat" to array
  List<double> _parseBounds(String? bounds) {
    if (bounds == null) return [-180, -85, 180, 85];
    try {
      return bounds.split(',').map((s) => double.parse(s.trim())).toList();
    } catch (_) {
      return [-180, -85, 180, 85];
    }
  }

  /// Parse center string "lon,lat,zoom" to array
  List<double> _parseCenter(String? center) {
    if (center == null) return [0, 0, 0];
    try {
      return center.split(',').map((s) => double.parse(s.trim())).toList();
    } catch (_) {
      return [0, 0, 0];
    }
  }

  /// 1x1 transparent PNG
  static final Uint8List _transparentPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
}
