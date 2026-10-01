import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/theme/shadi_imagery.dart';

void main() {
  group('ShadiImagery media-origin resolution', () {
    test('configureMediaOrigin extracts scheme/host/port from API base URL',
        () {
      ShadiImagery.configureMediaOrigin('http://10.0.2.2:3000/api/v1');
      expect(ShadiImagery.mediaOrigin, 'http://10.0.2.2:3000');
    });

    test('server-relative /media URLs resolve to absolute loadable URLs', () {
      ShadiImagery.configureMediaOrigin('http://10.0.2.2:3000/api/v1');
      final resolved = ShadiImagery.forVehicle(
        '/media/vehicles/innova_crysta_01.jpg',
        vehicleId: 'v1',
      );
      expect(resolved, 'http://10.0.2.2:3000/media/vehicles/innova_crysta_01.jpg');
      expect(ShadiImagery.isAsset(resolved), isFalse);
    });

    test('absolute http URLs pass through untouched', () {
      ShadiImagery.configureMediaOrigin('http://10.0.2.2:3000/api/v1');
      const absolute = 'https://cdn.example.com/car.jpg';
      expect(
        ShadiImagery.forVehicle(absolute, vehicleId: 'v1'),
        absolute,
      );
    });

    test('null or empty URLs still fall back to bundled reference assets', () {
      ShadiImagery.configureMediaOrigin('http://10.0.2.2:3000/api/v1');
      final fallback =
          ShadiImagery.forVehicle(null, vehicleId: 'deterministic-id');
      expect(fallback, startsWith('assets/'));
      expect(ShadiImagery.isAsset(fallback), isTrue);
    });

    test('unconfigured origin falls back to bundled assets for relative URLs',
        () {
      final previousOrigin = ShadiImagery.mediaOrigin;
      ShadiImagery.mediaOrigin = '';
      addTearDown(() => ShadiImagery.mediaOrigin = previousOrigin);
      final fallback = ShadiImagery.forVehicle(
        '/media/vehicles/innova_crysta_01.jpg',
        vehicleId: 'v1',
      );
      expect(fallback, startsWith('assets/'));
    });
  });
}
