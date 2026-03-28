import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:obsession_tracker/core/services/custom_marker_service.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/marker_attachment_service.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Result of an export operation
class ExportResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;
  final int? fileSize;

  const ExportResult({
    required this.success,
    this.filePath,
    this.errorMessage,
    this.fileSize,
  });

  factory ExportResult.success(String filePath, int fileSize) => ExportResult(
        success: true,
        filePath: filePath,
        fileSize: fileSize,
      );

  factory ExportResult.failure(String errorMessage) => ExportResult(
        success: false,
        errorMessage: errorMessage,
      );
}

/// Helper class to hold all media path mappings from export
class _MediaPathMappings {
  final Map<String, String> photoPath;
  final Map<String, String> photoThumb;
  final Map<String, String> voiceNotePath;
  final Map<String, String> attachmentPath;
  final Map<String, String> attachmentThumb;

  const _MediaPathMappings({
    required this.photoPath,
    required this.photoThumb,
    required this.voiceNotePath,
    required this.attachmentPath,
    required this.attachmentThumb,
  });
}

/// Service for exporting tracking sessions to encrypted .obstrack files.
///
/// .obstrack File Format:
/// ┌─────────────────────────────────────────────┐
/// │ Header (256 bytes)                           │
/// │  - Magic bytes: "OBST"                       │
/// │  - Format version: "1.0"                     │
/// │  - Encryption algorithm: "AES-256-GCM"       │
/// │  - KDF: "PBKDF2-SHA256"                      │
/// │  - KDF iterations: 600000                    │
/// │  - Salt (32 bytes)                           │
/// │  - Nonce (16 bytes)                          │
/// ├─────────────────────────────────────────────┤
/// │ Encrypted ZIP Archive                        │
/// │  ├── session.json                            │
/// │  ├── breadcrumbs.json                        │
/// │  ├── waypoints.json                          │
/// │  ├── photos/                                 │
/// │  │   ├── photo_001.jpg                       │
/// │  │   └── thumbnails/                         │
/// │  ├── voice_notes/                            │
/// │  │   └── note_001.m4a                        │
/// │  └── manifest.json                           │
/// └─────────────────────────────────────────────┘
///
/// Security:
/// - AES-256-GCM encryption (authenticated encryption)
/// - PBKDF2-SHA256 key derivation (600,000 iterations)
/// - Password-based encryption (user chooses password)
/// - Portable across devices (works anywhere with password)
///
/// File Association:
/// - Extension: .obstrack
/// - MIME type: application/vnd.obsessiontracker.session
/// - Opens directly in Obsession Tracker app when tapped
class SessionExportService {
  final DatabaseService _databaseService = DatabaseService();

  // File format constants
  static const String _magicBytes = 'OBST';
  static const String _fileExtension = '.obstrack';
  static const String _encryptionAlgorithm = 'AES-256-GCM';
  static const String _kdfAlgorithm = 'PBKDF2-SHA256';
  static const int _kdfIterations = 600000; // OWASP recommendation for 2024
  static const int _saltLength = 32; // 256 bits
  static const int _nonceLength = 16; // 128 bits for GCM
  static const int _headerSize = 256; // Fixed header size

