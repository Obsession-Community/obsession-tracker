import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/services/hunt_path_resolver.dart';

/// Type of attachment stored with a custom marker
enum MarkerAttachmentType {
  image, // Photos, screenshots, map images
  pdf, // Reference documents, clues
  document, // Text, spreadsheets, GPX, KML, etc.
  note, // Inline text/markdown (stored in DB)
  link, // External URLs
  audio, // Voice memos, audio recordings
}

/// Extension to provide display properties for attachment types
extension MarkerAttachmentTypeExtension on MarkerAttachmentType {
  /// Display name for the type
  String get displayName {
    switch (this) {
      case MarkerAttachmentType.image:
        return 'Image';
      case MarkerAttachmentType.pdf:
        return 'PDF';
      case MarkerAttachmentType.document:
        return 'Document';
      case MarkerAttachmentType.note:
        return 'Note';
      case MarkerAttachmentType.link:
        return 'Link';
      case MarkerAttachmentType.audio:
        return 'Voice Memo';
    }
  }

  /// Emoji icon for display
  String get icon {
    switch (this) {
      case MarkerAttachmentType.image:
        return '\u{1F5BC}'; // Framed picture
      case MarkerAttachmentType.pdf:
        return '\u{1F4C4}'; // Page facing up
      case MarkerAttachmentType.document:
        return '\u{1F4CB}'; // Clipboard
      case MarkerAttachmentType.note:
        return '\u{1F4DD}'; // Memo
      case MarkerAttachmentType.link:
        return '\u{1F517}'; // Link
      case MarkerAttachmentType.audio:
        return '\u{1F3A4}'; // Microphone
    }
  }

  /// Whether this type stores content in the file system
  bool get hasFile {
    switch (this) {
      case MarkerAttachmentType.image:
      case MarkerAttachmentType.pdf:
      case MarkerAttachmentType.document:
      case MarkerAttachmentType.audio:
        return true;
      case MarkerAttachmentType.note:
      case MarkerAttachmentType.link:
        return false;
    }
  }
}

/// Supported document file extensions for marker attachments
class MarkerAttachmentExtensions {
  MarkerAttachmentExtensions._();

  /// Text-based files
  static const List<String> text = ['txt', 'rtf', 'md', 'markdown'];

  /// Microsoft Office files
  static const List<String> office = [
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx'
  ];

  /// Spreadsheet files
  static const List<String> spreadsheets = ['csv', 'tsv'];

  /// OpenDocument files
  static const List<String> openDocument = ['odt', 'ods', 'odp'];

  /// Apple iWork files
  static const List<String> apple = ['pages', 'numbers', 'key'];

  /// Code and config files
  static const List<String> code = ['json', 'xml', 'html', 'htm'];

  /// Geographic files
  static const List<String> geo = ['gpx', 'kml', 'kmz'];

  /// Image files
  static const List<String> images = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'heif'
  ];

  /// PDF files
  static const List<String> pdfs = ['pdf'];

  /// Audio files
  static const List<String> audio = ['m4a', 'aac', 'mp3', 'wav', 'caf'];

  /// All supported document extensions
  static List<String> get allDocuments => [
        ...text,
        ...office,
        ...spreadsheets,
        ...openDocument,
        ...apple,
        ...code,
        ...geo,
      ];

  /// Get the attachment type for a file extension
  static MarkerAttachmentType? typeForExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    if (images.contains(ext)) return MarkerAttachmentType.image;
    if (pdfs.contains(ext)) return MarkerAttachmentType.pdf;
    if (audio.contains(ext)) return MarkerAttachmentType.audio;
    if (allDocuments.contains(ext)) return MarkerAttachmentType.document;
    return null;
  }
}

/// An attachment (document, image, note, or link) stored with a custom marker
///
/// Follows the same pattern as HuntDocument for consistency.
@immutable
class MarkerAttachment {
  const MarkerAttachment({
    required this.id,
    required this.markerId,
    required this.name,
    required this.type,
    this.filePath,
    this.url,
    this.content,
    this.thumbnailPath,
    required this.createdAt,
    this.updatedAt,
    this.sortOrder = 0,
    this.fileSize,
    this.userRotation,
    this.width,
    this.height,
    this.devicePitch,
    this.deviceRoll,
    this.deviceYaw,
    this.photoOrientation,
    this.cameraTiltAngle,
    this.source,
  });

  /// Unique identifier (UUID)
  final String id;

  /// Parent custom marker ID
  final String markerId;

  /// Display name for the attachment
  final String name;

  /// Type of attachment
  final MarkerAttachmentType type;

  /// Local file path for images, PDFs, documents (null for notes/links)
  final String? filePath;

  /// External URL (for links only)
  final String? url;

  /// Inline text content (for notes only)
  final String? content;

  /// Thumbnail path for images and PDFs
  final String? thumbnailPath;

  /// When the attachment was created
  final DateTime createdAt;

