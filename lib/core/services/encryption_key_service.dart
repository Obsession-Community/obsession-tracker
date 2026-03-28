import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing encryption keys used throughout the app.
///
/// This service generates and securely stores encryption keys using:
/// - iOS: Keychain (hardware-backed when available)
/// - Android: KeyStore (hardware-backed when available)
///
/// Keys are automatically generated on first access and persisted securely.
class EncryptionKeyService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Key names for different encryption purposes
  static const _databaseKeyName = 'db_encryption_key';
  static const _exportKeyName = 'export_encryption_key';

  /// Get or generate the database encryption key.
  ///
  /// This key is used to encrypt the SQLite database with SQLCipher.
  /// The key is 256 bits (32 bytes) of cryptographically secure random data.
  ///
  /// Returns: Base64-encoded encryption key suitable for SQLCipher
  static Future<String> getDatabaseKey() async {
    String? key = await _storage.read(key: _databaseKeyName);

    if (key == null) {
      // Generate new key on first access
      key = _generateSecureKey();
      await _storage.write(key: _databaseKeyName, value: key);
    }

    return key;
  }

  /// Get or generate the export file encryption key.
  ///
  /// This key is used as a master key for deriving session-specific keys
  /// when exporting .otx files. Each export will use this master key with
  /// a unique salt to derive a session-specific encryption key.
  ///
  /// Returns: Base64-encoded encryption key
  static Future<String> getExportKey() async {
    String? key = await _storage.read(key: _exportKeyName);

    if (key == null) {
      // Generate new key on first access
      key = _generateSecureKey();
      await _storage.write(key: _exportKeyName, value: key);
    }

    return key;
  }

  /// Generate a cryptographically secure 256-bit encryption key.
  ///
  /// Uses Random.secure() which is backed by:
  /// - iOS: SecRandomCopyBytes (hardware RNG when available)
  /// - Android: /dev/urandom (hardware RNG when available)
  ///
  /// Returns: Base64-encoded 256-bit key
  static String _generateSecureKey() {
    final random = Random.secure();
    final bytes = Uint8List(32); // 256 bits

    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }

    return base64.encode(bytes);
  }

  /// Check if database key exists (useful for migration scenarios).
  static Future<bool> hasDatabaseKey() async {
    final key = await _storage.read(key: _databaseKeyName);
    return key != null;
  }

  /// Reset database key (DANGEROUS - will make existing database unreadable).
  ///
  /// This should only be used when:
  /// 1. User explicitly requests data wipe
  /// 2. Database is corrupted and needs to be recreated
  /// 3. Security incident requires key rotation
  ///
  /// After calling this, the database must be deleted and recreated.
  static Future<void> resetDatabaseKey() async {
    await _storage.delete(key: _databaseKeyName);
  }

  /// Reset export key (regenerates master key for future exports).
  ///
  /// This does NOT affect previously exported files, as they each use
  /// their own derived keys. Only affects future exports.
  static Future<void> resetExportKey() async {
    await _storage.delete(key: _exportKeyName);
  }

  /// Delete all encryption keys (complete security reset).
  ///
  /// WARNING: This will make all encrypted data unrecoverable:
  /// - Database becomes unreadable
  /// - Previously exported files may not be decryptable (if master key-based)
  ///
  /// Use only for:
  /// - Complete app reset
  /// - Security incident response
  /// - User account deletion
  static Future<void> deleteAllKeys() async {
    await _storage.deleteAll();
  }

  /// Test secure storage availability.
  ///
  /// Verifies that the device's secure storage is accessible and functional.
  /// Returns true if secure storage is working, false otherwise.
  static Future<bool> isSecureStorageAvailable() async {
    try {
      const testKey = 'test_key';
      const testValue = 'test_value';

      // Write test value
      await _storage.write(key: testKey, value: testValue);

      // Read test value
      final readValue = await _storage.read(key: testKey);

      // Clean up
      await _storage.delete(key: testKey);

      return readValue == testValue;
    } catch (e) {
      return false;
    }
  }
}
