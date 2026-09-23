import { Global, Module } from '@nestjs/common';
import { SMS_PROVIDER, createSmsProvider } from './sms/sms.factory';

@Global()
@Module({
  providers: [
    {
      provide: SMS_PROVIDER,
      useFactory: createSmsProvider,
    },
  ],
  exports: [SMS_PROVIDER],
})
export class NotificationsModule {}
