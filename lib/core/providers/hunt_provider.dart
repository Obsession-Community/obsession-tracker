import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/achievements_provider.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/services/hunt_service.dart';

/// State notifier for managing treasure hunt operations
class HuntNotifier extends Notifier<AsyncValue<List<TreasureHunt>>> {
  late final HuntService _huntService;

  @override
  AsyncValue<List<TreasureHunt>> build() {
    _huntService = HuntService();

    // Load hunts asynchronously
    loadHunts();
    return const AsyncValue.loading();
  }

  /// Load all treasure hunts from database
  Future<void> loadHunts() async {
    try {
      debugPrint('HuntNotifier: Loading treasure hunts...');
      state = const AsyncValue.loading();
      final hunts = await _huntService.getAllHunts();
      debugPrint('HuntNotifier: Loaded ${hunts.length} hunts');
      state = AsyncValue.data(hunts);
    } catch (error, stackTrace) {
      debugPrint('HuntNotifier: Error loading hunts: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Create a new treasure hunt
  Future<TreasureHunt?> createHunt({
    required String name,
    String? author,
    String? description,
    List<String> tags = const [],
    File? coverImage,
  }) async {
    try {
      final hunt = await _huntService.createHunt(
        name: name,
        author: author,
        description: description,
        tags: tags,
        coverImage: coverImage,
      );
      await loadHunts();

      // Track hunt creation for achievements
      debugPrint('HuntNotifier: Tracking hunt creation for achievements...');
      await ref.read(lifetimeStatsProvider.notifier).incrementHuntsCreated();

      // Check achievements for newly unlocked badges
      final unlocked = await AchievementService().checkAllAchievements();
      if (unlocked.isNotEmpty) {
        debugPrint('HuntNotifier: Unlocked ${unlocked.length} achievement(s)!');
      }

      return hunt;
    } catch (error) {
      debugPrint('HuntNotifier: Error creating hunt: $error');
      return null;
    }
  }

  /// Update an existing treasure hunt
  Future<bool> updateHunt(TreasureHunt hunt, {File? newCoverImage}) async {
    try {
      await _huntService.updateHunt(hunt, newCoverImage: newCoverImage);

      // Clear entire image cache when cover image changes
      // This is necessary because Image.file uses internal caching by path
      if (newCoverImage != null) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        debugPrint('HuntNotifier: Cleared image cache after cover update');
      }

      await loadHunts();
      return true;
    } catch (error) {
      debugPrint('HuntNotifier: Error updating hunt: $error');
      return false;
    }
  }

  /// Update hunt status
  Future<bool> updateHuntStatus(String huntId, HuntStatus newStatus) async {
    try {
      await _huntService.updateHuntStatus(huntId, newStatus);
      await loadHunts();

      // Track hunt solved for achievements
      if (newStatus == HuntStatus.solved) {
        debugPrint('HuntNotifier: Tracking hunt solved for achievements...');
        await ref.read(lifetimeStatsProvider.notifier).incrementHuntsSolved();

        // Check achievements for newly unlocked badges
        final unlocked = await AchievementService().checkAllAchievements();
        if (unlocked.isNotEmpty) {
          debugPrint('HuntNotifier: Unlocked ${unlocked.length} achievement(s)!');
        }
      }

      return true;
    } catch (error) {
      debugPrint('HuntNotifier: Error updating hunt status: $error');
      return false;
    }
  }

  /// Delete a treasure hunt
  Future<bool> deleteHunt(String huntId) async {
    try {
      await _huntService.deleteHunt(huntId);
      await loadHunts();
      return true;
    } catch (error) {
      debugPrint('HuntNotifier: Error deleting hunt: $error');
      return false;
    }
  }

  /// Refresh hunts list
  Future<void> refresh() async {
    await loadHunts();
  }
}

/// Provider for treasure hunt management
final huntProvider =
    NotifierProvider<HuntNotifier, AsyncValue<List<TreasureHunt>>>(
  HuntNotifier.new,
);

/// Provider for getting a specific hunt by ID
final huntByIdProvider = Provider.family<TreasureHunt?, String>((ref, huntId) {
  final huntsAsync = ref.watch(huntProvider);
  return huntsAsync.maybeWhen(
    data: (hunts) {
      try {
        return hunts.firstWhere((hunt) => hunt.id == huntId);
      } catch (e) {
        return null;
      }
    },
    orElse: () => null,
  );
});

/// Provider for active hunts only
final activeHuntsProvider = Provider<List<TreasureHunt>>((ref) {
  final huntsAsync = ref.watch(huntProvider);
  return huntsAsync.maybeWhen(
    data: (hunts) => hunts.where((h) => h.status == HuntStatus.active).toList(),
    orElse: () => [],
  );
});

/// Provider for hunt summary (with statistics)
final huntSummaryProvider =
    FutureProvider.family<HuntSummary?, String>((ref, huntId) async {
  try {
    final huntService = HuntService();
    return await huntService.getHuntSummary(huntId);
  } catch (e) {
    debugPrint('Error loading hunt summary: $e');
    return null;
  }
});

// ============================================================
// Document Providers
// ============================================================

/// Provider for hunt documents
final huntDocumentProvider =
    FutureProvider.family<List<HuntDocument>, String>((ref, huntId) async {
  final huntService = HuntService();
  return huntService.getDocuments(huntId);
});

/// Notifier for document operations (add, update, delete)
class HuntDocumentNotifier extends Notifier<bool> {
  late final HuntService _huntService;

  @override
  bool build() {
    _huntService = HuntService();
    return false; // Not loading
  }

  /// Add an image to the hunt
  Future<HuntDocument?> addImage({
    required String huntId,
    required String name,
    required File imageFile,
  }) async {
    try {
      state = true; // Loading
      final doc = await _huntService.addImage(
        huntId: huntId,
        name: name,
        imageFile: imageFile,
      );
      state = false;
      return doc;
    } catch (error) {
      state = false;
      debugPrint('Error adding image: $error');
      return null;
    }
  }

  /// Add a PDF to the hunt
  Future<HuntDocument?> addPdf({
    required String huntId,
    required String name,
    required File pdfFile,
  }) async {
    try {
      state = true;
      final doc = await _huntService.addPdf(
        huntId: huntId,
        name: name,
        pdfFile: pdfFile,
      );
      state = false;
      return doc;
    } catch (error) {
      state = false;
      debugPrint('Error adding PDF: $error');
      return null;
    }
  }

  /// Add a note to the hunt
  Future<HuntDocument?> addNote({
    required String huntId,
    required String name,
    required String content,
  }) async {
    try {
      state = true;
      final doc = await _huntService.addNote(
        huntId: huntId,
        name: name,
        content: content,
      );
      state = false;
      return doc;
    } catch (error) {
      state = false;
      debugPrint('Error adding note: $error');
      return null;
    }
  }

  /// Add a link to the hunt
  Future<HuntDocument?> addLink({
    required String huntId,
    required String name,
    required String url,
  }) async {
    try {
      state = true;
      final doc = await _huntService.addLink(
        huntId: huntId,
        name: name,
        url: url,
      );
      state = false;
      return doc;
    } catch (error) {
      state = false;
      debugPrint('Error adding link: $error');
      return null;
    }
  }

  /// Add a generic document (txt, doc, docx, csv, etc.) to the hunt
  Future<HuntDocument?> addDocument({
    required String huntId,
    required String name,
    required File documentFile,
  }) async {
    try {
      state = true;
      final doc = await _huntService.addDocument(
        huntId: huntId,
        name: name,
        documentFile: documentFile,
      );
      state = false;
      return doc;
    } catch (error) {
      state = false;
      debugPrint('Error adding document: $error');
      return null;
    }
  }

  /// Delete a document
  Future<bool> deleteDocument(String documentId, String huntId) async {
    try {
      state = true;
      await _huntService.deleteDocument(documentId);
      state = false;
      return true;
    } catch (error) {
      state = false;
      debugPrint('Error deleting document: $error');
      return false;
    }
  }
}

/// Provider for document operations
final huntDocumentNotifierProvider =
    NotifierProvider<HuntDocumentNotifier, bool>(HuntDocumentNotifier.new);

// ============================================================
// Location Providers
// ============================================================

/// Provider for hunt locations
final huntLocationProvider =
    FutureProvider.family<List<HuntLocation>, String>((ref, huntId) async {
  final huntService = HuntService();
  return huntService.getLocations(huntId);
});

/// Notifier for location operations
class HuntLocationNotifier extends Notifier<bool> {
  late final HuntService _huntService;

  @override
  bool build() {
    _huntService = HuntService();
    return false; // Not loading
  }

  /// Add a location to the hunt
  Future<HuntLocation?> addLocation({
    required String huntId,
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    try {
      state = true;
      final location = await _huntService.addLocation(
        huntId: huntId,
        name: name,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
      );
      state = false;
      return location;
    } catch (error) {
      state = false;
      debugPrint('Error adding location: $error');
      return null;
    }
  }

  /// Update a location
  Future<bool> updateLocation(HuntLocation location, String huntId) async {
    try {
      state = true;
      await _huntService.updateLocation(location);
      state = false;
      return true;
    } catch (error) {
      state = false;
      debugPrint('Error updating location: $error');
      return false;
    }
  }

  /// Mark a location as searched
  Future<bool> markSearched(String locationId, String huntId) async {
    try {
      state = true;
      await _huntService.markLocationSearched(locationId, huntId);
      state = false;
      return true;
    } catch (error) {
      state = false;
      debugPrint('Error marking location searched: $error');
      return false;
    }
  }

  /// Delete a location
  Future<bool> deleteLocation(String locationId, String huntId) async {
    try {
      state = true;
      await _huntService.deleteLocation(locationId);
      state = false;
      return true;
    } catch (error) {
      state = false;
      debugPrint('Error deleting location: $error');
      return false;
    }
  }
}

/// Provider for location operations
final huntLocationNotifierProvider =
    NotifierProvider<HuntLocationNotifier, bool>(HuntLocationNotifier.new);

// ============================================================
// Session Link Providers
// ============================================================

/// Provider for session links (which hunts are linked to which sessions)
final huntSessionLinksProvider =
    FutureProvider.family<List<HuntSessionLink>, String>((ref, huntId) async {
  final huntService = HuntService();
  return huntService.getSessionLinks(huntId);
});

/// Provider for getting hunts linked to a specific session
final huntsForSessionProvider =
    FutureProvider.family<List<String>, String>((ref, sessionId) async {
  final huntService = HuntService();
  return huntService.getHuntsForSession(sessionId);
});

// ============================================================
// Selected Hunt Provider (for tracking context)
// ============================================================

/// State notifier for the currently selected hunt for new sessions
/// This persists the user's hunt selection for the tracking context
class SelectedHuntNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Default to no hunt selected
    // Could be persisted to SharedPreferences in the future
    return null;
  }

  /// Set the selected hunt for new sessions
  void selectHunt(String? huntId) {
    state = huntId;
    debugPrint('SelectedHuntNotifier: Selected hunt: $huntId');
  }

  /// Clear the selected hunt
  void clearSelection() {
    state = null;
    debugPrint('SelectedHuntNotifier: Cleared hunt selection');
  }
}

/// Provider for the currently selected hunt ID
final selectedHuntIdProvider =
    NotifierProvider<SelectedHuntNotifier, String?>(SelectedHuntNotifier.new);

/// Provider for the currently selected hunt object (convenience)
final selectedHuntProvider = Provider<TreasureHunt?>((ref) {
  final selectedId = ref.watch(selectedHuntIdProvider);
  if (selectedId == null) return null;

  return ref.watch(huntByIdProvider(selectedId));
});
