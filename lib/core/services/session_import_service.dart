import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/breadcrumb.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/voice_note.dart';
import 'package:obsession_tracker/core/models/waypoint.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/lifetime_statistics_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Result of an import operation
class ImportResult {
  final bool success;
  final String? sessionId;
  final String? errorMessage;
  final Map<String, int>? counts;

  const ImportResult({
    required this.success,
    this.sessionId,
    this.errorMessage,
    this.counts,
  });

  factory ImportResult.success(String sessionId, Map<String, int> counts) =>
      ImportResult(
        success: true,
        sessionId: sessionId,
        counts: counts,
      );

  factory ImportResult.failure(String errorMessage) => ImportResult(
        success: false,
        errorMessage: errorMessage,
      );
}

/// Service for importing tracking sessions from encrypted .obstrack files.
///
/// Decrypts and imports complete session data including:
/// - Session metadata
/// - GPS breadcrumbs/tracks
/// - Waypoints
/// - Photos
/// - Voice notes
///
/// Security:
/// - Requires correct password to decrypt
/// - Validates file format and checksums
/// - Prevents duplicate imports (checks session ID)
///
/// File Association:
/// - Extension: .obstrack
/// - MIME type: application/vnd.obsessiontracker.session
class SessionImportService {
  final DatabaseService _databaseService = DatabaseService();

  // File format constants (must match export service)
  static const String _magicBytes = 'OBST';
  static const int _kdfIterations = 600000;
  static const int _saltLength = 32;
  static const int _nonceLength = 16;
  static const int _headerSize = 256;

  /// Import a session from an encrypted .obstrack file
  ///
  /// [obstrackFilePath] - Path to the .obstrack file to import
  /// [password] - Password to decrypt the file
  /// [skipIfExists] - If true, skip import if session already exists
  ///
  /// Returns [ImportResult] with session ID or error
  Future<ImportResult> importSession({
    required String obstrackFilePath,
    required String password,
    bool skipIfExists = true,
  }) async {
    try {
      debugPrint('🔓 Starting import from: $obstrackFilePath');

      // 1. Read .obstrack file
      final file = File(obstrackFilePath);
      if (!await file.exists()) {
        return ImportResult.failure('File not found: $obstrackFilePath');
      }

      final fileBytes = await file.readAsBytes();
      debugPrint('📄 Read file: ${fileBytes.length} bytes');

      // 2. Validate and parse header
      if (fileBytes.length < _headerSize) {
        return ImportResult.failure('Invalid .obstrack file: too small');
      }

      final header = fileBytes.sublist(0, _headerSize);
      final magicBytesCheck = utf8.decode(header.sublist(0, 4));
      if (magicBytesCheck != _magicBytes) {
        return ImportResult.failure(
          'Invalid .obstrack file: wrong format (expected $_magicBytes, got $magicBytesCheck)',
        );
      }

      // 3. Extract salt and nonce from header
      final salt = header.sublist(72, 72 + _saltLength);
      final nonce = header.sublist(104, 104 + _nonceLength);

      // 4. Decrypt data
      final encryptedData = fileBytes.sublist(_headerSize);
      final decryptedZip = await _decryptData(
        encryptedData,
        password,
        salt,
        nonce,
      );

      if (decryptedZip == null) {
        return ImportResult.failure(
          'Decryption failed: incorrect password or corrupted file',
        );
      }

      debugPrint('🔓 Decrypted data: ${decryptedZip.length} bytes');

      // 5. Extract ZIP archive
      final archive = await _extractZipArchive(decryptedZip);
      if (archive == null) {
        return ImportResult.failure('Failed to extract archive');
      }

      // 6. Validate manifest and checksums
      final manifestValid = await _validateManifest(archive);
      if (!manifestValid) {
        return ImportResult.failure('File integrity check failed');
      }

      // 7. Parse JSON data
      final sessionData = await _parseSessionData(archive);
      if (sessionData == null) {
        return ImportResult.failure('Failed to parse session data');
      }

      final session = sessionData['session'] as TrackingSession;

      // 8. Check if session already exists
      if (skipIfExists) {
        final existing = await _databaseService.getSession(session.id);
        if (existing != null) {
          return ImportResult.failure(
            'Session already exists: ${session.name}',
          );
        }
      }

      // 9. Import photos and voice notes to app storage
      await _importMediaFiles(archive, session.id);

      // 10. Write to database
      await _importToDatabase(sessionData);

      // 11. Recalculate lifetime stats and check achievements
      // Imported sessions should contribute to user's stats and achievements
      final lifetimeStatsService = LifetimeStatisticsService();
      await lifetimeStatsService.recalculateFromAllSessions();
      debugPrint('📊 Lifetime stats recalculated after import');

      final achievementService = AchievementService();
      await achievementService.checkAllAchievements();
      debugPrint('🏆 Achievements checked after import');

      final photoWaypointsCount = (sessionData['photo_waypoints'] as List).length;
      final counts = {
        'breadcrumbs': (sessionData['breadcrumbs'] as List).length,
        'waypoints': (sessionData['waypoints'] as List).length,
        'photos': (sessionData['photo_count'] as int?) ?? 0,
        'photo_waypoints': photoWaypointsCount,
        'voice_notes': (sessionData['voice_notes'] as List).length,
        'custom_markers': (sessionData['custom_markers'] as List).length,
        'marker_attachments': (sessionData['marker_attachments'] as List).length,
      };

      debugPrint('✅ Import complete: ${session.name} (${session.id})');
      debugPrint('   Imported: ${counts['breadcrumbs']} breadcrumbs, ${counts['waypoints']} waypoints, ${counts['custom_markers']} markers, ${counts['marker_attachments']} attachments, $photoWaypointsCount photo_waypoints');

      return ImportResult.success(session.id, counts);
    } catch (e, stack) {
      debugPrint('❌ Import failed: $e');
      debugPrint('Stack: $stack');
      return ImportResult.failure('Import failed: $e');
    }
  }

