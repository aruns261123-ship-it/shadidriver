import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/security/in_memory_secure_storage.dart';

void main() {
  group('SecureStorageService (InMemory Implementation) Tests', () {
    late InMemorySecureStorage storage;

    setUp(() {
      storage = InMemorySecureStorage();
    });

    test('writes and reads keys correctly', () async {
      await storage.write('auth_token', 'jwt_test_123');
      final value = await storage.read('auth_token');

      expect(value, equals('jwt_test_123'));
    });

    test('returns null for non-existent key', () async {
      final value = await storage.read('non_existent');
      expect(value, isNull);
    });

    test('containsKey returns true when key present', () async {
      await storage.write('device_id', 'dev_456');

      expect(await storage.containsKey('device_id'), isTrue);
      expect(await storage.containsKey('unknown_key'), isFalse);
    });

    test('delete removes specified key', () async {
      await storage.write('temp_key', 'temp_val');
      await storage.delete('temp_key');

      expect(await storage.read('temp_key'), isNull);
    });

    test('deleteAll clears all stored entries', () async {
      await storage.write('k1', 'v1');
      await storage.write('k2', 'v2');
      await storage.deleteAll();

      expect(await storage.read('k1'), isNull);
      expect(await storage.read('k2'), isNull);
    });
  });
}
