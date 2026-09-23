import { Global, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { CONFIG_TOKEN, loadConfig } from './configuration';

@Global()
@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true, cache: true })],
  providers: [
    {
      provide: CONFIG_TOKEN,
      inject: [ConfigService],
      useFactory: () => loadConfig(),
    },
  ],
  exports: [CONFIG_TOKEN, ConfigModule],
})
export class AppConfigModule {}
