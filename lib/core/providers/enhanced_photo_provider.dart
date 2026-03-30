import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/providers/photo_provider.dart';
import 'package:obsession_tracker/core/services/photo_backup_service.dart';
import 'package:obsession_tracker/core/services/photo_compression_service.dart';
import 'package:obsession_tracker/core/services/photo_export_service.dart';
import 'package:obsession_tracker/core/services/photo_metadata_editor_service.dart';
import 'package:obsession_tracker/core/services/photo_organization_service.dart';
import 'package:obsession_tracker/core/services/photo_sharing_service.dart';

/// Enhanced photo state with additional features
@immutable
class EnhancedPhotoState extends PhotoState {
  const EnhancedPhotoState({
    // Base photo state properties
    super.photos,
    super.filteredPhotos,
    super.photoMetadata,
    super.isLoading,
    super.isLoadingMore,
    super.error,
    super.selectedPhoto,
    super.currentFilter,
    super.currentSort,
    super.searchQuery,
    super.hasMore,
    super.currentPage,
    super.thumbnailCache,
    super.selectedPhotos,
    super.isSelectionMode,
    super.batchOperation,
    super.deletedPhotos,
    super.isDeleting,
    super.deleteProgress,

    // Enhanced features
    this.albums = const <PhotoAlbum>[],
    this.categories = const <PhotoCategory>[],
    this.tags = const <PhotoTag>[],
    this.currentAlbum,
    this.organizationStats,
    this.backupConfig,
    this.lastBackupDate,
    this.isBackingUp = false,
    this.backupProgress = 0.0,
    this.isCompressing = false,
    this.compressionProgress = 0.0,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.isSharing = false,
    this.sharingProgress = 0.0,
    this.privacyAnalysis,
  });

  // Organization features
  final List<PhotoAlbum> albums;
  final List<PhotoCategory> categories;
  final List<PhotoTag> tags;
  final PhotoAlbum? currentAlbum;
  final OrganizationStats? organizationStats;

  // Backup features
  final BackupConfig? backupConfig;
  final DateTime? lastBackupDate;
  final bool isBackingUp;
  final double backupProgress;

  // Compression features
  final bool isCompressing;
  final double compressionProgress;

  // Export features
  final bool isExporting;
  final double exportProgress;

  // Sharing features
  final bool isSharing;
  final double sharingProgress;
  final PrivacyAnalysis? privacyAnalysis;

  @override
  EnhancedPhotoState copyWith({
    // Base properties
    List<PhotoWaypoint>? photos,
    List<PhotoWaypoint>? filteredPhotos,
    Map<String, List<PhotoMetadata>>? photoMetadata,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    PhotoWaypoint? selectedPhoto,
    PhotoFilter? currentFilter,
    PhotoSort? currentSort,
    String? searchQuery,
    bool? hasMore,
    int? currentPage,
    Map<String, Uint8List>? thumbnailCache,
    Set<String>? selectedPhotos,
    bool? isSelectionMode,
    BatchOperationProgress? batchOperation,
    List<DeletedPhoto>? deletedPhotos,
    bool? isDeleting,
    double? deleteProgress,

    // Enhanced properties
    List<PhotoAlbum>? albums,
    List<PhotoCategory>? categories,
    List<PhotoTag>? tags,
    PhotoAlbum? currentAlbum,
    OrganizationStats? organizationStats,
    BackupConfig? backupConfig,
    DateTime? lastBackupDate,
    bool? isBackingUp,
    double? backupProgress,
    bool? isCompressing,
    double? compressionProgress,
    bool? isExporting,
    double? exportProgress,
    bool? isSharing,
    double? sharingProgress,
    PrivacyAnalysis? privacyAnalysis,

    // Clear flags
    bool clearError = false,
    bool clearSelectedPhoto = false,
    bool clearBatchOperation = false,
    bool clearSelectedPhotos = false,
    bool clearCurrentAlbum = false,
    bool clearPrivacyAnalysis = false,
  }) =>
      EnhancedPhotoState(
        // Base properties
        photos: photos ?? this.photos,
        filteredPhotos: filteredPhotos ?? this.filteredPhotos,
        photoMetadata: photoMetadata ?? this.photoMetadata,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        selectedPhoto:
            clearSelectedPhoto ? null : (selectedPhoto ?? this.selectedPhoto),
        currentFilter: currentFilter ?? this.currentFilter,
        currentSort: currentSort ?? this.currentSort,
        searchQuery: searchQuery ?? this.searchQuery,
        hasMore: hasMore ?? this.hasMore,
        currentPage: currentPage ?? this.currentPage,
        thumbnailCache: thumbnailCache ?? this.thumbnailCache,
        selectedPhotos: clearSelectedPhotos
            ? const <String>{}
            : (selectedPhotos ?? this.selectedPhotos),
        isSelectionMode: isSelectionMode ?? this.isSelectionMode,
        batchOperation: clearBatchOperation
            ? null
            : (batchOperation ?? this.batchOperation),
        deletedPhotos: deletedPhotos ?? this.deletedPhotos,
        isDeleting: isDeleting ?? this.isDeleting,
        deleteProgress: deleteProgress ?? this.deleteProgress,

        // Enhanced properties
        albums: albums ?? this.albums,
        categories: categories ?? this.categories,
        tags: tags ?? this.tags,
        currentAlbum:
            clearCurrentAlbum ? null : (currentAlbum ?? this.currentAlbum),
        organizationStats: organizationStats ?? this.organizationStats,
        backupConfig: backupConfig ?? this.backupConfig,
        lastBackupDate: lastBackupDate ?? this.lastBackupDate,
        isBackingUp: isBackingUp ?? this.isBackingUp,
        backupProgress: backupProgress ?? this.backupProgress,
        isCompressing: isCompressing ?? this.isCompressing,
        compressionProgress: compressionProgress ?? this.compressionProgress,
        isExporting: isExporting ?? this.isExporting,
        exportProgress: exportProgress ?? this.exportProgress,
        isSharing: isSharing ?? this.isSharing,
        sharingProgress: sharingProgress ?? this.sharingProgress,
        privacyAnalysis: clearPrivacyAnalysis
            ? null
            : (privacyAnalysis ?? this.privacyAnalysis),
      );
}

