import { Module } from '@nestjs/common';
import { BookingsModule } from '../bookings/bookings.module';
import { BookingStateMachineModule } from '../booking-state-machine/booking-state-machine.module';
import { OperationsController } from './operations.controller';
import { OperationsService } from './operations.service';

/**
 * Operations desk: consumes the customer booking requests produced by
 * BookingsModule and drives the managed-booking lifecycle. It reuses
 * GroupBookingsService for writes so there is exactly ONE writer of group
 * booking state transitions (and therefore one place that writes history).
 */
@Module({
  imports: [BookingsModule, BookingStateMachineModule],
  controllers: [OperationsController],
  providers: [OperationsService],
  exports: [OperationsService],
})
export class OperationsModule {}
