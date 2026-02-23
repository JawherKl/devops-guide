/**
 * basics/03-dockerfile/app/index.js
 *
 * The simplest possible Node.js HTTP server — used to demonstrate
 * the node.dockerfile Dockerfile. No framework dependencies needed.
 *
 * Routes:
 *   GET /         service info
 *   GET /health   health check (used by Dockerfile HEALTHCHECK)
 */

'use strict';

const http = require('http');
const os   = require('os');

const PORT = parseInt(process.env.PORT || '3000', 10);

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');

  if (req.url === '/health') {
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'ok', uptime: process.uptime().toFixed(2) }));
    return;
  }

  res.writeHead(200);
  res.end(JSON.stringify({
    message:     'Hello from Docker!',
    hostname:    os.hostname(),
    platform:    os.platform(),
    node:        process.version,
    environment: process.env.NODE_ENV || 'unknown',
  }, null, 2));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[dockerfile-demo] Listening on :${PORT}`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT',  () => server.close(() => process.exit(0)));