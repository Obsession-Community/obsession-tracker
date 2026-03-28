import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:obsession_tracker/core/models/security_models.dart';
import 'package:obsession_tracker/core/services/secure_key_management_service.dart';
import 'package:path/path.dart' as path;

/// Data encryption service for encrypting database and photo data
class DataEncryptionService {
  factory DataEncryptionService() => _instance ??= DataEncryptionService._();
  DataEncryptionService._();
  static DataEncryptionService? _instance;

  final SecureKeyManagementService _keyService = SecureKeyManagementService();

  // Encryption settings
  DataEncryptionSettings _settings = const DataEncryptionSettings();

  /// Initialize the data encryption service
  Future<void> initialize(DataEncryptionSettings settings) async {
    try {
      _settings = settings;
      await _keyService.initialize();
      debugPrint('Data encryption service initialized');
    } catch (e) {
      debugPrint('Error initializing data encryption service: $e');
      rethrow;
    }
  }

  /// Update encryption settings
  void updateSettings(DataEncryptionSettings settings) {
    _settings = settings;
    debugPrint('Data encryption settings updated');
  }

  /// Encrypt database data
  Future<String?> encryptDatabaseData(String data) async {
    if (!_settings.enableDatabaseEncryption) return data;

    try {
      return await _keyService.encryptData('database_key', data);
    } catch (e) {
      debugPrint('Error encrypting database data: $e');
      return null;
    }
  }

  /// Decrypt database data
  Future<String?> decryptDatabaseData(String encryptedData) async {
    if (!_settings.enableDatabaseEncryption) return encryptedData;

    try {
      return await _keyService.decryptData('database_key', encryptedData);
    } catch (e) {
      debugPrint('Error decrypting database data: $e');
      return null;
    }
  }

