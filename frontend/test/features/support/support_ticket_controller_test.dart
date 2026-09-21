import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/support/presentation/controllers/support_ticket_controller.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  SupportTicketController makeController() {
    container.listen(supportTicketControllerProvider, (_, _) {});
    return container.read(supportTicketControllerProvider.notifier);
  }

  group('Support Ticket', () {
    test('successful submission returns a ticket ID', () async {
      final controller = makeController();

      await controller.submitTicket(
        bookingId: 'bk_mock_req_1',
        category: supportTicketCategories.first,
        message: 'Chauffeur arrived 40 minutes late to the haldi ceremony.',
      );

      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.ticketId, startsWith('TKT-'));
      expect(controller.state.errorMessage, isNull);
    });

    test('reset clears the submitted state', () async {
      final controller = makeController();

      await controller.submitTicket(
        bookingId: 'none',
        category: supportTicketCategories.last,
        message: 'General billing question about the advance token.',
      );

      expect(controller.state.isSuccess, isTrue);

      controller.reset();

      expect(controller.state.isSuccess, isFalse);
      expect(controller.state.ticketId, isNull);
    });
  });
}
