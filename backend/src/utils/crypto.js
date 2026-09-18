import { createHmac, createHash, randomInt, randomUUID, timingSafeEqual } from 'crypto';

export function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

export function hmacSha256(secret, payload) {
  return createHmac('sha256', secret).update(payload).digest('hex');
}

export function timingSafeEqualHex(a, b) {
  const left = Buffer.from(String(a || ''), 'utf8');
  const right = Buffer.from(String(b || ''), 'utf8');
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

export function generateOtp() {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

export function generateStartOtp() {
  return randomInt(0, 10_000).toString().padStart(4, '0');
}

export function newId() {
  return randomUUID();
}

export function clone(value) {
  return structuredClone(value);
}
