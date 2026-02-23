/**
 * Multi-Service App — API
 *
 * A production-pattern Express application demonstrating:
 *   - PostgreSQL connection via DATABASE_URL
 *   - Redis connection via REDIS_URL
 *   - Structured health check endpoint (used by Docker HEALTHCHECK)
 *   - Graceful shutdown on SIGTERM (Docker stop)
 *   - Environment-based config (no hardcoded values)
 *
 * Endpoints:
 *   GET /health    — liveness + dependency check (used by Docker health check)
 *   GET /          — service info
 *   GET /users     — list users from PostgreSQL
 *   POST /users    — create a user in PostgreSQL
 *   GET /cache/:key — get value from Redis
 *   PUT /cache/:key — set value in Redis
 */

'use strict';

const express = require('express');
const { Pool } = require('pg');
const { createClient } = require('redis');

// ── Config ────────────────────────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT || '3000', 10);
const DATABASE_URL = process.env.DATABASE_URL;
const REDIS_URL = process.env.REDIS_URL || 'redis://redis:6379';

if (!DATABASE_URL) {
  console.error('[FATAL] DATABASE_URL is not set');
  process.exit(1);
}

// ── Database (PostgreSQL) ─────────────────────────────────────────────────────
const db = new Pool({
  connectionString: DATABASE_URL,
  max: 10,                    // max pool connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

db.on('error', (err) => {
  console.error('[DB] Unexpected pool error:', err.message);
});

// ── Cache (Redis) ─────────────────────────────────────────────────────────────
const cache = createClient({
  url: REDIS_URL,
  socket: { connectTimeout: 5000, reconnectStrategy: (retries) => Math.min(retries * 100, 3000) },
});

cache.on('error', (err) => console.error('[REDIS] Error:', err.message));
cache.on('connect', ()   => console.log('[REDIS] Connected'));
cache.on('reconnecting', () => console.log('[REDIS] Reconnecting...'));

// ── App ───────────────────────────────────────────────────────────────────────
const app = express();
app.use(express.json());

// Remove X-Powered-By header
app.disable('x-powered-by');

// Request logging
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// ── Routes ────────────────────────────────────────────────────────────────────

/**
 * GET /health
 * Docker HEALTHCHECK hits this endpoint.
 * Returns 200 only if both DB and cache are reachable.
 * Returns 503 if any dependency is down.
 */
app.get('/health', async (req, res) => {
  const checks = { api: 'ok', postgres: 'unknown', redis: 'unknown' };
  let httpStatus = 200;

  try {
    await db.query('SELECT 1');
    checks.postgres = 'ok';
  } catch (err) {
    checks.postgres = `error: ${err.message}`;
    httpStatus = 503;
  }

  try {
    await cache.ping();
    checks.redis = 'ok';
  } catch (err) {
    checks.redis = `error: ${err.message}`;
    httpStatus = 503;
  }

  res.status(httpStatus).json({
    status: httpStatus === 200 ? 'healthy' : 'degraded',
    uptime: process.uptime().toFixed(2),
    checks,
  });
});

/**
 * GET /
 * Service info — useful for verifying the correct version is deployed.
 */
app.get('/', (_req, res) => {
  res.json({
    service: 'myapp-api',
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV,
    hostname: require('os').hostname(),
  });
});

/**
 * GET /users
 * Fetch all users from PostgreSQL.
 */
app.get('/users', async (_req, res) => {
  try {
    const result = await db.query(
      'SELECT id, name, email, created_at FROM users ORDER BY created_at DESC LIMIT 50'
    );
    res.json({ users: result.rows, count: result.rowCount });
  } catch (err) {
    console.error('[DB] Query error:', err.message);
    res.status(500).json({ error: 'Database query failed' });
  }
});

/**
 * POST /users
 * Create a user in PostgreSQL.
 * Body: { name: string, email: string }
 */
app.post('/users', async (req, res) => {
  const { name, email } = req.body;
  if (!name || !email) {
    return res.status(400).json({ error: 'name and email are required' });
  }
  try {
    const result = await db.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at',
      [name, email]
    );
    // Invalidate cached user list
    await cache.del('users:all').catch(() => {});
    res.status(201).json({ user: result.rows[0] });
  } catch (err) {
    if (err.code === '23505') {        // unique_violation
      return res.status(409).json({ error: 'Email already exists' });
    }
    console.error('[DB] Insert error:', err.message);
    res.status(500).json({ error: 'Database insert failed' });
  }
});

/**
 * GET /cache/:key
 * Retrieve a value from Redis.
 */
app.get('/cache/:key', async (req, res) => {
  try {
    const value = await cache.get(req.params.key);
    if (value === null) return res.status(404).json({ key: req.params.key, value: null });
    res.json({ key: req.params.key, value });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * PUT /cache/:key
 * Set a value in Redis (TTL: 60 seconds).
 * Body: { value: string }
 */
app.put('/cache/:key', async (req, res) => {
  const { value } = req.body;
  if (!value) return res.status(400).json({ error: 'value is required' });
  try {
    await cache.set(req.params.key, value, { EX: 60 });
    res.json({ key: req.params.key, value, ttl: 60 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── 404 handler ───────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ── Error handler ─────────────────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Startup ───────────────────────────────────────────────────────────────────
async function start() {
  await cache.connect();

  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`[myapp-api] Listening on :${PORT} (${process.env.NODE_ENV})`);
  });

  // ── Graceful shutdown ───────────────────────────────────────────────────────
  // Docker sends SIGTERM before SIGKILL (after 10s grace period).
  // Close the server first (stop accepting new connections), then
  // drain the DB pool and disconnect from Redis before exiting.
  const shutdown = async (signal) => {
    console.log(`[myapp-api] ${signal} received — shutting down gracefully`);
    server.close(async () => {
      await db.end();
      await cache.quit();
      console.log('[myapp-api] Shutdown complete');
      process.exit(0);
    });
    // Force exit after 10s if something hangs
    setTimeout(() => process.exit(1), 10_000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT',  () => shutdown('SIGINT'));
}

start().catch((err) => {
  console.error('[FATAL] Failed to start:', err.message);
  process.exit(1);
});