import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_storage_service.dart';

/// Implementation of [SecureStorageService] using FlutterSecureStorage.
/// Utilizes Android KeyStore (EncryptedSharedPreferences) and iOS Keychain.
class FlutterSecureStorageImpl implements SecureStorageService {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageImpl([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  @override
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  @override
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }
}
