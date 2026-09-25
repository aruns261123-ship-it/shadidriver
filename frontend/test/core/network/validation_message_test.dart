import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/network/validation_messages.dart';

void main() {
  group('parseFieldErrors', () {
    test('recognises a forbidden (unknown) property', () {
      final errors = parseFieldErrors(['property pickup_address should not exist']);
      expect(errors.single.field, 'pickup_address');
      expect(errors.single.rule, ValidationRule.unknownProperty);
      expect(unknownProperties(errors), ['pickup_address']);
    });

    test('recognises @Length lower and upper bounds', () {
      final errors = parseFieldErrors([
        'pickupAddress must be longer than or equal to 5 characters',
        'destinationAddress must be shorter than or equal to 500 characters',
      ]);
      expect(errors[0].rule, ValidationRule.minLength);
      expect(errors[0].limit, 5);
      expect(errors[1].rule, ValidationRule.maxLength);
      expect(errors[1].limit, 500);
      expect(unknownProperties(errors), isEmpty);
    });

    test('recognises numeric bounds, empty and enum rules', () {
      expect(
        parseFieldErrors(['passengerCount must not be less than 1']).single.rule,
        ValidationRule.minimum,
      );
      expect(
        parseFieldErrors(['passengerCount must not be greater than 60']).single
            .limit,
        60,
      );
      expect(
        parseFieldErrors(['city should not be empty']).single.rule,
        ValidationRule.required,
      );
      expect(
        parseFieldErrors([
          'role must be one of the following values: customer, driver',
        ]).single.rule,
        ValidationRule.oneOf,
      );
    });

    test('keeps the field name for a custom message', () {
      final errors = parseFieldErrors([
        'phoneNumber must be an E.164 string like +919876543210 (leading +, no spaces or formatting characters).',
      ]);
      expect(errors.single.field, 'phoneNumber');
      expect(unknownProperties(errors), isEmpty);
    });
  });

  group('humanizeField', () {
    test('turns wire names into words', () {
      expect(humanizeField('pickupAddress'), 'pickup address');
      expect(humanizeField('routeDistanceKm'), 'route distance km');
      expect(humanizeField('primaryContactPhone'), 'primary contact phone');
      expect(humanizeField('city'), 'city');
    });
  });

  group('customerValidationMessage', () {
    test('a supported field with a bad value is never called drift', () {
      final message = customerValidationMessage({
        'pickupAddress': [
          'pickupAddress must be longer than or equal to 5 characters',
        ],
        'destinationAddress': [
          'destinationAddress must be longer than or equal to 5 characters',
        ],
      });

      expect(message, isNotNull);
      expect(message, isNot(contains('unsupported field')));
      expect(message, contains('Pickup address'));
      expect(message, contains('at least 5 characters'));
    });

    test('a short address on an unpublished field still reads well', () {
      final message = customerValidationMessage({
        'specialInstructions': [
          'specialInstructions must be shorter than or equal to 20 characters',
        ],
      });
      expect(message, 'Special instructions must be 20 characters or fewer.');
    });

    test('only a truly unknown property reports contract drift', () {
      final message = customerValidationMessage({
        'pickup_address': ['property pickup_address should not exist'],
      });
      expect(message, contains('unsupported field'));
      expect(message, contains('pickup_address'));
    });

    test('keeps the bespoke wording for auth fields', () {
      expect(
        customerValidationMessage({
          'phoneNumber': ['phoneNumber must be a string'],
        }),
        'Enter a valid mobile number.',
      );
    });

    test('returns null when nothing useful can be said', () {
      expect(customerValidationMessage(const {}), isNull);
    });
  });
}
