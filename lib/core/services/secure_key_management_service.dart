import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Secure key management service for handling encryption keys and secure storage
class SecureKeyManagementService {
  factory SecureKeyManagementService() =>
      _instance ??= SecureKeyManagementService._();
  SecureKeyManagementService._();
  static SecureKeyManagementService? _instance;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Key identifiers
  static const String _masterKeyId = 'master_key';
  static const String _databaseKeyId = 'database_key';
  static const String _photoKeyId = 'photo_key';
  static const String _backupKeyId = 'backup_key';
  static const String _keyRotationDateId = 'key_rotation_date';
  static const String _pinHashId = 'pin_hash';
  static const String _saltId = 'salt';

  // Cache for frequently used keys
  final Map<String, Key> _keyCache = {};
  final Map<String, Encrypter> _encrypterCache = {};

  /// Initialize the key management service
  Future<void> initialize() async {
    try {
      // Check if master key exists, create if not
      if (!await _hasKey(_masterKeyId)) {
        await _generateMasterKey();
      }

      // Initialize other keys if they don't exist
      await _ensureKeyExists(_databaseKeyId);
      await _ensureKeyExists(_photoKeyId);
      await _ensureKeyExists(_backupKeyId);

      debugPrint('Secure key management service initialized');
    } catch (e) {
      debugPrint('Error initializing secure key management service: $e');
      rethrow;
    }
  }

  /// Generate a new master key
  Future<void> _generateMasterKey() async {
    try {
      final key = Key.fromSecureRandom(32); // 256-bit key
      await _storeKey(_masterKeyId, key);
      await _setKeyRotationDate(_masterKeyId, DateTime.now());
      debugPrint('Master key generated and stored');
    } catch (e) {
      debugPrint('Error generating master key: $e');
      rethrow;
    }
  }

  /// Ensure a key exists, generate if not
  Future<void> _ensureKeyExists(String keyId) async {
    if (!await _hasKey(keyId)) {
      await _generateKey(keyId);
    }
  }

  /// Generate a new key for the given identifier
  Future<void> _generateKey(String keyId) async {
    try {
      final key = Key.fromSecureRandom(32); // 256-bit key
      await _storeKey(keyId, key);
      await _setKeyRotationDate(keyId, DateTime.now());
      debugPrint('Key generated for: $keyId');
    } catch (e) {
      debugPrint('Error generating key for $keyId: $e');
      rethrow;
    }
  }

  /// Store a key securely
  Future<void> _storeKey(String keyId, Key key) async {
    try {
      final keyBase64 = key.base64;
      await _secureStorage.write(key: keyId, value: keyBase64);
      _keyCache[keyId] = key;
    } catch (e) {
      debugPrint('Error storing key $keyId: $e');
      rethrow;
    }
  }

  /// Retrieve a key from secure storage
  Future<Key?> _getKey(String keyId) async {
    try {
      // Check cache first
      if (_keyCache.containsKey(keyId)) {
        return _keyCache[keyId];
      }

      final keyBase64 = await _secureStorage.read(key: keyId);
      if (keyBase64 == null) return null;

      final key = Key.fromBase64(keyBase64);
      _keyCache[keyId] = key;
      return key;
    } catch (e) {
      debugPrint('Error retrieving key $keyId: $e');
      return null;
    }
  }

  /// Check if a key exists
  Future<bool> _hasKey(String keyId) async {
    try {
      final keyBase64 = await _secureStorage.read(key: keyId);
      return keyBase64 != null;
    } catch (e) {
      debugPrint('Error checking key existence $keyId: $e');
      return false;
    }
  }

  /// Get an encrypter for the specified key
  Future<Encrypter?> getEncrypter(String keyId) async {
    try {
      // Check cache first
      if (_encrypterCache.containsKey(keyId)) {
        return _encrypterCache[keyId];
      }

      final key = await _getKey(keyId);
      if (key == null) return null;

      final encrypter = Encrypter(AES(key));
      _encrypterCache[keyId] = encrypter;
      return encrypter;
    } catch (e) {
      debugPrint('Error getting encrypter for $keyId: $e');
      return null;
    }
  }

  /// Get database encrypter
  Future<Encrypter?> getDatabaseEncrypter() async =>
      getEncrypter(_databaseKeyId);

