import 'package:flutter/foundation.dart';

/// User information for collaboration
@immutable
class CollaborationUser {
  const CollaborationUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isOnline = false,
    this.lastActiveAt,
    this.role = UserRole.viewer,
    this.permissions = const [],
    this.metadata = const {},
  });

  factory CollaborationUser.fromMap(Map<String, dynamic> map) =>
      CollaborationUser(
        id: map['id'] as String,
        email: map['email'] as String,
        displayName: map['display_name'] as String,
        avatarUrl: map['avatar_url'] as String?,
        isOnline: map['is_online'] as bool? ?? false,
        lastActiveAt: map['last_active_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['last_active_at'] as int)
            : null,
        role: UserRole.values.firstWhere(
          (e) => e.name == map['role'],
          orElse: () => UserRole.viewer,
        ),
        permissions: (map['permissions'] as List?)
                ?.map((p) => Permission.values.firstWhere(
                      (e) => e.name == p,
                      orElse: () => Permission.view,
                    ))
                .toList() ??
            [],
        metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      );

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastActiveAt;
  final UserRole role;
  final List<Permission> permissions;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_online': isOnline,
        'last_active_at': lastActiveAt?.millisecondsSinceEpoch,
        'role': role.name,
        'permissions': permissions.map((p) => p.name).toList(),
        'metadata': metadata,
      };

  CollaborationUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastActiveAt,
    UserRole? role,
    List<Permission>? permissions,
    Map<String, dynamic>? metadata,
  }) =>
      CollaborationUser(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isOnline: isOnline ?? this.isOnline,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        role: role ?? this.role,
        permissions: permissions ?? this.permissions,
        metadata: metadata ?? this.metadata,
      );
}

/// User roles in collaboration
enum UserRole {
  owner,
  admin,
  editor,
  contributor,
  viewer,
}

/// Collaboration modes
enum CollaborationMode {
  readonly,
  collaborative,
  realtime,
}

/// Permissions for collaboration
enum Permission {
  view,
  comment,
  edit,
  share,
  delete,
  manageUsers,
  exportData,
  viewAnalytics,
}

/// Shared workspace for collaboration
@immutable
class SharedWorkspace {
  const SharedWorkspace({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    this.description,
    this.isPublic = false,
    this.inviteCode,
    this.expiresAt,
    this.maxMembers = 10,
    this.settings = const SharedWorkspaceSettings(),
    this.members = const [],
    this.sessionIds = const [],
    this.metadata = const {},
  });

  factory SharedWorkspace.fromMap(Map<String, dynamic> map) => SharedWorkspace(
        id: map['id'] as String,
        name: map['name'] as String,
        ownerId: map['owner_id'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        description: map['description'] as String?,
        isPublic: map['is_public'] as bool? ?? false,
        inviteCode: map['invite_code'] as String?,
        expiresAt: map['expires_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
            : null,
        maxMembers: map['max_members'] as int? ?? 10,
        settings: map['settings'] != null
            ? SharedWorkspaceSettings.fromMap(
                Map<String, dynamic>.from(map['settings'] as Map))
            : const SharedWorkspaceSettings(),
        members: (map['members'] as List?)
                ?.map((m) => CollaborationUser.fromMap(
                    Map<String, dynamic>.from(m as Map)))
                .toList() ??
            [],
        sessionIds: (map['session_ids'] as List?)?.cast<String>() ?? [],
        metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      );

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;
  final String? description;
  final bool isPublic;
  final String? inviteCode;
  final DateTime? expiresAt;
  final int maxMembers;
  final SharedWorkspaceSettings settings;
  final List<CollaborationUser> members;
  final List<String> sessionIds;
  final Map<String, dynamic> metadata;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get hasAvailableSlots => members.length < maxMembers;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'owner_id': ownerId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'description': description,
        'is_public': isPublic,
        'invite_code': inviteCode,
        'expires_at': expiresAt?.millisecondsSinceEpoch,
        'max_members': maxMembers,
        'settings': settings.toMap(),
        'members': members.map((m) => m.toMap()).toList(),
        'session_ids': sessionIds,
        'metadata': metadata,
      };
}

/// Settings for shared workspace
@immutable
class SharedWorkspaceSettings {
  const SharedWorkspaceSettings({
    this.allowComments = true,
    this.allowEditing = false,
    this.allowExport = true,
    this.requireApproval = false,
    this.enableRealTimeSync = true,
    this.enableNotifications = true,
    this.privacyLevel = PrivacyLevel.private,
    this.dataRetentionDays = 90,
  });

  factory SharedWorkspaceSettings.fromMap(Map<String, dynamic> map) =>
      SharedWorkspaceSettings(
        allowComments: map['allow_comments'] as bool? ?? true,
        allowEditing: map['allow_editing'] as bool? ?? false,
        allowExport: map['allow_export'] as bool? ?? true,
        requireApproval: map['require_approval'] as bool? ?? false,
        enableRealTimeSync: map['enable_real_time_sync'] as bool? ?? true,
        enableNotifications: map['enable_notifications'] as bool? ?? true,
        privacyLevel: PrivacyLevel.values.firstWhere(
          (e) => e.name == map['privacy_level'],
          orElse: () => PrivacyLevel.private,
        ),
        dataRetentionDays: map['data_retention_days'] as int? ?? 90,
      );

