/// Interface for hardware-backed secure key-value storage.
/// Protects tokens and sensitive session credentials without coupling the app to a specific package.
abstract interface class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
  Future<bool> containsKey(String key);
}
