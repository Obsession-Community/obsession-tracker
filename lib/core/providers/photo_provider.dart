import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';
import 'package:obsession_tracker/core/services/photo_capture_service.dart';
import 'package:obsession_tracker/core/services/photo_storage_service.dart';

/// Provider for the photo capture service
final Provider<PhotoCaptureService> photoCaptureServiceProvider =
    Provider<PhotoCaptureService>((Ref ref) => PhotoCaptureService());

/// Provider for the photo storage service
final Provider<PhotoStorageService> photoStorageServiceProvider =
    Provider<PhotoStorageService>((Ref ref) => PhotoStorageService());

/// Filter options for photo gallery
enum PhotoFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  favorites,
}

/// Sort options for photo gallery
enum PhotoSort {
  newest,
  oldest,
  name,
  size,
}

/// Batch operation types
enum BatchOperationType {
  delete,
  favorite,
  unfavorite,
  addTag,
  removeTag,
}

/// Batch operation progress
@immutable
class BatchOperationProgress {
  const BatchOperationProgress({
    required this.type,
    required this.total,
    required this.completed,
    required this.failed,
    this.currentItem,
    this.error,
  });

  final BatchOperationType type;
  final int total;
  final int completed;
  final int failed;
  final String? currentItem;
  final String? error;

  bool get isCompleted => completed + failed >= total;
  double get progress => total > 0 ? (completed + failed) / total : 0.0;
}

/// Deleted photo for undo functionality
@immutable
class DeletedPhoto {
  const DeletedPhoto({
    required this.photo,
    required this.metadata,
    required this.deletedAt,
    required this.sessionId,
  });

  final PhotoWaypoint photo;
  final List<PhotoMetadata> metadata;
  final DateTime deletedAt;
  final String sessionId;
}

/// State class for photo gallery management
@immutable
class PhotoState {
  const PhotoState({
    this.photos = const <PhotoWaypoint>[],
    this.filteredPhotos = const <PhotoWaypoint>[],
    this.photoMetadata = const <String, List<PhotoMetadata>>{},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedPhoto,
    this.currentFilter = PhotoFilter.all,
    this.currentSort = PhotoSort.newest,
    this.searchQuery = '',
    this.hasMore = true,
    this.currentPage = 0,
    this.thumbnailCache = const <String, Uint8List>{},
    this.selectedPhotos = const <String>{},
    this.isSelectionMode = false,
    this.batchOperation,
    this.deletedPhotos = const <DeletedPhoto>[],
    this.isDeleting = false,
    this.deleteProgress = 0.0,
  });

  final List<PhotoWaypoint> photos;
  final List<PhotoWaypoint> filteredPhotos;
  final Map<String, List<PhotoMetadata>> photoMetadata;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final PhotoWaypoint? selectedPhoto;
  final PhotoFilter currentFilter;
  final PhotoSort currentSort;
  final String searchQuery;
  final bool hasMore;
  final int currentPage;
  final Map<String, Uint8List> thumbnailCache;

  // Enhanced selection and batch operations
  final Set<String> selectedPhotos;
  final bool isSelectionMode;
  final BatchOperationProgress? batchOperation;
  final List<DeletedPhoto> deletedPhotos;
  final bool isDeleting;
  final double deleteProgress;

  PhotoState copyWith({
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
    bool clearError = false,
    bool clearSelectedPhoto = false,
    bool clearBatchOperation = false,
    bool clearSelectedPhotos = false,
  }) =>
      PhotoState(
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
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoState &&
          runtimeType == other.runtimeType &&
          listEquals(photos, other.photos) &&
          listEquals(filteredPhotos, other.filteredPhotos) &&
          mapEquals(photoMetadata, other.photoMetadata) &&
          isLoading == other.isLoading &&
          isLoadingMore == other.isLoadingMore &&
          error == other.error &&
          selectedPhoto == other.selectedPhoto &&
          currentFilter == other.currentFilter &&
          currentSort == other.currentSort &&
          searchQuery == other.searchQuery &&
          hasMore == other.hasMore &&
          currentPage == other.currentPage;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(photos),
        Object.hashAll(filteredPhotos),
        photoMetadata,
        isLoading,
        isLoadingMore,
        error,
        selectedPhoto,
        currentFilter,
        currentSort,
        searchQuery,
        hasMore,
        currentPage,
      );
}

