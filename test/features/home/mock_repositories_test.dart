import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  group('Mock Repositories Verification', () {
    late MockVehicleRepository vehicleRepo;
    late MockServiceCategoryRepository categoryRepo;

    setUp(() {
      vehicleRepo = MockVehicleRepository();
      categoryRepo = MockServiceCategoryRepository();
    });

    test('MockVehicleRepository returns featured vehicles', () async {
      final result = await vehicleRepo.getFeaturedVehicles();
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.length, equals(3));
      expect(result.dataOrNull![0].make, equals('BMW'));
    });

    test(
      'MockServiceCategoryRepository returns ceremonial categories',
      () async {
        final result = await categoryRepo.getCategories();
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull!.any((c) => c.name == 'Wedding Cars'), isTrue);
      },
    );
  });
}
