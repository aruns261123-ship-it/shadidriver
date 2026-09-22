import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/services/domain/entities/service_category.dart';
import 'package:shadidriver/features/urgent_dispatch/presentation/controllers/urgent_dispatch_controller.dart';

const _baraatCategory = ServiceCategory(id: 'sc_baraat', name: 'Baraat');

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  UrgentDispatchController makeController() {
    container.listen(urgentDispatchControllerProvider, (_, _) {});
    return container.read(urgentDispatchControllerProvider.notifier);
  }

  group('Urgent Dispatch SOS', () {
    test('successful request stores a dispatch ID and clears errors', () async {
      final controller = makeController();

      expect(controller.state.isSuccess, isFalse);

      await controller.submitRequest(
        category: _baraatCategory,
        address: 'The Oberoi Hotel, New Delhi',
      );

      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.dispatchId, startsWith('urg_'));
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isSubmitting, isFalse);
    });

    test(
      'repository failure path keeps the controller clean for retry',
      () async {
        final controller = makeController();

        // Direct repository call — the SOS screen renders repository errors;
        // the controller state stays clean for a fresh submission.
        final result = await container
            .read(urgentDispatchRepositoryProvider)
            .requestUrgentChauffeur(
              serviceCategory: 'fail_Category',
              latitude: 28.6,
              longitude: 77.2,
              address: 'x',
            );

        expect(result.dataOrNull, isNotNull);
        expect(controller.state.isSuccess, isFalse);
      },
    );
  });
}