/// Notifier for managing photo state
class PhotoNotifier extends Notifier<PhotoState> {
  // Use getters that read from providers instead of late final fields
  // This avoids LateInitializationError when build() is called multiple times
  PhotoCaptureService get _photoCaptureService =>
      ref.read(photoCaptureServiceProvider);
  PhotoStorageService get _photoStorageService =>
      ref.read(photoStorageServiceProvider);

  @override
  PhotoState build() {
    return const PhotoState();
  }

  static const int _pageSize = 20;

  /// Load photos for a session with pagination
  Future<void> loadPhotosForSession(String sessionId,
      {bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(
        photos: <PhotoWaypoint>[],
        filteredPhotos: <PhotoWaypoint>[],
        currentPage: 0,
        hasMore: true,
        clearError: true,
      );
    }

    if (state.isLoading || (!state.hasMore && !refresh)) return;

    state = state.copyWith(
      isLoading: refresh || state.photos.isEmpty,
      isLoadingMore: !refresh && state.photos.isNotEmpty,
      clearError: true,
    );

    try {
      final List<PhotoWaypoint> newPhotos =
          await _photoCaptureService.getPhotoWaypointsForSession(sessionId,
              offset: state.currentPage * _pageSize);

      final List<PhotoWaypoint> allPhotos =
          refresh ? newPhotos : [...state.photos, ...newPhotos];

      // Load metadata for new photos
      final Map<String, List<PhotoMetadata>> updatedMetadata =
          Map<String, List<PhotoMetadata>>.from(state.photoMetadata);

      for (final PhotoWaypoint photo in newPhotos) {
        if (!updatedMetadata.containsKey(photo.id)) {
          updatedMetadata[photo.id] =
              await _photoCaptureService.getPhotoMetadata(photo.id);
        }
      }

      state = state.copyWith(
        photos: allPhotos,
        photoMetadata: updatedMetadata,
        isLoading: false,
        isLoadingMore: false,
        hasMore: newPhotos.length == _pageSize,
        currentPage: state.currentPage + 1,
      );

      // Apply current filters and sorting
      _applyFiltersAndSort();
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Failed to load photos: $e',
      );
    }
  }

  /// Load more photos (pagination)
  Future<void> loadMorePhotos(String sessionId) async {
    if (state.isLoadingMore || !state.hasMore) return;
    await loadPhotosForSession(sessionId);
  }

  /// Refresh photos
  Future<void> refreshPhotos(String sessionId) async {
    await loadPhotosForSession(sessionId, refresh: true);
  }

  /// Apply filters and sorting to photos
  void _applyFiltersAndSort() {
    List<PhotoWaypoint> filtered = List<PhotoWaypoint>.from(state.photos);

    // Apply filter
    switch (state.currentFilter) {
      case PhotoFilter.all:
        break;
      case PhotoFilter.today:
        final DateTime today = DateTime.now();
        final DateTime startOfDay =
            DateTime(today.year, today.month, today.day);
        filtered = filtered
            .where((PhotoWaypoint photo) => photo.createdAt.isAfter(startOfDay))
            .toList();
        break;
      case PhotoFilter.thisWeek:
        final DateTime now = DateTime.now();
        final DateTime startOfWeek =
            now.subtract(Duration(days: now.weekday - 1));
        final DateTime startOfWeekDay =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        filtered = filtered
            .where((PhotoWaypoint photo) =>
                photo.createdAt.isAfter(startOfWeekDay))
            .toList();
        break;
      case PhotoFilter.thisMonth:
        final DateTime now = DateTime.now();
        final DateTime startOfMonth = DateTime(now.year, now.month);
        filtered = filtered
            .where(
                (PhotoWaypoint photo) => photo.createdAt.isAfter(startOfMonth))
            .toList();
        break;
      case PhotoFilter.favorites:
        filtered = filtered.where((PhotoWaypoint photo) {
          final List<PhotoMetadata>? metadata = state.photoMetadata[photo.id];
          return metadata?.any((PhotoMetadata meta) =>
                  meta.key == CustomKeys.favorite && meta.typedValue == true) ??
              false;
        }).toList();
        break;
    }

    // Apply search query
    if (state.searchQuery.isNotEmpty) {
      final String query = state.searchQuery.toLowerCase();
      filtered = filtered.where((PhotoWaypoint photo) {
        final List<PhotoMetadata>? metadata = state.photoMetadata[photo.id];

        // Search in metadata
        final bool matchesMetadata = metadata?.any((PhotoMetadata meta) =>
                meta.key.toLowerCase().contains(query) ||
                (meta.value?.toLowerCase().contains(query) ?? false)) ??
            false;

        // Search in file path
        final bool matchesPath = photo.filePath.toLowerCase().contains(query);

        return matchesMetadata || matchesPath;
      }).toList();
    }

    // Apply sorting
    switch (state.currentSort) {
      case PhotoSort.newest:
        filtered.sort((PhotoWaypoint a, PhotoWaypoint b) =>
            b.createdAt.compareTo(a.createdAt));
        break;
      case PhotoSort.oldest:
        filtered.sort((PhotoWaypoint a, PhotoWaypoint b) =>
            a.createdAt.compareTo(b.createdAt));
        break;
      case PhotoSort.name:
        filtered.sort((PhotoWaypoint a, PhotoWaypoint b) =>
            a.filePath.compareTo(b.filePath));
        break;
      case PhotoSort.size:
        filtered.sort((PhotoWaypoint a, PhotoWaypoint b) =>
            b.fileSize.compareTo(a.fileSize));
        break;
    }

    state = state.copyWith(filteredPhotos: filtered);
  }

  /// Set filter
  void setFilter(PhotoFilter filter) {
    state = state.copyWith(currentFilter: filter);
    _applyFiltersAndSort();
  }

  /// Set sort order
  void setSort(PhotoSort sort) {
    state = state.copyWith(currentSort: sort);
    _applyFiltersAndSort();
  }

  /// Set search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFiltersAndSort();
  }

  /// Select a photo
  void selectPhoto(PhotoWaypoint? photo) {
    state = state.copyWith(selectedPhoto: photo);
  }

  /// Clear selected photo
  void clearSelectedPhoto() {
    state = state.copyWith(clearSelectedPhoto: true);
  }

  /// Delete a photo
  Future<bool> deletePhoto(PhotoWaypoint photo) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final bool success =
          await _photoCaptureService.deletePhotoWaypoint(photo);

      if (success) {
        // Remove from state
        final List<PhotoWaypoint> updatedPhotos =
            state.photos.where((PhotoWaypoint p) => p.id != photo.id).toList();

        final Map<String, List<PhotoMetadata>> updatedMetadata =
            Map<String, List<PhotoMetadata>>.from(state.photoMetadata);
        updatedMetadata.remove(photo.id);

        final Map<String, Uint8List> updatedCache =
            Map<String, Uint8List>.from(state.thumbnailCache);
        updatedCache.remove(photo.id);

        state = state.copyWith(
          photos: updatedPhotos,
          photoMetadata: updatedMetadata,
          thumbnailCache: updatedCache,
          isLoading: false,
          clearSelectedPhoto: state.selectedPhoto?.id == photo.id,
        );

        _applyFiltersAndSort();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to delete photo',
        );
      }

      return success;
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete photo: $e',
      );
      return false;
    }
  }

  /// Toggle favorite status of a photo
  Future<void> toggleFavorite(PhotoWaypoint photo) async {
    try {
      final List<PhotoMetadata>? metadata = state.photoMetadata[photo.id];
      final bool currentFavorite = metadata?.any((PhotoMetadata meta) =>
              meta.key == CustomKeys.favorite && meta.typedValue == true) ??
          false;

      // This would require implementing metadata update in PhotoCaptureService
      // For now, we'll update the local state
      final Map<String, List<PhotoMetadata>> updatedMetadata =
          Map<String, List<PhotoMetadata>>.from(state.photoMetadata);

      final List<PhotoMetadata> photoMeta = List<PhotoMetadata>.from(
          updatedMetadata[photo.id] ?? <PhotoMetadata>[]);

      // Remove existing favorite metadata
      photoMeta
          .removeWhere((PhotoMetadata meta) => meta.key == CustomKeys.favorite);

      // Add new favorite metadata
      photoMeta.add(PhotoMetadata.boolean(
        id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
        photoWaypointId: photo.id,
        key: CustomKeys.favorite,
        value: !currentFavorite,
      ));

      updatedMetadata[photo.id] = photoMeta;

      state = state.copyWith(photoMetadata: updatedMetadata);
      _applyFiltersAndSort();
    } on Exception catch (e) {
      state = state.copyWith(error: 'Failed to toggle favorite: $e');
    }
  }

  /// Get thumbnail for a photo
  Future<Uint8List?> getThumbnail(PhotoWaypoint photo) async {
    // Check cache first
    if (state.thumbnailCache.containsKey(photo.id)) {
      return state.thumbnailCache[photo.id];
    }

    try {
      // Load thumbnail from storage
      Uint8List? thumbnailData;

      if (photo.hasThumbnail && photo.thumbnailPath != null) {
        final bool exists =
            await _photoStorageService.photoExists(photo.thumbnailPath!);
        if (exists) {
          // Load existing thumbnail
          final File thumbnailFile = File(photo.thumbnailPath!);
          thumbnailData = await thumbnailFile.readAsBytes();
        }
      }

      // If no thumbnail exists, generate one
      if (thumbnailData == null) {
        // This would require session ID - for now return null
        // In a real implementation, we'd need to track session ID with photos
        return null;
      }

      // Cache the thumbnail
      final Map<String, Uint8List> updatedCache =
          Map<String, Uint8List>.from(state.thumbnailCache);
      updatedCache[photo.id] = thumbnailData;

      state = state.copyWith(thumbnailCache: updatedCache);

      return thumbnailData;
    } on Exception catch (e) {
      debugPrint('Error loading thumbnail for ${photo.id}: $e');
      return null;
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear all cached data
  void clearCache() {
    state = state.copyWith(
      photos: <PhotoWaypoint>[],
      filteredPhotos: <PhotoWaypoint>[],
      photoMetadata: <String, List<PhotoMetadata>>{},
      thumbnailCache: <String, Uint8List>{},
      currentPage: 0,
      hasMore: true,
      clearSelectedPhoto: true,
      clearSelectedPhotos: true,
      clearBatchOperation: true,
      clearError: true,
    );
  }

  // MARK: - Selection Management

  /// Toggle selection mode
  void toggleSelectionMode() {
    state = state.copyWith(
      isSelectionMode: !state.isSelectionMode,
      clearSelectedPhotos: !state.isSelectionMode,
    );
  }

  /// Select/deselect a photo
  void togglePhotoSelection(String photoId) {
    final Set<String> updatedSelection = Set<String>.from(state.selectedPhotos);

    if (updatedSelection.contains(photoId)) {
      updatedSelection.remove(photoId);
    } else {
      updatedSelection.add(photoId);
    }

    state = state.copyWith(selectedPhotos: updatedSelection);
  }

  /// Select all visible photos
  void selectAllPhotos() {
    final Set<String> allPhotoIds =
        state.filteredPhotos.map((photo) => photo.id).toSet();

    state = state.copyWith(selectedPhotos: allPhotoIds);
  }

  /// Clear all selections
  void clearSelection() {
    state = state.copyWith(clearSelectedPhotos: true);
  }

  /// Exit selection mode
  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      clearSelectedPhotos: true,
    );
  }

  // MARK: - Batch Operations

  /// Delete multiple photos with progress tracking
  Future<bool> batchDeletePhotos(
      List<String> photoIds, String sessionId) async {
    if (photoIds.isEmpty) return true;

    // Initialize batch operation
    state = state.copyWith(
      batchOperation: BatchOperationProgress(
        type: BatchOperationType.delete,
        total: photoIds.length,
        completed: 0,
        failed: 0,
      ),
      isDeleting: true,
    );

    final List<DeletedPhoto> deletedPhotos = <DeletedPhoto>[];
    int completed = 0;
    int failed = 0;

    try {
      for (final String photoId in photoIds) {
        final PhotoWaypoint? photo =
            state.photos.where((p) => p.id == photoId).firstOrNull;

        if (photo == null) {
          failed++;
          continue;
        }

        // Update progress
        state = state.copyWith(
          batchOperation: BatchOperationProgress(
            type: BatchOperationType.delete,
            total: photoIds.length,
            completed: completed,
            failed: failed,
            currentItem: photo.filePath,
          ),
          deleteProgress: (completed + failed) / photoIds.length,
        );

        // Store for undo functionality
        final List<PhotoMetadata> metadata =
            state.photoMetadata[photoId] ?? <PhotoMetadata>[];

        deletedPhotos.add(DeletedPhoto(
          photo: photo,
          metadata: metadata,
          deletedAt: DateTime.now(),
          sessionId: sessionId,
        ));

        // Delete the photo
        final bool success =
            await _photoCaptureService.deletePhotoWaypoint(photo);

        if (success) {
          completed++;

          // Remove from state immediately
          final List<PhotoWaypoint> updatedPhotos =
              state.photos.where((p) => p.id != photoId).toList();

          final Map<String, List<PhotoMetadata>> updatedMetadata =
              Map<String, List<PhotoMetadata>>.from(state.photoMetadata);
          updatedMetadata.remove(photoId);

          final Map<String, Uint8List> updatedCache =
              Map<String, Uint8List>.from(state.thumbnailCache);
          updatedCache.remove(photoId);

          state = state.copyWith(
            photos: updatedPhotos,
            photoMetadata: updatedMetadata,
            thumbnailCache: updatedCache,
          );
        } else {
          failed++;
        }

        // Small delay to show progress
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // Update final state
      state = state.copyWith(
        batchOperation: BatchOperationProgress(
          type: BatchOperationType.delete,
          total: photoIds.length,
          completed: completed,
          failed: failed,
        ),
        deletedPhotos: [...state.deletedPhotos, ...deletedPhotos],
        isDeleting: false,
        deleteProgress: 1.0,
        clearSelectedPhotos: true,
        isSelectionMode: false,
      );

      // Apply filters after deletion
      _applyFiltersAndSort();

      // Clear batch operation after delay
      Timer(const Duration(seconds: 2), () {
        state = state.copyWith(
          clearBatchOperation: true,
          deleteProgress: 0.0,
        );
      });

      return failed == 0;
    } catch (e) {
      state = state.copyWith(
        batchOperation: BatchOperationProgress(
          type: BatchOperationType.delete,
          total: photoIds.length,
          completed: completed,
          failed: failed + (photoIds.length - completed - failed),
          error: 'Batch deletion failed: $e',
        ),
        isDeleting: false,
        error: 'Batch deletion failed: $e',
      );
      return false;
    }
  }

  /// Batch favorite/unfavorite photos
  Future<bool> batchToggleFavorite(List<String> photoIds,
      {required bool favorite}) async {
    if (photoIds.isEmpty) return true;

    state = state.copyWith(
      batchOperation: BatchOperationProgress(
        type: favorite
            ? BatchOperationType.favorite
            : BatchOperationType.unfavorite,
        total: photoIds.length,
        completed: 0,
        failed: 0,
      ),
    );

    int completed = 0;
    int failed = 0;

    try {
      for (final String photoId in photoIds) {
        final PhotoWaypoint? photo =
            state.photos.where((p) => p.id == photoId).firstOrNull;

        if (photo == null) {
          failed++;
          continue;
        }

        // Update progress
        state = state.copyWith(
          batchOperation: BatchOperationProgress(
            type: favorite
                ? BatchOperationType.favorite
                : BatchOperationType.unfavorite,
            total: photoIds.length,
            completed: completed,
            failed: failed,
            currentItem: photo.filePath,
          ),
        );

        // Toggle favorite (reuse existing logic)
        await toggleFavorite(photo);
        completed++;

        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      state = state.copyWith(
        batchOperation: BatchOperationProgress(
          type: favorite
              ? BatchOperationType.favorite
              : BatchOperationType.unfavorite,
          total: photoIds.length,
          completed: completed,
          failed: failed,
        ),
        clearSelectedPhotos: true,
        isSelectionMode: false,
      );

      // Clear batch operation after delay
      Timer(const Duration(seconds: 2), () {
        state = state.copyWith(clearBatchOperation: true);
      });

      return failed == 0;
    } catch (e) {
      state = state.copyWith(
        batchOperation: BatchOperationProgress(
          type: favorite
              ? BatchOperationType.favorite
              : BatchOperationType.unfavorite,
          total: photoIds.length,
          completed: completed,
          failed: failed + (photoIds.length - completed - failed),
          error: 'Batch operation failed: $e',
        ),
        error: 'Batch operation failed: $e',
      );
      return false;
    }
  }

  // MARK: - Undo Functionality

  /// Undo recent deletions (within last 30 seconds)
  Future<bool> undoRecentDeletions() async {
    final DateTime cutoff =
        DateTime.now().subtract(const Duration(seconds: 30));
    final List<DeletedPhoto> recentDeletions = state.deletedPhotos
        .where((deleted) => deleted.deletedAt.isAfter(cutoff))
        .toList();

    if (recentDeletions.isEmpty) return false;

    try {
      // This would require implementing restoration in PhotoCaptureService
      // For now, we'll just remove them from the deleted list
      final List<DeletedPhoto> remainingDeleted = state.deletedPhotos
          .where((deleted) => !recentDeletions.contains(deleted))
          .toList();

      state = state.copyWith(deletedPhotos: remainingDeleted);

      // In a real implementation, you would restore the files and database entries
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to undo deletions: $e');
      return false;
    }
  }

  /// Clear old deleted photos (older than 24 hours)
  void cleanupDeletedPhotos() {
    final DateTime cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final List<DeletedPhoto> recentDeleted = state.deletedPhotos
        .where((deleted) => deleted.deletedAt.isAfter(cutoff))
        .toList();

    if (recentDeleted.length != state.deletedPhotos.length) {
      state = state.copyWith(deletedPhotos: recentDeleted);
    }
  }

  // MARK: - Annotation Management

  /// Add or update photo annotations
  Future<bool> updatePhotoAnnotations(
      String photoId, List<PhotoMetadata> annotations) async {
    try {
      // Get current metadata
      final Map<String, List<PhotoMetadata>> updatedMetadata =
          Map<String, List<PhotoMetadata>>.from(state.photoMetadata);

      final List<PhotoMetadata> existingMetadata =
          updatedMetadata[photoId] ?? <PhotoMetadata>[];

      // Remove existing custom annotations
      final List<PhotoMetadata> nonCustomMetadata =
          existingMetadata.where((meta) => !meta.isCustomData).toList();

      // Add new annotations
      updatedMetadata[photoId] = [...nonCustomMetadata, ...annotations];

      // Update state
      state = state.copyWith(photoMetadata: updatedMetadata);

      // Apply filters to refresh the view
      _applyFiltersAndSort();

      // In a real implementation, this would persist to database
      // await _photoCaptureService.updatePhotoMetadata(photoId, annotations);

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to update annotations: $e');
      return false;
    }
  }

  /// Get annotations for a specific photo
  List<PhotoMetadata> getPhotoAnnotations(String photoId) {
    final List<PhotoMetadata> metadata =
        state.photoMetadata[photoId] ?? <PhotoMetadata>[];
    return metadata.where((meta) => meta.isCustomData).toList();
  }

  /// Delete specific annotation
  Future<bool> deletePhotoAnnotation(
      String photoId, String annotationKey) async {
    try {
      final Map<String, List<PhotoMetadata>> updatedMetadata =
          Map<String, List<PhotoMetadata>>.from(state.photoMetadata);

      final List<PhotoMetadata> existingMetadata =
          updatedMetadata[photoId] ?? <PhotoMetadata>[];

      // Remove the specific annotation
      final List<PhotoMetadata> filteredMetadata =
          existingMetadata.where((meta) => meta.key != annotationKey).toList();

      updatedMetadata[photoId] = filteredMetadata;

      // Update state
      state = state.copyWith(photoMetadata: updatedMetadata);

      // Apply filters to refresh the view
      _applyFiltersAndSort();

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete annotation: $e');
      return false;
    }
  }

  /// Batch update annotations for multiple photos
  Future<bool> batchUpdateAnnotations(
      Map<String, List<PhotoMetadata>> photoAnnotations) async {
    try {
      final Map<String, List<PhotoMetadata>> updatedMetadata =
          Map<String, List<PhotoMetadata>>.from(state.photoMetadata);

      for (final MapEntry<String, List<PhotoMetadata>> entry
          in photoAnnotations.entries) {
        final String photoId = entry.key;
        final List<PhotoMetadata> annotations = entry.value;

        final List<PhotoMetadata> existingMetadata =
            updatedMetadata[photoId] ?? <PhotoMetadata>[];

        // Remove existing custom annotations
        final List<PhotoMetadata> nonCustomMetadata =
            existingMetadata.where((meta) => !meta.isCustomData).toList();

        // Add new annotations
        updatedMetadata[photoId] = [...nonCustomMetadata, ...annotations];
      }

      // Update state
      state = state.copyWith(photoMetadata: updatedMetadata);

      // Apply filters to refresh the view
      _applyFiltersAndSort();

      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to batch update annotations: $e');
      return false;
    }
  }

  /// Get photos with specific annotation criteria
  List<PhotoWaypoint> getPhotosWithAnnotations({
    bool? isFavorite,
    int? minRating,
    List<String>? tags,
    String? searchText,
  }) =>
      state.photos.where((photo) {
        final List<PhotoMetadata> annotations = getPhotoAnnotations(photo.id);
        final Map<String, PhotoMetadata> annotationMap = {
          for (final annotation in annotations) annotation.key: annotation,
        };

        // Check favorite status
        if (isFavorite != null) {
          final bool photoIsFavorite =
              annotationMap[CustomKeys.favorite]?.typedValue == true;
          if (photoIsFavorite != isFavorite) return false;
        }

        // Check rating
        if (minRating != null) {
          final int photoRating =
              annotationMap[CustomKeys.rating]?.typedValue as int? ?? 0;
          if (photoRating < minRating) return false;
        }

        // Check tags
        if (tags != null && tags.isNotEmpty) {
          final String? photoTags = annotationMap[CustomKeys.tags]?.value;
          if (photoTags == null) return false;

          final List<String> photoTagList = photoTags
              .split(',')
              .map((tag) => tag.trim().toLowerCase())
              .toList();

          final bool hasAnyTag =
              tags.any((tag) => photoTagList.contains(tag.toLowerCase()));
          if (!hasAnyTag) return false;
        }

        // Check search text in annotations
        if (searchText != null && searchText.isNotEmpty) {
          final String searchLower = searchText.toLowerCase();
          final bool matchesAnnotation = annotations.any((annotation) =>
              annotation.value?.toLowerCase().contains(searchLower) == true);
          if (!matchesAnnotation) return false;
        }

        return true;
      }).toList();
}

/// Provider for photo state management
final NotifierProvider<PhotoNotifier, PhotoState> photoProvider =
    NotifierProvider<PhotoNotifier, PhotoState>(PhotoNotifier.new);

/// Provider for filtered photos
final Provider<List<PhotoWaypoint>> filteredPhotosProvider =
    Provider<List<PhotoWaypoint>>((Ref ref) {
  final PhotoState photoState = ref.watch(photoProvider);
  return photoState.filteredPhotos;
});

/// Provider for photo count
final Provider<int> photoCountProvider = Provider<int>((Ref ref) {
  final PhotoState photoState = ref.watch(photoProvider);
  return photoState.photos.length;
});

/// Provider for filtered photo count
final Provider<int> filteredPhotoCountProvider = Provider<int>((Ref ref) {
  final PhotoState photoState = ref.watch(photoProvider);
  return photoState.filteredPhotos.length;
});

/// Provider for photos by date
final  photosByDateProvider =
    Provider.family<List<PhotoWaypoint>, DateTime>((Ref ref, DateTime date) {
  final PhotoState photoState = ref.watch(photoProvider);
  final DateTime startOfDay = DateTime(date.year, date.month, date.day);
  final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

  return photoState.photos
      .where((PhotoWaypoint photo) =>
          photo.createdAt.isAfter(startOfDay) &&
          photo.createdAt.isBefore(endOfDay))
      .toList();
});
