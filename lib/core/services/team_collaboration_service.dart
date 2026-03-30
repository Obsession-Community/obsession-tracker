import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/collaboration_models.dart';
import 'package:obsession_tracker/core/services/selective_sharing_service.dart';

/// Team collaboration service for real-time collaborative sessions and notes
class TeamCollaborationService {
  TeamCollaborationService({
    required SelectiveSharingService sharingService,
  }) : _sharingService = sharingService;

  final SelectiveSharingService _sharingService;

  // Service state
  bool _isInitialized = false;
  String? _currentUserId;

  // Active collaboration sessions
  final Map<String, CollaborationSession> _activeSessions = {};
  final Map<String, List<CollaborationComment>> _sessionComments = {};
  final Map<String, List<CollaborationUser>> _activeUsers = {};

  // Stream controllers
  final StreamController<CollaborationEvent> _eventController =
      StreamController.broadcast();
  final StreamController<CollaborationComment> _commentController =
      StreamController.broadcast();
  final StreamController<List<CollaborationUser>> _usersController =
      StreamController.broadcast();
  final StreamController<CollaborationCursor> _cursorController =
      StreamController.broadcast();

  // Real-time connection
  Timer? _heartbeatTimer;
  Timer? _presenceTimer;

  /// Stream of collaboration events
  Stream<CollaborationEvent> get eventStream => _eventController.stream;

  /// Stream of new comments
  Stream<CollaborationComment> get commentStream => _commentController.stream;

  /// Stream of active users
  Stream<List<CollaborationUser>> get usersStream => _usersController.stream;

  /// Stream of cursor movements
  Stream<CollaborationCursor> get cursorStream => _cursorController.stream;

  /// Initialize the team collaboration service
  Future<void> initialize({required String userId}) async {
    if (_isInitialized) return;

    try {
      debugPrint('👥 Initializing team collaboration service...');

      _currentUserId = userId;

      // Initialize sharing service
      await _sharingService.initialize(userId: userId);

      // Load active collaboration sessions
      await _loadActiveCollaborationSessions();

      // Start presence and heartbeat timers
      _startPresenceUpdates();
      _startHeartbeat();

      _isInitialized = true;
      debugPrint('✅ Team collaboration service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize team collaboration service: $e');
      rethrow;
    }
  }

  /// Stop the collaboration service
  Future<void> stop() async {
    if (!_isInitialized) return;

    debugPrint('🛑 Stopping team collaboration service...');

    // Cancel timers
    _heartbeatTimer?.cancel();
    _presenceTimer?.cancel();

    // Leave all active sessions
    for (final sessionId in _activeSessions.keys) {
      await leaveCollaborationSession(sessionId);
    }

    _isInitialized = false;
    debugPrint('✅ Team collaboration service stopped');
  }

  /// Start a collaborative session
  Future<CollaborationSession> startCollaborationSession({
    required String sessionId,
    required String workspaceId,
    CollaborationMode mode = CollaborationMode.realTime,
    Map<String, dynamic> settings = const {},
  }) async {
    if (!_isInitialized || _currentUserId == null) {
      throw Exception('Service not initialized');
    }

    debugPrint('🚀 Starting collaboration session: $sessionId');

    try {
      // Verify user has access to workspace
      final workspaces =
          await _sharingService.getUserWorkspaces(_currentUserId!);
      if (!workspaces.any((w) => w.id == workspaceId)) {
        throw Exception('Workspace not found or no access');
      }

      // Create collaboration session
      final collaborationSession = CollaborationSession(
        id: _generateCollaborationId(),
        sessionId: sessionId,
        workspaceId: workspaceId,
        hostId: _currentUserId!,
        createdAt: DateTime.now(),
        mode: mode,
        status: CollaborationStatus.active,
        settings: settings,
        participants: [_currentUserId!],
      );

      // Save collaboration session
      _activeSessions[collaborationSession.id] = collaborationSession;
      await _saveCollaborationSession(collaborationSession);

      // Initialize session data
      _sessionComments[collaborationSession.id] = [];
      _activeUsers[collaborationSession.id] = [
        CollaborationUser(
          id: _currentUserId!,
          email: 'host@example.com', // Would get from user service
          displayName: 'Session Host',
          role: UserRole.owner,
          permissions: Permission.values,
          isOnline: true,
          lastActiveAt: DateTime.now(),
        ),
      ];

      // Broadcast event
      final event = CollaborationEvent(
        id: _generateEventId(),
        type: CollaborationEventType.sessionShared,
        workspaceId: workspaceId,
        userId: _currentUserId!,
        timestamp: DateTime.now(),
        sessionId: sessionId,
        data: {'collaboration_id': collaborationSession.id},
      );

      _eventController.add(event);

      debugPrint('✅ Collaboration session started: ${collaborationSession.id}');
      return collaborationSession;
    } catch (e) {
      debugPrint('❌ Failed to start collaboration session: $e');
      rethrow;
    }
  }

