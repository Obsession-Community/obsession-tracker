import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Desktop file system integration service
class DesktopFileSystemService {
  factory DesktopFileSystemService() => _instance;
  DesktopFileSystemService._internal();
  static final DesktopFileSystemService _instance =
      DesktopFileSystemService._internal();

  /// Check if running on desktop platform
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Get the default documents directory for the app
  Future<Directory> getDocumentsDirectory() async {
    if (!isDesktop) {
      return getApplicationDocumentsDirectory();
    }

    // For desktop, use a more user-friendly location
    final documentsDir = await getApplicationDocumentsDirectory();
    final appDir = Directory(path.join(documentsDir.path, 'Obsession Tracker'));

    if (!appDir.existsSync()) {
      await appDir.create(recursive: true);
    }

    return appDir;
  }

  /// Get the exports directory
  Future<Directory> getExportsDirectory() async {
    final docsDir = await getDocumentsDirectory();
    final exportsDir = Directory(path.join(docsDir.path, 'Exports'));

    if (!exportsDir.existsSync()) {
      await exportsDir.create(recursive: true);
    }

    return exportsDir;
  }

  /// Get the backups directory
  Future<Directory> getBackupsDirectory() async {
    final docsDir = await getDocumentsDirectory();
    final backupsDir = Directory(path.join(docsDir.path, 'Backups'));

    if (!backupsDir.existsSync()) {
      await backupsDir.create(recursive: true);
    }

    return backupsDir;
  }

  /// Get the cache directory for temporary files
  Future<Directory> getCacheDirectory() async => getTemporaryDirectory();