  /// Export a session to an encrypted .obstrack file
  ///
  /// [sessionId] - ID of session to export
  /// [password] - Password to encrypt the file (user-chosen)
  /// [outputDirectory] - Optional directory (defaults to Downloads/Obsession)
  ///
  /// Returns [ExportResult] with file path or error
  Future<ExportResult> exportSession({
    required String sessionId,
    required String password,
    String? outputDirectory,
  }) async {
    try {
      debugPrint('🔐 Starting export for session: $sessionId');

      // Validate password strength
      if (password.length < 8) {
        return ExportResult.failure(
          'Password must be at least 8 characters long',
        );
      }

      // 1. Load all session data from database
      final sessionData = await _loadSessionData(sessionId);
      if (sessionData == null) {
        return ExportResult.failure('Session not found: $sessionId');
      }

      // 2. Create temporary directory for building the archive
      final tempDir = await getTemporaryDirectory();
      final archiveDir = Directory('${tempDir.path}/otx_export_$sessionId');
      if (await archiveDir.exists()) {
        await archiveDir.delete(recursive: true);
      }
      await archiveDir.create();

      // 3. Copy photos, voice notes, and attachments first (to get relative path mappings)
      final mediaMappings = await _copyMediaFiles(archiveDir, sessionData);

      // 4. Write all JSON data files with relative paths
      await _writeJsonFiles(
        archiveDir,
        sessionData,
        mediaMappings,
      );

      // 5. Create manifest with checksums
      await _createManifest(archiveDir, sessionData);

      // 6. Create ZIP archive
      final zipBytes = await _createZipArchive(archiveDir);
      debugPrint('📦 Created ZIP archive: ${zipBytes.length} bytes');

      // 7. Encrypt ZIP with user password
      final encryptedBytes = await _encryptData(zipBytes, password);
      debugPrint('🔐 Encrypted data: ${encryptedBytes.length} bytes');

      // 8. Write .obstrack file
      final outputPath = await _writeObstrackFile(
        sessionData['session'] as TrackingSession,
        encryptedBytes,
        outputDirectory,
      );

      // 9. Clean up temporary directory
      await archiveDir.delete(recursive: true);

      final fileSize = File(outputPath).lengthSync();
      debugPrint('✅ Export complete: $outputPath ($fileSize bytes)');

      return ExportResult.success(outputPath, fileSize);
    } catch (e, stack) {
      debugPrint('❌ Export failed: $e');
      debugPrint('Stack: $stack');
      return ExportResult.failure('Export failed: $e');
    }
  }

  /// Load all session data from database
  Future<Map<String, dynamic>?> _loadSessionData(String sessionId) async {
    final session = await _databaseService.getSession(sessionId);
    if (session == null) return null;

    final breadcrumbs = await _databaseService.getBreadcrumbsForSession(sessionId);
    final waypoints = await _databaseService.getWaypointsForSession(sessionId);
    final voiceNotes = await _databaseService.getVoiceNotesForSession(sessionId);

    // Get photo waypoints for this session
    final photoCaptureService = PhotoCaptureService();
    final photoWaypoints = await photoCaptureService.getAllPhotoWaypointsForSession(sessionId);

    // Get custom markers linked to this session
    final markerService = CustomMarkerService();
    final customMarkers = await markerService.getMarkersForSession(sessionId);

    // Get marker attachments for all custom markers (photos, voice memos, documents, etc.)
    final attachmentService = MarkerAttachmentService();
    final List<MarkerAttachment> markerAttachments = [];
    for (final marker in customMarkers) {
      final attachments = await attachmentService.getAttachmentsForMarker(marker.id);
      markerAttachments.addAll(attachments);
    }

    debugPrint('📊 Loaded session data for export:');
    debugPrint('   - ${breadcrumbs.length} breadcrumbs');
    debugPrint('   - ${waypoints.length} waypoints');
    debugPrint('   - ${voiceNotes.length} voice notes');
    debugPrint('   - ${photoWaypoints.length} photos (legacy)');
    debugPrint('   - ${customMarkers.length} custom markers');
    debugPrint('   - ${markerAttachments.length} marker attachments');

    // Log waypoint types for debugging
    for (final wp in waypoints) {
      debugPrint('   📍 Waypoint: ${wp.type.name} - ${wp.name ?? wp.notes ?? "unnamed"}');
    }

    // Log custom markers and their attachments for debugging
    for (final marker in customMarkers) {
      final markerAttachmentCount = markerAttachments.where((a) => a.markerId == marker.id).length;
      debugPrint('   📌 Marker: ${marker.category.displayName} - ${marker.name} ($markerAttachmentCount attachments)');
    }

    return {
      'session': session,
      'breadcrumbs': breadcrumbs,
      'waypoints': waypoints,
      'voice_notes': voiceNotes,
      'photo_waypoints': photoWaypoints,
      'custom_markers': customMarkers,
      'marker_attachments': markerAttachments,
    };
  }

