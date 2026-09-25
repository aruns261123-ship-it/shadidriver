import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './services/otp.service';
import { TokenService } from './services/token.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { NotificationsModule } from '../notifications/notifications.module';
import { CONFIG_TOKEN, AppConfig } from '../config/configuration';

@Module({
  // The JwtService ALSO verifies tokens (JwtAuthGuard.verifyAsync), so the
  // access secret and issuer must be registered module-wide — not only passed
  // per-call in TokenService.signAsync. Without this, every verify call runs
  // with an undefined secret and rejects all legitimate tokens.
  imports: [
    JwtModule.registerAsync({
      inject: [CONFIG_TOKEN],
      useFactory: (config: AppConfig) => ({
        secret: config.jwt.accessSecret,
        verifyOptions: { issuer: config.jwt.issuer },
      }),
    }),
    NotificationsModule,
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    TokenService,
    // Global guards: every route requires a valid token unless @Public(),
    // and every route is role-checked via @Roles().
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
  exports: [AuthService, TokenService, JwtModule],
})
export class AuthModule {}
