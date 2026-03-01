# ⚙️ JavaScript / Node.js Automation

> Real DevOps automation with Node.js: GitHub API integration, CI pipeline scripts, Docker registry management, Slack notifications, and build tooling. These patterns cover the automation work that JavaScript engineers do inside Node.js-heavy organizations.

---

## CLI Tool with Commander

```js
#!/usr/bin/env node
// deploy.js — deployment CLI using Commander
import { Command, Option } from 'commander';
import chalk from 'chalk';
import ora from 'ora';
import { execa } from 'execa';

const program = new Command();

program
  .name('deploy')
  .description('Application deployment tool')
  .version('1.0.0');

program
  .command('service <name> <tag>')
  .description('Deploy a service to Kubernetes')
  .addOption(
    new Option('-e, --env <env>', 'target environment')
      .choices(['dev', 'staging', 'production'])
      .default('dev')
  )
  .option('-t, --timeout <seconds>', 'rollout timeout', '300')
  .option('-n, --dry-run', 'show what would happen without deploying')
  .option('--namespace <ns>', 'kubernetes namespace (default: <name>-<env>)')
  .action(async (name, tag, opts) => {
    const ns = opts.namespace ?? `${name}-${opts.env}`;

    console.log(chalk.blue(`Deploying ${chalk.bold(name)}:${tag} → ${opts.env}`));

    if (opts.dryRun) {
      console.log(chalk.yellow(`DRY RUN: kubectl set image deployment/${name} ${name}=registry/${name}:${tag} -n ${ns}`));
      return;
    }

    const spinner = ora('Rolling out...').start();
    try {
      await execa('kubectl', [
        'set', 'image', `deployment/${name}`,
        `${name}=registry.example.com/${name}:${tag}`,
        '-n', ns,
      ]);
      await execa('kubectl', [
        'rollout', 'status', `deployment/${name}`,
        '-n', ns,
        `--timeout=${opts.timeout}s`,
      ]);
      spinner.succeed(chalk.green(`Deployed ${name}:${tag} to ${opts.env}`));
    } catch (err) {
      spinner.fail(chalk.red('Deployment failed'));
      console.error(err.stderr ?? err.message);
      process.exit(1);
    }
  });

program
  .command('rollback <name>')
  .description('Roll back the last deployment')
  .option('-e, --env <env>', 'environment', 'dev')
  .action(async (name, opts) => {
    const ns = `${name}-${opts.env}`;
    const spinner = ora(`Rolling back ${name}...`).start();
    try {
      await execa('kubectl', ['rollout', 'undo', `deployment/${name}`, '-n', ns]);
      spinner.succeed(`Rolled back ${name}`);
    } catch (err) {
      spinner.fail('Rollback failed');
      process.exit(1);
    }
  });

program.parseAsync();
```

---

## GitHub API Automation with Octokit

