import { store } from '../store/memory-store.js';
import { clone } from '../utils/crypto.js';
import { ok } from './envelope.js';

export function idempotencyMiddleware(req, res, next) {
  if (!['POST', 'PUT', 'PATCH'].includes(req.method)) return next();
  const key = req.header('idempotency-key') || req.header('x-idempotency-key');
  if (!key) return next();

  const cacheKey = `${req.user?.id || 'anon'}:${req.method}:${req.path}:${key}`;
  const cached = store.idempotency.get(cacheKey);
  if (cached) {
    return res.status(cached.status).json(cached.body);
  }

  const originalJson = res.json.bind(res);
  res.json = (body) => {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      store.idempotency.set(cacheKey, { status: res.statusCode, body: clone(body) });
    }
    return originalJson(body);
  };
  next();
}

export { ok };
