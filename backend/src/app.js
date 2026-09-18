import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { config } from './config.js';
import { correlationMiddleware, normalizeBodyMiddleware } from './middleware/correlation.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';
import { mountRoutes } from './routes/index.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet({ contentSecurityPolicy: false }));
  app.use(cors({ origin: config.corsOrigin === '*' ? true : config.corsOrigin, credentials: true }));
  app.use(express.json({ limit: '2mb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use(correlationMiddleware);
  app.use(normalizeBodyMiddleware);
  mountRoutes(app);
  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
