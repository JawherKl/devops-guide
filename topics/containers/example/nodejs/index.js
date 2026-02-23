/**
 * Task Manager API
 *
 * Full Express REST API demonstrating production patterns:
 *   - PostgreSQL connection pool (pg)
 *   - Redis session cache (ioredis)
 *   - Structured /api/health endpoint (checks DB + cache)
 *   - Full tasks CRUD: GET / POST / PUT / DELETE
 *   - Graceful SIGTERM shutdown (Docker stop compatibility)
 *   - Environment-based config (no hardcoded values)
 *   - Request logging with timestamp
 *   - Global error handler
 *
 * Routes:
 *   GET    /api/health         Liveness + dependency status
 *   GET    /api/tasks          List all tasks (with Redis cache)
 *   POST   /api/tasks          Create a task { title, description }
 *   PUT    /api/tasks/:id      Update { title?, description?, done? }
 *   DELETE /api/tasks/:id      Delete a task
 */

'use strict';

const express = require('express');
const { Pool } = require('pg');
const { createClient } = require('redis');

// ── Config ────────────────────────────────────────────────────────────────────
const PORT         = parseInt(process.env.PORT         || '3000', 10);
const DATABASE_URL = process.env.DATABASE_URL;
const REDIS_URL    = process.env.REDIS_URL    || 'redis://redis:6379';
const LOG_LEVEL    = process.env.LOG_LEVEL    || 'info';

if (!DATABASE_URL) {
  console.error('[FATAL] DATABASE_URL is required');
  process.exit(1);
}

// ── PostgreSQL pool ───────────────────────────────────────────────────────────
const db = new Pool({
  connectionString:     DATABASE_URL,
  max:                  10,
  idleTimeoutMillis:    30_000,
  connectionTimeoutMillis: 5_000,
});

db.on('error', (err) => console.error('[DB] Unexpected error:', err.message));

// ── Redis client ──────────────────────────────────────────────────────────────
const cache = createClient({
  url: REDIS_URL,
  socket: {
    connectTimeout:    5_000,
    reconnectStrategy: (retries) => Math.min(retries * 200, 5_000),
  },
});

cache.on('error',        (err) => console.error('[REDIS] Error:', err.message));
cache.on('connect',      ()    => console.log('[REDIS] Connected'));
cache.on('reconnecting', ()    => console.log('[REDIS] Reconnecting...'));

// ── App ───────────────────────────────────────────────────────────────────────
const app = express();
app.use(express.json());
app.disable('x-powered-by');

// ── Request logger ────────────────────────────────────────────────────────────
app.use((req, _res, next) => {
  if (LOG_LEVEL === 'debug') {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  }
  next();
});

// =============================================================================
// Routes
// =============================================================================

// ── Health check ──────────────────────────────────────────────────────────────
// Docker HEALTHCHECK hits this endpoint.
// Returns 200 only if BOTH postgres and redis are reachable.
app.get('/api/health', async (_req, res) => {
  const checks  = { api: 'ok', postgres: 'unknown', redis: 'unknown' };
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
    uptime:     `${process.uptime().toFixed(1)}s`,
    environment: process.env.NODE_ENV,
    checks,
  });
});

// ── List tasks (with 10-second Redis cache) ───────────────────────────────────
app.get('/api/tasks', async (_req, res, next) => {
  try {
    const CACHE_KEY = 'tasks:all';
    const cached = await cache.get(CACHE_KEY).catch(() => null);

    if (cached) {
      return res.json({ tasks: JSON.parse(cached), source: 'cache' });
    }

    const { rows } = await db.query(
      'SELECT id, title, description, done, created_at, updated_at FROM tasks ORDER BY created_at DESC'
    );

    await cache.setEx(CACHE_KEY, 10, JSON.stringify(rows)).catch(() => {});
    res.json({ tasks: rows, source: 'database' });
  } catch (err) { next(err); }
});

// ── Get single task ───────────────────────────────────────────────────────────
app.get('/api/tasks/:id', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      'SELECT * FROM tasks WHERE id = $1',
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Task not found' });
    res.json({ task: rows[0] });
  } catch (err) { next(err); }
});

// ── Create task ───────────────────────────────────────────────────────────────
app.post('/api/tasks', async (req, res, next) => {
  const { title, description = '' } = req.body;
  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'title is required' });
  }
  try {
    const { rows } = await db.query(
      `INSERT INTO tasks (title, description)
       VALUES ($1, $2)
       RETURNING id, title, description, done, created_at`,
      [title.trim(), description.trim()]
    );
    await cache.del('tasks:all').catch(() => {});   // invalidate list cache
    res.status(201).json({ task: rows[0] });
  } catch (err) { next(err); }
});

// ── Update task ───────────────────────────────────────────────────────────────
app.put('/api/tasks/:id', async (req, res, next) => {
  const { title, description, done } = req.body;
  if (title === undefined && description === undefined && done === undefined) {
    return res.status(400).json({ error: 'Provide at least one of: title, description, done' });
  }
  try {
    const { rows } = await db.query(
      `UPDATE tasks
       SET title       = COALESCE($1, title),
           description = COALESCE($2, description),
           done        = COALESCE($3, done),
           updated_at  = NOW()
       WHERE id = $4
       RETURNING id, title, description, done, updated_at`,
      [title ?? null, description ?? null, done ?? null, req.params.id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Task not found' });
    await cache.del('tasks:all').catch(() => {});
    res.json({ task: rows[0] });
  } catch (err) { next(err); }
});

// ── Delete task ───────────────────────────────────────────────────────────────
app.delete('/api/tasks/:id', async (req, res, next) => {
  try {
    const { rowCount } = await db.query(
      'DELETE FROM tasks WHERE id = $1',
      [req.params.id]
    );
    if (!rowCount) return res.status(404).json({ error: 'Task not found' });
    await cache.del('tasks:all').catch(() => {});
    res.status(204).end();
  } catch (err) { next(err); }
});

// ── 404 ───────────────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ── Global error handler ──────────────────────────────────────────────────────
// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error('[ERROR]', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// =============================================================================
// Startup
// =============================================================================
async function start() {
  console.log(`[taskapp-api] Connecting to cache...`);
  await cache.connect();

  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`[taskapp-api] Listening on :${PORT} (${process.env.NODE_ENV})`);
    console.log(`[taskapp-api] DB: ${DATABASE_URL.replace(/:\/\/.*@/, '://***@')}`);
  });

  // ── Graceful shutdown ─────────────────────────────────────────────────────
  // Docker sends SIGTERM on `docker stop`. We stop accepting new connections,
  // drain the DB pool, disconnect Redis, then exit cleanly.
  const shutdown = async (signal) => {
    console.log(`[taskapp-api] ${signal} — shutting down gracefully`);
    server.close(async () => {
      await db.end().catch(() => {});
      await cache.quit().catch(() => {});
      console.log('[taskapp-api] Shutdown complete');
      process.exit(0);
    });
    setTimeout(() => { console.error('[taskapp-api] Forced exit'); process.exit(1); }, 10_000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT',  () => shutdown('SIGINT'));
}

start().catch((err) => {
  console.error('[FATAL] Startup failed:', err.message);
  process.exit(1);
});