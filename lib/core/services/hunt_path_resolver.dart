import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Resolves hunt file paths between relative (database) and absolute (filesystem) forms.
///
/// On iOS, the application container UUID changes between app launches (especially
/// during development), causing absolute paths stored in the database to become invalid.
///
/// This class provides:
/// - Conversion from absolute to relative paths (for database storage)
/// - Conversion from relative to absolute paths (for file access)
///
/// The documents directory path is cached at initialization for synchronous access
/// in model factory constructors.
///
/// Example:
/// ```dart
/// // Initialize at app startup
/// await HuntPathResolver.initialize();
///
/// // Store relative path
/// final relativePath = HuntPathResolver.toRelativePath('/var/.../Documents/hunts/covers/abc.png');
/// // Returns: 'hunts/covers/abc.png'
///
/// // Resolve to absolute path
/// final absolutePath = HuntPathResolver.toAbsolutePath('hunts/covers/abc.png');
/// // Returns: '/var/.../Documents/hunts/covers/abc.png'
/// ```
class HuntPathResolver {
  HuntPathResolver._();

  static String? _documentsPath;

  /// Initialize the path resolver. Must be called before using other methods.
  ///
  /// Typically called in main.dart before runApp().
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _documentsPath = dir.path;
    debugPrint('HuntPathResolver initialized: $_documentsPath');
  }

  /// Get the cached documents directory path.
  ///
  /// Returns null if not initialized.
  static String? get documentsPath => _documentsPath;

  /// Check if the resolver is initialized.
  static bool get isInitialized => _documentsPath != null;

  /// Convert an absolute path to a relative path for database storage.
  ///
  /// If the path is already relative or null, returns it unchanged.
  /// If the path doesn't start with the documents directory, returns unchanged.
  ///
  /// Example:
  /// - Input: '/var/.../Documents/hunts/covers/abc.png'
  /// - Output: 'hunts/covers/abc.png'
  static String? toRelativePath(String? absolutePath) {
    if (absolutePath == null || absolutePath.isEmpty) {
      return absolutePath;
    }

    // If no documents path cached, can't convert
    if (_documentsPath == null) {
      debugPrint('HuntPathResolver: Not initialized, returning path as-is');
      return absolutePath;
    }

    // If already relative (doesn't start with /), return as-is
    if (!absolutePath.startsWith('/')) {
      return absolutePath;
    }

    // If path starts with documents directory, make it relative
    if (absolutePath.startsWith(_documentsPath!)) {
      // Remove the documents path prefix and leading slash
      var relativePath = absolutePath.substring(_documentsPath!.length);
      if (relativePath.startsWith('/')) {
        relativePath = relativePath.substring(1);
      }
      return relativePath;
    }

    // Path doesn't start with documents directory - return as-is
    // (might be a different app's path or already relative)
    debugPrint('HuntPathResolver: Path not under documents dir, returning as-is: $absolutePath');
    return absolutePath;
  }

  /// Convert a relative path to an absolute path for filesystem access.
  ///
  /// If the path is already absolute (starts with /) or null, returns it unchanged.
  ///
  /// Example:
  /// - Input: 'hunts/covers/abc.png'
  /// - Output: '/var/.../Documents/hunts/covers/abc.png'
  static String? toAbsolutePath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) {
      return relativePath;
    }

    // If no documents path cached, can't convert
    if (_documentsPath == null) {
      debugPrint('HuntPathResolver: Not initialized, returning path as-is');
      return relativePath;
    }

    // If already absolute (starts with /), return as-is
    if (relativePath.startsWith('/')) {
      // But check if it's a stale absolute path from old container
      // If so, try to fix it by extracting the relative portion
      if (!File(relativePath).existsSync()) {
        final fixed = _tryFixStalePath(relativePath);
        if (fixed != null) {
          debugPrint('HuntPathResolver: Fixed stale path: $relativePath -> $fixed');
          return fixed;
        }
      }
      return relativePath;
    }

    // Convert relative to absolute
    return path.join(_documentsPath!, relativePath);
  }

  /// Try to fix a stale absolute path from an old container UUID.
  ///
  /// Extracts the relative portion (starting from 'hunts/') and resolves
  /// it against the current documents directory.
  static String? _tryFixStalePath(String stalePath) {
    // Look for common hunt path patterns
    const patterns = [
      '/hunts/',
      '/Documents/hunts/',
    ];

    for (final pattern in patterns) {
      final idx = stalePath.indexOf(pattern);
      if (idx != -1) {
        // Extract relative path starting from 'hunts/'
        String relativePath;
        if (pattern == '/Documents/hunts/') {
          relativePath = stalePath.substring(idx + '/Documents/'.length);
        } else {
          relativePath = stalePath.substring(idx + 1); // Remove leading /
        }

        final fixedPath = path.join(_documentsPath!, relativePath);
        if (File(fixedPath).existsSync()) {
          return fixedPath;
        }
      }
    }

    return null;
  }

  /// Resolve a path from database, handling both legacy absolute paths
  /// and new relative paths.
  ///
  /// This is the main method to use when reading paths from the database.
  /// It handles:
  /// 1. Null/empty paths -> returns null/empty
  /// 2. Relative paths -> converts to absolute
  /// 3. Valid absolute paths -> returns as-is
  /// 4. Stale absolute paths (old container) -> tries to fix
  static String? resolveFromDatabase(String? dbPath) {
    return toAbsolutePath(dbPath);
  }

  /// Prepare a path for database storage.
  ///
  /// Converts absolute paths to relative for portability.
  static String? prepareForDatabase(String? absolutePath) {
    return toRelativePath(absolutePath);
  }
}
