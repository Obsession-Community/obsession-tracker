import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/collaboration_models.dart';
import 'package:obsession_tracker/core/services/selective_sharing_service.dart';
import 'package:web/web.dart' as web;

/// Web viewer service for browser-based session viewing
class WebViewerService {
  WebViewerService({
    required SelectiveSharingService sharingService,
  }) : _sharingService = sharingService;

  final SelectiveSharingService _sharingService;

  // Service state
  bool _isInitialized = false;
  String? _currentViewerId;

  // Current viewing session
  SharedSession? _currentSharedSession;
  Map<String, dynamic>? _sessionData;

  // Stream controllers
  final StreamController<Map<String, dynamic>> _sessionDataController =
      StreamController.broadcast();
  final StreamController<ViewerEvent> _viewerEventController =
      StreamController.broadcast();
  final StreamController<List<CollaborationComment>> _commentsController =
      StreamController.broadcast();

  // Web-specific elements
  web.Element? _mapContainer;
  web.Element? _controlsContainer;

  /// Stream of session data updates
  Stream<Map<String, dynamic>> get sessionDataStream =>
      _sessionDataController.stream;

  /// Stream of viewer events
  Stream<ViewerEvent> get viewerEventStream => _viewerEventController.stream;

  /// Stream of comments updates
  Stream<List<CollaborationComment>> get commentsStream =>
      _commentsController.stream;

  /// Initialize the web viewer service
  Future<void> initialize({
    required String viewerId,
    String? containerId,
  }) async {
    if (_isInitialized) return;

    try {
      debugPrint('🌐 Initializing web viewer service...');

      _currentViewerId = viewerId;

      // Initialize sharing service
      await _sharingService.initialize(userId: viewerId);

      // Setup web-specific elements
      await _setupWebElements(containerId);

      // Setup event listeners
      _setupEventListeners();

      _isInitialized = true;
      debugPrint('✅ Web viewer service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize web viewer service: $e');
      rethrow;
    }
  }

  /// Load and display a shared session
  Future<bool> loadSharedSession({
    required String shareId,
    String? accessToken,
  }) async {
    if (!_isInitialized || _currentViewerId == null) return false;

    debugPrint('📂 Loading shared session: $shareId');

    try {
      // Access shared session data
      final sessionData = await _sharingService.accessSharedSession(
        shareId: shareId,
        userId: _currentViewerId!,
      );

      if (sessionData == null) {
        debugPrint('❌ Failed to access shared session: $shareId');
        return false;
      }

      // Store session data
      _sessionData = sessionData;

      // Create shared session object for reference
      _currentSharedSession = SharedSession(
        id: shareId,
        sessionId: sessionData['id'] as String? ?? '',
        workspaceId: sessionData['workspace_id'] as String? ?? '',
        sharedBy: sessionData['shared_by'] as String? ?? '',
        createdAt: DateTime.now(),
        allowDownload: sessionData['allow_download'] as bool? ?? false,
        stripPrivateData: sessionData['strip_private_data'] as bool? ?? true,
      );

      // Render session in web viewer
      await _renderSession(sessionData);

      // Notify listeners
      _sessionDataController.add(sessionData);

      // Emit viewer event
      final event = ViewerEvent(
        type: ViewerEventType.sessionLoaded,
        timestamp: DateTime.now(),
        data: {'share_id': shareId},
      );
      _viewerEventController.add(event);

      debugPrint('✅ Shared session loaded: $shareId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to load shared session: $e');
      return false;
    }
  }

  /// Export session data (if allowed)
  Future<String?> exportSessionData({
    required ExportFormat format,
  }) async {
    if (_currentSharedSession == null || _sessionData == null) return null;

    // Check if download is allowed
    if (!_currentSharedSession!.allowDownload) {
      debugPrint('❌ Download not allowed for this session');
      return null;
    }

    debugPrint('📤 Exporting session data as ${format.name}');

    try {
      String exportedData;

      switch (format) {
        case ExportFormat.json:
          exportedData = _exportAsJson();
          break;
        case ExportFormat.gpx:
          exportedData = _exportAsGpx();
          break;
        case ExportFormat.csv:
          exportedData = _exportAsCsv();
          break;
        case ExportFormat.kml:
          exportedData = _exportAsKml();
          break;
      }

      // Trigger download in browser
      _triggerDownload(exportedData, format);

      // Emit viewer event
      final event = ViewerEvent(
        type: ViewerEventType.dataExported,
        timestamp: DateTime.now(),
        data: {'format': format.name},
      );
      _viewerEventController.add(event);

      debugPrint('✅ Session data exported as ${format.name}');
      return exportedData;
    } catch (e) {
      debugPrint('❌ Failed to export session data: $e');
      return null;
    }
  }

