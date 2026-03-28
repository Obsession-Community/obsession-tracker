import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/collaboration_models.dart';
import 'package:obsession_tracker/core/models/security_models.dart';
import 'package:obsession_tracker/core/services/data_encryption_service.dart';

/// Selective sharing service with privacy controls and time limits
class SelectiveSharingService {
  SelectiveSharingService({
    required DataEncryptionService encryptionService,
  }) : _encryptionService = encryptionService;

  final DataEncryptionService _encryptionService;

  // Service state
  bool _isInitialized = false;
  String? _currentUserId;

  // Shared sessions and workspaces
  final Map<String, SharedSession> _sharedSessions = {};
  final Map<String, SharedWorkspace> _workspaces = {};
  final Map<String, WorkspaceInvitation> _invitations = {};

  // Stream controllers
  final StreamController<SharedSession> _sharedSessionController =
      StreamController.broadcast();
  final StreamController<SharedWorkspace> _workspaceController =
      StreamController.broadcast();
  final StreamController<WorkspaceInvitation> _invitationController =
      StreamController.broadcast();

  // Timers for cleanup
  Timer? _cleanupTimer;

  /// Stream of shared sessions
  Stream<SharedSession> get sharedSessionStream =>
      _sharedSessionController.stream;

  /// Stream of workspace updates
  Stream<SharedWorkspace> get workspaceStream => _workspaceController.stream;

  /// Stream of invitations
  Stream<WorkspaceInvitation> get invitationStream =>
      _invitationController.stream;

  /// Initialize the selective sharing service
  Future<void> initialize({required String userId}) async {
    if (_isInitialized) return;

    try {
      debugPrint('🔗 Initializing selective sharing service...');

      _currentUserId = userId;

      // Initialize encryption service
      await _encryptionService.initialize(
        const DataEncryptionSettings(),
      );

      // Load existing shared sessions and workspaces
      await _loadSharedData();

      // Start cleanup timer for expired shares
      _startCleanupTimer();

      _isInitialized = true;
      debugPrint('✅ Selective sharing service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize selective sharing service: $e');
      rethrow;
    }
  }

  /// Stop the sharing service
  Future<void> stop() async {
    if (!_isInitialized) return;

    debugPrint('🛑 Stopping selective sharing service...');

    // Cancel cleanup timer
    _cleanupTimer?.cancel();

    // Clean up expired shares
    await _cleanupExpiredShares();

    _isInitialized = false;
    debugPrint('✅ Selective sharing service stopped');
  }

  /// Create a shared workspace
  Future<SharedWorkspace> createWorkspace({
    required String name,
    String? description,
    bool isPublic = false,
    int maxMembers = 10,
    SharedWorkspaceSettings? settings,
    DateTime? expiresAt,
  }) async {
    if (!_isInitialized || _currentUserId == null) {
      throw Exception('Service not initialized');
    }

    debugPrint('🏗️ Creating shared workspace: $name');

    try {
      final workspace = SharedWorkspace(
        id: _generateWorkspaceId(),
        name: name,
        ownerId: _currentUserId!,
        createdAt: DateTime.now(),
        description: description,
        isPublic: isPublic,
        inviteCode: isPublic ? _generateInviteCode() : null,
        expiresAt: expiresAt,
        maxMembers: maxMembers,
        settings: settings ?? const SharedWorkspaceSettings(),
        members: [
          CollaborationUser(
            id: _currentUserId!,
            email: 'owner@example.com', // Would get from user service
            displayName: 'Workspace Owner',
            role: UserRole.owner,
            permissions: Permission.values,
            isOnline: true,
            lastActiveAt: DateTime.now(),
          ),
        ],
      );

      // Save workspace
      _workspaces[workspace.id] = workspace;
      await _saveWorkspace(workspace);

      // Notify listeners
      _workspaceController.add(workspace);

      debugPrint('✅ Workspace created: ${workspace.name}');
      return workspace;
    } catch (e) {
      debugPrint('❌ Failed to create workspace: $e');
      rethrow;
    }
  }