/// Enhanced photo notifier with all photo management features
class EnhancedPhotoNotifier extends Notifier<EnhancedPhotoState> {
  // Use nullable backing fields with lazy initialization getters to avoid
  // LateInitializationError when build() is called multiple times
  PhotoExportService? __exportService;
  PhotoCompressionService? __compressionService;
  PhotoMetadataEditorService? __metadataEditorService;
  PhotoBackupService? __backupService;
  PhotoSharingService? __sharingService;
  PhotoOrganizationService? __organizationService;

  // Getters for lazy initialization - these are used throughout the class
  PhotoExportService get _exportService => __exportService ??= PhotoExportService();
  PhotoCompressionService get _compressionService => __compressionService ??= PhotoCompressionService();
  PhotoMetadataEditorService get _metadataEditorService => __metadataEditorService ??= PhotoMetadataEditorService();
  PhotoBackupService get _backupService => __backupService ??= PhotoBackupService();
  PhotoSharingService get _sharingService => __sharingService ??= PhotoSharingService();
  PhotoOrganizationService get _organizationService => __organizationService ??= PhotoOrganizationService();

  @override
  EnhancedPhotoState build() {
    ref.onDispose(() {
      // Dispose backing fields directly (not getters) to avoid creating instances
      __exportService?.dispose();
      __compressionService?.dispose();
      __metadataEditorService?.dispose();
      __backupService?.dispose();
      __sharingService?.dispose();
      __organizationService?.dispose();
    });

    return const EnhancedPhotoState();
  }

  @override
  EnhancedPhotoState get state => super.state;

  @override
  set state(PhotoState value) {
    if (value is EnhancedPhotoState) {
      super.state = value;
    } else {
      // Convert base PhotoState to EnhancedPhotoState
      super.state = EnhancedPhotoState(
        photos: value.photos,
        filteredPhotos: value.filteredPhotos,
        photoMetadata: value.photoMetadata,
        isLoading: value.isLoading,
        isLoadingMore: value.isLoadingMore,
        error: value.error,
        selectedPhoto: value.selectedPhoto,
        currentFilter: value.currentFilter,
        currentSort: value.currentSort,
        searchQuery: value.searchQuery,
        hasMore: value.hasMore,
        currentPage: value.currentPage,
        thumbnailCache: value.thumbnailCache,
        selectedPhotos: value.selectedPhotos,
        isSelectionMode: value.isSelectionMode,
        batchOperation: value.batchOperation,
        deletedPhotos: value.deletedPhotos,
        isDeleting: value.isDeleting,
        deleteProgress: value.deleteProgress,
      );
    }
  }