```js
// github.js — GitHub automation: releases, PRs, branch protection
import { Octokit } from '@octokit/rest';
import { throttling } from '@octokit/plugin-throttling';

const ThrottledOctokit = Octokit.plugin(throttling);

const octokit = new ThrottledOctokit({
  auth: process.env.GITHUB_TOKEN,
  throttle: {
    onRateLimit: (retryAfter, options) => {
      console.warn(`Rate limit hit for ${options.url}. Retrying after ${retryAfter}s.`);
      return options.request.retryCount < 3;  // retry up to 3 times
    },
    onSecondaryRateLimit: (retryAfter, options) => {
      console.warn(`Secondary rate limit for ${options.url}`);
      return true;
    },
  },
});

const OWNER = 'JawherKl';
const REPO  = 'devops-guide';

// ── Create a release ──────────────────────────────────────────────────────────
async function createRelease(tag, name, body, prerelease = false) {
  const { data } = await octokit.rest.repos.createRelease({
    owner: OWNER,
    repo: REPO,
    tag_name: tag,
    name,
    body,
    draft: false,
    prerelease,
    generate_release_notes: true,   // auto-generate from merged PRs
  });
  console.log(`Release created: ${data.html_url}`);
  return data;
}

// ── Get all open PRs targeting main ──────────────────────────────────────────
async function getOpenPRs() {
  const prs = await octokit.paginate(octokit.rest.pulls.list, {
    owner: OWNER,
    repo: REPO,
    state: 'open',
    base: 'main',
    per_page: 100,
  });
  return prs.map(pr => ({
    number: pr.number,
    title: pr.title,
    author: pr.user.login,
    draft: pr.draft,
    labels: pr.labels.map(l => l.name),
    updatedAt: pr.updated_at,
  }));
}

// ── Comment on a PR ────────────────────────────────────────────────────────────
async function commentOnPR(prNumber, body) {
  await octokit.rest.issues.createComment({
    owner: OWNER,
    repo: REPO,
    issue_number: prNumber,
    body,
  });
}

// ── Set branch protection ──────────────────────────────────────────────────────
async function protectBranch(branch) {
  await octokit.rest.repos.updateBranchProtection({
    owner: OWNER,
    repo: REPO,
    branch,
    required_status_checks: {
      strict: true,
      contexts: ['ci/test', 'ci/lint', 'ci/build', 'security/trivy'],
    },
    enforce_admins: true,
    required_pull_request_reviews: {
      required_approving_review_count: 1,
      dismiss_stale_reviews: true,
      require_code_owner_reviews: true,
    },
    restrictions: null,
    allow_force_pushes: false,
    allow_deletions: false,
    required_linear_history: true,
  });
  console.log(`Branch protection set on ${branch}`);
}

// ── List failed workflow runs ──────────────────────────────────────────────────
async function getFailedRuns(workflowFile, limit = 10) {
  const { data } = await octokit.rest.actions.listWorkflowRuns({
    owner: OWNER,
    repo: REPO,
    workflow_id: workflowFile,
    status: 'failure',
    per_page: limit,
  });
  return data.workflow_runs.map(run => ({
    id: run.id,
    branch: run.head_branch,
    sha: run.head_sha.slice(0, 7),
    url: run.html_url,
    createdAt: run.created_at,
  }));
}
```

---

## Docker Registry Automation

```js
// registry.js — interact with Docker registries
import { execaCommand } from 'execa';

// ── Build and push with multiple tags ─────────────────────────────────────────
async function buildAndPush({ registry, image, dockerfile = 'Dockerfile', context = '.' }) {
  const { stdout: sha } = await execaCommand('git rev-parse --short HEAD');
  const gitSha = sha.trim();

  const branch = (process.env.GITHUB_REF_NAME ?? 
    (await execaCommand('git rev-parse --abbrev-ref HEAD')).stdout.trim());

  // Compute tags based on branch:
  const tags = [`${registry}/${image}:${gitSha}`];
  if (branch === 'main') tags.push(`${registry}/${image}:latest`);
  if (branch.startsWith('release/')) {
    tags.push(`${registry}/${image}:${branch.replace('release/', '')}`);
  }

  const tagArgs = tags.flatMap(t => ['--tag', t]);

  console.log(`Building ${image} with tags:\n  ${tags.join('\n  ')}`);

  // Build with cache:
  await execaCommand(
    `docker buildx build ${tagArgs.join(' ')} --file ${dockerfile} --push ${context}`,
    { stdio: 'inherit' }
  );

  return { tags, gitSha };
}

// ── Scan image for vulnerabilities ────────────────────────────────────────────
async function scanImage(imageRef, { failOn = 'HIGH,CRITICAL', format = 'table' } = {}) {
  console.log(`Scanning ${imageRef}...`);
  const { exitCode, stdout } = await execaCommand(
    `trivy image --exit-code 1 --severity ${failOn} --format ${format} ${imageRef}`,
    { reject: false }
  );

  console.log(stdout);

  if (exitCode !== 0) {
    throw new Error(`Vulnerabilities found in ${imageRef} at severity ${failOn}`);
  }
  console.log(`✓ No ${failOn} vulnerabilities found`);
}

// ── List and clean old images ──────────────────────────────────────────────────
async function pruneImages(registry, image, keepTags = 10) {
  // Uses Docker Hub API as example — adapt for other registries
  const res = await fetch(
    `https://hub.docker.com/v2/repositories/${registry}/${image}/tags/?page_size=100`,
    { headers: { Authorization: `Bearer ${process.env.DOCKER_TOKEN}` } }
  );
  const { results } = await res.json();

  // Sort by last pushed, keep newest N:
  const sorted = results.sort((a, b) =>
    new Date(b.last_updated) - new Date(a.last_updated)
  );
  const toDelete = sorted.slice(keepTags);

  for (const tag of toDelete) {
    await fetch(
      `https://hub.docker.com/v2/repositories/${registry}/${image}/tags/${tag.name}/`,
      { method: 'DELETE', headers: { Authorization: `Bearer ${process.env.DOCKER_TOKEN}` } }
    );
    console.log(`Deleted ${image}:${tag.name}`);
  }
}
```

---

## Slack & Notification Automation

```js
// notify.js — send structured notifications to Slack / other channels
const SLACK_WEBHOOK = process.env.SLACK_WEBHOOK_URL;

