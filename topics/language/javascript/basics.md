# 🟨 JavaScript / Node.js Basics for DevOps

> Node.js is used in DevOps for build tooling, CI automation scripts, package management, and running JavaScript-based services. This file covers the Node.js patterns most relevant to DevOps work: running commands, file operations, HTTP, async patterns, and configuration management.

---

## Project Setup

```bash
# Node version management (use nvm or volta)
nvm install 20
nvm use 20
node --version   # v20.x.x

# or volta (faster, per-project pinning):
volta install node@20
volta pin node@20    # writes to package.json, pins for this project

# Init a project:
npm init -y
# OR modern with type:"module" for ESM:
cat > package.json << 'EOF'
{
  "name": "devops-scripts",
  "version": "1.0.0",
  "type": "module",
  "engines": { "node": ">=20" },
  "scripts": {
    "deploy": "node scripts/deploy.js",
    "health": "node scripts/healthcheck.js",
    "test": "node --test"
  }
}
EOF

# Key packages for DevOps automation:
npm install commander          # CLI argument parsing (like Click for Python)
npm install chalk              # terminal colours
npm install ora                # spinners
npm install execa              # better child_process (promises, output streaming)
npm install dotenv             # .env file loading
npm install @octokit/rest      # GitHub API
npm install @aws-sdk/client-s3 # AWS SDK v3
```

---

## Running Commands with execa

```js
// scripts/run.js
import { execa, execaCommand } from 'execa';

// ── Simple command execution ──────────────────────────────────────────────────
const { stdout } = await execa('git', ['rev-parse', '--short', 'HEAD']);
const gitSha = stdout.trim();

// ── Stream output in real time ────────────────────────────────────────────────
const proc = execa('kubectl', [
  'rollout', 'status', 'deployment/myapp',
  '-n', 'production', '--timeout=120s'
]);
proc.stdout.pipe(process.stdout);
proc.stderr.pipe(process.stderr);
await proc;   // waits and throws on non-zero exit

// ── Capture stdout and stderr separately ─────────────────────────────────────
const { stdout: out, stderr: err, exitCode } = await execa('npm', ['audit'], {
  reject: false,    // don't throw on non-zero exit
});

// ── Run with environment variables ───────────────────────────────────────────
await execa('node', ['server.js'], {
  env: { ...process.env, NODE_ENV: 'production', PORT: '3000' },
  cwd: '/app',
});

// ── Pipe between processes ────────────────────────────────────────────────────
const ps = execa('ps', ['aux']);
const grep = execa('grep', ['nginx']);
ps.stdout.pipe(grep.stdin);
const { stdout: filtered } = await grep;
```

---

## File System Operations

```js
import { readFile, writeFile, mkdir, readdir, stat, rm, rename } from 'node:fs/promises';
import { createReadStream, createWriteStream } from 'node:fs';
import { join, dirname, basename, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

// ESM equivalent of __dirname:
const __dirname = dirname(fileURLToPath(import.meta.url));

// ── Read / write ──────────────────────────────────────────────────────────────
const content = await readFile('/etc/nginx/nginx.conf', 'utf8');
await writeFile('/tmp/output.txt', 'hello\n', 'utf8');

// ── Parse config files ────────────────────────────────────────────────────────
import { parse as parseYaml } from 'yaml';          // npm install yaml
import { parse as parseToml } from '@iarna/toml';   // npm install @iarna/toml

const yamlConfig = parseYaml(await readFile('config.yaml', 'utf8'));
const packageJson = JSON.parse(await readFile('package.json', 'utf8'));

// ── Atomic write ──────────────────────────────────────────────────────────────
async function atomicWrite(path, content) {
  const tmp = `${path}.tmp`;
  await writeFile(tmp, content, 'utf8');
  await rename(tmp, path);   // atomic on same filesystem
}

// ── Walk directory tree ───────────────────────────────────────────────────────
async function* walkDir(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walkDir(full);
    } else {
      yield full;
    }
  }
}

// Find all YAML files:
for await (const file of walkDir('./k8s')) {
  if (extname(file) === '.yaml') {
    console.log(file);
  }
}

// ── Create dirs recursively ───────────────────────────────────────────────────
await mkdir('/tmp/output/nested/dir', { recursive: true });
```