  /// Share a session with privacy controls
  Future<SharedSession> shareSession({
    required String sessionId,
    required String workspaceId,
    AccessLevel accessLevel = AccessLevel.view,
    bool allowDownload = false,
    bool stripPrivateData = true,
    DateTime? expiresAt,
    String? customMessage,
  }) async {
    if (!_isInitialized || _currentUserId == null) {
      throw Exception('Service not initialized');
    }

    debugPrint('🔗 Sharing session: $sessionId');

    try {
      // Verify workspace exists and user has permission
      final workspace = _workspaces[workspaceId];
      if (workspace == null) {
        throw Exception('Workspace not found');
      }

      if (!_canUserShareInWorkspace(_currentUserId!, workspace)) {
        throw Exception('Insufficient permissions to share in workspace');
      }

      // Create shared session
      final sharedSession = SharedSession(
        id: _generateShareId(),
        sessionId: sessionId,
        workspaceId: workspaceId,
        sharedBy: _currentUserId!,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        accessLevel: accessLevel,
        allowDownload: allowDownload,
        stripPrivateData: stripPrivateData,
        customMessage: customMessage,
      );

      // Process session data based on privacy settings
      await _processSharedSessionData(sharedSession);

      // Save shared session
      _sharedSessions[sharedSession.id] = sharedSession;
      await _saveSharedSession(sharedSession);

      // Notify listeners
      _sharedSessionController.add(sharedSession);

      debugPrint('✅ Session shared: ${sharedSession.id}');
      return sharedSession;
    } catch (e) {
      debugPrint('❌ Failed to share session: $e');
      rethrow;
    }
  }

  /// Access a shared session
  Future<Map<String, dynamic>?> accessSharedSession({
    required String shareId,
    required String userId,
  }) async {
    if (!_isInitialized) return null;

    debugPrint('👁️ Accessing shared session: $shareId');

    try {
      final sharedSession = _sharedSessions[shareId];
      if (sharedSession == null) {
        debugPrint('❌ Shared session not found: $shareId');
        return null;
      }

      // Check if share is expired
      if (sharedSession.isExpired) {
        debugPrint('❌ Shared session expired: $shareId');
        await _removeSharedSession(shareId);
        return null;
      }

      // Verify user has access to workspace
      final workspace = _workspaces[sharedSession.workspaceId];
      if (workspace == null || !_canUserAccessWorkspace(userId, workspace)) {
        debugPrint('❌ User cannot access workspace: $userId');
        return null;
      }

      // Update access statistics
      await _updateAccessStatistics(sharedSession);

      // Load and return session data
      final sessionData = await _loadSharedSessionData(sharedSession);

      debugPrint('✅ Shared session accessed: $shareId');
      return sessionData;
    } catch (e) {
      debugPrint('❌ Failed to access shared session: $e');
      return null;
    }
  }

  /// Invite user to workspace
  Future<WorkspaceInvitation> inviteUserToWorkspace({
    required String workspaceId,
    required String email,
    required UserRole role,
    List<Permission> permissions = const [],
    DateTime? expiresAt,
    String? customMessage,
  }) async {
    if (!_isInitialized || _currentUserId == null) {
      throw Exception('Service not initialized');
    }

    debugPrint('📧 Inviting user to workspace: $email');

    try {
      // Verify workspace exists and user can invite
      final workspace = _workspaces[workspaceId];
      if (workspace == null) {
        throw Exception('Workspace not found');
      }

      if (!_canUserInviteToWorkspace(_currentUserId!, workspace)) {
        throw Exception('Insufficient permissions to invite users');
      }

      // Check if workspace has available slots
      if (!workspace.hasAvailableSlots) {
        throw Exception('Workspace is at maximum capacity');
      }

      // Create invitation
      final invitation = WorkspaceInvitation(
        id: _generateInvitationId(),
        workspaceId: workspaceId,
        invitedBy: _currentUserId!,
        invitedEmail: email,
        createdAt: DateTime.now(),
        role: role,
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
        customMessage: customMessage,
        permissions:
            permissions.isNotEmpty ? permissions : _getDefaultPermissions(role),
      );

      // Save invitation
      _invitations[invitation.id] = invitation;
      await _saveInvitation(invitation);

      // Send invitation (would integrate with email service)
      await _sendInvitationEmail(invitation);

      // Notify listeners
      _invitationController.add(invitation);

      debugPrint('✅ User invited to workspace: $email');
      return invitation;
    } catch (e) {
      debugPrint('❌ Failed to invite user: $e');
      rethrow;
    }
  }