  /// Get photo encrypter
  Future<Encrypter?> getPhotoEncrypter() async => getEncrypter(_photoKeyId);

  /// Get backup encrypter
  Future<Encrypter?> getBackupEncrypter() async => getEncrypter(_backupKeyId);

  /// Encrypt data with the specified key
  Future<String?> encryptData(String keyId, String data) async {
    try {
      final encrypter = await getEncrypter(keyId);
      if (encrypter == null) return null;

      final iv = IV.fromSecureRandom(16);
      final encrypted = encrypter.encrypt(data, iv: iv);

      // Combine IV and encrypted data
      final combined = '${iv.base64}:${encrypted.base64}';
      return combined;
    } catch (e) {
      debugPrint('Error encrypting data with $keyId: $e');
      return null;
    }
  }

  /// Decrypt data with the specified key
  Future<String?> decryptData(String keyId, String encryptedData) async {
    try {
      final encrypter = await getEncrypter(keyId);
      if (encrypter == null) return null;

      // Split IV and encrypted data
      final parts = encryptedData.split(':');
      if (parts.length != 2) return null;

      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);

      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      debugPrint('Error decrypting data with $keyId: $e');
      return null;
    }
  }

  /// Encrypt binary data (for photos)
  Future<Uint8List?> encryptBinaryData(String keyId, Uint8List data) async {
    try {
      final encrypter = await getEncrypter(keyId);
      if (encrypter == null) return null;

      final iv = IV.fromSecureRandom(16);
      final encrypted = encrypter.encryptBytes(data, iv: iv);

      // Combine IV and encrypted data
      final combined = Uint8List(16 + encrypted.bytes.length);
      combined.setRange(0, 16, iv.bytes);
      combined.setRange(16, combined.length, encrypted.bytes);

      return combined;
    } catch (e) {
      debugPrint('Error encrypting binary data with $keyId: $e');
      return null;
    }
  }

  /// Decrypt binary data (for photos)
  Future<Uint8List?> decryptBinaryData(
      String keyId, Uint8List encryptedData) async {
    try {
      final encrypter = await getEncrypter(keyId);
      if (encrypter == null) return null;

      if (encryptedData.length < 16) return null;

      // Extract IV and encrypted data
      final iv = IV(encryptedData.sublist(0, 16));
      final encrypted = Encrypted(encryptedData.sublist(16));

      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('Error decrypting binary data with $keyId: $e');
      return null;
    }
  }

  /// Set PIN hash
  Future<void> setPinHash(String pin) async {
    try {
      final salt = await _getOrCreateSalt();
      final pinHash = _hashPin(pin, salt);
      await _secureStorage.write(key: _pinHashId, value: pinHash);
      debugPrint('PIN hash set');
    } catch (e) {
      debugPrint('Error setting PIN hash: $e');
      rethrow;
    }
  }

  /// Verify PIN
  Future<bool> verifyPin(String pin) async {
    try {
      final storedHash = await _secureStorage.read(key: _pinHashId);
      if (storedHash == null) return false;

      final salt = await _getOrCreateSalt();
      final pinHash = _hashPin(pin, salt);

      return storedHash == pinHash;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }

  /// Check if PIN is set
  Future<bool> isPinSet() async {
    try {
      final pinHash = await _secureStorage.read(key: _pinHashId);
      return pinHash != null;
    } catch (e) {
      debugPrint('Error checking PIN status: $e');
      return false;
    }
  }

  /// Remove PIN
  Future<void> removePin() async {
    try {
      await _secureStorage.delete(key: _pinHashId);
      debugPrint('PIN removed');
    } catch (e) {
      debugPrint('Error removing PIN: $e');
      rethrow;
    }
  }

  /// Get or create salt for PIN hashing
  Future<String> _getOrCreateSalt() async {
    try {
      String? salt = await _secureStorage.read(key: _saltId);
      if (salt == null) {
        final random = Random.secure();
        final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
        salt = base64Encode(saltBytes);
        await _secureStorage.write(key: _saltId, value: salt);
      }
      return salt;
    } catch (e) {
      debugPrint('Error getting/creating salt: $e');
      rethrow;
    }
  }

  /// Hash PIN with salt
  String _hashPin(String pin, String salt) {
    final saltBytes = base64Decode(salt);
    final pinBytes = utf8.encode(pin);

    // Use PBKDF2 for secure PIN hashing
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(Uint8List.fromList(saltBytes), 10000, 32));

    final hash = pbkdf2.process(Uint8List.fromList(pinBytes));
    return base64Encode(hash);
  }

  /// Rotate keys (for security)
  Future<void> rotateKeys() async {
    try {
      debugPrint('Starting key rotation...');

      // Generate new keys
      await _generateKey(_databaseKeyId);
      await _generateKey(_photoKeyId);
      await _generateKey(_backupKeyId);

      // Clear cache to force reload
      _keyCache.clear();
      _encrypterCache.clear();

      debugPrint('Key rotation completed');
    } catch (e) {
      debugPrint('Error during key rotation: $e');
      rethrow;
    }
  }

  /// Check if keys need rotation
  Future<bool> needsKeyRotation(Duration rotationInterval) async {
    try {
      final lastRotation = await _getKeyRotationDate(_databaseKeyId);
      if (lastRotation == null) return true;

      final now = DateTime.now();
      return now.difference(lastRotation) > rotationInterval;
    } catch (e) {
      debugPrint('Error checking key rotation: $e');
      return false;
    }
  }

  /// Set key rotation date
  Future<void> _setKeyRotationDate(String keyId, DateTime date) async {
    try {
      final dateString = date.toIso8601String();
      await _secureStorage.write(
          key: '${keyId}_$_keyRotationDateId', value: dateString);
    } catch (e) {
      debugPrint('Error setting key rotation date for $keyId: $e');
    }
  }

  /// Get key rotation date
  Future<DateTime?> _getKeyRotationDate(String keyId) async {
    try {
      final dateString =
          await _secureStorage.read(key: '${keyId}_$_keyRotationDateId');
      if (dateString == null) return null;
      return DateTime.parse(dateString);
    } catch (e) {
      debugPrint('Error getting key rotation date for $keyId: $e');
      return null;
    }
  }

  /// Generate secure random bytes
  Uint8List generateSecureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (i) => random.nextInt(256)));
  }

  /// Derive key from password (for backup encryption)
  Key deriveKeyFromPassword(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, 10000, 32));

    final passwordBytes = utf8.encode(password);
    final derivedKey = pbkdf2.process(Uint8List.fromList(passwordBytes));

    return Key(derivedKey);
  }

  /// Securely wipe memory (best effort)
  void secureWipeMemory(Uint8List data) {
    try {
      // Overwrite with random data multiple times
      final random = Random.secure();
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < data.length; j++) {
          data[j] = random.nextInt(256);
        }
      }
      // Final pass with zeros
      data.fillRange(0, data.length, 0);
    } catch (e) {
      debugPrint('Error during secure memory wipe: $e');
    }
  }

  /// Clear all cached keys and encrypters
  void clearCache() {
    _keyCache.clear();
    _encrypterCache.clear();
    debugPrint('Key cache cleared');
  }

  /// Export key for backup (encrypted with master key)
  Future<String?> exportKeyForBackup(String keyId) async {
    try {
      final key = await _getKey(keyId);
      final masterKey = await _getKey(_masterKeyId);

      if (key == null || masterKey == null) return null;

      final masterEncrypter = Encrypter(AES(masterKey));
      final iv = IV.fromSecureRandom(16);
      final encrypted = masterEncrypter.encrypt(key.base64, iv: iv);

      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('Error exporting key $keyId: $e');
      return null;
    }
  }

  /// Import key from backup
  Future<bool> importKeyFromBackup(String keyId, String encryptedKey) async {
    try {
      final masterKey = await _getKey(_masterKeyId);
      if (masterKey == null) return false;

      final parts = encryptedKey.split(':');
      if (parts.length != 2) return false;

      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);

      final masterEncrypter = Encrypter(AES(masterKey));
      final keyBase64 = masterEncrypter.decrypt(encrypted, iv: iv);
      final key = Key.fromBase64(keyBase64);

      await _storeKey(keyId, key);
      return true;
    } catch (e) {
      debugPrint('Error importing key $keyId: $e');
      return false;
    }
  }

  /// Dispose of the service
  void dispose() {
    clearCache();
    _instance = null;
  }
}