  /// Open file explorer/finder at the specified directory
  Future<bool> openDirectoryInExplorer(String directoryPath) async {
    if (!isDesktop) return false;

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          await Process.run('explorer', [directoryPath]);
          break;
        case TargetPlatform.macOS:
          await Process.run('open', [directoryPath]);
          break;
        case TargetPlatform.linux:
          // Try common file managers
          try {
            await Process.run('xdg-open', [directoryPath]);
          } catch (e) {
            try {
              await Process.run('nautilus', [directoryPath]);
            } catch (e) {
              await Process.run('dolphin', [directoryPath]);
            }
          }
          break;
        default:
          return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error opening directory in explorer: $e');
      return false;
    }
  }

  /// Open file with default system application
  Future<bool> openFileWithDefaultApp(String filePath) async {
    if (!isDesktop) return false;

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          await Process.run('start', ['', filePath], runInShell: true);
          break;
        case TargetPlatform.macOS:
          await Process.run('open', [filePath]);
          break;
        case TargetPlatform.linux:
          await Process.run('xdg-open', [filePath]);
          break;
        default:
          return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error opening file with default app: $e');
      return false;
    }
  }

  /// Create a desktop shortcut/alias for the application
  Future<bool> createDesktopShortcut() async {
    if (!isDesktop) return false;

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          return await _createWindowsShortcut();
        case TargetPlatform.macOS:
          return await _createMacOSAlias();
        case TargetPlatform.linux:
          return await _createLinuxDesktopEntry();
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error creating desktop shortcut: $e');
      return false;
    }
  }

  /// Get file associations for the app
  Future<List<String>> getSupportedFileExtensions() async => [
        '.gpx',
        '.kml',
        '.json',
        '.csv',
        '.wlt', // Obsession Tracker format
      ];

  /// Register file associations (requires admin privileges)
  Future<bool> registerFileAssociations() async {
    if (!isDesktop) return false;

    try {
      final extensions = await getSupportedFileExtensions();

      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
          return await _registerWindowsFileAssociations(extensions);
        case TargetPlatform.macOS:
          return await _registerMacOSFileAssociations(extensions);
        case TargetPlatform.linux:
          return await _registerLinuxFileAssociations(extensions);
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error registering file associations: $e');
      return false;
    }
  }

  /// Watch directory for changes
  Stream<FileSystemEvent> watchDirectory(String directoryPath) {
    final directory = Directory(directoryPath);
    return directory.watch(recursive: true);
  }

  /// Get recent files list
  Future<List<FileInfo>> getRecentFiles({int limit = 10}) async {
    try {
      final docsDir = await getDocumentsDirectory();
      final recentFiles = <FileInfo>[];

      await for (final entity in docsDir.list(recursive: true)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          final supportedExtensions = await getSupportedFileExtensions();

          if (supportedExtensions.contains(extension)) {
            final stat = entity.statSync();
            recentFiles.add(FileInfo(
              path: entity.path,
              name: path.basename(entity.path),
              size: stat.size,
              modified: stat.modified,
              extension: extension,
            ));
          }
        }
      }

      // Sort by modification date (newest first)
      recentFiles.sort((a, b) => b.modified.compareTo(a.modified));

      return recentFiles.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting recent files: $e');
      return [];
    }
  }

  /// Clean up temporary files
  Future<void> cleanupTempFiles() async {
    try {
      final cacheDir = await getCacheDirectory();
      final tempFiles = <File>[];

      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final stat = entity.statSync();
          final age = DateTime.now().difference(stat.modified);

          // Delete files older than 7 days
          if (age.inDays > 7) {
            tempFiles.add(entity);
          }
        }
      }

      for (final file in tempFiles) {
        try {
          await file.delete();
        } catch (e) {
          debugPrint('Error deleting temp file ${file.path}: $e');
        }
      }

      debugPrint('Cleaned up ${tempFiles.length} temporary files');
    } catch (e) {
      debugPrint('Error cleaning up temp files: $e');
    }
  }

  /// Create backup of important files
  Future<String?> createBackup({
    required List<String> filePaths,
    String? backupName,
  }) async {
    try {
      final backupsDir = await getBackupsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupDirName = backupName ?? 'backup_$timestamp';
      final backupDir = Directory(path.join(backupsDir.path, backupDirName));

      await backupDir.create(recursive: true);

      for (final filePath in filePaths) {
        final sourceFile = File(filePath);
        if (sourceFile.existsSync()) {
          final fileName = path.basename(filePath);
          final targetPath = path.join(backupDir.path, fileName);
          await sourceFile.copy(targetPath);
        }
      }

      return backupDir.path;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      return null;
    }
  }

  // Platform-specific implementations
  Future<bool> _createWindowsShortcut() async =>
      // Implementation would create a .lnk file on the desktop
      // This requires Windows-specific APIs or PowerShell commands
      false; // Placeholder

  Future<bool> _createMacOSAlias() async =>
      // Implementation would create an alias on the desktop
      // This requires macOS-specific APIs or AppleScript
      false; // Placeholder

  Future<bool> _createLinuxDesktopEntry() async {
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) return false;

      final desktopDir = Directory(path.join(homeDir, 'Desktop'));
      if (!desktopDir.existsSync()) return false;

      final desktopEntryPath =
          path.join(desktopDir.path, 'obsession-tracker.desktop');
      final desktopEntry = File(desktopEntryPath);

      final content = '''
[Desktop Entry]
Version=1.0
Type=Application
Name=Obsession Tracker
Comment=Privacy-first GPS tracking app
Exec=${Platform.resolvedExecutable}
Icon=obsession-tracker
Terminal=false
Categories=Utility;GPS;
''';

      await desktopEntry.writeAsString(content);

      // Make executable
      await Process.run('chmod', ['+x', desktopEntryPath]);

      return true;
    } catch (e) {
      debugPrint('Error creating Linux desktop entry: $e');
      return false;
    }
  }

  Future<bool> _registerWindowsFileAssociations(
          List<String> extensions) async =>
      // Implementation would modify Windows registry
      // This requires admin privileges and registry manipulation
      false; // Placeholder

  Future<bool> _registerMacOSFileAssociations(List<String> extensions) async =>
      // Implementation would modify Info.plist and register with Launch Services
      false; // Placeholder

  Future<bool> _registerLinuxFileAssociations(List<String> extensions) async {
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) return false;

      final mimeDir =
          Directory(path.join(homeDir, '.local', 'share', 'mime', 'packages'));
      await mimeDir.create(recursive: true);

      final mimeFile = File(path.join(mimeDir.path, 'obsession-tracker.xml'));

      const mimeContent = '''
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-obsession-tracker">
    <comment>Obsession Tracker File</comment>
    <glob pattern="*.wlt"/>
  </mime-type>
</mime-info>
''';

      await mimeFile.writeAsString(mimeContent);

      // Update MIME database
      await Process.run('update-mime-database',
          [path.join(homeDir, '.local', 'share', 'mime')]);

      return true;
    } catch (e) {
      debugPrint('Error registering Linux file associations: $e');
      return false;
    }
  }
}

/// File information class
class FileInfo {
  const FileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.extension,
  });

  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String extension;

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024)
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(modified);

    if (difference.inDays == 0) {
      return 'Today ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${modified.day}/${modified.month}/${modified.year}';
    }
  }
}
