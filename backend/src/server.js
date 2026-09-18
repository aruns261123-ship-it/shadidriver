import { createServer } from 'http';
import { config } from './config.js';
import { createApp } from './app.js';
import { attachTracking } from './ws/tracking.js';
import { startExpiryJobs } from './jobs/expiry.js';

const app = createApp();
const server = createServer(app);
attachTracking(server);
startExpiryJobs();

server.listen(config.port, () => {
  console.log(`ShadiDriver API listening on http://localhost:${config.port}`);
  console.log('Storage: in-memory (no database)');
  console.log('Health: GET /health  |  API prefix: /api/v1');
  console.log('Demo OTP: 000000 (universal). Role codes: customer 111111, driver 222222, ops 444444');
});