  /// Join a collaborative session
  Future<bool> joinCollaborationSession({
    required String collaborationId,
    required String userId,
    required String displayName,
  }) async {
    if (!_isInitialized) return false;

    debugPrint('🤝 Joining collaboration session: $collaborationId');

    try {
      final session = _activeSessions[collaborationId];
      if (session == null || session.status != CollaborationStatus.active) {
        debugPrint(
            '❌ Collaboration session not found or inactive: $collaborationId');
        return false;
      }

      // Check if user already in session
      if (session.participants.contains(userId)) {
        debugPrint('ℹ️ User already in session: $userId');
        return true;
      }

      // Verify user has access to workspace
      final workspaces = await _sharingService.getUserWorkspaces(userId);
      final hasAccess = workspaces.any((w) => w.id == session.workspaceId);

      if (!hasAccess) {
        debugPrint('❌ User does not have access to workspace: $userId');
        return false;
      }

      // Add user to session
      final updatedSession = CollaborationSession(
        id: session.id,
        sessionId: session.sessionId,
        workspaceId: session.workspaceId,
        hostId: session.hostId,
        createdAt: session.createdAt,
        mode: session.mode,
        status: session.status,
        settings: session.settings,
        participants: [...session.participants, userId],
        lastActivityAt: DateTime.now(),
      );

      _activeSessions[collaborationId] = updatedSession;
      await _saveCollaborationSession(updatedSession);

      // Add user to active users list
      final newUser = CollaborationUser(
        id: userId,
        email: '$userId@example.com', // Would get from user service
        displayName: displayName,
        role: UserRole.contributor,
        permissions: const [
          Permission.view,
          Permission.comment,
          Permission.edit
        ],
        isOnline: true,
        lastActiveAt: DateTime.now(),
      );

      _activeUsers[collaborationId] = [
        ..._activeUsers[collaborationId] ?? [],
        newUser,
      ];

      // Broadcast user joined event
      final event = CollaborationEvent(
        id: _generateEventId(),
        type: CollaborationEventType.userJoined,
        workspaceId: session.workspaceId,
        userId: userId,
        timestamp: DateTime.now(),
        sessionId: session.sessionId,
        data: {
          'collaboration_id': collaborationId,
          'display_name': displayName,
        },
      );

      _eventController.add(event);
      _usersController.add(_activeUsers[collaborationId]!);

      debugPrint('✅ User joined collaboration session: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to join collaboration session: $e');
      return false;
    }
  }