  /// Add a comment to the session (if allowed)
  Future<bool> addComment({
    required String content,
    CommentLocation? location,
  }) async {
    if (_currentSharedSession == null || _currentViewerId == null) return false;

    // Check if commenting is allowed
    if (_currentSharedSession!.accessLevel == AccessLevel.view) {
      debugPrint('❌ Commenting not allowed with current access level');
      return false;
    }

    debugPrint('💬 Adding comment to session');

    try {
      // Create comment (would integrate with collaboration service)
      final comment = CollaborationComment(
        id: _generateCommentId(),
        sessionId: _currentSharedSession!.sessionId,
        authorId: _currentViewerId!,
        content: content,
        createdAt: DateTime.now(),
        location: location,
      );

      // Save comment (implementation would save to backend)
      await _saveComment(comment);

      // Update comments stream
      final comments = await _loadSessionComments();
      _commentsController.add(comments);

      // Emit viewer event
      final event = ViewerEvent(
        type: ViewerEventType.commentAdded,
        timestamp: DateTime.now(),
        data: {
          'comment_id': comment.id,
          'content': content,
        },
      );
      _viewerEventController.add(event);

      debugPrint('✅ Comment added successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to add comment: $e');
      return false;
    }
  }

  /// Load comments for current session
  Future<List<CollaborationComment>> loadComments() async {
    if (_currentSharedSession == null) return [];

    try {
      final comments = await _loadSessionComments();
      _commentsController.add(comments);
      return comments;
    } catch (e) {
      debugPrint('❌ Failed to load comments: $e');
      return [];
    }
  }

  /// Update viewer settings
  Future<void> updateViewerSettings(WebViewerSettings settings) async {
    try {
      // Apply settings to web viewer
      await _applyViewerSettings(settings);

      // Emit viewer event
      final event = ViewerEvent(
        type: ViewerEventType.settingsUpdated,
        timestamp: DateTime.now(),
        data: settings.toMap(),
      );
      _viewerEventController.add(event);

      debugPrint('⚙️ Viewer settings updated');
    } catch (e) {
      debugPrint('❌ Failed to update viewer settings: $e');
    }
  }

  /// Get current session statistics
  Map<String, dynamic> getSessionStatistics() {
    if (_sessionData == null) return {};

    try {
      return {
        'total_distance': _sessionData!['total_distance'] ?? 0.0,
        'total_duration': _sessionData!['total_duration'] ?? 0,
        'breadcrumb_count': _sessionData!['breadcrumb_count'] ?? 0,
        'waypoint_count': (_sessionData!['waypoints'] as List?)?.length ?? 0,
        'start_time': _sessionData!['started_at'],
        'end_time': _sessionData!['completed_at'],
      };
    } catch (e) {
      debugPrint('❌ Failed to get session statistics: $e');
      return {};
    }
  }

  // Private methods

  Future<void> _setupWebElements(String? containerId) async {
    if (!kIsWeb) return;

    try {
      // Get or create main container
      final containerElement = containerId != null
          ? web.document.getElementById(containerId)
          : web.document.body;

      if (containerElement == null) {
        throw Exception('Container element not found');
      }

      // Create map container
      _mapContainer = web.HTMLDivElement()
        ..id = 'obsession-map-container'
        ..style.width = '100%'
        ..style.height = '70%'
        ..style.position = 'relative';

      // Create controls container
      _controlsContainer = web.HTMLDivElement()
        ..id = 'obsession-controls-container'
        ..style.width = '100%'
        ..style.height = '30%'
        ..style.padding = '10px'
        ..style.backgroundColor = '#f5f5f5';

      // Add elements to container
      containerElement.appendChild(_mapContainer!);
      containerElement.appendChild(_controlsContainer!);

      debugPrint('🌐 Web elements setup completed');
    } catch (e) {
      debugPrint('❌ Failed to setup web elements: $e');
    }
  }