  /// Write JSON files to archive directory
  /// This must be called AFTER _copyMediaFiles so we have the relative paths
  Future<void> _writeJsonFiles(
    Directory archiveDir,
    Map<String, dynamic> sessionData,
    _MediaPathMappings mediaMappings,
  ) async {
    final session = sessionData['session'] as TrackingSession;
    final breadcrumbs = sessionData['breadcrumbs'] as List<Breadcrumb>;
    final waypoints = sessionData['waypoints'] as List<Waypoint>;
    final voiceNotes = sessionData['voice_notes'] as List<VoiceNote>;
    final photoWaypoints = sessionData['photo_waypoints'] as List<PhotoWaypoint>;
    final customMarkers = sessionData['custom_markers'] as List<CustomMarker>;
    final markerAttachments = sessionData['marker_attachments'] as List<MarkerAttachment>;

    // session.json
    await File('${archiveDir.path}/session.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(session.toMap()),
    );

    // breadcrumbs.json
    await File('${archiveDir.path}/breadcrumbs.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        breadcrumbs.map((b) => b.toMap()).toList(),
      ),
    );

    // waypoints.json
    await File('${archiveDir.path}/waypoints.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        waypoints.map((w) => w.toMap()).toList(),
      ),
    );

    // voice_notes.json with relative paths
    final voiceNotesData = voiceNotes.map((vn) {
      final map = vn.toMap();
      // Replace absolute path with relative archive path
      if (mediaMappings.voiceNotePath.containsKey(vn.id)) {
        map['file_path'] = mediaMappings.voiceNotePath[vn.id];
      }
      return map;
    }).toList();
    await File('${archiveDir.path}/voice_notes.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(voiceNotesData),
    );

    // photo_waypoints.json with relative paths (legacy photos)
    final photoWaypointsData = photoWaypoints.map((pw) {
      final map = pw.toMap();
      // Replace absolute paths with relative archive paths
      if (mediaMappings.photoPath.containsKey(pw.id)) {
        map['file_path'] = mediaMappings.photoPath[pw.id];
      }
      if (mediaMappings.photoThumb.containsKey(pw.id)) {
        map['thumbnail_path'] = mediaMappings.photoThumb[pw.id];
      }
      return map;
    }).toList();
    await File('${archiveDir.path}/photo_waypoints.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(photoWaypointsData),
    );

    // custom_markers.json
    await File('${archiveDir.path}/custom_markers.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        customMarkers.map((m) => m.toDatabaseMap()).toList(),
      ),
    );

    // marker_attachments.json with relative paths (new unified attachment system)
    final attachmentsData = markerAttachments.map((att) {
      final map = att.toDatabaseMap();
      // Replace absolute paths with relative archive paths
      if (mediaMappings.attachmentPath.containsKey(att.id)) {
        map['file_path'] = mediaMappings.attachmentPath[att.id];
      }
      if (mediaMappings.attachmentThumb.containsKey(att.id)) {
        map['thumbnail_path'] = mediaMappings.attachmentThumb[att.id];
      }
      return map;
    }).toList();
    await File('${archiveDir.path}/marker_attachments.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(attachmentsData),
    );

    debugPrint('✅ Wrote JSON files: ${breadcrumbs.length} breadcrumbs, ${waypoints.length} waypoints, ${photoWaypoints.length} legacy photos, ${customMarkers.length} markers, ${markerAttachments.length} attachments');
  }

  /// Copy photos, voice notes, and marker attachments to archive directory
  /// Returns mappings of original IDs to relative archive paths
  Future<_MediaPathMappings> _copyMediaFiles(
    Directory archiveDir,
    Map<String, dynamic> sessionData,
  ) async {
    // Create media directories
    final photosDir = Directory('${archiveDir.path}/photos');
    final thumbnailsDir = Directory('${archiveDir.path}/photos/thumbnails');
    final voiceNotesDir = Directory('${archiveDir.path}/voice_notes');
    final attachmentsDir = Directory('${archiveDir.path}/attachments');
    final attachmentThumbsDir = Directory('${archiveDir.path}/attachments/thumbnails');

    await photosDir.create();
    await thumbnailsDir.create();
    await voiceNotesDir.create();
    await attachmentsDir.create();
    await attachmentThumbsDir.create();

    // Get the app's documents directory to resolve relative paths
    final documentsDir = await getApplicationDocumentsDirectory();

    // Mappings from original ID to relative path in archive
    final photoPathMapping = <String, String>{};
    final photoThumbMapping = <String, String>{};
    final voiceNotePathMapping = <String, String>{};
    final attachmentPathMapping = <String, String>{};
    final attachmentThumbMapping = <String, String>{};

    // Copy photos from photo waypoints
    final photoWaypoints = sessionData['photo_waypoints'] as List<PhotoWaypoint>;
    var photosCopied = 0;
    for (var i = 0; i < photoWaypoints.length; i++) {
      final photoWaypoint = photoWaypoints[i];

      // Resolve the file path - it may be relative or absolute
      final photoPath = _resolveFilePath(photoWaypoint.filePath, documentsDir.path);
      final sourceFile = File(photoPath);

      if (await sourceFile.exists()) {
        final ext = path.extension(photoWaypoint.filePath);
        final relativePath = 'photos/photo_${i.toString().padLeft(3, '0')}$ext';
        final destPath = '${archiveDir.path}/$relativePath';
        await sourceFile.copy(destPath);
        photoPathMapping[photoWaypoint.id] = relativePath;
        photosCopied++;
      } else {
        debugPrint('⚠️ Photo file not found: $photoPath');
      }

      // Copy thumbnail if exists
      if (photoWaypoint.thumbnailPath != null) {
        final thumbPath = _resolveFilePath(photoWaypoint.thumbnailPath!, documentsDir.path);
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          final ext = path.extension(photoWaypoint.thumbnailPath!);
          final relativePath = 'photos/thumbnails/photo_${i.toString().padLeft(3, '0')}_thumb$ext';
          final destPath = '${archiveDir.path}/$relativePath';
          await thumbFile.copy(destPath);
          photoThumbMapping[photoWaypoint.id] = relativePath;
        }
      }
    }

    // Copy voice notes
    final voiceNotes = sessionData['voice_notes'] as List<VoiceNote>;
    var voiceNotesCopied = 0;
    for (var i = 0; i < voiceNotes.length; i++) {
      final voiceNote = voiceNotes[i];
      final notePath = _resolveFilePath(voiceNote.filePath, documentsDir.path);
      final sourceFile = File(notePath);

      if (await sourceFile.exists()) {
        final ext = path.extension(voiceNote.filePath);
        final relativePath = 'voice_notes/note_${i.toString().padLeft(3, '0')}$ext';
        final destPath = '${archiveDir.path}/$relativePath';
        await sourceFile.copy(destPath);
        voiceNotePathMapping[voiceNote.id] = relativePath;
        voiceNotesCopied++;
      } else {
        debugPrint('⚠️ Voice note file not found: $notePath');
      }
    }

    // Copy marker attachments (images, audio, documents, PDFs from new unified system)
    final markerAttachments = sessionData['marker_attachments'] as List<MarkerAttachment>;
    var attachmentsCopied = 0;
    for (var i = 0; i < markerAttachments.length; i++) {
      final attachment = markerAttachments[i];

      // Only copy file-based attachments (not notes or links)
      if (!attachment.type.hasFile || attachment.filePath == null) {
        continue;
      }

      final attachmentPath = _resolveFilePath(attachment.filePath!, documentsDir.path);
      final sourceFile = File(attachmentPath);

      if (await sourceFile.exists()) {
        final ext = path.extension(attachment.filePath!);
        // Use subfolder based on type for organization
        final typeFolder = attachment.type.name;
        final relativePath = 'attachments/$typeFolder/att_${i.toString().padLeft(3, '0')}$ext';

        // Create type subfolder if needed
        final typeDir = Directory('${archiveDir.path}/attachments/$typeFolder');
        if (!await typeDir.exists()) {
          await typeDir.create(recursive: true);
        }

        final destPath = '${archiveDir.path}/$relativePath';
        await sourceFile.copy(destPath);
        attachmentPathMapping[attachment.id] = relativePath;
        attachmentsCopied++;
      } else {
        debugPrint('⚠️ Attachment file not found: $attachmentPath (${attachment.type.displayName}: ${attachment.name})');
      }

      // Copy thumbnail if exists
      if (attachment.thumbnailPath != null) {
        final thumbPath = _resolveFilePath(attachment.thumbnailPath!, documentsDir.path);
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          final ext = path.extension(attachment.thumbnailPath!);
          final relativePath = 'attachments/thumbnails/att_${i.toString().padLeft(3, '0')}_thumb$ext';
          final destPath = '${archiveDir.path}/$relativePath';
          await thumbFile.copy(destPath);
          attachmentThumbMapping[attachment.id] = relativePath;
        }
      }
    }

    debugPrint('✅ Copied media: $photosCopied legacy photos, $voiceNotesCopied voice notes, $attachmentsCopied attachments');
    return _MediaPathMappings(
      photoPath: photoPathMapping,
      photoThumb: photoThumbMapping,
      voiceNotePath: voiceNotePathMapping,
      attachmentPath: attachmentPathMapping,
      attachmentThumb: attachmentThumbMapping,
    );
  }

  /// Resolve a file path that may be relative or absolute
  /// If relative (doesn't start with /), prepends the documents directory
  String _resolveFilePath(String filePath, String documentsPath) {
    if (filePath.startsWith('/')) {
      // Already absolute
      return filePath;
    }
    // Relative path - prepend documents directory
    return '$documentsPath/$filePath';
  }

  /// Create manifest.json with checksums and metadata
  Future<void> _createManifest(
    Directory archiveDir,
    Map<String, dynamic> sessionData,
  ) async {
    final session = sessionData['session'] as TrackingSession;
    final breadcrumbs = sessionData['breadcrumbs'] as List<Breadcrumb>;
    final waypoints = sessionData['waypoints'] as List<Waypoint>;
    final photoWaypoints = sessionData['photo_waypoints'] as List<PhotoWaypoint>;
    final voiceNotes = sessionData['voice_notes'] as List<VoiceNote>;
    final customMarkers = sessionData['custom_markers'] as List<CustomMarker>;
    final markerAttachments = sessionData['marker_attachments'] as List<MarkerAttachment>;

    final manifest = {
      'version': '1.3', // v1.3: adds marker_attachments support
      'created_at': DateTime.now().toIso8601String(),
      'session_id': session.id,
      'session_name': session.name,
      'app_version': '1.10.0',
      'format_features': <String>[
        'nullable_session_id', // Waypoints can have null session_id (standalone)
        'multi_photo_waypoint', // Multiple photos can link to same waypoint_id
        'multi_voice_waypoint', // Multiple voice notes can link to same waypoint_id
        'custom_markers', // Custom markers linked to session
        'marker_attachments', // MarkerAttachments on CustomMarkers (photos, audio, docs)
      ],
      'counts': {
        'breadcrumbs': breadcrumbs.length,
        'waypoints': waypoints.length,
        'photos': photoWaypoints.length,
        'voice_notes': voiceNotes.length,
        'custom_markers': customMarkers.length,
        'marker_attachments': markerAttachments.length,
      },
      'checksums': await _calculateChecksums(archiveDir),
    };

    await File('${archiveDir.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
    );
  }

  /// Calculate SHA-256 checksums for all files
  Future<Map<String, String>> _calculateChecksums(Directory archiveDir) async {
    final checksums = <String, String>{};
    final files = archiveDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => !f.path.endsWith('manifest.json'));

    for (final file in files) {
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes);
      final relativePath = path.relative(file.path, from: archiveDir.path);
      checksums[relativePath] = hash.toString();
    }

    return checksums;
  }

  /// Create ZIP archive from directory
  Future<Uint8List> _createZipArchive(Directory archiveDir) async {
    final encoder = ZipEncoder();
    final archive = Archive();

    // Add all files to archive
    final files = archiveDir.listSync(recursive: true).whereType<File>();
    for (final file in files) {
      final relativePath = path.relative(file.path, from: archiveDir.path);
      final bytes = await file.readAsBytes();
      final archiveFile = ArchiveFile(relativePath, bytes.length, bytes);
      archive.addFile(archiveFile);
    }

    return Uint8List.fromList(encoder.encode(archive));
  }

  /// Encrypt data with AES-256-GCM using password-based key derivation
  Future<Uint8List> _encryptData(Uint8List plaintext, String password) async {
    // Generate random salt and nonce
    final salt = _generateSecureRandom(_saltLength);
    final nonce = _generateSecureRandom(_nonceLength);

    // Derive encryption key from password using PBKDF2
    final key = _deriveKey(password, salt);

    // Encrypt with AES-256-GCM
    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(
        encrypt_lib.Key(key),
        mode: encrypt_lib.AESMode.gcm,
      ),
    );

    final encrypted = encrypter.encryptBytes(
      plaintext,
      iv: encrypt_lib.IV(nonce),
    );

    // Build .otx file format:
    // [Header 256 bytes][Encrypted data]
    final header = _buildHeader(salt, nonce);
    final result = Uint8List(header.length + encrypted.bytes.length);
    result.setRange(0, header.length, header);
    result.setRange(header.length, result.length, encrypted.bytes);

    return result;
  }

  /// Derive encryption key from password using PBKDF2
  Uint8List _deriveKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);

    // PBKDF2 implementation
    final result = Uint8List(32); // 256 bits
    final block = Uint8List(32);

    for (var i = 0; i < 32; i += 32) {
      // Simplified: single block for 256-bit key
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

  /// Build .otx file header
  Uint8List _buildHeader(Uint8List salt, Uint8List nonce) {
    final header = Uint8List(_headerSize);

    // Magic bytes "OTX1"
    header.setRange(0, 4, utf8.encode(_magicBytes));

    // Encryption algorithm (32 bytes, null-padded)
    final algBytes = utf8.encode(_encryptionAlgorithm);
    header.setRange(4, 4 + algBytes.length, algBytes);

    // KDF algorithm (32 bytes, null-padded)
    final kdfBytes = utf8.encode(_kdfAlgorithm);
    header.setRange(36, 36 + kdfBytes.length, kdfBytes);

    // KDF iterations (4 bytes, big-endian)
    header[68] = (_kdfIterations >> 24) & 0xFF;
    header[69] = (_kdfIterations >> 16) & 0xFF;
    header[70] = (_kdfIterations >> 8) & 0xFF;
    header[71] = _kdfIterations & 0xFF;

    // Salt (32 bytes)
    header.setRange(72, 72 + _saltLength, salt);

    // Nonce (16 bytes)
    header.setRange(104, 104 + _nonceLength, nonce);

    // Remaining bytes are reserved (zeros)

    return header;
  }

  /// Generate cryptographically secure random bytes
  Uint8List _generateSecureRandom(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Write encrypted data to .obstrack file
  Future<String> _writeObstrackFile(
    TrackingSession session,
    Uint8List encryptedBytes,
    String? outputDirectory,
  ) async {
    // Determine output directory
    Directory outputDir;
    if (outputDirectory != null) {
      outputDir = Directory(outputDirectory);
    } else {
      // Use app's documents directory for exports (works on both iOS and Android)
      // Files are shared via the share sheet, not saved to a user-visible location
      final documentsDir = await getApplicationDocumentsDirectory();
      outputDir = Directory('${documentsDir.path}/exports');
    }

    // Create directory if it doesn't exist
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    // Generate filename: session_name_YYYY-MM-DD.obstrack
    final timestamp = session.createdAt.toIso8601String().split('T')[0];
    final safeName = session.name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final filename = '${safeName}_$timestamp$_fileExtension';
    final filePath = '${outputDir.path}/$filename';

    // Write file
    final file = File(filePath);
    await file.writeAsBytes(encryptedBytes);

    return filePath;
  }
}
