/**
 * Network Demo API
 *
 * A minimal Express app that demonstrates container-to-container DNS resolution.
 * Each endpoint exercises a different network connection so you can observe
 * what is reachable from the API container (backend network) and what isn't.
 *
 * Routes:
 *   GET /health       — liveness probe (used by Docker health check)
 *   GET /             — service info + network info
 *   GET /db           — test PostgreSQL connectivity (via backend network)
 *   GET /cache        — test Redis connectivity (via backend network)
 *   GET /network-info — show resolved hostnames + IPs for all services
 */

'use strict';

const http = require('http');
const { execSync } = require('child_process');

const PORT = parseInt(process.env.PORT || '3000', 10);
const DB_HOST = process.env.DB_HOST || 'postgres';
const REDIS_HOST = process.env.REDIS_HOST || 'redis';

// ── Minimal router ────────────────────────────────────────────────────────────
const routes = {

  '/health': (_req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', uptime: process.uptime().toFixed(2) }));
  },

  '/': (_req, res) => {
    const info = {
      service: 'netdemo-api',
      version: '1.0.0',
      container: {
        hostname: require('os').hostname(),
        pid: process.pid,
      },
      networks: {
        description: 'This container is on BOTH frontend and backend networks.',
        frontend: 'Reachable by nginx proxy.',
        backend: 'Used to reach postgres and redis.',
      },
      endpoints: ['/health', '/', '/db', '/cache', '/network-info'],
    };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(info, null, 2));
  },

  '/db': (_req, res) => {
    // Test TCP connectivity to postgres using Node.js net module
    const net = require('net');
    const DB_PORT = parseInt(process.env.DB_PORT || '5432', 10);
    const socket = new net.Socket();
    const timeout = setTimeout(() => {
      socket.destroy();
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ host: DB_HOST, port: DB_PORT, reachable: false, error: 'Timeout' }));
    }, 3000);

    socket.connect(DB_PORT, DB_HOST, () => {
      clearTimeout(timeout);
      socket.destroy();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ host: DB_HOST, port: DB_PORT, reachable: true }));
    });

    socket.on('error', (err) => {
      clearTimeout(timeout);
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ host: DB_HOST, port: DB_PORT, reachable: false, error: err.message }));
    });
  },

  '/cache': (_req, res) => {
    // Test TCP connectivity to redis
    const net = require('net');
    const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);
    const socket = new net.Socket();
    const timeout = setTimeout(() => {
      socket.destroy();
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ host: REDIS_HOST, port: REDIS_PORT, reachable: false, error: 'Timeout' }));
    }, 3000);

    socket.connect(REDIS_PORT, REDIS_HOST, () => {
      clearTimeout(timeout);
      // Send a PING command and read the +PONG response
      socket.write('PING\r\n');
      socket.once('data', (data) => {
        socket.destroy();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ host: REDIS_HOST, port: REDIS_PORT, reachable: true, response: data.toString().trim() }));
      });
    });

    socket.on('error', (err) => {
      clearTimeout(timeout);
      res.writeHead(503, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ host: REDIS_HOST, port: REDIS_PORT, reachable: false, error: err.message }));
    });
  },

  '/network-info': (_req, res) => {
    // Use nslookup to show DNS resolution from inside the container
    const resolve = (host) => {
      try {
        const out = execSync(`nslookup ${host} 2>/dev/null || echo "NXDOMAIN"`, { encoding: 'utf8', timeout: 2000 });
        const match = out.match(/Address:\s+([\d.]+)/g);
        return match ? match.map(m => m.replace('Address: ', '').trim()) : ['unresolved'];
      } catch {
        return ['error'];
      }
    };

    const info = {
      dns_server: '127.0.0.11 (Docker embedded DNS)',
      resolutions: {
        'proxy (frontend network)':    resolve('proxy'),
        'api (self)':                  resolve('api'),
        'postgres (backend network)':  resolve('postgres'),
        'redis (backend network)':     resolve('redis'),
      },
      note: 'All names resolve because this container is on both frontend and backend networks.',
    };

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(info, null, 2));
  },
};

// ── Server ────────────────────────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  const handler = routes[req.url] || routes['/'];
  handler(req, res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[netdemo-api] Listening on :${PORT}`);
  console.log(`[netdemo-api] DB_HOST=${DB_HOST} | REDIS_HOST=${REDIS_HOST}`);
});

process.on('SIGTERM', () => { server.close(() => process.exit(0)); });
process.on('SIGINT',  () => { server.close(() => process.exit(0)); });