import { Module } from '@nestjs/common';
import { BookingStateMachineModule } from '../booking-state-machine/booking-state-machine.module';
import { BookingsModule } from '../bookings/bookings.module';
import { PaymentsController } from './payments.controller';
import { PaymentsService, PAYMENT_GATEWAY } from './payments.service';
import { MockPaymentGateway } from './mock-gateway.provider';
import { RazorpayGateway } from './razorpay-gateway.provider';
import { PaymentGateway } from './payment-gateway.interface';

@Module({
  imports: [BookingStateMachineModule, BookingsModule],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    {
      provide: PAYMENT_GATEWAY,
      useFactory: (): PaymentGateway => {
        const gateway = (process.env.PAYMENT_GATEWAY ?? 'mock').toLowerCase();
        if (gateway === 'razorpay') {
          // REAL integration: fails at boot when merchant credentials are
          // missing — production never runs a gateway that cannot collect.
          return new RazorpayGateway();
        }
        if (gateway === 'mock') {
          return new MockPaymentGateway();
        }
        throw new Error(
          `Unknown PAYMENT_GATEWAY '${gateway}'. Supported: razorpay (real), mock (development only).`,
        );
      },
    },
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}
