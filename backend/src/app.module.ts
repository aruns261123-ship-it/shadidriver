import { Module } from '@nestjs/common';
import { AppConfigModule } from './config/config.module';
import { DatabaseModule } from './database/database.module';
import { RedisModule } from './redis/redis.module';
import { CommonModule } from './common/common.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { NotificationsModule } from './notifications/notifications.module';
import { UsersModule } from './users/users.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { QuotesModule } from './quotes/quotes.module';
import { AvailabilityModule } from './availability/availability.module';
import { BookingsModule } from './bookings/bookings.module';
import { PaymentsModule } from './payments/payments.module';

/**
 * Modular monolith root. Each feature slice registers its own module;
 * cross-cutting concerns live in CommonModule / AppConfigModule.
 */
@Module({
  imports: [
    AppConfigModule,
    DatabaseModule,
    RedisModule,
    CommonModule,
    HealthModule,
    AuthModule,
    NotificationsModule,
    UsersModule,
    VehiclesModule,
    QuotesModule,
    AvailabilityModule,
    BookingsModule,
    PaymentsModule,
    // NEXT: AdminModule, AuditModule
  ],
})
export class AppModule {}
