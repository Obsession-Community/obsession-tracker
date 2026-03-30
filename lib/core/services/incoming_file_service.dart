// Incoming File Service for handling deep links and file associations
//
// Handles files opened via:
// - Files app (Open In...)
// - Email attachments
// - AirDrop
// - Other file sharing mechanisms
//
// Uses the app_links package for reliable cross-platform deep link handling.
//
// Supported file types:
// - .obstrack (session export files)
// - .obk (full backup files)
// - .gpx (GPS exchange format)
// - .kml (Google Earth/KML format)

import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Event emitted when an incoming file is received
class IncomingFileEvent {
  IncomingFileEvent({
    required this.filePath,
    required this.fileType,
  });

  final String filePath;
  final IncomingFileType fileType;

  @override
  String toString() => 'IncomingFileEvent(filePath: $filePath, fileType: $fileType)';
}

/// Types of files that can be received
enum IncomingFileType {
  obstrack,  // Session export
  obk,       // Full backup
  gpx,       // GPS exchange format
  kml,       // Google Earth/KML
  unknown,
}

/// Service for handling incoming files from deep links and file associations
class IncomingFileService {
  factory IncomingFileService() => _instance;

  IncomingFileService._internal();

  static final IncomingFileService _instance = IncomingFileService._internal();

  // App Links instance for handling deep links
  final AppLinks _appLinks = AppLinks();

  // Method channel for receiving files from native code (iOS security-scoped files)
  static const MethodChannel _channel = MethodChannel('obsessiontracker/incoming_file');

  // Stream controller for incoming file events
  final StreamController<IncomingFileEvent> _fileController =
      StreamController<IncomingFileEvent>.broadcast();

  // Subscription to app links stream
  StreamSubscription<Uri>? _linkSubscription;

  // Pending file path (received before Flutter was ready)
  String? _pendingFilePath;

  bool _isInitialized = false;

  /// Stream of incoming file events
  Stream<IncomingFileEvent> get onIncomingFile => _fileController.stream;

  /// Check if there's a pending file that was received before initialization
  String? get pendingFilePath => _pendingFilePath;

  /// Clear the pending file after it's been processed
  void clearPendingFile() {
    _pendingFilePath = null;
  }

  /// Initialize the incoming file service
  ///
  /// Should be called early in app startup, before the main UI is built
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('📂 IncomingFileService: Initializing with app_links...');

    // Set up method channel for receiving files from native code
    // This is used on iOS when files are copied from security-scoped locations (iCloud, etc.)
    _channel.setMethodCallHandler(_handleMethodCall);

