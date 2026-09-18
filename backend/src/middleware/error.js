import { AppError, HttpStatus } from '../errors.js';

export function errorHandler(err, req, res, _next) {
  if (err instanceof AppError) {
    return res.status(err.status).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
      },
    });
  }

  if (err.name === 'UnauthorizedError' || err.status === 401) {
    return res.status(401).json({
      success: false,
      error: { code: 'UNAUTHORIZED', message: err.message || 'Unauthorized.' },
    });
  }

  console.error(`[${req.correlationId || '-'}] ${req.method} ${req.originalUrl}`, err);
  return res.status(HttpStatus.INTERNAL).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred.',
    },
  });
}

export function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: `No route for ${req.method} ${req.path}`,
    },
  });
}