  /// When the attachment was last updated
  final DateTime? updatedAt;

  /// Sort order for display
  final int sortOrder;

  /// File size in bytes (for file-based attachments)
  final int? fileSize;

  /// User-applied rotation in quarter turns (0=none, 1=90° CW, 2=180°, 3=270° CW)
  ///
  /// Used to correct image orientation when the camera didn't capture it properly
  /// or when the user wants to manually rotate the image for display.
  final int? userRotation;

  /// Image width in pixels (for image attachments)
  final int? width;

  /// Image height in pixels (for image attachments)
  final int? height;

  /// Device pitch when photo was taken (-90° down to +90° up)
  final double? devicePitch;

  /// Device roll when photo was taken (-180° left to +180° right)
  final double? deviceRoll;

  /// Device yaw/compass heading when photo was taken (0-360°)
  final double? deviceYaw;

  /// Photo orientation string ('portrait', 'landscape', 'landscape_left', 'landscape_right')
  final String? photoOrientation;

  /// Combined camera tilt angle measurement
  final double? cameraTiltAngle;

  /// Photo source ('phone_camera', 'meta_glasses')
  final String? source;

  /// Check if this attachment has a thumbnail
  bool get hasThumbnail => thumbnailPath != null && thumbnailPath!.isNotEmpty;

  /// Get file size formatted as human-readable string
  String get fileSizeFormatted {
    if (fileSize == null) return '';
    final kb = fileSize! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  /// Create from database map
  ///
  /// Resolves relative file paths to absolute paths using [HuntPathResolver].
  factory MarkerAttachment.fromDatabaseMap(Map<String, dynamic> map) {
    return MarkerAttachment(
      id: map['id'] as String,
      markerId: map['marker_id'] as String,
      name: map['name'] as String,
      type: MarkerAttachmentType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MarkerAttachmentType.note,
      ),
      // Resolve relative paths to absolute for filesystem access
      filePath: HuntPathResolver.resolveFromDatabase(
        map['file_path'] as String?,
      ),
      url: map['url'] as String?,
      content: map['content'] as String?,
      thumbnailPath: HuntPathResolver.resolveFromDatabase(
        map['thumbnail_path'] as String?,
      ),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
      sortOrder: map['sort_order'] as int? ?? 0,
      fileSize: map['file_size'] as int?,
      userRotation: map['user_rotation'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      devicePitch: map['device_pitch'] as double?,
      deviceRoll: map['device_roll'] as double?,
      deviceYaw: map['device_yaw'] as double?,
      photoOrientation: map['photo_orientation'] as String?,
      cameraTiltAngle: map['camera_tilt_angle'] as double?,
      source: map['source'] as String?,
    );
  }

  /// Convert to database map
  ///
  /// Converts absolute file paths to relative paths for portability using [HuntPathResolver].
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'marker_id': markerId,
      'name': name,
      'type': type.name,
      // Store relative paths for portability across iOS container changes
      'file_path': HuntPathResolver.prepareForDatabase(filePath),
      'url': url,
      'content': content,
      'thumbnail_path': HuntPathResolver.prepareForDatabase(thumbnailPath),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'sort_order': sortOrder,
      'file_size': fileSize,
      'user_rotation': userRotation,
      'width': width,
      'height': height,
      'device_pitch': devicePitch,
      'device_roll': deviceRoll,
      'device_yaw': deviceYaw,
      'photo_orientation': photoOrientation,
      'camera_tilt_angle': cameraTiltAngle,
      'source': source,
    };
  }

  /// Create a copy with updated values
  MarkerAttachment copyWith({
    String? id,
    String? markerId,
    String? name,
    MarkerAttachmentType? type,
    String? filePath,
    String? url,
    String? content,
    String? thumbnailPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    int? fileSize,
    int? userRotation,
    int? width,
    int? height,
    double? devicePitch,
    double? deviceRoll,
    double? deviceYaw,
    String? photoOrientation,
    double? cameraTiltAngle,
    String? source,
  }) {
    return MarkerAttachment(
      id: id ?? this.id,
      markerId: markerId ?? this.markerId,
      name: name ?? this.name,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      url: url ?? this.url,
      content: content ?? this.content,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      fileSize: fileSize ?? this.fileSize,
      userRotation: userRotation ?? this.userRotation,
      width: width ?? this.width,
      height: height ?? this.height,
      devicePitch: devicePitch ?? this.devicePitch,
      deviceRoll: deviceRoll ?? this.deviceRoll,
      deviceYaw: deviceYaw ?? this.deviceYaw,
      photoOrientation: photoOrientation ?? this.photoOrientation,
      cameraTiltAngle: cameraTiltAngle ?? this.cameraTiltAngle,
      source: source ?? this.source,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkerAttachment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MarkerAttachment{id: $id, name: $name, type: ${type.displayName}, markerId: $markerId}';
}
