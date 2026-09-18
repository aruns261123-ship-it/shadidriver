export function ok(res, data, status = 200, meta) {
  const body = { success: true, data: data ?? null };
  if (meta) body.meta = meta;
  return res.status(status).json(body);
}

export function wrap(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}