  /// Leave a collaborative session
  Future<bool> leaveCollaborationSession(String collaborationId) async {
    if (!_isInitialized || _currentUserId == null) return false;

    debugPrint('👋 Leaving collaboration session: $collaborationId');

    try {
      final session = _activeSessions[collaborationId];
      if (session == null) return false;

      // Remove user from session
      final updatedParticipants =
          session.participants.where((id) => id != _currentUserId).toList();

      // If host is leaving and there are other participants, transfer host
      String newHostId = session.hostId;
      if (session.hostId == _currentUserId && updatedParticipants.isNotEmpty) {
        newHostId = updatedParticipants.first;
      }

      // Update session
      final updatedSession = CollaborationSession(
        id: session.id,
        sessionId: session.sessionId,
        workspaceId: session.workspaceId,
        hostId: newHostId,
        createdAt: session.createdAt,
        mode: session.mode,
        status: updatedParticipants.isEmpty
            ? CollaborationStatus.ended
            : session.status,
        settings: session.settings,
        participants: updatedParticipants,
        lastActivityAt: DateTime.now(),
      );

      if (updatedParticipants.isEmpty) {
        // End session if no participants left
        _activeSessions.remove(collaborationId);
        await _deleteCollaborationSession(collaborationId);
      } else {
        _activeSessions[collaborationId] = updatedSession;
        await _saveCollaborationSession(updatedSession);
      }

      // Remove user from active users
      _activeUsers[collaborationId]
          ?.removeWhere((user) => user.id == _currentUserId);

      // Broadcast user left event
      final event = CollaborationEvent(
        id: _generateEventId(),
        type: CollaborationEventType.userLeft,
        workspaceId: session.workspaceId,
        userId: _currentUserId!,
        timestamp: DateTime.now(),
        sessionId: session.sessionId,
        data: {'collaboration_id': collaborationId},
      );

      _eventController.add(event);
      _usersController.add(_activeUsers[collaborationId] ?? []);

      debugPrint('✅ Left collaboration session: $collaborationId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to leave collaboration session: $e');
      return false;
    }
  }

  /// Add a comment to a collaborative session
  Future<CollaborationComment> addComment({
    required String collaborationId,
    required String content,
    String? parentId,
    CommentLocation? location,
    List<String> attachments = const [],
  }) async {
    if (!_isInitialized || _currentUserId == null) {
      throw Exception('Service not initialized');
    }

    debugPrint('💬 Adding comment to session: $collaborationId');

    try {
      final session = _activeSessions[collaborationId];
      if (session == null) {
        throw Exception('Collaboration session not found');
      }

      // Verify user is participant
      if (!session.participants.contains(_currentUserId)) {
        throw Exception('User is not a participant in this session');
      }

      // Create comment
      final comment = CollaborationComment(
        id: _generateCommentId(),
        sessionId: session.sessionId,
        authorId: _currentUserId!,
        content: content,
        createdAt: DateTime.now(),
        parentId: parentId,
        location: location,
        attachments: attachments,
      );

      // Save comment
      _sessionComments[collaborationId] = [
        ..._sessionComments[collaborationId] ?? [],
        comment,
      ];
      await _saveComment(comment);

      // Broadcast comment event
      final event = CollaborationEvent(
        id: _generateEventId(),
        type: CollaborationEventType.commentAdded,
        workspaceId: session.workspaceId,
        userId: _currentUserId!,
        timestamp: DateTime.now(),
        sessionId: session.sessionId,
        data: {
          'collaboration_id': collaborationId,
          'comment_id': comment.id,
          'content': content,
        },
      );

      _eventController.add(event);
      _commentController.add(comment);

      debugPrint('✅ Comment added: ${comment.id}');
      return comment;
    } catch (e) {
      debugPrint('❌ Failed to add comment: $e');
      rethrow;
    }
  }