  /// Decrypt data with AES-256-GCM
  Future<Uint8List?> _decryptData(
    Uint8List encryptedData,
    String password,
    Uint8List salt,
    Uint8List nonce,
  ) async {
    try {
      // Derive key from password using PBKDF2
      final key = _deriveKey(password, salt);

      // Decrypt with AES-256-GCM
      final encrypter = encrypt_lib.Encrypter(
        encrypt_lib.AES(
          encrypt_lib.Key(key),
          mode: encrypt_lib.AESMode.gcm,
        ),
      );

      final decrypted = encrypter.decryptBytes(
        encrypt_lib.Encrypted(encryptedData),
        iv: encrypt_lib.IV(nonce),
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return null;
    }
  }

  /// Derive key from password using PBKDF2 (must match export service)
  Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);

    final result = Uint8List(32); // 256 bits
    final block = Uint8List(32);

    for (var i = 0; i < 32; i += 32) {
      var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
      for (var j = 0; j < 32; j++) {
        block[j] = u[j];
      }

      for (var iter = 1; iter < _kdfIterations; iter++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < 32; j++) {
          block[j] ^= u[j];
        }
      }

      result.setRange(i, i + 32, block);
    }

    return result;
  }

  /// Extract ZIP archive from decrypted bytes
  Future<Archive?> _extractZipArchive(Uint8List zipBytes) async {
    try {
      final decoder = ZipDecoder();
      return decoder.decodeBytes(zipBytes);
    } catch (e) {
      debugPrint('ZIP extraction error: $e');
      return null;
    }
  }

  /// Validate manifest and checksums
  Future<bool> _validateManifest(Archive archive) async {
    try {
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        debugPrint('⚠️ No manifest found, skipping validation');
        return true; // Don't fail if manifest missing (backwards compat)
      }

      final manifestJson = utf8.decode(manifestFile.content as List<int>);
      final manifest = json.decode(manifestJson) as Map<String, dynamic>;
      final checksums = manifest['checksums'] as Map<String, dynamic>?;

      if (checksums == null) {
        return true; // No checksums to validate
      }

      // Validate each file's checksum
      for (final entry in checksums.entries) {
        final filePath = entry.key;
        final expectedHash = entry.value as String;

        final file = archive.findFile(filePath);
        if (file == null) {
          debugPrint('⚠️ Missing file: $filePath');
          return false;
        }

        final actualHash = sha256.convert(file.content as List<int>).toString();
        if (actualHash != expectedHash) {
          debugPrint('⚠️ Checksum mismatch: $filePath');
          return false;
        }
      }

      debugPrint('✅ All checksums valid');
      return true;
    } catch (e) {
      debugPrint('Manifest validation error: $e');
      return false;
    }
  }

  /// Parse session data from archive
  Future<Map<String, dynamic>?> _parseSessionData(Archive archive) async {
    try {
      // Parse session.json
      final sessionFile = archive.findFile('session.json');
      if (sessionFile == null) return null;
      final sessionJson = utf8.decode(sessionFile.content as List<int>);
      final sessionMap = json.decode(sessionJson) as Map<String, dynamic>;
      final session = TrackingSession.fromMap(sessionMap);

      // Parse breadcrumbs.json
      final breadcrumbsFile = archive.findFile('breadcrumbs.json');
      final breadcrumbs = <Breadcrumb>[];
      if (breadcrumbsFile != null) {
        final breadcrumbsJson =
            utf8.decode(breadcrumbsFile.content as List<int>);
        final breadcrumbsList = json.decode(breadcrumbsJson) as List;
        breadcrumbs.addAll(
          breadcrumbsList.map((b) => Breadcrumb.fromMap(b as Map<String, dynamic>)),
        );
      }

      // Parse waypoints.json
      final waypointsFile = archive.findFile('waypoints.json');
      final waypoints = <Waypoint>[];
      if (waypointsFile != null) {
        final waypointsJson = utf8.decode(waypointsFile.content as List<int>);
        final waypointsList = json.decode(waypointsJson) as List;
        waypoints.addAll(
          waypointsList.map((w) => Waypoint.fromMap(w as Map<String, dynamic>)),
        );
      }

      // Parse voice_notes.json
      final voiceNotesFile = archive.findFile('voice_notes.json');
      final voiceNotes = <VoiceNote>[];
      if (voiceNotesFile != null) {
        final voiceNotesJson =
            utf8.decode(voiceNotesFile.content as List<int>);
        final voiceNotesList = json.decode(voiceNotesJson) as List;
        voiceNotes.addAll(
          voiceNotesList.map((vn) => VoiceNote.fromMap(vn as Map<String, dynamic>)),
        );
      }

      // Parse custom_markers.json (v1.2+)
      final customMarkersFile = archive.findFile('custom_markers.json');
      final customMarkers = <CustomMarker>[];
      if (customMarkersFile != null) {
        final customMarkersJson =
            utf8.decode(customMarkersFile.content as List<int>);
        final customMarkersList = json.decode(customMarkersJson) as List;
        customMarkers.addAll(
          customMarkersList.map((m) => CustomMarker.fromDatabaseMap(m as Map<String, dynamic>)),
        );
      }

      // Parse marker_attachments.json (v1.3+)
      final markerAttachmentsFile = archive.findFile('marker_attachments.json');
      final markerAttachments = <MarkerAttachment>[];
      if (markerAttachmentsFile != null) {
        final markerAttachmentsJson =
            utf8.decode(markerAttachmentsFile.content as List<int>);
        final markerAttachmentsList = json.decode(markerAttachmentsJson) as List;
        markerAttachments.addAll(
          markerAttachmentsList.map((a) => MarkerAttachment.fromDatabaseMap(a as Map<String, dynamic>)),
        );
      }

      // Parse photo_waypoints.json (legacy format)
      final photoWaypointsFile = archive.findFile('photo_waypoints.json');
      final photoWaypoints = <Map<String, dynamic>>[];
      if (photoWaypointsFile != null) {
        final photoWaypointsJson =
            utf8.decode(photoWaypointsFile.content as List<int>);
        final photoWaypointsList = json.decode(photoWaypointsJson) as List;
        photoWaypoints.addAll(
          photoWaypointsList.map((p) => p as Map<String, dynamic>),
        );
        debugPrint('📸 Found ${photoWaypoints.length} legacy photo_waypoints to import');
      }

      // Count photos (legacy)
      final photoCount = archive.files
          .where((f) => f.name.startsWith('photos/') && !f.name.contains('thumbnails'))
          .length;

      // Count attachments
      final attachmentCount = archive.files
          .where((f) => f.name.startsWith('attachments/') && !f.name.contains('thumbnails'))
          .length;

      return {
        'session': session,
        'breadcrumbs': breadcrumbs,
        'waypoints': waypoints,
        'voice_notes': voiceNotes,
        'custom_markers': customMarkers,
        'marker_attachments': markerAttachments,
        'photo_waypoints': photoWaypoints,
        'photo_count': photoCount,
        'attachment_count': attachmentCount,
        'archive': archive,
      };
    } catch (e) {
      debugPrint('Parse error: $e');
      return null;
    }
  }

  /// Import photos, voice notes, and attachments to app storage
  Future<void> _importMediaFiles(Archive archive, String sessionId) async {
    final appDir = await getApplicationDocumentsDirectory();

    // Import photos (legacy)
    final photosDir = Directory('${appDir.path}/photos/$sessionId');
    await photosDir.create(recursive: true);

    final photoFiles = archive.files.where(
      (f) => f.name.startsWith('photos/') && f.isFile && !f.name.contains('thumbnails'),
    );

    for (final file in photoFiles) {
      final fileName = path.basename(file.name);
      final destPath = '${photosDir.path}/$fileName';
      final destFile = File(destPath);
      await destFile.writeAsBytes(file.content as List<int>);
    }

    // Import photo thumbnails
    final photoThumbsDir = Directory('${appDir.path}/photos/$sessionId/thumbnails');
    await photoThumbsDir.create(recursive: true);

    final photoThumbFiles = archive.files.where(
      (f) => f.name.startsWith('photos/thumbnails/') && f.isFile,
    );

    for (final file in photoThumbFiles) {
      final fileName = path.basename(file.name);
      final destPath = '${photoThumbsDir.path}/$fileName';
      final destFile = File(destPath);
      await destFile.writeAsBytes(file.content as List<int>);
    }

    // Import voice notes
    final voiceNotesDir = Directory('${appDir.path}/voice_notes/$sessionId');
    await voiceNotesDir.create(recursive: true);

    final voiceNoteFiles = archive.files.where(
      (f) => f.name.startsWith('voice_notes/') && f.isFile,
    );

    for (final file in voiceNoteFiles) {
      final fileName = path.basename(file.name);
      final destPath = '${voiceNotesDir.path}/$fileName';
      final destFile = File(destPath);
      await destFile.writeAsBytes(file.content as List<int>);
    }

    // Import marker attachments (new unified system)
    final attachmentsDir = Directory('${appDir.path}/attachments/$sessionId');
    await attachmentsDir.create(recursive: true);

    final attachmentFiles = archive.files.where(
      (f) => f.name.startsWith('attachments/') && f.isFile && !f.name.contains('thumbnails'),
    );

    for (final file in attachmentFiles) {
      // Preserve subfolder structure (e.g., attachments/image/att_001.jpg)
      final relativePath = file.name.replaceFirst('attachments/', '');
      final destPath = '${attachmentsDir.path}/$relativePath';

      // Create subfolders if needed
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      await destFile.writeAsBytes(file.content as List<int>);
    }

    // Import attachment thumbnails
    final attachmentThumbFiles = archive.files.where(
      (f) => f.name.startsWith('attachments/thumbnails/') && f.isFile,
    );

    for (final file in attachmentThumbFiles) {
      final fileName = path.basename(file.name);
      final destPath = '${attachmentsDir.path}/thumbnails/$fileName';
      final destFile = File(destPath);
      await destFile.parent.create(recursive: true);
      await destFile.writeAsBytes(file.content as List<int>);
    }

    debugPrint('✅ Imported ${photoFiles.length} legacy photos, ${voiceNoteFiles.length} voice notes, ${attachmentFiles.length} attachments');
  }

  /// Write all session data to database
  Future<void> _importToDatabase(Map<String, dynamic> sessionData) async {
    final session = sessionData['session'] as TrackingSession;
    final breadcrumbs = sessionData['breadcrumbs'] as List<Breadcrumb>;
    final waypoints = sessionData['waypoints'] as List<Waypoint>;
    final voiceNotes = sessionData['voice_notes'] as List<VoiceNote>;
    final customMarkers = sessionData['custom_markers'] as List<CustomMarker>;
    final markerAttachments = sessionData['marker_attachments'] as List<MarkerAttachment>;
    final photoWaypointMaps = sessionData['photo_waypoints'] as List<Map<String, dynamic>>;

    // Insert session
    await _databaseService.insertSession(session);

    // Insert breadcrumbs in batches
    if (breadcrumbs.isNotEmpty) {
      await _databaseService.insertBreadcrumbs(breadcrumbs);
    }

    // Insert waypoints
    for (final waypoint in waypoints) {
      await _databaseService.insertWaypoint(waypoint);
    }

    // Get app directory for path fixing (used by voice notes, attachments, and photos)
    final appDir = await getApplicationDocumentsDirectory();

    // Insert voice notes
    // Update file paths to include session ID (files were extracted to voice_notes/{sessionId}/...)
    for (final voiceNote in voiceNotes) {
      VoiceNote updatedVoiceNote = voiceNote;

      // Update file path
      if (voiceNote.filePath.isNotEmpty) {
        // Original export path: voice_notes/note_001.m4a
        // Extract just the filename
        final fileName = path.basename(voiceNote.filePath);
        // New path: voice_notes/{sessionId}/{fileName}
        final newFilePath = path.join(appDir.path, 'voice_notes', session.id, fileName);
        updatedVoiceNote = updatedVoiceNote.copyWith(filePath: newFilePath);
      }

      await _databaseService.insertVoiceNote(updatedVoiceNote);
    }

    // Insert custom markers (v1.2+)
    // Use database service directly since we have full objects with IDs
    for (final marker in customMarkers) {
      await _databaseService.insertCustomMarker(marker);
    }

    // Insert marker attachments (v1.3+)
    // Update file paths to include session ID (files were extracted to attachments/{sessionId}/...)
    for (final attachment in markerAttachments) {
      MarkerAttachment updatedAttachment = attachment;

      // Update file path if present
      if (attachment.filePath != null && attachment.filePath!.isNotEmpty) {
        // Original export path: attachments/image/att_001.jpg
        // Extract the relative part after 'attachments/'
        final originalPath = attachment.filePath!;
        String relativePart;
        if (originalPath.contains('attachments/')) {
          relativePart = originalPath.substring(originalPath.indexOf('attachments/') + 'attachments/'.length);
        } else {
          relativePart = path.basename(originalPath);
        }
        // New path: attachments/{sessionId}/{relativePart}
        final newFilePath = path.join(appDir.path, 'attachments', session.id, relativePart);
        updatedAttachment = updatedAttachment.copyWith(filePath: newFilePath);
      }

      // Update thumbnail path if present
      if (attachment.thumbnailPath != null && attachment.thumbnailPath!.isNotEmpty) {
        final originalThumbPath = attachment.thumbnailPath!;
        String relativePart;
        if (originalThumbPath.contains('attachments/')) {
          relativePart = originalThumbPath.substring(originalThumbPath.indexOf('attachments/') + 'attachments/'.length);
        } else {
          relativePart = path.basename(originalThumbPath);
        }
        final newThumbPath = path.join(appDir.path, 'attachments', session.id, relativePart);
        updatedAttachment = updatedAttachment.copyWith(thumbnailPath: newThumbPath);
      }

      await _databaseService.insertMarkerAttachment(updatedAttachment);
    }

    // Insert legacy photo_waypoints
    // These are converted to proper paths during media import
    var photoWaypointCount = 0;
    for (final photoMap in photoWaypointMaps) {
      try {
        // Update file paths to match where we extracted them
        String? newFilePath;
        String? newThumbPath;

        // The exported file paths are like 'photos/filename.jpg'
        // We extracted them to 'photos/{sessionId}/filename.jpg'
        if (photoMap['file_path'] != null) {
          final originalPath = photoMap['file_path'] as String;
          final fileName = path.basename(originalPath);
          newFilePath = path.join(appDir.path, 'photos', session.id, fileName);
        }

        if (photoMap['thumbnail_path'] != null) {
          final originalThumbPath = photoMap['thumbnail_path'] as String;
          final thumbName = path.basename(originalThumbPath);
          newThumbPath = path.join(appDir.path, 'photos', session.id, 'thumbnails', thumbName);
        }

        final photoWaypoint = PhotoWaypoint.fromMap({
          ...photoMap,
          'file_path': newFilePath ?? photoMap['file_path'],
          'thumbnail_path': newThumbPath ?? photoMap['thumbnail_path'],
        });

        await _insertPhotoWaypoint(photoWaypoint);
        photoWaypointCount++;
      } catch (e) {
        debugPrint('⚠️ Failed to import photo_waypoint: $e');
      }
    }

    debugPrint('✅ Wrote to database: ${breadcrumbs.length} breadcrumbs, ${waypoints.length} waypoints, ${customMarkers.length} markers, ${markerAttachments.length} attachments, $photoWaypointCount photo_waypoints');
  }

  /// Insert a photo waypoint into the database
  Future<void> _insertPhotoWaypoint(PhotoWaypoint photoWaypoint) async {
    try {
      final db = await _databaseService.database;
      await db.insert(
        'photo_waypoints',
        photoWaypoint.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error inserting photo waypoint: $e');
      rethrow;
    }
  }
}
