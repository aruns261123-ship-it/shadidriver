import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/domain/entities/search_handoff.dart';

void main() {
  group('SearchHandoff', () {
    test('hasAny is true when any field carries intent', () {
      expect(
        const SearchHandoff(destination: 'Taj Palace').hasAny,
        isTrue,
      );
      expect(
        SearchHandoff(eventDate: DateTime(2026, 11, 20)).hasAny,
        isTrue,
      );
      expect(const SearchHandoff(occasion: 'Baraat').hasAny, isTrue);
      expect(const SearchHandoff(passengerCount: 4).hasAny, isTrue);
      expect(const SearchHandoff(pickupLocation: 'Delhi NCR').hasAny, isTrue);
    });

    test('hasAny is false for empty/blank handoff', () {
      expect(const SearchHandoff().hasAny, isFalse);
      expect(
        const SearchHandoff(
          destination: '  ',
          pickupLocation: '',
          occasion: '',
        ).hasAny,
        isFalse,
      );
      expect(const SearchHandoff(passengerCount: 0).hasAny, isFalse);
    });

    test('equality is value-based (immutable value object)', () {
      final a = SearchHandoff(
        destination: 'Taj Palace',
        eventDate: DateTime(2026, 11, 20),
        passengerCount: 4,
      );
      final b = SearchHandoff(
        destination: 'Taj Palace',
        eventDate: DateTime(2026, 11, 20),
        passengerCount: 4,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
