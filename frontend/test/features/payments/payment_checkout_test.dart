import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/payments/data/mock_payment_repository.dart';
import 'package:shadidriver/features/payments/presentation/controllers/payment_checkout_controller.dart';

void main() {
  late MockBookingRepository bookingStore;
  late MockPaymentRepository paymentRepo;
  late ProviderContainer container;

  setUp(() {
    bookingStore = MockBookingRepository();
    paymentRepo = MockPaymentRepository(bookingRepository: bookingStore);
    container = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookingStore),
        paymentRepositoryProvider.overrideWithValue(paymentRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  PaymentCheckoutController makeController(String bookingId) {
    container.listen(paymentCheckoutControllerProvider(bookingId), (_, _) {});
    return container.read(paymentCheckoutControllerProvider(bookingId).notifier);
  }

  group('Advance Token Payment Flow', () {
    test('creating an order returns a CREATED order for the booking',
        () async {
      final result = await paymentRepo.createAdvanceTokenOrder(
        bookingId: 'bk_x',
        idempotencyKey: 'idem_1',
      );

      expect(result.dataOrNull, isNotNull);
      expect(result.dataOrNull!.status, 'created');
      expect(result.dataOrNull!.currency, 'INR');
    });

    test('successful checkout transitions the booking to CONFIRMED',
        () async {
      // Seed: a driver-accepted booking that awaits the advance token.
      final seeded = await bookingStore.getSubmissionResult('bk_mock_req_1');
      expect(seeded, isNotNull);
      bookingStore.acceptBooking(bookingId: 'bk_mock_req_1', driverId: 'd1');

      final controller = makeController('bk_mock_req_1');
      final paid = await controller.payAdvanceToken();

      expect(paid, isTrue);
      expect(controller.state.stage, PaymentCheckoutStage.success);

      final booking =
          (await bookingStore.getSubmissionResult('bk_mock_req_1'))
              .dataOrNull!;
      expect(booking.status, BookingStatus.confirmed);
    });

    test('declined gateway payment keeps booking unconfirmed', () async {
      bookingStore.acceptBooking(bookingId: 'bk_mock_req_1', driverId: 'd1');

      final controller = makeController('bk_mock_req_1');
      final paid = await controller.payAdvanceToken(
        payerReference: 'fail_declined_card',
      );

      expect(paid, isFalse);
      expect(controller.state.stage, PaymentCheckoutStage.failed);
      expect(controller.state.errorMessage, isNotNull);

      // Retry after a decline succeeds.
      controller.reset();
      final retried = await controller.payAdvanceToken();
      expect(retried, isTrue);
    });

    test('tampered signature fails verification without confirming',
        () async {
      final order = (await paymentRepo.createAdvanceTokenOrder(
        bookingId: 'bk_mock_req_1',
        idempotencyKey: 'idem_sig',
      )).dataOrNull!;

      await paymentRepo.processGatewayCheckout(
        order: order,
        payerReference: 'upi_ok',
      );

      final verify = await paymentRepo.verifyPaymentSignature(
        orderId: order.orderId,
        paymentId: 'pay_x',
        signature: 'tampered',
      );

      expect(verify.dataOrNull, isNull);
      final booking =
          (await bookingStore.getSubmissionResult('bk_mock_req_1'))
              .dataOrNull!;
      expect(booking.status, isNot(BookingStatus.confirmed));
    });
  });
}