  /// Accept workspace invitation
  Future<bool> acceptInvitation({
    required String invitationId,
    required String userId,
    required String userEmail,
    required String displayName,
  }) async {
    if (!_isInitialized) return false;

    debugPrint('✅ Accepting invitation: $invitationId');

    try {
      final invitation = _invitations[invitationId];
      if (invitation == null || !invitation.isPending) {
        debugPrint('❌ Invalid or expired invitation: $invitationId');
        return false;
      }

      // Verify email matches
      if (invitation.invitedEmail.toLowerCase() != userEmail.toLowerCase()) {
        debugPrint('❌ Email mismatch for invitation: $invitationId');
        return false;
      }

      // Get workspace
      final workspace = _workspaces[invitation.workspaceId];
      if (workspace == null || workspace.isExpired) {
        debugPrint(
            '❌ Workspace not found or expired: ${invitation.workspaceId}');
        return false;
      }

      // Check if workspace has space
      if (!workspace.hasAvailableSlots) {
        debugPrint('❌ Workspace is full: ${invitation.workspaceId}');
        return false;
      }

      // Add user to workspace
      final newUser = CollaborationUser(
        id: userId,
        email: userEmail,
        displayName: displayName,
        role: invitation.role,
        permissions: invitation.permissions,
        isOnline: true,
        lastActiveAt: DateTime.now(),
      );

      final updatedWorkspace = SharedWorkspace(
        id: workspace.id,
        name: workspace.name,
        ownerId: workspace.ownerId,
        createdAt: workspace.createdAt,
        description: workspace.description,
        isPublic: workspace.isPublic,
        inviteCode: workspace.inviteCode,
        expiresAt: workspace.expiresAt,
        maxMembers: workspace.maxMembers,
        settings: workspace.settings,
        members: [...workspace.members, newUser],
        sessionIds: workspace.sessionIds,
        metadata: workspace.metadata,
      );

      // Update workspace
      _workspaces[workspace.id] = updatedWorkspace;
      await _saveWorkspace(updatedWorkspace);

      // Mark invitation as accepted
      final acceptedInvitation = WorkspaceInvitation(
        id: invitation.id,
        workspaceId: invitation.workspaceId,
        invitedBy: invitation.invitedBy,
        invitedEmail: invitation.invitedEmail,
        createdAt: invitation.createdAt,
        role: invitation.role,
        expiresAt: invitation.expiresAt,
        acceptedAt: DateTime.now(),
        customMessage: invitation.customMessage,
        permissions: invitation.permissions,
      );

      _invitations[invitationId] = acceptedInvitation;
      await _saveInvitation(acceptedInvitation);

      // Notify listeners
      _workspaceController.add(updatedWorkspace);
      _invitationController.add(acceptedInvitation);

      debugPrint('✅ Invitation accepted: $invitationId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to accept invitation: $e');
      return false;
    }
  }

  /// Revoke shared session
  Future<bool> revokeSharedSession(String shareId) async {
    if (!_isInitialized || _currentUserId == null) return false;

    debugPrint('🚫 Revoking shared session: $shareId');

    try {
      final sharedSession = _sharedSessions[shareId];
      if (sharedSession == null) return false;

      // Verify user can revoke (owner or sharer)
      final workspace = _workspaces[sharedSession.workspaceId];
      if (workspace == null) return false;

      final canRevoke = sharedSession.sharedBy == _currentUserId ||
          workspace.ownerId == _currentUserId ||
          _hasPermission(_currentUserId!, workspace, Permission.manageUsers);

      if (!canRevoke) {
        debugPrint('❌ Insufficient permissions to revoke share: $shareId');
        return false;
      }

      // Remove shared session
      await _removeSharedSession(shareId);

      debugPrint('✅ Shared session revoked: $shareId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to revoke shared session: $e');
      return false;
    }
  }

  /// Get user's shared sessions
  Future<List<SharedSession>> getUserSharedSessions(String userId) async {
    if (!_isInitialized) return [];

    try {
      final userSessions = _sharedSessions.values
          .where((session) => session.sharedBy == userId && !session.isExpired)
          .toList();

      return userSessions;
    } catch (e) {
      debugPrint('❌ Failed to get user shared sessions: $e');
      return [];
    }
  }

  /// Get user's workspaces
  Future<List<SharedWorkspace>> getUserWorkspaces(String userId) async {
    if (!_isInitialized) return [];

    try {
      final userWorkspaces = _workspaces.values
          .where((workspace) =>
              workspace.members.any((member) => member.id == userId) &&
              !workspace.isExpired)
          .toList();

      return userWorkspaces;
    } catch (e) {
      debugPrint('❌ Failed to get user workspaces: $e');
      return [];
    }
  }

  // Private methods

  Future<void> _loadSharedData() async {
    try {
      // Load shared sessions from storage
      await _loadSharedSessions();

      // Load workspaces from storage
      await _loadWorkspaces();

      // Load invitations from storage
      await _loadInvitations();

      debugPrint('📂 Shared data loaded');
    } catch (e) {
      debugPrint('❌ Failed to load shared data: $e');
    }
  }

