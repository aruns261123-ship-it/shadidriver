import 'secure_storage_service.dart';

/// In-memory implementation of [SecureStorageService] for fast, isolated unit testing.
class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);
}
