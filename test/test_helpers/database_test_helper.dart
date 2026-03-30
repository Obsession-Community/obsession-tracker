import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseTestHelper {
  static bool _initialized = false;
  static const String _testDbPath = '/tmp/test_app_documents';

  // In-memory storage for secure storage mock
  static final Map<String, String> _mockSecureStorage = {};

  static Future<void> initializeTestDatabase() async {
    if (_initialized) return;

    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Set up method channel mock for path provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return _testDbPath;
        }
        return null;
      },
    );

    // Set up method channel mock for flutter_secure_storage
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (methodCall) async {
        switch (methodCall.method) {
          case 'read':
            final key = methodCall.arguments['key'] as String;
            return _mockSecureStorage[key];
          case 'write':
            final key = methodCall.arguments['key'] as String;
            final value = methodCall.arguments['value'] as String;
            _mockSecureStorage[key] = value;
            return null;
          case 'delete':
            final key = methodCall.arguments['key'] as String;
            _mockSecureStorage.remove(key);
            return null;
          case 'deleteAll':
            _mockSecureStorage.clear();
            return null;
          case 'readAll':
            return _mockSecureStorage;
          case 'containsKey':
            final key = methodCall.arguments['key'] as String;
            return _mockSecureStorage.containsKey(key);
          default:
            return null;
        }
      },
    );

    _initialized = true;
  }

  /// Close database connections and clean up test database
  static Future<void> resetTestDatabase() async {
    try {
      // Delete the test database file
      final dbFile = File('$_testDbPath/obsession_tracker.db');
      if (dbFile.existsSync()) {
        dbFile.deleteSync();
      }

      // Also delete WAL and SHM files if they exist
      final walFile = File('$_testDbPath/obsession_tracker.db-wal');
      if (walFile.existsSync()) {
        walFile.deleteSync();
      }

      final shmFile = File('$_testDbPath/obsession_tracker.db-shm');
      if (shmFile.existsSync()) {
        shmFile.deleteSync();
      }
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  /// Wait a bit to allow database locks to clear
  static Future<void> waitForDatabaseRelease() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
