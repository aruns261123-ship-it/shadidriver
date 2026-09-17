import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/profile/domain/entities/saved_address.dart';
import 'package:shadidriver/features/profile/data/mock_saved_addresses_repository.dart';
import 'package:shadidriver/features/profile/presentation/controllers/saved_addresses_controller.dart';

void main() {
  group('SavedAddress Entity & AddressType Tests', () {
    test('AddressType enums have correct display labels', () {
      expect(AddressType.home.displayLabel, equals('Home'));
      expect(AddressType.work.displayLabel, equals('Work'));
      expect(AddressType.weddingVenue.displayLabel, equals('Wedding Venue'));
      expect(AddressType.family.displayLabel, equals('Family / Relatives'));
      expect(AddressType.other.displayLabel, equals('Other'));
    });

    test('SavedAddress copyWith updates properties correctly', () {
      const addr = SavedAddress(
        id: 'addr_1',
        customerId: 'cust_101',
        label: 'Grand Hyatt Goa',
        address: 'Bambolim, Goa 403201',
        landmark: 'Near Bambolim Bay',
        type: AddressType.weddingVenue,
        isDefault: true,
      );

      expect(addr.id, equals('addr_1'));
      expect(addr.isDefault, isTrue);

      final updated = addr.copyWith(
        label: 'Grand Hyatt Banquet Hall A',
        isDefault: false,
      );

      expect(updated.label, equals('Grand Hyatt Banquet Hall A'));
      expect(updated.isDefault, isFalse);
      expect(updated.id, equals('addr_1'));
      expect(updated.customerId, equals('cust_101'));
    });
  });

  group('MockSavedAddressesRepository Tests', () {
    late MockSavedAddressesRepository repository;

    setUp(() {
      repository = MockSavedAddressesRepository();
    });

    test('getAddresses returns seeded addresses for cust_101', () async {
      final res = await repository.getAddresses('cust_101');
      expect(res.isSuccess, isTrue);
      final list = res.dataOrNull!;
      expect(list.length, greaterThanOrEqualTo(2));
      expect(list.any((a) => a.isDefault), isTrue);
    });

    test('addAddress adds a new address', () async {
      const newAddr = SavedAddress(
        id: 'addr_test',
        customerId: 'cust_101',
        label: 'Taj Palace',
        address: 'Sardar Patel Marg, Diplomatic Enclave, New Delhi',
        type: AddressType.weddingVenue,
        isDefault: false,
      );

      final addRes = await repository.addAddress(newAddr);
      expect(addRes.isSuccess, isTrue);

      final getRes = await repository.getAddresses('cust_101');
      final list = getRes.dataOrNull!;
      expect(list.any((a) => a.id == 'addr_test'), isTrue);
    });

    test('updateAddress updates existing address', () async {
      final list = (await repository.getAddresses('cust_101')).dataOrNull!;
      final target = list.first;

      final updated = target.copyWith(label: 'Updated Label Test');
      final updateRes = await repository.updateAddress(updated);
      expect(updateRes.isSuccess, isTrue);

      final refreshed = (await repository.getAddresses('cust_101')).dataOrNull!;
      expect(
        refreshed.firstWhere((a) => a.id == target.id).label,
        equals('Updated Label Test'),
      );
    });

    test('deleteAddress removes the address', () async {
      final listBefore = (await repository.getAddresses(
        'cust_101',
      ))
          .dataOrNull!;
      final toDelete = listBefore.first.id;

      final delRes = await repository.deleteAddress(
        customerId: 'cust_101',
        addressId: toDelete,
      );
      expect(delRes.isSuccess, isTrue);

      final listAfter = (await repository.getAddresses('cust_101')).dataOrNull!;
      expect(listAfter.any((a) => a.id == toDelete), isFalse);
    });
  });

  group('SavedAddressesController Tests', () {
    late MockSavedAddressesRepository repository;
    late SavedAddressesController controller;

    setUp(() {
      repository = MockSavedAddressesRepository();
      controller = SavedAddressesController(
        repository: repository,
        customerId: 'cust_101',
      );
    });

    test('initializes and loads addresses', () async {
      await controller.loadAddresses();
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.addresses.isNotEmpty, isTrue);
    });

    test('addAddress handles default flag exclusivity', () async {
      await controller.loadAddresses();

      const newDefault = SavedAddress(
        id: 'new_default_addr',
        customerId: 'cust_101',
        label: 'ITC Maurya',
        address: 'Diplomatic Enclave, Chanakyapuri, New Delhi',
        type: AddressType.weddingVenue,
        isDefault: true,
      );

      final success = await controller.addAddress(newDefault);
      expect(success, isTrue);

      final addresses = controller.state.addresses;
      final defaultItems = addresses.where((a) => a.isDefault).toList();
      expect(defaultItems.length, equals(1));
      expect(defaultItems.first.id, equals('new_default_addr'));
    });

    test('deleteAddress updates controller state', () async {
      await controller.loadAddresses();
      final firstId = controller.state.addresses.first.id;

      final success = await controller.deleteAddress(firstId);
      expect(success, isTrue);
      expect(controller.state.addresses.any((a) => a.id == firstId), isFalse);
    });
  });
}
