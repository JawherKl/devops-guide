/**
 * Volumes Demo App
 *
 * Demonstrates all three volume types from inside a running container:
 *
 *   GET /          — service info + volume mount summary
 *   GET /named     — reads from /data (named volume mount point)
 *   GET /bind      — reads from /app/src (bind mount — live reloaded)
 *   GET /tmpfs     — writes + reads from /tmp (tmpfs — in-memory only)
 *   GET /health    — liveness probe
 */

'use strict';

const http = require('http');
const fs   = require('fs');
const os   = require('os');
const path = require('path');

const PORT = parseInt(process.env.PORT || '3000', 10);

const routes = {

  '/health': (_req, res) => {
    json(res, 200, { status: 'ok' });
  },

  '/': (_req, res) => {
    json(res, 200, {
      service: 'volumes-demo',
      hostname: os.hostname(),
      mounts: {
        named_volume:  '/data        → postgres_data (managed by Docker)',
        bind_mount:    '/app/src     → ./app/src on host (live reload)',
        tmpfs:         '/tmp + /run  → in-memory only (lost on container stop)',
      },
      endpoints: ['/health', '/', '/named', '/bind', '/tmpfs'],
    });
  },

  '/named': (_req, res) => {
    // Named volume mounted at /data — written by postgres, readable here for demo
    try {
      const files = fs.readdirSync('/data').slice(0, 5);
      json(res, 200, {
        mount: '/data (named volume)',
        managed_by: 'Docker Engine',
        survives_container_removal: true,
        sample_files: files,
        note: 'This data persists even after docker rm',
      });
    } catch (err) {
      json(res, 200, {
        mount: '/data (named volume)',
        note: 'Mount not present in this demo context — see compose.yml',
      });
    }
  },

  '/bind': (_req, res) => {
    // Bind mount — /app/src is the host's ./app/src directory
    // Edit any file on the host and the change is immediately visible here
    try {
      const files = fs.readdirSync('/app/src');
      const selfContent = fs.readFileSync('/app/src/index.js', 'utf8').split('\n').slice(0, 5).join('\n');
      json(res, 200, {
        mount: '/app/src (bind mount from host)',
        managed_by: 'Host OS filesystem',
        live_reload: true,
        files_in_src: files,
        first_5_lines_of_this_file: selfContent,
        note: 'Edit index.js on your host — the change is immediately visible here',
      });
    } catch (err) {
      json(res, 200, { error: err.message });
    }
  },

  '/tmpfs': (_req, res) => {
    // Write a file to /tmp (tmpfs — in-memory, never touches disk)
    const tmpFile = path.join('/tmp', `demo-${Date.now()}.txt`);
    const payload = `Written at ${new Date().toISOString()} by PID ${process.pid}`;
    try {
      fs.writeFileSync(tmpFile, payload);
      const readBack = fs.readFileSync(tmpFile, 'utf8');
      json(res, 200, {
        mount: '/tmp (tmpfs — in-memory)',
        managed_by: 'Host RAM (never written to disk)',
        survives_container_removal: false,
        wrote: tmpFile,
        read_back: readBack,
        note: 'This file exists only in memory. It vanishes when the container stops.',
      });
    } catch (err) {
      json(res, 500, { error: err.message });
    }
  },

};

// ── Helpers ───────────────────────────────────────────────────────────────────
function json(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body, null, 2));
}

// ── Server ────────────────────────────────────────────────────────────────────
const server = http.createServer((req, res) => {
  const handler = routes[req.url] || ((_r, r) => json(r, 404, { error: 'Not found', endpoints: Object.keys(routes) }));
  handler(req, res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[volumes-demo] :${PORT} — endpoints: ${Object.keys(routes).join(', ')}`);
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
process.on('SIGINT',  () => server.close(() => process.exit(0)));