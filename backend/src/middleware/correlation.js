import { randomUUID } from 'crypto';
import { normalizeKeys } from '../utils/body.js';

export function correlationMiddleware(req, res, next) {
  const id = req.header('x-correlation-id') || randomUUID();
  req.correlationId = id;
  res.setHeader('X-Correlation-ID', id);
  next();
}

export function normalizeBodyMiddleware(req, _res, next) {
  if (req.body && typeof req.body === 'object') {
    req.body = normalizeKeys(req.body);
  }
  next();
}