---

## Async Patterns

```js
// ── Promise.all: run concurrently ────────────────────────────────────────────
const hosts = ['web1.example.com', 'web2.example.com', 'db1.example.com'];

const results = await Promise.all(
  hosts.map(async (host) => {
    try {
      const res = await fetch(`https://${host}/health`);
      return { host, ok: res.ok, status: res.status };
    } catch (err) {
      return { host, ok: false, error: err.message };
    }
  })
);

// ── Promise.allSettled: run all, collect all outcomes ─────────────────────────
const settled = await Promise.allSettled(
  services.map(svc => deployService(svc))
);
const failed = settled
  .filter(r => r.status === 'rejected')
  .map(r => r.reason);

// ── Bounded concurrency with a semaphore ──────────────────────────────────────
async function mapLimit(arr, limit, fn) {
  const results = [];
  const executing = new Set();

  for (const item of arr) {
    const p = fn(item).then(r => { executing.delete(p); return r; });
    executing.add(p);
    results.push(p);
    if (executing.size >= limit) {
      await Promise.race(executing);
    }
  }
  return Promise.all(results);
}

// Deploy max 3 services at a time:
const deployResults = await mapLimit(services, 3, deployService);

// ── Retry with exponential backoff ────────────────────────────────────────────
async function retry(fn, { attempts = 5, baseDelay = 1000 } = {}) {
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i === attempts - 1) throw err;
      const delay = baseDelay * Math.pow(2, i) + Math.random() * 1000;
      console.warn(`Attempt ${i + 1} failed. Retrying in ${Math.round(delay)}ms...`);
      await new Promise(r => setTimeout(r, delay));
    }
  }
}

const result = await retry(() => fetch('https://api.example.com/deploy'), {
  attempts: 5,
  baseDelay: 2000,
});
```

---

## Environment Variables & Configuration

```js
// config.js
import 'dotenv/config';   // loads .env into process.env

function required(key) {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required env var: ${key}`);
  return val;
}

function optional(key, defaultVal) {
  return process.env[key] ?? defaultVal;
}

export const config = {
  // Required — throw at startup if missing:
  dbHost:     required('DB_HOST'),
  dbName:     required('DB_NAME'),
  dbPassword: required('DB_PASSWORD'),

  // Optional with defaults:
  dbPort:     parseInt(optional('DB_PORT', '5432'), 10),
  nodeEnv:    optional('NODE_ENV', 'development'),
  logLevel:   optional('LOG_LEVEL', 'info'),
  port:       parseInt(optional('PORT', '3000'), 10),

  // Derived:
  isProd:     optional('NODE_ENV', '') === 'production',
};
```

---

## Error Handling

```js
// ── Custom errors ─────────────────────────────────────────────────────────────
class DeployError extends Error {
  constructor(service, stage, cause) {
    super(`Deploy ${service} failed at ${stage}: ${cause.message}`);
    this.name = 'DeployError';
    this.service = service;
    this.stage = stage;
    this.cause = cause;   // Node.js 16+ native cause chaining
  }
}

// ── Top-level error handler ───────────────────────────────────────────────────
async function main() {
  try {
    await run();
  } catch (err) {
    console.error(`Error: ${err.message}`);
    if (err.cause) console.error(`Caused by: ${err.cause.message}`);
    process.exit(1);
  }
}

// Catch unhandled rejections (never let them silently disappear):
process.on('unhandledRejection', (reason) => {
  console.error('Unhandled rejection:', reason);
  process.exit(1);
});

main();
```