  /// Initialize enhanced photo services
  Future<void> initializeEnhancedServices() async {
    try {
      await _metadataEditorService.initialize();
      await _backupService.initialize();
      await _organizationService.initialize();

      // Load initial data
      await _loadOrganizationData();
      await _loadBackupConfig();

      debugPrint('Enhanced photo services initialized');
    } catch (e) {
      debugPrint('Error initializing enhanced photo services: $e');
    }
  }

  /// Load organization data (albums, categories, tags)
  Future<void> _loadOrganizationData() async {
    try {
      final List<PhotoAlbum> albums = await _organizationService.getAlbums();
      final List<PhotoCategory> categories =
          await _organizationService.getCategories();
      final List<PhotoTag> tags = await _organizationService.getTags();
      final OrganizationStats stats =
          await _organizationService.getOrganizationStats();

      state = state.copyWith(
        albums: albums,
        categories: categories,
        tags: tags,
        organizationStats: stats,
      );
    } catch (e) {
      debugPrint('Error loading organization data: $e');
    }
  }

  /// Load backup configuration
  Future<void> _loadBackupConfig() async {
    try {
      final BackupConfig config = _backupService.config;
      final List<BackupInfo> backupHistory =
          await _backupService.getBackupHistory();

      final DateTime? lastBackup =
          backupHistory.isNotEmpty ? backupHistory.first.createdAt : null;

      state = state.copyWith(
        backupConfig: config,
        lastBackupDate: lastBackup,
      );
    } catch (e) {
      debugPrint('Error loading backup config: $e');
    }
  }

  // MARK: - Export Operations

