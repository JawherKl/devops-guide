# 🔍 Pull Request

> A Pull Request (PR) — called Merge Request (MR) on GitLab — is the mechanism by which code moves from a feature branch into the shared codebase. It's a conversation about code changes, not just a button to click. A good PR culture is the single highest-leverage practice a team can adopt: it shares knowledge, catches bugs before production, and creates a permanent record of *why* code changed.

---

## Anatomy of a Good Pull Request

A PR has three audiences: the reviewer (today), a future engineer reading git history (next year), and the automated CI system. Write for all three.

```
┌───────────────────────────────────────────────────────────┐
│  Title: feat(auth): add JWT refresh endpoint              │
│  (follows Conventional Commits, ≤72 chars, imperative)    │
├───────────────────────────────────────────────────────────┤
│  Description                                              │
│  ─────────────                                            │
│  ## What                                                  │
│  Adds a POST /auth/refresh endpoint that accepts an       │
│  expired access token + valid refresh token, validates    │
│  both, and returns a new access token pair.               │
│                                                           │
│  ## Why                                                   │
│  Previously, users were logged out every 15 minutes       │
│  because there was no way to silently refresh tokens.     │
│  This fixes the session expiry complaints in #234.      │
│                                                           │
│  ## How (non-obvious decisions)                           │
│  Refresh tokens are stored in httpOnly cookies (not       │
│  localStorage) to prevent XSS theft. Tokens are           │
│  rotated on each use — once a refresh token is used,      │
│  it's invalidated.                                        │
│                                                           │
│  ## Testing                                               │
│  - Unit tests: src/auth/refresh.test.ts                   │
│  - Manual: curl -b "refresh_token=..." POST /auth/refresh │
│                                                           │
│  ## Screenshots / before-after (for UI changes)           │
│  [attach screenshot here]                                 │
│                                                           │
│  Closes #234                                            │
│  Related: #198, #201                                  │
├───────────────────────────────────────────────────────────┤
│  Checklist                                                │
│  ☑ Tests pass (CI green)                                  │
│  ☑ Documentation updated                                  │
│  ☑ No secrets or sensitive data                           │
│  ☑ Breaking change? (add to CHANGELOG)                    │
└───────────────────────────────────────────────────────────┘
```

---

## PR Templates

Set up a PR template so the structure is enforced automatically.

```markdown
<!-- .github/pull_request_template.md -->
<!-- GitHub reads this file and pre-fills the PR description -->

## What does this PR do?
<!-- 2–3 sentences: describe the change and its purpose -->


## Why is this change needed?
<!-- Link to issue, describe the problem being solved -->
Closes #


## How was it implemented?
<!-- Explain non-obvious decisions. What alternatives did you consider? -->


## Testing
<!-- How can a reviewer verify this works? -->
- [ ] Unit tests added / updated
- [ ] Integration tests pass
- [ ] Manually tested: describe steps


## Checklist
- [ ] CI is green (all checks pass)
- [ ] No secrets or credentials in code
- [ ] Documentation updated (README, API docs, CHANGELOG)
- [ ] Breaking change? If yes, add migration guide in CHANGELOG
- [ ] Dependent PRs listed below

## Screenshots (for UI changes)
| Before | After |
|--------|-------|
|        |       |
```

```yaml
# .github/ISSUE_TEMPLATE/bug_report.md (for bug reports)
# .github/ISSUE_TEMPLATE/feature_request.md (for features)
# These pre-fill the issue creation form on GitHub
```

---

## Opening a PR

```bash
# 1. Ensure your branch is clean and up to date
git fetch origin
git rebase origin/main                  # no merge commits in your branch
git push --force-with-lease             # update remote after rebase

# 2. Run checks locally before opening the PR (save CI minutes)
npm test                                # unit tests
npm run lint                            # linting
npm run build                           # verify it builds

# 3. Open the PR via GitHub CLI (fastest)
gh pr create \
  --title "feat(auth): add JWT refresh endpoint" \
  --body "$(cat .github/pr_body.md)" \  # or write inline
  --assignee @me \
  --reviewer alice,bob \
  --label "feature,auth" \
  --draft                               # open as draft first

# Convert from draft to ready when CI is green and you want review
gh pr ready

# 4. Other gh CLI commands
gh pr list                              # list open PRs
gh pr view 42                           # view PR #42
gh pr checkout 42                       # check out the PR branch locally
gh pr status                            # PRs assigned to / created by you
gh pr merge 42 --squash --delete-branch  # merge and clean up

# 5. Link PR to an issue
# In the PR description: "Closes #234" / "Fixes #234" / "Resolves #234"
# GitHub automatically closes the issue when the PR merges to the default branch
```

---

## Reviewing Code

