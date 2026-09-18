function toCamel(key) {
  return String(key).replace(/_([a-z])/g, (_, c) => c.toUpperCase());
}

export function normalizeKeys(value) {
  if (Array.isArray(value)) return value.map(normalizeKeys);
  if (!value || typeof value !== 'object') return value;
  const out = {};
  for (const [key, nested] of Object.entries(value)) {
    const camel = toCamel(key);
    const next = normalizeKeys(nested);
    out[key] = next;
    if (!(camel in out)) out[camel] = next;
  }
  return out;
}

export function pick(body, ...keys) {
  const src = body || {};
  for (const key of keys) {
    if (src[key] !== undefined && src[key] !== null) return src[key];
  }
  return undefined;
}
