import { WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { store } from '../store/memory-store.js';
import { bookingsService } from '../services/bookings.service.js';

const bookingRooms = new Map();

function addToRoom(bookingId, socket) {
  if (!bookingRooms.has(bookingId)) bookingRooms.set(bookingId, new Set());
  bookingRooms.get(bookingId).add(socket);
}

function removeSocket(socket) {
  for (const room of bookingRooms.values()) room.delete(socket);
}

export function broadcastTracking(bookingId, payload) {
  const room = bookingRooms.get(bookingId);
  if (!room) return;
  const raw = JSON.stringify(payload);
  for (const client of room) {
    if (client.readyState === 1) client.send(raw);
  }
}

function parseToken(req) {
  const url = new URL(req.url, 'http://localhost');
  const header = req.headers.authorization || '';
  const fromHeader = header.startsWith('Bearer ') ? header.slice(7) : null;
  return url.searchParams.get('token') || fromHeader;
}

function userFromToken(token) {
  if (!token) return null;
  try {
    const payload = jwt.verify(token, config.jwtAccessSecret);
    const user = store.users.get(payload.sub);
    if (!user) return null;
    return { id: user.id, role: user.role };
  } catch {
    return null;
  }
}

export function attachTracking(server) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (req, socket, head) => {
    const url = new URL(req.url, 'http://localhost');
    if (!url.pathname.startsWith('/ws/v1/tracking')) {
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  });

  wss.on('connection', (ws, req) => {
    const url = new URL(req.url, 'http://localhost');
    const user = userFromToken(parseToken(req));
    if (!user) {
      ws.close(4401, 'Unauthorized');
      return;
    }

    const bookingMatch = url.pathname.match(/^\/ws\/v1\/tracking\/booking\/([^/]+)$/);
    if (bookingMatch) {
      const bookingId = bookingMatch[1];
      try {
        const booking = bookingsService.loadBooking(bookingId);
        bookingsService.assertCanRead(user, booking);
      } catch {
        ws.close(4403, 'Forbidden');
        return;
      }
      addToRoom(bookingId, ws);
      const last = store.tracking.get(bookingId);
      if (last) ws.send(JSON.stringify({ type: 'location', ...last }));
      ws.on('close', () => removeSocket(ws));
      return;
    }

    if (url.pathname === '/ws/v1/tracking/driver') {
      if (user.role !== 'driver' && user.role !== 'fleetOwner' && user.role !== 'superAdmin') {
        ws.close(4403, 'Forbidden');
        return;
      }
      ws.on('message', (raw) => {
        try {
          const message = JSON.parse(raw.toString());
          const bookingId = message.booking_id || message.bookingId;
          const coords = message.coordinates || {};
          const point = {
            type: 'location',
            driverId: user.id,
            bookingId,
            lat: coords.lat ?? coords.latitude,
            lng: coords.lng ?? coords.longitude,
            speed: coords.speed || 0,
            bearing: coords.bearing || 0,
            timestamp: message.timestamp || new Date().toISOString(),
          };
          const drift = Math.abs(Date.now() - new Date(point.timestamp).getTime());
          if (drift > config.settings.timestampDriftSeconds * 1000) {
            ws.send(JSON.stringify({ type: 'error', code: 'TIMESTAMP_DRIFT' }));
            return;
          }
          store.tracking.set(bookingId, point);
          broadcastTracking(bookingId, {
            ...point,
            estimatedArrivalMinutes: 8,
          });
          ws.send(JSON.stringify({ type: 'ack', bookingId }));
        } catch {
          ws.send(JSON.stringify({ type: 'error', code: 'INVALID_PAYLOAD' }));
        }
      });
      ws.on('close', () => removeSocket(ws));
    }
  });

  return wss;
}