  void _setupEventListeners() {
    if (!kIsWeb) return;

    try {
      // Listen for browser events
      web.window.addEventListener('resize', _handleWindowResize.toJS);
      web.window.addEventListener('beforeunload', _handleBeforeUnload.toJS);

      // Listen for keyboard shortcuts
      web.document.addEventListener('keydown', _handleKeyDown.toJS);

      debugPrint('🎧 Event listeners setup completed');
    } catch (e) {
      debugPrint('❌ Failed to setup event listeners: $e');
    }
  }

  void _handleWindowResize(web.Event event) {
    // Resize map and controls
    _resizeViewerElements();
  }

  void _handleBeforeUnload(web.Event event) {
    // Cleanup before page unload
    _cleanup();
  }

  void _handleKeyDown(web.KeyboardEvent event) {
    // Handle keyboard shortcuts
    if (event.ctrlKey || event.metaKey) {
      switch (event.key) {
        case 's':
          event.preventDefault();
          if (_currentSharedSession?.allowDownload == true) {
            exportSessionData(format: ExportFormat.gpx);
          }
          break;
        case 'c':
          if (event.shiftKey) {
            event.preventDefault();
            _showCommentDialog();
          }
          break;
      }
    }
  }

  Future<void> _renderSession(Map<String, dynamic> sessionData) async {
    if (!kIsWeb || _mapContainer == null || _controlsContainer == null) return;

    try {
      // Render map with session data
      await _renderMap(sessionData);

      // Render controls and information
      await _renderControls(sessionData);

      debugPrint('🗺️ Session rendered in web viewer');
    } catch (e) {
      debugPrint('❌ Failed to render session: $e');
    }
  }

  Future<void> _renderMap(Map<String, dynamic> sessionData) async {
    if (_mapContainer == null) return;

    // Clear existing content
    while (_mapContainer!.firstChild != null) {
      _mapContainer!.removeChild(_mapContainer!.firstChild!);
    }

    // Create map using web-compatible mapping library
    final mapElement = web.HTMLDivElement()
      ..id = 'session-map'
      ..style.width = '100%'
      ..style.height = '100%';

    _mapContainer!.children.add(mapElement);

    // Initialize map with session data
    await _initializeWebMap(mapElement, sessionData);
  }

  Future<void> _renderControls(Map<String, dynamic> sessionData) async {
    if (_controlsContainer == null) return;

    // Clear existing content
    while (_controlsContainer!.firstChild != null) {
      _controlsContainer!.removeChild(_controlsContainer!.firstChild!);
    }

    // Create control elements
    final controlsHtml = '''
      <div class="viewer-controls">
        <div class="session-info">
          <h3>${sessionData['name'] ?? 'Unnamed Session'}</h3>
          <p>Distance: ${_formatDistance((sessionData['total_distance'] as num?)?.toDouble() ?? 0.0)}</p>
          <p>Duration: ${_formatDuration((sessionData['total_duration'] as num?)?.toInt() ?? 0)}</p>
        </div>
        <div class="viewer-actions">
          ${_currentSharedSession?.allowDownload == true ? '''
            <button id="export-gpx" class="btn btn-primary">Export GPX</button>
            <button id="export-json" class="btn btn-secondary">Export JSON</button>
          ''' : ''}
          ${_currentSharedSession?.accessLevel != AccessLevel.view ? '''
            <button id="add-comment" class="btn btn-info">Add Comment</button>
          ''' : ''}
        </div>
      </div>
    ''';

    _controlsContainer!.innerHTML = controlsHtml.toJS;

    // Add event listeners to buttons
    _setupControlEventListeners();
  }

  Future<void> _initializeWebMap(
      web.Element mapElement, Map<String, dynamic> sessionData) async {
    // Implementation would initialize a web-compatible map
    // Using libraries like Leaflet, Mapbox GL JS, or Google Maps

    debugPrint('🗺️ Initializing web map with session data');

    // For now, create a placeholder
    mapElement.innerHTML = '''
      <div style="display: flex; align-items: center; justify-content: center; height: 100%; background: #e0e0e0;">
        <div style="text-align: center;">
          <h2>Session Map</h2>
          <p>Interactive map would be rendered here</p>
          <p>Breadcrumbs: ${(sessionData['breadcrumbs'] as List?)?.length ?? 0}</p>
          <p>Waypoints: ${(sessionData['waypoints'] as List?)?.length ?? 0}</p>
        </div>
      </div>
    '''
        .toJS;
  }