  /// Export selected photos
  Future<bool> exportSelectedPhotos({
    required PhotoExportOptions options,
    ExportProgressCallback? onProgress,
  }) async {
    if (state.selectedPhotos.isEmpty) {
      state = state.copyWith(error: 'No photos selected for export');
      return false;
    }

    state = state.copyWith(
        isExporting: true, exportProgress: 0.0, clearError: true);

    try {
      final List<PhotoWaypoint> photosToExport = state.photos
          .where((photo) => state.selectedPhotos.contains(photo.id))
          .toList();

      final PhotoExportResult result = await _exportService.exportPhotos(
        photos: photosToExport,
        options: options,
        onProgress: (completed, total, currentFile) {
          state = state.copyWith(exportProgress: completed / total);
          onProgress?.call(completed, total, currentFile);
        },
      );

      if (result.success) {
        state = state.copyWith(
          isExporting: false,
          exportProgress: 1.0,
          clearSelectedPhotos: true,
          isSelectionMode: false,
        );

        // Share exported files if requested
        if (options.format == PhotoExportFormat.zip) {
          await _exportService.shareExportedPhotos(result);
        }

        return true;
      } else {
        state = state.copyWith(
          isExporting: false,
          exportProgress: 0.0,
          error: result.error ?? 'Export failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        exportProgress: 0.0,
        error: 'Export failed: $e',
      );
      return false;
    }
  }

  // MARK: - Compression Operations

  /// Compress selected photos
  Future<bool> compressSelectedPhotos({
    required CompressionSettings settings,
    CompressionProgressCallback? onProgress,
  }) async {
    if (state.selectedPhotos.isEmpty) {
      state = state.copyWith(error: 'No photos selected for compression');
      return false;
    }

    state = state.copyWith(
        isCompressing: true, compressionProgress: 0.0, clearError: true);

    try {
      final List<PhotoWaypoint> photosToCompress = state.photos
          .where((photo) => state.selectedPhotos.contains(photo.id))
          .toList();

      // Assume we have a session ID from the first photo
      final String sessionId = photosToCompress.isNotEmpty
          ? photosToCompress
              .first.waypointId // This would need proper session ID resolution
          : '';

      final CompressionResult result = await _compressionService.compressPhotos(
        photos: photosToCompress,
        sessionId: sessionId,
        settings: settings,
        onProgress: (completed, total, currentFile) {
          state = state.copyWith(compressionProgress: completed / total);
          onProgress?.call(completed, total, currentFile);
        },
      );

      if (result.success) {
        state = state.copyWith(
          isCompressing: false,
          compressionProgress: 1.0,
          clearSelectedPhotos: true,
          isSelectionMode: false,
        );

        // Refresh photos to show updated file sizes
        // This would require reloading from the database
        return true;
      } else {
        state = state.copyWith(
          isCompressing: false,
          compressionProgress: 0.0,
          error: result.error ?? 'Compression failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isCompressing: false,
        compressionProgress: 0.0,
        error: 'Compression failed: $e',
      );
      return false;
    }
  }

  // MARK: - Backup Operations

  /// Create backup for current session
  Future<bool> createBackup({
    required String sessionId,
    String? description,
    BackupConfig? customConfig,
    BackupProgressCallback? onProgress,
  }) async {
    state = state.copyWith(
        isBackingUp: true, backupProgress: 0.0, clearError: true);

    try {
      final BackupResult result = await _backupService.createBackup(
        sessionId: sessionId,
        customConfig: customConfig,
        description: description,
        onProgress: (completed, total, currentFile) {
          state = state.copyWith(backupProgress: completed / total);
          onProgress?.call(completed, total, currentFile);
        },
      );

      if (result.success) {
        state = state.copyWith(
          isBackingUp: false,
          backupProgress: 1.0,
          lastBackupDate: DateTime.now(),
        );
        return true;
      } else {
        state = state.copyWith(
          isBackingUp: false,
          backupProgress: 0.0,
          error: result.error ?? 'Backup failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isBackingUp: false,
        backupProgress: 0.0,
        error: 'Backup failed: $e',
      );
      return false;
    }
  }

  /// Update backup configuration
  Future<bool> updateBackupConfig(BackupConfig config) async {
    try {
      final bool success = await _backupService.saveConfig(config);
      if (success) {
        state = state.copyWith(backupConfig: config);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update backup config: $e');
      return false;
    }
  }

  // MARK: - Sharing Operations

  /// Share selected photos with privacy controls
  Future<bool> shareSelectedPhotos({
    required SharingOptions options,
    SharingProgressCallback? onProgress,
  }) async {
    if (state.selectedPhotos.isEmpty) {
      state = state.copyWith(error: 'No photos selected for sharing');
      return false;
    }

    state =
        state.copyWith(isSharing: true, sharingProgress: 0.0, clearError: true);

    try {
      final List<PhotoWaypoint> photosToShare = state.photos
          .where((photo) => state.selectedPhotos.contains(photo.id))
          .toList();

      final SharingResult result = await _sharingService.sharePhotos(
        photos: photosToShare,
        options: options,
        onProgress: (completed, total, currentFile) {
          state = state.copyWith(sharingProgress: completed / total);
          onProgress?.call(completed, total, currentFile);
        },
      );

      if (result.success) {
        state = state.copyWith(
          isSharing: false,
          sharingProgress: 1.0,
          clearSelectedPhotos: true,
          isSelectionMode: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isSharing: false,
          sharingProgress: 0.0,
          error: result.error ?? 'Sharing failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSharing: false,
        sharingProgress: 0.0,
        error: 'Sharing failed: $e',
      );
      return false;
    }
  }

  /// Analyze privacy for selected photo
  Future<void> analyzePhotoPrivacy(PhotoWaypoint photo) async {
    try {
      final PrivacyAnalysis analysis =
          await _sharingService.analyzePhotoPrivacy(photo);
      state = state.copyWith(privacyAnalysis: analysis);
    } catch (e) {
      state = state.copyWith(error: 'Privacy analysis failed: $e');
    }
  }

  // MARK: - Organization Operations

  /// Create new album
  Future<PhotoAlbum?> createAlbum({
    required String name,
    required String description,
    String? color,
  }) async {
    try {
      final PhotoAlbum? album = await _organizationService.createAlbum(
        name: name,
        description: description,
        color: color,
      );

      if (album != null) {
        final List<PhotoAlbum> updatedAlbums = [...state.albums, album];
        state = state.copyWith(albums: updatedAlbums);
      }

      return album;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create album: $e');
      return null;
    }
  }

  /// Add selected photos to album
  Future<bool> addSelectedPhotosToAlbum(String albumId) async {
    if (state.selectedPhotos.isEmpty) {
      state = state.copyWith(error: 'No photos selected');
      return false;
    }

    try {
      final int organizedCount =
          await _organizationService.bulkOrganizeIntoAlbums(
        photoIds: state.selectedPhotos.toList(),
        albumId: albumId,
      );

      if (organizedCount > 0) {
        state = state.copyWith(
          clearSelectedPhotos: true,
          isSelectionMode: false,
        );

        // Refresh organization stats
        await _loadOrganizationData();
        return true;
      }

      return false;
    } catch (e) {
      state = state.copyWith(error: 'Failed to add photos to album: $e');
      return false;
    }
  }

  /// Load photos for specific album
  Future<void> loadAlbumPhotos(String albumId) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);

      final List<PhotoWaypoint> albumPhotos =
          await _organizationService.getPhotosInAlbum(albumId);

      final PhotoAlbum? album = await _organizationService.getAlbum(albumId);

      state = state.copyWith(
        photos: albumPhotos,
        filteredPhotos: albumPhotos,
        currentAlbum: album,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load album photos: $e',
      );
    }
  }

  /// Auto-organize photos
  Future<int> autoOrganizePhotos() async {
    try {
      final int organizedCount =
          await _organizationService.autoOrganizePhotos();

      // Refresh organization data
      await _loadOrganizationData();

      return organizedCount;
    } catch (e) {
      state = state.copyWith(error: 'Auto-organization failed: $e');
      return 0;
    }
  }

  // MARK: - Metadata Operations

  /// Edit metadata for selected photos
  Future<bool> editSelectedPhotosMetadata(Map<String, String> metadata) async {
    if (state.selectedPhotos.isEmpty) {
      state = state.copyWith(error: 'No photos selected');
      return false;
    }

    try {
      for (final String photoId in state.selectedPhotos) {
        await _metadataEditorService.editPhotoMetadata(
          photoId: photoId,
          metadata: metadata,
        );
      }

      state = state.copyWith(
        clearSelectedPhotos: true,
        isSelectionMode: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to edit metadata: $e');
      return false;
    }
  }

  /// Apply metadata template to selected photos
  Future<bool> applyTemplateToSelectedPhotos({
    required String templateId,
    Map<String, String>? fieldValues,
  }) async {
    if (state.selectedPhotos.isEmpty) {
      state = state.copyWith(error: 'No photos selected');
      return false;
    }

    try {
      for (final String photoId in state.selectedPhotos) {
        await _metadataEditorService.applyTemplate(
          photoId: photoId,
          templateId: templateId,
          fieldValues: fieldValues,
        );
      }

      state = state.copyWith(
        clearSelectedPhotos: true,
        isSelectionMode: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to apply template: $e');
      return false;
    }
  }

  /// Clear current album view
  void clearCurrentAlbum() {
    state = state.copyWith(clearCurrentAlbum: true);
  }

  /// Clear privacy analysis
  void clearPrivacyAnalysis() {
    state = state.copyWith(clearPrivacyAnalysis: true);
  }

  /// Refresh all organization data
  Future<void> refreshOrganizationData() async {
    await _loadOrganizationData();
  }

}

/// Enhanced photo provider with all services
final NotifierProvider<EnhancedPhotoNotifier, EnhancedPhotoState>
    enhancedPhotoProvider =
    NotifierProvider<EnhancedPhotoNotifier, EnhancedPhotoState>(
        EnhancedPhotoNotifier.new);

/// Provider for export service
final Provider<PhotoExportService> photoExportServiceProvider =
    Provider<PhotoExportService>((ref) => PhotoExportService());

/// Provider for compression service
final Provider<PhotoCompressionService> photoCompressionServiceProvider =
    Provider<PhotoCompressionService>((ref) => PhotoCompressionService());

/// Provider for metadata editor service
final Provider<PhotoMetadataEditorService> photoMetadataEditorServiceProvider =
    Provider<PhotoMetadataEditorService>((ref) => PhotoMetadataEditorService());

/// Provider for backup service
final Provider<PhotoBackupService> photoBackupServiceProvider =
    Provider<PhotoBackupService>((ref) => PhotoBackupService());

/// Provider for sharing service
final Provider<PhotoSharingService> photoSharingServiceProvider =
    Provider<PhotoSharingService>((ref) => PhotoSharingService());

/// Provider for organization service
final Provider<PhotoOrganizationService> photoOrganizationServiceProvider =
    Provider<PhotoOrganizationService>((ref) => PhotoOrganizationService());
