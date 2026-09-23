import { Module } from '@nestjs/common';
import { BookingsController } from './bookings.controller';
import { GroupBookingsController } from './group-bookings.controller';
import { BookingsService } from './bookings.service';
import { GroupBookingsService } from './group-bookings.service';
import { BookingStateMachineModule } from '../booking-state-machine/booking-state-machine.module';
import { QuotesModule } from '../quotes/quotes.module';
import { AvailabilityModule } from '../availability/availability.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [BookingStateMachineModule, QuotesModule, AvailabilityModule, NotificationsModule],
  controllers: [BookingsController, GroupBookingsController],
  providers: [BookingsService, GroupBookingsService],
  exports: [BookingsService, GroupBookingsService],
})
export class BookingsModule {}