### The Reviewer's Responsibility

A code review is not a gatekeeping exercise. It's a quality conversation. Your job as reviewer is to:

1. Understand the change — *what* does it do, *why* is it needed?
2. Check for correctness — will this work? Are there edge cases?
3. Check for safety — secrets? SQL injection? XSS? Performance cliff?
4. Check for maintainability — is this the simplest approach? Will someone understand it in a year?
5. Share knowledge — "did you know there's a `util.promisify` for this?"

### Tone: How to Give Constructive Feedback

```
# ── Calibrate feedback clearly ────────────────────────────────────────────

# Blocking (must fix before merge):
# "This introduces a SQL injection vulnerability — user input must be
#  parameterised: db.query('SELECT * FROM users WHERE id = $1', [userId])"

# Non-blocking suggestion (take it or leave it):
# "nit: we could extract this into a named function to improve readability,
#  but it's not blocking — up to you."

# Question (genuine curiosity):
# "I'm not familiar with this pattern — can you add a comment explaining
#  why we use a double-encoded token here?"

# Positive feedback (underused, important for culture):
# "Nice approach — extracting the TokenValidator makes this much easier to test."
# "I learned something from this! Didn't know about the 'httpOnly' flag."

# ── Comment prefixes the team agrees on ──────────────────────────────────
# [BLOCKING] Must fix before merge. Security, correctness, or critical quality issue.
# [nit]      Minor style preference. Don't block on this.
# [question] I want to understand this better. Not a request to change.
# [suggestion] Optional improvement. Take it or leave it.
# [praise]   Genuinely nice work. Say so explicitly.
```

### GitHub Review Mechanics

```bash
# Start a review (batch all comments, submit at once — don't send
# individual comment notifications for every line)
# GitHub UI: "Start a review" button on first comment

# Review outcomes:
# ✅ Approve        → "LGTM" — ready to merge
# 💬 Comment        → leave feedback without approving or blocking
# ❌ Request changes → must be addressed before merge

# On the command line (GitHub CLI):
gh pr review 42 --approve -b "LGTM! One nit about error handling but not blocking."
gh pr review 42 --request-changes -b "Please address the SQL injection on line 47."
gh pr review 42 --comment -b "Left a few questions inline — not blocking anything."

# Check out the PR branch to run it locally
gh pr checkout 42
npm test                    # run their tests
curl http://localhost:3000  # manual testing

# Leave an inline code suggestion (reviewer proposes specific code)
# In GitHub UI: click "+" on the line → "Add a suggestion"
# Appears as a diff the author can apply with one click
```

### What to Check in a Review

```
Security
  ☐ No secrets, credentials, or private keys committed
  ☐ User inputs are validated and sanitised
  ☐ No SQL injection (parameterised queries)
  ☐ Authentication/authorization on new endpoints
  ☐ No debug logs that print sensitive data

Correctness
  ☐ Does the code do what the PR description says?
  ☐ Are edge cases handled (null, empty, max values)?
  ☐ Are errors handled, not silently swallowed?
  ☐ Are concurrent access scenarios safe?

Tests
  ☐ Are new features covered by tests?
  ☐ Are bug fixes covered by a regression test?
  ☐ Are tests testing behaviour, not implementation?

Performance
  ☐ No N+1 database queries
  ☐ No synchronous I/O in hot paths
  ☐ Are expensive operations cached?

Maintainability
  ☐ Is the code readable without needing to ask the author?
  ☐ Are non-obvious decisions explained in comments?
  ☐ Does it follow the existing patterns in the codebase?
  ☐ Are function/variable names meaningful?
```

---

## Merge Strategies

Choosing the right merge strategy shapes your Git history permanently.

### 1. Squash and Merge

```bash
# All commits from the PR are squashed into a single commit on main.
# Result: one clean commit per PR, very readable main history.
# Cost: individual commit history of the feature branch is lost.

# GitHub UI: "Squash and merge" button
# CLI:
git switch main
git merge --squash feature/user-auth
git commit -m "feat(auth): add JWT refresh endpoint

Adds POST /auth/refresh using httpOnly cookies.
Refresh tokens are rotated on each use.

Closes #234"

# Best for: most projects. Clean, readable main history.
# Avoid if: the feature branch has meaningful, well-structured commits
#            that you want to preserve for debugging (git bisect, git blame).
```

### 2. Rebase and Merge (Linear)

```bash
# Each commit from the feature branch is replayed on top of main.
# Result: linear history, all commits preserved, no merge commit.
# Cost: commit SHAs change (rebasing rewrites history).

# GitHub UI: "Rebase and merge" button
# CLI:
git switch feature/user-auth
git rebase main
git switch main
git merge --ff-only feature/user-auth   # fast-forward only (no merge commit)

# Best for: teams that write clean, atomic commits and want full history.
# Avoid if: feature branches have messy WIP commits (use squash instead).
```