  final bool allowComments;
  final bool allowEditing;
  final bool allowExport;
  final bool requireApproval;
  final bool enableRealTimeSync;
  final bool enableNotifications;
  final PrivacyLevel privacyLevel;
  final int dataRetentionDays;

  Map<String, dynamic> toMap() => {
        'allow_comments': allowComments,
        'allow_editing': allowEditing,
        'allow_export': allowExport,
        'require_approval': requireApproval,
        'enable_real_time_sync': enableRealTimeSync,
        'enable_notifications': enableNotifications,
        'privacy_level': privacyLevel.name,
        'data_retention_days': dataRetentionDays,
      };

  SharedWorkspaceSettings copyWith({
    bool? allowComments,
    bool? allowEditing,
    bool? allowExport,
    bool? requireApproval,
    bool? enableRealTimeSync,
    bool? enableNotifications,
    PrivacyLevel? privacyLevel,
    int? dataRetentionDays,
  }) =>
      SharedWorkspaceSettings(
        allowComments: allowComments ?? this.allowComments,
        allowEditing: allowEditing ?? this.allowEditing,
        allowExport: allowExport ?? this.allowExport,
        requireApproval: requireApproval ?? this.requireApproval,
        enableRealTimeSync: enableRealTimeSync ?? this.enableRealTimeSync,
        enableNotifications: enableNotifications ?? this.enableNotifications,
        privacyLevel: privacyLevel ?? this.privacyLevel,
        dataRetentionDays: dataRetentionDays ?? this.dataRetentionDays,
      );
}

/// Privacy levels for sharing
enum PrivacyLevel {
  public,
  unlisted,
  private,
  restricted,
}

/// Shared session information
@immutable
class SharedSession {
  const SharedSession({
    required this.id,
    required this.sessionId,
    required this.workspaceId,
    required this.sharedBy,
    required this.createdAt,
    this.expiresAt,
    this.accessLevel = AccessLevel.view,
    this.allowDownload = false,
    this.stripPrivateData = true,
    this.customMessage,
    this.accessCount = 0,
    this.lastAccessedAt,
    this.metadata = const {},
  });