    // Check if there's an initial link that launched the app
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('📂 IncomingFileService: Initial link: $initialUri');
        final filePath = _uriToFilePath(initialUri);
        if (filePath != null && _isSupportedFile(filePath)) {
          _pendingFilePath = filePath;
          debugPrint('📂 IncomingFileService: Stored pending file: $filePath');
        }
      }
    } catch (e) {
      debugPrint('📂 IncomingFileService: Error getting initial link: $e');
    }

    // Listen for incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('📂 IncomingFileService: Received link: $uri');
        final filePath = _uriToFilePath(uri);
        if (filePath != null && _isSupportedFile(filePath)) {
          _handleIncomingFile(filePath);
        }
      },
      onError: (Object error) {
        debugPrint('📂 IncomingFileService: Link stream error: $error');
      },
    );

    _isInitialized = true;
    debugPrint('📂 IncomingFileService: Initialized');
  }

  /// Handle method calls from native code (iOS)
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onFileReceived':
        final filePath = call.arguments as String?;
        if (filePath != null && filePath.isNotEmpty) {
          debugPrint('📂 IncomingFileService: File received via method channel: $filePath');
          _handleIncomingFile(filePath);
        }
        return true;
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Unknown method: ${call.method}',
        );
    }
  }

  /// Convert a URI to a file path
  String? _uriToFilePath(Uri uri) {
    // Handle file:// URLs
    if (uri.scheme == 'file') {
      return uri.toFilePath();
    }
    // Handle custom URL schemes that might contain file paths
    if (uri.scheme == 'obsessiontracker') {
      // Could be obsessiontracker://open?file=/path/to/file.obstrack
      final filePath = uri.queryParameters['file'];
      if (filePath != null) {
        return filePath;
      }
    }
    // If it's a path-like string without scheme, treat as file path
    if (uri.scheme.isEmpty && uri.path.isNotEmpty) {
      return uri.path;
    }
    return null;
  }

  /// Check if the file has a supported extension
  bool _isSupportedFile(String filePath) {
    final lowerPath = filePath.toLowerCase();
    return lowerPath.endsWith('.obstrack') ||
        lowerPath.endsWith('.obk') ||
        lowerPath.endsWith('.gpx') ||
        lowerPath.endsWith('.kml');
  }

  /// Handle an incoming file path
  void _handleIncomingFile(String filePath) {
    final fileType = _detectFileType(filePath);
    debugPrint('📂 IncomingFileService: Detected file type: $fileType');

    // Validate file exists (for local files)
    final localPath = filePath.replaceFirst('file://', '');
    final file = File(localPath);
    if (!file.existsSync()) {
      debugPrint('📂 IncomingFileService: File does not exist: $localPath');
      return;
    }

    final event = IncomingFileEvent(
      filePath: localPath,
      fileType: fileType,
    );

    // If there are listeners, emit the event
    // Otherwise, store as pending for later processing
    if (_fileController.hasListener) {
      debugPrint('📂 IncomingFileService: Emitting event to listeners');
      _fileController.add(event);
    } else {
      debugPrint('📂 IncomingFileService: No listeners, storing as pending');
      _pendingFilePath = localPath;
    }
  }

  /// Detect file type from path
  IncomingFileType _detectFileType(String filePath) {
    final lowerPath = filePath.toLowerCase();

    if (lowerPath.endsWith('.obstrack')) {
      return IncomingFileType.obstrack;
    } else if (lowerPath.endsWith('.obk')) {
      return IncomingFileType.obk;
    } else if (lowerPath.endsWith('.gpx')) {
      return IncomingFileType.gpx;
    } else if (lowerPath.endsWith('.kml')) {
      return IncomingFileType.kml;
    } else {
      return IncomingFileType.unknown;
    }
  }

  /// Process any pending file (call this after UI is ready)
  void processPendingFile() {
    if (_pendingFilePath != null) {
      debugPrint('📂 IncomingFileService: Processing pending file: $_pendingFilePath');
      _handleIncomingFile(_pendingFilePath!);
      _pendingFilePath = null;
    }
  }

  /// Check the Documents/Inbox folder for files shared via iOS share sheet
  ///
  /// On iOS, when files are shared to the app (via Files, email, AirDrop, etc.),
  /// they are often placed in the app's Documents/Inbox folder. This method
  /// checks that folder and processes any supported files found.
  ///
  /// Call this when the app becomes active to catch files that were shared
  /// while the app was in the background.
  Future<void> checkInboxFolder() async {
    if (!Platform.isIOS) return;

    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final inboxDir = Directory('${documentsDir.path}/Inbox');

      debugPrint('📂 IncomingFileService: Checking Inbox folder: ${inboxDir.path}');

      if (!await inboxDir.exists()) {
        debugPrint('📂 IncomingFileService: Inbox folder does not exist');
        return;
      }

      final supportedExtensions = ['obstrack', 'obk', 'gpx', 'kml'];
      final files = await inboxDir.list().toList();

      debugPrint('📂 IncomingFileService: Found ${files.length} items in Inbox');

      for (final entity in files) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          debugPrint('📂 IncomingFileService: Inbox file: ${entity.path} (ext: $extension)');

          if (supportedExtensions.contains(extension)) {
            debugPrint('📂 IncomingFileService: Processing Inbox file: ${entity.path}');
            _handleIncomingFile(entity.path);
            // Only process one file at a time to avoid overwhelming the user
            // The file will be deleted after successful import by the caller
            return;
          }
        }
      }

      debugPrint('📂 IncomingFileService: No supported files in Inbox');
    } catch (e) {
      debugPrint('📂 IncomingFileService: Error checking Inbox: $e');
    }
  }

  /// Delete a file from the Inbox folder after successful processing
  Future<bool> deleteInboxFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists() && filePath.contains('/Inbox/')) {
        await file.delete();
        debugPrint('📂 IncomingFileService: Deleted Inbox file: $filePath');
        return true;
      }
    } catch (e) {
      debugPrint('📂 IncomingFileService: Error deleting Inbox file: $e');
    }
    return false;
  }

  /// Dispose of the service
  void dispose() {
    _linkSubscription?.cancel();
    _fileController.close();
  }
}