  /// Encrypt photo file
  Future<bool> encryptPhotoFile(String filePath) async {
    if (!_settings.enablePhotoEncryption) return true;

    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      // Read original file
      final originalData = await file.readAsBytes();

      // Encrypt data
      final encryptedData =
          await _keyService.encryptBinaryData('photo_key', originalData);
      if (encryptedData == null) return false;

      // Write encrypted data back to file
      await file.writeAsBytes(encryptedData);

      // Secure wipe original data from memory
      _keyService.secureWipeMemory(originalData);

      debugPrint('Photo encrypted: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error encrypting photo file $filePath: $e');
      return false;
    }
  }

  /// Decrypt photo file
  Future<bool> decryptPhotoFile(String filePath) async {
    if (!_settings.enablePhotoEncryption) return true;

    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      // Read encrypted file
      final encryptedData = await file.readAsBytes();

      // Decrypt data
      final decryptedData =
          await _keyService.decryptBinaryData('photo_key', encryptedData);
      if (decryptedData == null) return false;

      // Write decrypted data back to file
      await file.writeAsBytes(decryptedData);

      debugPrint('Photo decrypted: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error decrypting photo file $filePath: $e');
      return false;
    }
  }

  /// Encrypt photo data in memory
  Future<Uint8List?> encryptPhotoData(Uint8List photoData) async {
    if (!_settings.enablePhotoEncryption) return photoData;

    try {
      final encryptedData =
          await _keyService.encryptBinaryData('photo_key', photoData);

      // Secure wipe original data from memory
      _keyService.secureWipeMemory(photoData);

      return encryptedData;
    } catch (e) {
      debugPrint('Error encrypting photo data: $e');
      return null;
    }
  }

  /// Decrypt photo data in memory
  Future<Uint8List?> decryptPhotoData(Uint8List encryptedData) async {
    if (!_settings.enablePhotoEncryption) return encryptedData;

    try {
      return await _keyService.decryptBinaryData('photo_key', encryptedData);
    } catch (e) {
      debugPrint('Error decrypting photo data: $e');
      return null;
    }
  }

  /// Create encrypted backup of data
  Future<Uint8List?> createEncryptedBackup(
      Map<String, dynamic> data, String password) async {
    try {
      // Convert data to JSON
      final jsonData = jsonEncode(data);
      final dataBytes = utf8.encode(jsonData);

      // Generate salt for key derivation
      final salt = _keyService.generateSecureRandomBytes(32);

      // Derive key from password (for future use with custom encryption)
      _keyService.deriveKeyFromPassword(password, salt);

      // Encrypt data
      final encrypter = await _keyService.getEncrypter('backup_key');
      if (encrypter == null) return null;

      final iv = _keyService.generateSecureRandomBytes(16);
      final encrypted = encrypter.encryptBytes(dataBytes, iv: IV(iv));

      // Combine salt, IV, and encrypted data
      final result = Uint8List(32 + 16 + encrypted.bytes.length);
      result.setRange(0, 32, salt);
      result.setRange(32, 48, iv);
      result.setRange(48, result.length, encrypted.bytes);

      // Secure wipe sensitive data from memory
      _keyService.secureWipeMemory(dataBytes);
      _keyService.secureWipeMemory(salt);
      _keyService.secureWipeMemory(iv);

      debugPrint('Encrypted backup created');
      return result;
    } catch (e) {
      debugPrint('Error creating encrypted backup: $e');
      return null;
    }
  }

  /// Restore data from encrypted backup
  Future<Map<String, dynamic>?> restoreFromEncryptedBackup(
      Uint8List backupData, String password) async {
    try {
      if (backupData.length < 48) return null; // Minimum size for salt + IV

      // Extract salt, IV, and encrypted data
      final salt = backupData.sublist(0, 32);
      final iv = backupData.sublist(32, 48);
      final encryptedBytes = backupData.sublist(48);

      // Derive key from password (for future use with custom encryption)
      _keyService.deriveKeyFromPassword(password, salt);

      // Decrypt data
      final encrypter = await _keyService.getEncrypter('backup_key');
      if (encrypter == null) return null;

      final encrypted = Encrypted(encryptedBytes);
      final decryptedBytes = encrypter.decryptBytes(encrypted, iv: IV(iv));

      // Convert back to JSON
      final jsonData = utf8.decode(decryptedBytes);
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      debugPrint('Data restored from encrypted backup');
      return data;
    } catch (e) {
      debugPrint('Error restoring from encrypted backup: $e');
      return null;
    }
  }

  /// Encrypt directory of photos
  Future<int> encryptPhotoDirectory(String directoryPath) async {
    if (!_settings.enablePhotoEncryption) return 0;

    try {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) return 0;

      int encryptedCount = 0;

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && _isImageFile(entity.path)) {
          if (await encryptPhotoFile(entity.path)) {
            encryptedCount++;
          }
        }
      }

      debugPrint(
          'Encrypted $encryptedCount photos in directory: $directoryPath');
      return encryptedCount;
    } catch (e) {
      debugPrint('Error encrypting photo directory $directoryPath: $e');
      return 0;
    }
  }

  /// Decrypt directory of photos
  Future<int> decryptPhotoDirectory(String directoryPath) async {
    if (!_settings.enablePhotoEncryption) return 0;

    try {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) return 0;

      int decryptedCount = 0;

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && _isImageFile(entity.path)) {
          if (await decryptPhotoFile(entity.path)) {
            decryptedCount++;
          }
        }
      }

      debugPrint(
          'Decrypted $decryptedCount photos in directory: $directoryPath');
      return decryptedCount;
    } catch (e) {
      debugPrint('Error decrypting photo directory $directoryPath: $e');
      return 0;
    }
  }

  /// Check if file is an image file
  bool _isImageFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        .contains(extension);
  }

  /// Securely delete file
  Future<bool> secureDeleteFile(String filePath) async {
    if (!_settings.enableSecureDelete) {
      // Just delete normally if secure delete is disabled
      try {
        await File(filePath).delete();
        return true;
      } catch (e) {
        debugPrint('Error deleting file $filePath: $e');
        return false;
      }
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) return true;

      // Get file size
      final fileSize = await file.length();

      // Overwrite file with random data multiple times
      final randomData = _keyService.generateSecureRandomBytes(1024);

      for (int pass = 0; pass < 3; pass++) {
        final randomFile = await file.open(mode: FileMode.write);

        for (int i = 0; i < fileSize; i += randomData.length) {
          final remainingBytes = fileSize - i;
          final bytesToWrite = remainingBytes < randomData.length
              ? randomData.sublist(0, remainingBytes.toInt())
              : randomData;

          await randomFile.writeFrom(bytesToWrite);
        }

        await randomFile.flush();
        await randomFile.close();

        // Generate new random data for next pass
        _keyService.secureWipeMemory(randomData);
        randomData.setAll(0, _keyService.generateSecureRandomBytes(1024));
      }

      // Final pass with zeros
      final zeroData = Uint8List(1024);
      final zeroFile = await file.open(mode: FileMode.write);

      for (int i = 0; i < fileSize; i += zeroData.length) {
        final remainingBytes = fileSize - i;
        final bytesToWrite = remainingBytes < zeroData.length
            ? zeroData.sublist(0, remainingBytes.toInt())
            : zeroData;

        await zeroFile.writeFrom(bytesToWrite);
      }

      await zeroFile.flush();
      await zeroFile.close();

      // Finally delete the file
      await file.delete();

      debugPrint('File securely deleted: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error securely deleting file $filePath: $e');
      return false;
    }
  }

  /// Get encryption status for a file
  Future<bool> isFileEncrypted(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;

      // Read first few bytes to check for encryption signature
      final bytes = await file.openRead(0, 16).first;

      // Check if it looks like encrypted data (high entropy)
      return _hasHighEntropy(Uint8List.fromList(bytes));
    } catch (e) {
      debugPrint('Error checking encryption status for $filePath: $e');
      return false;
    }
  }

  /// Check if data has high entropy (likely encrypted)
  bool _hasHighEntropy(Uint8List data) {
    if (data.length < 16) return false;

    // Count unique bytes
    final uniqueBytes = <int>{};
    data.forEach(uniqueBytes.add);

    // If more than 75% of bytes are unique, likely encrypted
    return uniqueBytes.length / data.length > 0.75;
  }

  /// Rotate encryption keys
  Future<bool> rotateEncryptionKeys() async {
    if (!_settings.enableKeyRotation) return true;

    try {
      await _keyService.rotateKeys();
      debugPrint('Encryption keys rotated');
      return true;
    } catch (e) {
      debugPrint('Error rotating encryption keys: $e');
      return false;
    }
  }

  /// Check if key rotation is needed
  Future<bool> needsKeyRotation() async {
    if (!_settings.enableKeyRotation) return false;

    try {
      return await _keyService.needsKeyRotation(_settings.keyRotationInterval);
    } catch (e) {
      debugPrint('Error checking key rotation: $e');
      return false;
    }
  }

  /// Get encryption statistics
  Future<Map<String, dynamic>> getEncryptionStats(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        return {
          'totalFiles': 0,
          'encryptedFiles': 0,
          'unencryptedFiles': 0,
          'encryptionPercentage': 0.0,
        };
      }

      int totalFiles = 0;
      int encryptedFiles = 0;

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && _isImageFile(entity.path)) {
          totalFiles++;
          if (await isFileEncrypted(entity.path)) {
            encryptedFiles++;
          }
        }
      }

      final unencryptedFiles = totalFiles - encryptedFiles;
      final encryptionPercentage =
          totalFiles > 0 ? (encryptedFiles / totalFiles) * 100 : 0.0;

      return {
        'totalFiles': totalFiles,
        'encryptedFiles': encryptedFiles,
        'unencryptedFiles': unencryptedFiles,
        'encryptionPercentage': encryptionPercentage,
      };
    } catch (e) {
      debugPrint('Error getting encryption stats: $e');
      return {
        'totalFiles': 0,
        'encryptedFiles': 0,
        'unencryptedFiles': 0,
        'encryptionPercentage': 0.0,
      };
    }
  }

  /// Dispose of the service
  void dispose() {
    _keyService.dispose();
    _instance = null;
  }
}
