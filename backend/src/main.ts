import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { RequestIdMiddleware } from './common/middleware/request-id.middleware';
import { BigIntSerialInterceptor } from './common/interceptors/bigint-serial.interceptor';
import { CONFIG_TOKEN, AppConfig } from './config/configuration';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: false,
  });

  const config: AppConfig = app.get(CONFIG_TOKEN);
  const logger = new Logger('Bootstrap');

  app.use(helmet());
  app.enableCors({
    origin: config.corsOrigins,
    credentials: true,
  });
  app.use(new RequestIdMiddleware().use.bind(new RequestIdMiddleware()));
  app.setGlobalPrefix(config.apiPrefix, { exclude: ['health'] });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: false },
    }),
  );

  app.useGlobalFilters(new GlobalExceptionFilter());

  // BigInt paise amounts must reach clients as strings — JSON.stringify
  // cannot serialize BigInt and would 500 every booking response.
  app.useGlobalInterceptors(new BigIntSerialInterceptor());

  if (config.enableSwagger) {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('ShadiDriver API')
      .setDescription(
        'Premium Indian wedding & event chauffeur marketplace. ' +
          'Server-authoritative booking state machine, fleet allocation, and pricing.',
      )
      .setVersion('0.1')
      .addBearerAuth()
      .addTag('auth')
      .addTag('health')
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  await app.listen(config.port);
  logger.log(`ShadiDriver API listening on :${config.port} (${config.env})`);
  if (config.enableSwagger) {
    logger.log(`Swagger docs at /${config.apiPrefix}/../docs or /api/docs`);
  }
}

void bootstrap();