  /// Edit a comment
  Future<bool> editComment({
    required String commentId,
    required String newContent,
  }) async {
    if (!_isInitialized || _currentUserId == null) return false;

    debugPrint('✏️ Editing comment: $commentId');

    try {
      // Find comment across all sessions
      CollaborationComment? targetComment;
      String? sessionKey;

      for (final entry in _sessionComments.entries) {
        final comment = entry.value.firstWhere(
          (c) => c.id == commentId,
          orElse: () => CollaborationComment(
            id: '',
            sessionId: '',
            authorId: '',
            content: '',
            createdAt: DateTime.now(),
          ),
        );

        if (comment.id.isNotEmpty) {
          targetComment = comment;
          sessionKey = entry.key;
          break;
        }
      }

      if (targetComment == null || sessionKey == null) {
        debugPrint('❌ Comment not found: $commentId');
        return false;
      }

      // Verify user can edit (author or admin)
      if (targetComment.authorId != _currentUserId) {
        final session = _activeSessions[sessionKey];
        if (session == null || session.hostId != _currentUserId) {
          debugPrint('❌ Insufficient permissions to edit comment: $commentId');
          return false;
        }
      }

      // Update comment
      final updatedComment = CollaborationComment(
        id: targetComment.id,
        sessionId: targetComment.sessionId,
        authorId: targetComment.authorId,
        content: newContent,
        createdAt: targetComment.createdAt,
        parentId: targetComment.parentId,
        editedAt: DateTime.now(),
        location: targetComment.location,
        attachments: targetComment.attachments,
        reactions: targetComment.reactions,
        isResolved: targetComment.isResolved,
        metadata: targetComment.metadata,
      );

      // Update in memory
      final comments = _sessionComments[sessionKey]!;
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index >= 0) {
        comments[index] = updatedComment;
      }

      // Save updated comment
      await _saveComment(updatedComment);

      // Broadcast edit event
      final session = _activeSessions[sessionKey]!;
      final event = CollaborationEvent(
        id: _generateEventId(),
        type: CollaborationEventType.commentEdited,
        workspaceId: session.workspaceId,
        userId: _currentUserId!,
        timestamp: DateTime.now(),
        sessionId: session.sessionId,
        data: {
          'collaboration_id': sessionKey,
          'comment_id': commentId,
          'new_content': newContent,
        },
      );

      _eventController.add(event);
      _commentController.add(updatedComment);

      debugPrint('✅ Comment edited: $commentId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to edit comment: $e');
      return false;
    }
  }

  /// Update cursor position for real-time collaboration
  Future<void> updateCursorPosition({
    required String collaborationId,
    required double latitude,
    required double longitude,
    String? context,
  }) async {
    if (!_isInitialized || _currentUserId == null) return;

    try {
      final session = _activeSessions[collaborationId];
      if (session == null || !session.participants.contains(_currentUserId)) {
        return;
      }

      final cursor = CollaborationCursor(
        userId: _currentUserId!,
        collaborationId: collaborationId,
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        context: context,
      );

      _cursorController.add(cursor);

      // Broadcast cursor update (would send to other participants)
      await _broadcastCursorUpdate(cursor);
    } catch (e) {
      debugPrint('❌ Failed to update cursor position: $e');
    }
  }

  /// Get comments for a collaboration session
  Future<List<CollaborationComment>> getSessionComments(
      String collaborationId) async {
    if (!_isInitialized) return [];

    try {
      return _sessionComments[collaborationId] ?? [];
    } catch (e) {
      debugPrint('❌ Failed to get session comments: $e');
      return [];
    }
  }

  /// Get active users in a collaboration session
  Future<List<CollaborationUser>> getActiveUsers(String collaborationId) async {
    if (!_isInitialized) return [];

    try {
      return _activeUsers[collaborationId] ?? [];
    } catch (e) {
      debugPrint('❌ Failed to get active users: $e');
      return [];
    }
  }

  /// Get user's active collaboration sessions
  Future<List<CollaborationSession>> getUserActiveSessions() async {
    if (!_isInitialized || _currentUserId == null) return [];

    try {
      return _activeSessions.values
          .where((session) => session.participants.contains(_currentUserId))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to get user active sessions: $e');
      return [];
    }
  }

  // Private methods

  Future<void> _loadActiveCollaborationSessions() async {
    try {
      // Load active sessions from database
      debugPrint('📂 Loading active collaboration sessions...');

      // Implementation would load from database
    } catch (e) {
      debugPrint('❌ Failed to load active collaboration sessions: $e');
    }
  }

  void _startPresenceUpdates() {
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateUserPresence();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendHeartbeat();
    });
  }

  Future<void> _updateUserPresence() async {
    if (_currentUserId == null) return;

    try {
      // Update user presence in all active sessions
      for (final entry in _activeUsers.entries) {
        final users = entry.value;
        final userIndex = users.indexWhere((u) => u.id == _currentUserId);

        if (userIndex >= 0) {
          users[userIndex] = users[userIndex].copyWith(
            isOnline: true,
            lastActiveAt: DateTime.now(),
          );
        }
      }

      debugPrint('👤 User presence updated');
    } catch (e) {
      debugPrint('❌ Failed to update user presence: $e');
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      // Send heartbeat to maintain connection
      debugPrint('💓 Sending collaboration heartbeat');

      // Implementation would send heartbeat to server
    } catch (e) {
      debugPrint('❌ Failed to send heartbeat: $e');
    }
  }

  Future<void> _saveCollaborationSession(CollaborationSession session) async {
    try {
      // Save session to database
      debugPrint('💾 Saving collaboration session: ${session.id}');

      // Implementation would save to database
    } catch (e) {
      debugPrint('❌ Failed to save collaboration session: $e');
    }
  }

  Future<void> _deleteCollaborationSession(String collaborationId) async {
    try {
      // Delete session from database
      debugPrint('🗑️ Deleting collaboration session: $collaborationId');

      // Implementation would delete from database
    } catch (e) {
      debugPrint('❌ Failed to delete collaboration session: $e');
    }
  }

  Future<void> _saveComment(CollaborationComment comment) async {
    try {
      // Save comment to database
      debugPrint('💾 Saving comment: ${comment.id}');

      // Implementation would save to database
    } catch (e) {
      debugPrint('❌ Failed to save comment: $e');
    }
  }

  Future<void> _broadcastCursorUpdate(CollaborationCursor cursor) async {
    try {
      // Broadcast cursor update to other participants
      debugPrint('📡 Broadcasting cursor update: ${cursor.userId}');

      // Implementation would broadcast via WebSocket or similar
    } catch (e) {
      debugPrint('❌ Failed to broadcast cursor update: $e');
    }
  }

  String _generateCollaborationId() =>
      'collab_${DateTime.now().millisecondsSinceEpoch}';

  String _generateEventId() => 'event_${DateTime.now().millisecondsSinceEpoch}';

  String _generateCommentId() =>
      'comment_${DateTime.now().millisecondsSinceEpoch}';

  /// Dispose of the service
  void dispose() {
    _heartbeatTimer?.cancel();
    _presenceTimer?.cancel();
    _eventController.close();
    _commentController.close();
    _usersController.close();
    _cursorController.close();
  }
}

/// Collaboration session information
@immutable
class CollaborationSession {
  const CollaborationSession({
    required this.id,
    required this.sessionId,
    required this.workspaceId,
    required this.hostId,
    required this.createdAt,
    required this.mode,
    required this.status,
    this.settings = const {},
    this.participants = const [],
    this.lastActivityAt,
  });

  final String id;
  final String sessionId;
  final String workspaceId;
  final String hostId;
  final DateTime createdAt;
  final CollaborationMode mode;
  final CollaborationStatus status;
  final Map<String, dynamic> settings;
  final List<String> participants;
  final DateTime? lastActivityAt;
}

/// Collaboration modes
enum CollaborationMode {
  realTime,
  asynchronous,
  hybrid,
}

/// Collaboration status
enum CollaborationStatus {
  active,
  paused,
  ended,
}

/// Real-time cursor position
@immutable
class CollaborationCursor {
  const CollaborationCursor({
    required this.userId,
    required this.collaborationId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.context,
  });

  final String userId;
  final String collaborationId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? context;
}
