import { Module } from '@nestjs/common';
import { BookingStateMachineService } from './booking-state-machine.service';

@Module({
  providers: [BookingStateMachineService],
  exports: [BookingStateMachineService],
})
export class BookingStateMachineModule {}