  factory SharedSession.fromMap(Map<String, dynamic> map) => SharedSession(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        workspaceId: map['workspace_id'] as String,
        sharedBy: map['shared_by'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        expiresAt: map['expires_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
            : null,
        accessLevel: AccessLevel.values.firstWhere(
          (e) => e.name == map['access_level'],
          orElse: () => AccessLevel.view,
        ),
        allowDownload: map['allow_download'] as bool? ?? false,
        stripPrivateData: map['strip_private_data'] as bool? ?? true,
        customMessage: map['custom_message'] as String?,
        accessCount: map['access_count'] as int? ?? 0,
        lastAccessedAt: map['last_accessed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                map['last_accessed_at'] as int)
            : null,
        metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      );

  final String id;
  final String sessionId;
  final String workspaceId;
  final String sharedBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final AccessLevel accessLevel;
  final bool allowDownload;
  final bool stripPrivateData;
  final String? customMessage;
  final int accessCount;
  final DateTime? lastAccessedAt;
  final Map<String, dynamic> metadata;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'workspace_id': workspaceId,
        'shared_by': sharedBy,
        'created_at': createdAt.millisecondsSinceEpoch,
        'expires_at': expiresAt?.millisecondsSinceEpoch,
        'access_level': accessLevel.name,
        'allow_download': allowDownload,
        'strip_private_data': stripPrivateData,
        'custom_message': customMessage,
        'access_count': accessCount,
        'last_accessed_at': lastAccessedAt?.millisecondsSinceEpoch,
        'metadata': metadata,
      };
}

/// Access levels for shared content
enum AccessLevel {
  view,
  comment,
  edit,
  full,
}

/// Comment on shared content
@immutable
class CollaborationComment {
  const CollaborationComment({
    required this.id,
    required this.sessionId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.editedAt,
    this.location,
    this.attachments = const [],
    this.reactions = const {},
    this.isResolved = false,
    this.metadata = const {},
  });

  factory CollaborationComment.fromMap(Map<String, dynamic> map) =>
      CollaborationComment(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        authorId: map['author_id'] as String,
        content: map['content'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        parentId: map['parent_id'] as String?,
        editedAt: map['edited_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['edited_at'] as int)
            : null,
        location: map['location'] != null
            ? CommentLocation.fromMap(
                Map<String, dynamic>.from(map['location'] as Map))
            : null,
        attachments: (map['attachments'] as List?)?.cast<String>() ?? [],
        reactions: Map<String, int>.from(map['reactions'] as Map? ?? {}),
        isResolved: map['is_resolved'] as bool? ?? false,
        metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      );

  final String id;
  final String sessionId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final String? parentId;
  final DateTime? editedAt;
  final CommentLocation? location;
  final List<String> attachments;
  final Map<String, int> reactions;
  final bool isResolved;
  final Map<String, dynamic> metadata;

  bool get isEdited => editedAt != null;
  bool get isReply => parentId != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'author_id': authorId,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
        'parent_id': parentId,
        'edited_at': editedAt?.millisecondsSinceEpoch,
        'location': location?.toMap(),
        'attachments': attachments,
        'reactions': reactions,
        'is_resolved': isResolved,
        'metadata': metadata,
      };
}

/// Location context for comments
@immutable
class CommentLocation {
  const CommentLocation({
    this.latitude,
    this.longitude,
    this.waypointId,
    this.timestamp,
    this.context,
  });

  factory CommentLocation.fromMap(Map<String, dynamic> map) => CommentLocation(
        latitude: map['latitude'] as double?,
        longitude: map['longitude'] as double?,
        waypointId: map['waypoint_id'] as String?,
        timestamp: map['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
            : null,
        context: map['context'] as String?,
      );

  final double? latitude;
  final double? longitude;
  final String? waypointId;
  final DateTime? timestamp;
  final String? context;

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'waypoint_id': waypointId,
        'timestamp': timestamp?.millisecondsSinceEpoch,
        'context': context,
      };
}

/// Real-time collaboration event
@immutable
class CollaborationEvent {
  const CollaborationEvent({
    required this.id,
    required this.type,
    required this.workspaceId,
    required this.userId,
    required this.timestamp,
    this.sessionId,
    this.data = const {},
  });

  factory CollaborationEvent.fromMap(Map<String, dynamic> map) =>
      CollaborationEvent(
        id: map['id'] as String,
        type: CollaborationEventType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => CollaborationEventType.userJoined,
        ),
        workspaceId: map['workspace_id'] as String,
        userId: map['user_id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        sessionId: map['session_id'] as String?,
        data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      );

  final String id;
  final CollaborationEventType type;
  final String workspaceId;
  final String userId;
  final DateTime timestamp;
  final String? sessionId;
  final Map<String, dynamic> data;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'workspace_id': workspaceId,
        'user_id': userId,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'session_id': sessionId,
        'data': data,
      };
}

/// Types of collaboration events
enum CollaborationEventType {
  userJoined,
  userLeft,
  sessionShared,
  sessionUnshared,
  commentAdded,
  commentEdited,
  commentDeleted,
  dataEdited,
  permissionChanged,
  workspaceUpdated,
}

/// Invitation to join workspace
@immutable
class WorkspaceInvitation {
  const WorkspaceInvitation({
    required this.id,
    required this.workspaceId,
    required this.invitedBy,
    required this.invitedEmail,
    required this.createdAt,
    required this.role,
    this.expiresAt,
    this.acceptedAt,
    this.declinedAt,
    this.customMessage,
    this.permissions = const [],
  });

  factory WorkspaceInvitation.fromMap(Map<String, dynamic> map) =>
      WorkspaceInvitation(
        id: map['id'] as String,
        workspaceId: map['workspace_id'] as String,
        invitedBy: map['invited_by'] as String,
        invitedEmail: map['invited_email'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        role: UserRole.values.firstWhere(
          (e) => e.name == map['role'],
          orElse: () => UserRole.viewer,
        ),
        expiresAt: map['expires_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
            : null,
        acceptedAt: map['accepted_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['accepted_at'] as int)
            : null,
        declinedAt: map['declined_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['declined_at'] as int)
            : null,
        customMessage: map['custom_message'] as String?,
        permissions: (map['permissions'] as List?)
                ?.map((p) => Permission.values.firstWhere(
                      (e) => e.name == p,
                      orElse: () => Permission.view,
                    ))
                .toList() ??
            [],
      );

  final String id;
  final String workspaceId;
  final String invitedBy;
  final String invitedEmail;
  final DateTime createdAt;
  final UserRole role;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final String? customMessage;
  final List<Permission> permissions;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isAccepted => acceptedAt != null;
  bool get isDeclined => declinedAt != null;
  bool get isPending => !isAccepted && !isDeclined && !isExpired;

  Map<String, dynamic> toMap() => {
        'id': id,
        'workspace_id': workspaceId,
        'invited_by': invitedBy,
        'invited_email': invitedEmail,
        'created_at': createdAt.millisecondsSinceEpoch,
        'role': role.name,
        'expires_at': expiresAt?.millisecondsSinceEpoch,
        'accepted_at': acceptedAt?.millisecondsSinceEpoch,
        'declined_at': declinedAt?.millisecondsSinceEpoch,
        'custom_message': customMessage,
        'permissions': permissions.map((p) => p.name).toList(),
      };
}

/// Collaboration session
@immutable
class CollaborationSession {
  const CollaborationSession({
    required this.id,
    required this.workspaceId,
    required this.sessionId,
    required this.mode,
    required this.startedAt,
    this.endedAt,
    this.activeUsers = const [],
    this.metadata = const {},
  });

  final String id;
  final String workspaceId;
  final String sessionId;
  final CollaborationMode mode;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<CollaborationUser> activeUsers;
  final Map<String, dynamic> metadata;

  bool get isActive => endedAt == null;
}