  void _setupControlEventListeners() {
    // Export GPX button
    web.document.getElementById('export-gpx')?.addEventListener(
        'click',
        ((event) {
          exportSessionData(format: ExportFormat.gpx);
        }).toJS);

    // Export JSON button
    web.document.getElementById('export-json')?.addEventListener(
        'click',
        ((event) {
          exportSessionData(format: ExportFormat.json);
        }).toJS);

    // Add comment button
    web.document.getElementById('add-comment')?.addEventListener(
        'click',
        ((event) {
          _showCommentDialog();
        }).toJS);
  }

  String _exportAsJson() {
    if (_sessionData == null) return '{}';
    return jsonEncode(_sessionData);
  }

  String _exportAsGpx() {
    if (_sessionData == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Obsession Tracker">');
    buffer.writeln('  <trk>');
    buffer.writeln(
        '    <name>${_sessionData!['name'] ?? 'Unnamed Session'}</name>');
    buffer.writeln('    <trkseg>');

    final breadcrumbs = _sessionData!['breadcrumbs'] as List?;
    if (breadcrumbs != null) {
      for (final breadcrumb in breadcrumbs) {
        if (breadcrumb is Map<String, dynamic>) {
          final lat = breadcrumb['latitude'];
          final lon = breadcrumb['longitude'];
          final time = breadcrumb['timestamp'];

          if (lat != null && lon != null) {
            buffer.writeln('      <trkpt lat="$lat" lon="$lon">');
            if (time != null) {
              buffer.writeln('        <time>$time</time>');
            }
            buffer.writeln('      </trkpt>');
          }
        }
      }
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  String _exportAsCsv() {
    if (_sessionData == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('timestamp,latitude,longitude,altitude,speed,heading');

    final breadcrumbs = _sessionData!['breadcrumbs'] as List?;
    if (breadcrumbs != null) {
      for (final breadcrumb in breadcrumbs) {
        if (breadcrumb is Map<String, dynamic>) {
          final timestamp = breadcrumb['timestamp'] ?? '';
          final lat = breadcrumb['latitude'] ?? '';
          final lon = breadcrumb['longitude'] ?? '';
          final alt = breadcrumb['altitude'] ?? '';
          final speed = breadcrumb['speed'] ?? '';
          final heading = breadcrumb['heading'] ?? '';

          buffer.writeln('$timestamp,$lat,$lon,$alt,$speed,$heading');
        }
      }
    }

    return buffer.toString();
  }

  String _exportAsKml() {
    if (_sessionData == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('  <Document>');
    buffer.writeln(
        '    <name>${_sessionData!['name'] ?? 'Unnamed Session'}</name>');
    buffer.writeln('    <Placemark>');
    buffer.writeln('      <name>Track</name>');
    buffer.writeln('      <LineString>');
    buffer.writeln('        <coordinates>');

    final breadcrumbs = _sessionData!['breadcrumbs'] as List?;
    if (breadcrumbs != null) {
      for (final breadcrumb in breadcrumbs) {
        if (breadcrumb is Map<String, dynamic>) {
          final lat = breadcrumb['latitude'];
          final lon = breadcrumb['longitude'];
          final alt = breadcrumb['altitude'] ?? 0;

          if (lat != null && lon != null) {
            buffer.writeln('          $lon,$lat,$alt');
          }
        }
      }
    }

    buffer.writeln('        </coordinates>');
    buffer.writeln('      </LineString>');
    buffer.writeln('    </Placemark>');
    buffer.writeln('  </Document>');
    buffer.writeln('</kml>');

    return buffer.toString();
  }

  void _triggerDownload(String data, ExportFormat format) {
    if (!kIsWeb) return;

    final blob = web.Blob([data.toJS].toJS);
    final url = web.URL.createObjectURL(blob);

    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..setAttribute('download', 'session.${format.extension}');
    anchor.click();

    web.URL.revokeObjectURL(url);
  }

  void _showCommentDialog() {
    if (!kIsWeb) return;

    // Create comment dialog
    final dialog = web.HTMLDivElement()
      ..id = 'comment-dialog'
      ..style.position = 'fixed'
      ..style.top = '50%'
      ..style.left = '50%'
      ..style.transform = 'translate(-50%, -50%)'
      ..style.backgroundColor = 'white'
      ..style.padding = '20px'
      ..style.border = '1px solid #ccc'
      ..style.borderRadius = '8px'
      ..style.boxShadow = '0 4px 8px rgba(0,0,0,0.1)'
      ..style.zIndex = '1000';

    dialog.innerHTML = '''
      <h3>Add Comment</h3>
      <textarea id="comment-text" placeholder="Enter your comment..." style="width: 300px; height: 100px;"></textarea>
      <div style="margin-top: 10px;">
        <button id="submit-comment" style="margin-right: 10px;">Submit</button>
        <button id="cancel-comment">Cancel</button>
      </div>
    '''
        .toJS;

    web.document.body!.appendChild(dialog);

    // Add event listeners
    web.document.getElementById('submit-comment')?.addEventListener(
        'click',
        ((event) {
          final textarea = web.document.getElementById('comment-text')
              as web.HTMLTextAreaElement?;
          final content = textarea?.value.trim() ?? '';

          if (content.isNotEmpty) {
            addComment(content: content);
          }

          dialog.remove();
        }).toJS);

    web.document.getElementById('cancel-comment')?.addEventListener(
        'click',
        ((event) {
          dialog.remove();
        }).toJS);
  }

  Future<void> _applyViewerSettings(WebViewerSettings settings) async {
    // Apply settings to web viewer elements
    if (_mapContainer != null) {
      (_mapContainer! as web.HTMLElement)
          .style
          .setProperty('display', settings.showMap ? 'block' : 'none');
    }

    if (_controlsContainer != null) {
      (_controlsContainer! as web.HTMLElement)
          .style
          .setProperty('display', settings.showControls ? 'block' : 'none');
    }
  }

  Future<void> _saveComment(CollaborationComment comment) async {
    // Implementation would save comment to backend
    debugPrint('💾 Saving comment: ${comment.id}');
  }

  Future<List<CollaborationComment>> _loadSessionComments() async =>
      // Implementation would load comments from backend
      [];

  void _resizeViewerElements() {
    // Resize map and controls based on window size
    if (_mapContainer != null && _controlsContainer != null) {
      final windowHeight = web.window.innerHeight;
      final mapHeight = (windowHeight * 0.7).round();
      final controlsHeight = (windowHeight * 0.3).round();

      (_mapContainer! as web.HTMLElement)
          .style
          .setProperty('height', '${mapHeight}px');
      (_controlsContainer! as web.HTMLElement)
          .style
          .setProperty('height', '${controlsHeight}px');
    }
  }

  void _cleanup() {
    // Cleanup resources before page unload
    debugPrint('🧹 Cleaning up web viewer resources');
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _generateCommentId() =>
      'comment_${DateTime.now().millisecondsSinceEpoch}';

  /// Dispose of the service
  void dispose() {
    _sessionDataController.close();
    _viewerEventController.close();
    _commentsController.close();

    if (kIsWeb) {
      web.window.removeEventListener('resize', _handleWindowResize.toJS);
      web.window.removeEventListener('beforeunload', _handleBeforeUnload.toJS);
      web.document.removeEventListener('keydown', _handleKeyDown.toJS);
    }
  }
}

/// Web viewer event
@immutable
class ViewerEvent {
  const ViewerEvent({
    required this.type,
    required this.timestamp,
    this.data = const {},
  });

  final ViewerEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
}

/// Types of viewer events
enum ViewerEventType {
  sessionLoaded,
  dataExported,
  commentAdded,
  settingsUpdated,
  error,
}

/// Export formats
enum ExportFormat {
  json,
  gpx,
  csv,
  kml;

  String get extension {
    switch (this) {
      case ExportFormat.json:
        return 'json';
      case ExportFormat.gpx:
        return 'gpx';
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.kml:
        return 'kml';
    }
  }
}

/// Web viewer settings
@immutable
class WebViewerSettings {
  const WebViewerSettings({
    this.showMap = true,
    this.showControls = true,
    this.enableComments = true,
    this.enableExport = true,
    this.theme = ViewerTheme.light,
  });

  final bool showMap;
  final bool showControls;
  final bool enableComments;
  final bool enableExport;
  final ViewerTheme theme;

  Map<String, dynamic> toMap() => {
        'show_map': showMap,
        'show_controls': showControls,
        'enable_comments': enableComments,
        'enable_export': enableExport,
        'theme': theme.name,
      };
}

/// Viewer themes
enum ViewerTheme {
  light,
  dark,
  auto,
}
