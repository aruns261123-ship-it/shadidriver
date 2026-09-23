import { Module } from '@nestjs/common';
import { BookingStateMachineModule } from '../booking-state-machine/booking-state-machine.module';
import { PaymentsController } from './payments.controller';
import { PaymentsService, PAYMENT_GATEWAY } from './payments.service';
import { MockPaymentGateway } from './mock-gateway.provider';
import { PaymentGateway } from './payment-gateway.interface';

@Module({
  imports: [BookingStateMachineModule],
  controllers: [PaymentsController],
  providers: [
    PaymentsService,
    {
      provide: PAYMENT_GATEWAY,
      useFactory: (): PaymentGateway => {
        const gateway = (process.env.PAYMENT_GATEWAY ?? 'mock').toLowerCase();
        if (gateway === 'razorpay') {
          // Razorpay adapter lands with real merchant credentials (ADR-013).
          throw new Error(
            'Razorpay adapter requires merchant credentials; implement RazorpayGateway in src/payments/ and provide PAYMENT_KEY_ID/PAYMENT_KEY_SECRET.',
          );
        }
        return new MockPaymentGateway();
      },
    },
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}