// ── Rich Slack message with Block Kit ────────────────────────────────────────
async function slackNotify({ status, service, version, environment, url, actor }) {
  const color   = { success: '#2eb886', failure: '#e01e5a', warning: '#ecb22e' }[status] ?? '#aaa';
  const icon    = { success: '✅', failure: '❌', warning: '⚠️' }[status] ?? 'ℹ️';

  const body = {
    attachments: [{
      color,
      blocks: [
        {
          type: 'header',
          text: { type: 'plain_text', text: `${icon} Deployment ${status.toUpperCase()}` },
        },
        {
          type: 'section',
          fields: [
            { type: 'mrkdwn', text: `*Service:*\n${service}` },
            { type: 'mrkdwn', text: `*Version:*\n${version}` },
            { type: 'mrkdwn', text: `*Environment:*\n${environment}` },
            { type: 'mrkdwn', text: `*Triggered by:*\n${actor}` },
          ],
        },
        url && {
          type: 'actions',
          elements: [{
            type: 'button',
            text: { type: 'plain_text', text: 'View Deployment' },
            url,
            style: status === 'success' ? 'primary' : 'danger',
          }],
        },
      ].filter(Boolean),
    }],
  };

  const res = await fetch(SLACK_WEBHOOK, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) throw new Error(`Slack notify failed: ${res.status}`);
}

// ── Usage in CI pipeline ──────────────────────────────────────────────────────
async function runWithNotification(deployFn, context) {
  try {
    await deployFn();
    await slackNotify({ ...context, status: 'success' });
  } catch (err) {
    await slackNotify({ ...context, status: 'failure' });
    throw err;
  }
}
```

---

## package.json Scripts & Build Tooling

```json
{
  "scripts": {
    "build":        "tsc --project tsconfig.build.json",
    "build:watch":  "tsc --watch",
    "test":         "node --test --experimental-test-coverage",
    "test:watch":   "node --test --watch",
    "lint":         "eslint src/ --max-warnings 0",
    "lint:fix":     "eslint src/ --fix",
    "format":       "prettier --write src/",
    "format:check": "prettier --check src/",
    "typecheck":    "tsc --noEmit",
    "ci":           "npm run typecheck && npm run lint && npm run test",
    "release":      "semantic-release",
    "docker:build": "docker build -t myapp .",
    "docker:push":  "node scripts/build-push.js",
    "deploy:dev":   "node scripts/deploy.js dev",
    "deploy:prod":  "node scripts/deploy.js production"
  },
  "lint-staged": {
    "*.{ts,js}": ["eslint --fix", "prettier --write"],
    "*.{json,yaml,md}": ["prettier --write"]
  },
  "release": {
    "branches": ["main", { "name": "beta", "prerelease": true }],
    "plugins": [
      "@semantic-release/commit-analyzer",
      "@semantic-release/release-notes-generator",
      "@semantic-release/changelog",
      "@semantic-release/npm",
      "@semantic-release/github"
    ]
  }
}
```

```js
// scripts/ci-check.js — run in CI to validate build is clean
import { execa } from 'execa';
import chalk from 'chalk';

const steps = [
  { name: 'Type check',     cmd: 'npm run typecheck' },
  { name: 'Lint',           cmd: 'npm run lint' },
  { name: 'Format check',   cmd: 'npm run format:check' },
  { name: 'Tests',          cmd: 'npm test' },
  { name: 'Build',          cmd: 'npm run build' },
  { name: 'Audit (high)',   cmd: 'npm audit --audit-level=high' },
];

let failed = 0;
for (const { name, cmd } of steps) {
  process.stdout.write(`  ${name}... `);
  const result = await execa(cmd, { shell: true, reject: false });
  if (result.exitCode === 0) {
    console.log(chalk.green('✓'));
  } else {
    console.log(chalk.red('✗'));
    console.error(result.stderr || result.stdout);
    failed++;
  }
}

if (failed > 0) {
  console.error(chalk.red(`\n${failed} step(s) failed`));
  process.exit(1);
}
console.log(chalk.green('\nAll checks passed ✓'));
```