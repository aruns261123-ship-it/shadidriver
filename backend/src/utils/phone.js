export function normalizePhone(input) {
  const digits = String(input || '').replace(/\D/g, '');
  if (digits.length === 10) return `+91${digits}`;
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`;
  if (String(input || '').startsWith('+') && digits) return `+${digits}`;
  return `+${digits}`;
}

export function isValidIndianPhone(input) {
  return /^\+91[6-9]\d{9}$/.test(normalizePhone(input));
}

export function nationalNumber(e164) {
  return String(e164 || '').replace(/^\+91/, '').replace(/\D/g, '').slice(-10);
}

export function maskPhone(e164) {
  const digits = String(e164 || '').replace(/\D/g, '');
  if (digits.length < 4) return '+91 ••••• •••••';
  return `+91 ••••• ••${digits.slice(-3)}`;
}

export function maskName(name) {
  const parts = String(name || '').trim().split(/\s+/);
  if (!parts[0]) return 'Host';
  if (parts.length === 1) return `Host: ${parts[0]}`;
  return `Host: ${parts[0]} ${parts[1][0].toUpperCase()}.`;
}