  Future<void> _loadSharedSessions() async {
    // Implementation would load from database
    debugPrint('📂 Loading shared sessions...');
  }

  Future<void> _loadWorkspaces() async {
    // Implementation would load from database
    debugPrint('📂 Loading workspaces...');
  }

  Future<void> _loadInvitations() async {
    // Implementation would load from database
    debugPrint('📂 Loading invitations...');
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupExpiredShares();
    });
  }

  Future<void> _cleanupExpiredShares() async {
    try {
      debugPrint('🧹 Cleaning up expired shares...');

      // Remove expired shared sessions
      final expiredSessions = _sharedSessions.entries
          .where((entry) => entry.value.isExpired)
          .map((entry) => entry.key)
          .toList();

      for (final sessionId in expiredSessions) {
        await _removeSharedSession(sessionId);
      }

      // Remove expired workspaces
      final expiredWorkspaces = _workspaces.entries
          .where((entry) => entry.value.isExpired)
          .map((entry) => entry.key)
          .toList();

      for (final workspaceId in expiredWorkspaces) {
        await _removeWorkspace(workspaceId);
      }

      // Remove expired invitations
      final expiredInvitations = _invitations.entries
          .where((entry) => entry.value.isExpired)
          .map((entry) => entry.key)
          .toList();

      for (final invitationId in expiredInvitations) {
        _invitations.remove(invitationId);
        await _deleteInvitation(invitationId);
      }

      debugPrint('✅ Cleanup completed');
    } catch (e) {
      debugPrint('❌ Failed to cleanup expired shares: $e');
    }
  }

  Future<void> _processSharedSessionData(SharedSession sharedSession) async {
    try {
      // Load original session data
      final sessionData =
          await _loadOriginalSessionData(sharedSession.sessionId);
      if (sessionData == null) return;

      // Apply privacy filters
      final filteredData =
          await _applyPrivacyFilters(sessionData, sharedSession);

      // Encrypt and store processed data
      await _storeProcessedSessionData(sharedSession.id, filteredData);

      debugPrint('🔒 Session data processed with privacy controls');
    } catch (e) {
      debugPrint('❌ Failed to process shared session data: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadOriginalSessionData(
          String sessionId) async =>
      // Implementation would load session from database
      null;

  Future<Map<String, dynamic>> _applyPrivacyFilters(
    Map<String, dynamic> sessionData,
    SharedSession sharedSession,
  ) async {
    final filteredData = Map<String, dynamic>.from(sessionData);

    if (sharedSession.stripPrivateData) {
      // Remove sensitive information
      filteredData.remove('device_id');
      filteredData.remove('user_notes');
      filteredData.remove('private_waypoints');

      // Reduce GPS precision for privacy
      if (filteredData.containsKey('breadcrumbs')) {
        final breadcrumbs = filteredData['breadcrumbs'] as List?;
        if (breadcrumbs != null) {
          for (final breadcrumb in breadcrumbs) {
            if (breadcrumb is Map<String, dynamic>) {
              _reducePrecision(breadcrumb, 'latitude');
              _reducePrecision(breadcrumb, 'longitude');
            }
          }
        }
      }
    }

    return filteredData;
  }

  void _reducePrecision(Map<String, dynamic> data, String key) {
    if (data.containsKey(key) && data[key] is double) {
      // Reduce precision to ~100m for privacy
      final value = data[key] as double;
      data[key] = double.parse(value.toStringAsFixed(3));
    }
  }

  Future<void> _storeProcessedSessionData(
      String shareId, Map<String, dynamic> data) async {
    try {
      final jsonData = jsonEncode(data);
      final encryptedData =
          await _encryptionService.encryptDatabaseData(jsonData);

      // Store encrypted data (implementation would save to database)
      if (encryptedData != null) {
        debugPrint('💾 Processed session data stored: $shareId');
      }
    } catch (e) {
      debugPrint('❌ Failed to store processed session data: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadSharedSessionData(
      SharedSession sharedSession) async {
    try {
      // Load encrypted data (implementation would load from database)
      const encryptedData = ''; // Would load actual encrypted data

      if (encryptedData.isEmpty) return null;

      final decryptedData =
          await _encryptionService.decryptDatabaseData(encryptedData);
      if (decryptedData == null) return null;

      return jsonDecode(decryptedData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Failed to load shared session data: $e');
      return null;
    }
  }

  Future<void> _updateAccessStatistics(SharedSession sharedSession) async {
    try {
      final updatedSession = SharedSession(
        id: sharedSession.id,
        sessionId: sharedSession.sessionId,
        workspaceId: sharedSession.workspaceId,
        sharedBy: sharedSession.sharedBy,
        createdAt: sharedSession.createdAt,
        expiresAt: sharedSession.expiresAt,
        accessLevel: sharedSession.accessLevel,
        allowDownload: sharedSession.allowDownload,
        stripPrivateData: sharedSession.stripPrivateData,
        customMessage: sharedSession.customMessage,
        accessCount: sharedSession.accessCount + 1,
        lastAccessedAt: DateTime.now(),
        metadata: sharedSession.metadata,
      );

      _sharedSessions[sharedSession.id] = updatedSession;
      await _saveSharedSession(updatedSession);
    } catch (e) {
      debugPrint('❌ Failed to update access statistics: $e');
    }
  }

  bool _canUserShareInWorkspace(String userId, SharedWorkspace workspace) {
    final user = workspace.members.firstWhere(
      (member) => member.id == userId,
      orElse: () => const CollaborationUser(
        id: '',
        email: '',
        displayName: '',
      ),
    );

    return user.id.isNotEmpty && user.permissions.contains(Permission.share);
  }

  bool _canUserAccessWorkspace(String userId, SharedWorkspace workspace) {
    if (workspace.isPublic) return true;

    return workspace.members.any((member) => member.id == userId);
  }

  bool _canUserInviteToWorkspace(String userId, SharedWorkspace workspace) {
    final user = workspace.members.firstWhere(
      (member) => member.id == userId,
      orElse: () => const CollaborationUser(
        id: '',
        email: '',
        displayName: '',
      ),
    );

    return user.id.isNotEmpty &&
        user.permissions.contains(Permission.manageUsers);
  }

  bool _hasPermission(
      String userId, SharedWorkspace workspace, Permission permission) {
    final user = workspace.members.firstWhere(
      (member) => member.id == userId,
      orElse: () => const CollaborationUser(
        id: '',
        email: '',
        displayName: '',
      ),
    );

    return user.id.isNotEmpty && user.permissions.contains(permission);
  }

  List<Permission> _getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Permission.values;
      case UserRole.admin:
        return [
          Permission.view,
          Permission.comment,
          Permission.edit,
          Permission.share,
          Permission.manageUsers,
          Permission.exportData,
          Permission.viewAnalytics,
        ];
      case UserRole.editor:
        return [
          Permission.view,
          Permission.comment,
          Permission.edit,
          Permission.exportData,
        ];
      case UserRole.contributor:
        return [
          Permission.view,
          Permission.comment,
          Permission.edit,
        ];
      case UserRole.viewer:
        return [Permission.view];
    }
  }

  Future<void> _sendInvitationEmail(WorkspaceInvitation invitation) async {
    // Implementation would send email via email service
    debugPrint('📧 Sending invitation email to: ${invitation.invitedEmail}');
  }

  Future<void> _saveWorkspace(SharedWorkspace workspace) async {
    // Implementation would save to database
    debugPrint('💾 Saving workspace: ${workspace.name}');
  }

  Future<void> _saveSharedSession(SharedSession sharedSession) async {
    // Implementation would save to database
    debugPrint('💾 Saving shared session: ${sharedSession.id}');
  }

  Future<void> _saveInvitation(WorkspaceInvitation invitation) async {
    // Implementation would save to database
    debugPrint('💾 Saving invitation: ${invitation.id}');
  }

  Future<void> _removeSharedSession(String shareId) async {
    _sharedSessions.remove(shareId);
    // Implementation would delete from database
    debugPrint('🗑️ Removed shared session: $shareId');
  }

  Future<void> _removeWorkspace(String workspaceId) async {
    _workspaces.remove(workspaceId);
    // Implementation would delete from database
    debugPrint('🗑️ Removed workspace: $workspaceId');
  }

  Future<void> _deleteInvitation(String invitationId) async {
    // Implementation would delete from database
    debugPrint('🗑️ Deleted invitation: $invitationId');
  }

  String _generateWorkspaceId() =>
      'ws_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

  String _generateShareId() =>
      'share_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

  String _generateInvitationId() =>
      'inv_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// Dispose of the service
  void dispose() {
    _cleanupTimer?.cancel();
    _sharedSessionController.close();
    _workspaceController.close();
    _invitationController.close();
  }
}
