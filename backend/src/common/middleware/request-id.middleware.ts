import { Injectable, NestMiddleware } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';
import { randomUUID } from 'crypto';

/**
 * Assigns a correlation ID to every request (honoring an inbound
 * X-Correlation-ID) and echoes it back on the response.
 */
@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  use(req: Request & { id?: string; correlationId?: string }, res: Response, next: NextFunction): void {
    const inbound = req.headers['x-correlation-id'];
    const id =
      typeof inbound === 'string' && inbound.length > 0 ? inbound : randomUUID();
    req.id = id;
    req.correlationId = id;
    res.setHeader('X-Correlation-ID', id);
    next();
  }
}