### 3. Merge Commit (Create a Merge Commit)

```bash
# Creates a merge commit that ties the feature branch to main.
# Result: full history preserved, branch topology visible in git log.
# Cost: noisy history, hard to read with many branches.

# GitHub UI: "Create a merge commit" button
# CLI:
git switch main
git merge --no-ff feature/user-auth
# → Creates commit: "Merge pull request #42 from feature/user-auth"

# Best for: Git Flow (where preserving the branch history matters).
# Avoid for: GitHub Flow / TBD (creates unnecessary clutter).
```

### Choosing a Strategy

| Strategy | History | Use when |
|----------|---------|----------|
| **Squash** | One commit per PR on main | Most projects. Clean, simple. |
| **Rebase** | All commits linear on main | Team writes clean atomic commits. |
| **Merge commit** | Full topology preserved | Git Flow, audited release branches. |

> ⚠️ Pick ONE strategy and enforce it consistently. GitHub branch protection rules can enforce this: "Require linear history" prevents merge commits.

---

## Branch Protection Rules

Configure in GitHub: **Settings → Branches → Add branch protection rule** for `main`.

```yaml
# Recommended settings for main branch:

Branch name pattern: main

Protect matching branches:
  ✅ Require a pull request before merging
      ✅ Require approvals: 1  (or 2 for large teams)
      ✅ Dismiss stale pull request approvals when new commits are pushed
      ✅ Require review from Code Owners (see CODEOWNERS below)

  ✅ Require status checks to pass before merging
      ✅ Require branches to be up to date before merging
      Status checks required:
        - ci/test          (unit + integration tests)
        - ci/lint          (ESLint, Prettier)
        - ci/build         (verify the build succeeds)
        - security/scan    (Snyk, Trivy, CodeQL)

  ✅ Require conversation resolution before merging
      (every comment thread must be marked resolved)

  ✅ Require linear history
      (enforces squash or rebase — no merge commits)

  ✅ Include administrators
      (even repo admins must follow the rules)

  ✅ Restrict who can push to matching branches
      (only CI bots and release managers can push directly)
```

### CODEOWNERS File

```bash
# .github/CODEOWNERS
# Syntax: <path pattern>  <GitHub usernames or teams>
# The listed owners are automatically added as reviewers when a PR
# touches the matching files.

# Default: everything requires review from the platform team
*                          @JawherKl/platform-team

# Security-sensitive code: requires security team review
src/auth/                  @JawherKl/security-team @alice
src/crypto/                @JawherKl/security-team
**/secrets*                @JawherKl/security-team

# Infra: requires DevOps team review
.github/                   @JawherKl/devops-team
Dockerfile*                @JawherKl/devops-team
docker-compose*.yml        @JawherKl/devops-team
**/k8s/                    @JawherKl/devops-team

# Frontend: requires frontend team review
src/components/            @JawherKl/frontend-team
src/pages/                 @JawherKl/frontend-team

# Specific files with single owner
CHANGELOG.md               @alice
package.json               @alice @bob
```

---

## CI Checks on Pull Requests

Every PR should trigger automated checks. Here's a minimal GitHub Actions workflow:

```yaml
# .github/workflows/pr-checks.yml
name: PR Checks

on:
  pull_request:
    branches: [main]

jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run format:check

  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm test -- --coverage
      - uses: codecov/codecov-action@v4   # upload coverage report

  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: fs
          scan-ref: .
          severity: HIGH,CRITICAL
          exit-code: 1
```

---

## PR Anti-Patterns

```bash
# ❌ Giant PRs (> 400 changed lines)
# → Hard to review, risk of rubber-stamping
# → Split into: 1. refactor 2. feature 3. tests (each mergeable independently)

# ❌ "Fixing a bug + adding a feature" in one PR
# → Mixed concerns, harder to revert one without the other
# → One PR = one logical change

# ❌ Opening a PR then going silent
# → Respond to review comments within 1 business day
# → If blocked, say why

# ❌ "LGTM" without actually reading the code
# → Defeats the purpose of code review
# → Reviewing 200 lines takes 20 minutes — that's the job

# ❌ Nitpicking style in reviews (without automation)
# → Set up ESLint + Prettier + pre-commit hooks
# → Let machines enforce style; humans review logic

# ❌ Long-running draft PRs (> 5 days)
# → Split into smaller PRs or merge behind a feature flag

# ✅ Instead:
# Keep PRs small and focused (one logical change)
# Open as draft immediately (for CI and early feedback)
# Respond to reviews promptly
# Use automation for style/format (not human reviews)
# Merge and delete promptly when approved
```