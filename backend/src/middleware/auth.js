import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { AppError, HttpStatus } from '../errors.js';
import { store } from '../store/memory-store.js';
import { isAdminRole } from '../domain/roles.js';

export function authenticate(required = true) {
  return (req, _res, next) => {
    const header = req.header('authorization') || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) {
      if (!required) return next();
      return next(new AppError('UNAUTHORIZED', 'Access token is required.', HttpStatus.UNAUTHORIZED));
    }
    try {
      const payload = jwt.verify(token, config.jwtAccessSecret);
      const user = store.users.get(payload.sub);
      if (!user) {
        return next(new AppError('AUTH_INVALID_TOKEN', 'Account no longer exists.', HttpStatus.UNAUTHORIZED));
      }
      req.user = {
        id: user.id,
        role: user.role,
        accountStatus: user.accountStatus,
        fullName: user.fullName,
        phoneNumber: user.phoneNumber,
      };
      next();
    } catch {
      next(new AppError('AUTH_INVALID_TOKEN', 'Access token expired, invalid, or revoked.', HttpStatus.UNAUTHORIZED));
    }
  };
}

export function requireRoles(...roles) {
  return (req, _res, next) => {
    if (!req.user) {
      return next(new AppError('UNAUTHORIZED', 'Authentication required.', HttpStatus.UNAUTHORIZED));
    }
    if (req.user.role === 'superAdmin') return next();
    if (roles.includes(req.user.role)) return next();
    return next(new AppError('ROLE_FORBIDDEN', 'Actor lacks role permission for the requested resource.', HttpStatus.FORBIDDEN));
  };
}

export function requireAdmin(req, _res, next) {
  if (!req.user || !isAdminRole(req.user.role)) {
    return next(new AppError('ROLE_FORBIDDEN', 'Admin access required.', HttpStatus.FORBIDDEN));
  }
  next();
}
