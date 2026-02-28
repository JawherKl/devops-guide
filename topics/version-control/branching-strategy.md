# 🌿 Branching Strategy

> A branching strategy defines the rules for how your team uses branches: when to create them, what they're named, when they merge, and how releases are cut. Choosing the right strategy for your team size and deployment cadence is one of the most consequential engineering decisions you'll make.

---

## The Three Main Strategies

| Strategy | Best for | Release cadence | Complexity |
|----------|----------|-----------------|------------|
| **Git Flow** | Libraries, versioned products, mobile apps | Scheduled releases (weekly/monthly) | High |
| **GitHub Flow** | SaaS web apps, small–medium teams | Continuous deployment (many times/day) | Low |
| **Trunk-Based Development** | Large teams, microservices, Google/Meta scale | Continuous deployment, feature flags | Medium |

---

## 1. Git Flow

Git Flow uses two permanent branches (`main` and `develop`) and several types of short-lived support branches. It was designed for projects that maintain multiple released versions simultaneously.

### Branch Types

| Branch | Branches from | Merges into | Purpose |
|--------|---------------|-------------|---------|
| `main` | — | — | Production-ready code. Tagged on every release. |
| `develop` | `main` | — | Integration branch. Latest delivered development. |
| `feature/*` | `develop` | `develop` | New features |
| `release/*` | `develop` | `main` + `develop` | Release preparation (version bump, final fixes) |
| `hotfix/*` | `main` | `main` + `develop` | Emergency production fixes |
| `bugfix/*` | `develop` | `develop` | Non-urgent bug fixes in development |

### Git Flow Diagram

```
main     ────●───────────────────────●─────────────●──────────
             │ v1.0                  │ v1.1        │ v1.1.1
             │                       │             │
develop  ────●────────────●──────────●─────────────●─────────
             │            │          │             │
feature/     │   ●──●──●──┘          │             │
login        │                       │             │
             │         release/      │             │
             │         v1.1 ─●──●────┘             │
             │                                     │
             │                          hotfix/    │
             │                          v1.1.1 ─●──┘
```

### Git Flow Workflow

```bash
# ── Set up (one-time) ──────────────────────────────────────────────────────
# Using git-flow tool (optional, wraps the commands below)
# apt install git-flow  /  brew install git-flow

git flow init
# Main branch: main
# Develop branch: develop
# Feature prefix: feature/
# Release prefix: release/
# Hotfix prefix: hotfix/
# Version tag prefix: v

# ── Start a new feature ────────────────────────────────────────────────────
git flow feature start user-authentication
# Equivalent to:
# git switch -c feature/user-authentication develop

# Work on the feature...
git add .
git commit -m "feat(auth): add JWT token generation"
git commit -m "feat(auth): add token refresh endpoint"

# ── Finish the feature (merges back to develop) ───────────────────────────
git flow feature finish user-authentication
# Equivalent to:
# git switch develop
# git merge --no-ff feature/user-authentication
# git branch -d feature/user-authentication

# ── Start a release ────────────────────────────────────────────────────────
git flow release start 1.1.0
# Equivalent to: git switch -c release/1.1.0 develop

# Bump version, update CHANGELOG, final fixes only
npm version minor                    # updates package.json
git commit -m "chore: bump version to 1.1.0"

# ── Finish the release ────────────────────────────────────────────────────
git flow release finish 1.1.0
# This:
#   merges release/1.1.0 → main
#   tags main as v1.1.0
#   merges release/1.1.0 → develop
#   deletes release/1.1.0

git push origin main develop --tags

# ── Start a hotfix ────────────────────────────────────────────────────────
# Production is broken — branch from main immediately
git flow hotfix start 1.1.1
# Equivalent to: git switch -c hotfix/1.1.1 main

git commit -m "fix(auth): prevent token reuse after logout"

git flow hotfix finish 1.1.1
# This:
#   merges hotfix/1.1.1 → main  (with tag v1.1.1)
#   merges hotfix/1.1.1 → develop
#   deletes hotfix/1.1.1

git push origin main develop --tags
```

### When to Use Git Flow
- You ship versioned releases (v1.0, v1.1, v2.0)
- You support multiple versions simultaneously (v1.x + v2.x)
- You have a QA process that requires a release-stabilisation window
- Your team is large and needs explicit rules to avoid chaos

### When NOT to Use Git Flow
- You deploy to production multiple times per day
- You have a single production environment
- Your team is small (< 5 engineers) — the overhead outweighs the benefits
- You want continuous delivery

---

## 2. GitHub Flow

GitHub Flow is intentionally minimal: one permanent branch (`main`) and short-lived feature branches. Every change goes through a pull request. Main is always deployable.

### GitHub Flow Diagram

```
main    ────●───────────────●───────────────────●────────────
            │ deploy        │ deploy            │ deploy
            │               │                   │
feature/    │   ●──●──●─PR──┘                   │
login       │                                   │
            │                     feature/      │
            │                     dark-mode     │
            │                     ●──●──●──PR───┘
```

### GitHub Flow Workflow

```bash
# 1. Always start from an up-to-date main
git switch main
git pull origin main

# 2. Create a short-lived feature branch
# Naming: type/short-description
git switch -c feature/user-profile-page
# or:
git switch -c fix/login-null-error
git switch -c chore/upgrade-dependencies
git switch -c docs/update-api-readme

# 3. Make small, focused commits
git add -p                        # review each change before staging
git commit -m "feat(profile): add avatar upload"
git commit -m "feat(profile): add bio field"

# 4. Push early and often — enables collaboration and backup
git push -u origin feature/user-profile-page

# 5. Open a pull request as soon as work begins (draft PR)
# → creates discussion space
# → triggers CI (tests, linting, security scans)
# → signals to teammates what you're working on
# Mark as "Draft" until ready for review

# 6. Keep branch up to date with main
git fetch origin
git rebase origin/main            # keeps history linear (preferred over merge)
git push --force-with-lease       # safe force push after rebase

# 7. Get review approval + all CI checks pass → merge

# 8. Delete the branch immediately after merge
git push origin --delete feature/user-profile-page
git branch -d feature/user-profile-page

# 9. main is deployed automatically by CI/CD
```

### Branch Naming Conventions

```
feature/add-oauth-google       ← new functionality
fix/correct-password-reset     ← bug fix
hotfix/critical-login-crash    ← urgent production fix
chore/upgrade-node-20          ← maintenance, no user-facing change
docs/add-api-reference         ← documentation only
refactor/extract-auth-service  ← code restructuring
test/add-payment-unit-tests    ← test coverage
perf/optimize-db-queries       ← performance improvement
ci/add-security-scan           ← CI/CD pipeline change
release/v2.1.0                 ← release preparation (if needed)
```

### When to Use GitHub Flow
- Continuous deployment to a single production environment
- Small to medium teams (2–30 engineers)
- Web applications, SaaS products
- Teams that want simplicity and fast iteration

---

## 3. Trunk-Based Development (TBD)

In TBD, everyone commits to `main` (the "trunk") either directly or via very short-lived branches (< 1 day). Large features are hidden behind **feature flags** rather than in long-running branches. This is how Google, Facebook, and Netflix ship.

### TBD Diagram

```
main (trunk)    ●──●──●──●──●──●──●──●──●──●──●──
                │  │  │  │  │  │  │  │  │  │
                │  short branch (< 1 day)  │
                │  ●──●──┘                 │
                │                          │
                deploy   deploy   deploy   deploy
                (CI/CD on every commit)
```

### Feature Flags Pattern

```javascript
// Without feature flags: long-running branch blocks deployment
// With feature flags: code ships behind a flag, enabled when ready

// feature-flags.js
const flags = {
    newCheckoutFlow: process.env.FEATURE_NEW_CHECKOUT === 'true',
    aiRecommendations: process.env.FEATURE_AI_RECOMMENDATIONS === 'true',
};

// In your code:
if (flags.newCheckoutFlow) {
    return renderNewCheckout(cart);   // new code, hidden by default
} else {
    return renderLegacyCheckout(cart); // existing code
}

// Deployment:
// 1. Merge to main (flag is OFF in production)
// 2. Enable flag for internal users: FEATURE_NEW_CHECKOUT=true (10%)
// 3. Expand rollout: 25% → 50% → 100%
// 4. Remove old code + flag once fully rolled out
```

### TBD Workflow

```bash
# Option A: direct commits to main (for small, safe changes)
git switch main
git pull
git add .
git commit -m "chore: update README"
git push origin main                  # CI runs immediately

# Option B: short-lived branch (for anything that needs review)
git switch -c fix/null-user-error     # branch lives < 24 hours
git commit -m "fix: handle null user in /profile"
git push -u origin fix/null-user-error
# Open PR → review → merge → delete
# Branch is merged within hours, not days

# Sync frequently to avoid divergence
git pull --rebase origin main         # run this multiple times per day

# Feature flag libraries
# JavaScript: LaunchDarkly, Unleash, flagsmith, @growthbook/growthbook
# Python:     python-decouple + env vars, Unleash, LaunchDarkly
# Go:         flipt, ConfigCat
```

### Release Branches in TBD

When you need a stable release artifact (mobile apps, on-prem software):

```bash
# Cut a release branch from main at a commit that passed all tests
git switch -c release/2.1.0 main

# Only cherry-pick critical fixes into this branch
git cherry-pick abc1234              # cherry-pick from main
git tag v2.1.0 -m "Release 2.1.0"
git push origin release/2.1.0 --tags

# NO new features go into this branch — they go into main
# after v2.2.0 is cut, release/2.1.0 is maintained for patches only
```

### When to Use TBD
- Large teams (50+ engineers) working on the same codebase
- Microservices (each service has its own trunk)
- High deployment frequency (10+ deploys/day)
- Teams that have mastered CI/CD and can trust automated tests
- When long-lived branches create painful merge conflicts

---

## Choosing Your Strategy

```
Do you deploy multiple times per day?
    ├── Yes → Do you have 50+ engineers on the same repo?
    │              ├── Yes → Trunk-Based Development
    │              └── No  → GitHub Flow
    └── No  → Do you maintain multiple released versions?
                   ├── Yes → Git Flow
                   └── No  → GitHub Flow (or simplified Git Flow)
```

### Anti-Patterns to Avoid

```bash
# ❌ Long-lived feature branches (> 3 days without merging to main)
# → Merge conflicts grow exponentially
# → Teammates can't see your work
# → CI runs on stale code

# ❌ Committing directly to main without a PR (except TBD with strong CI)
# → No review, no CI check before it's in production

# ❌ Keeping branches after merging
# → Stale branches pile up and confuse everyone
# → Clean up immediately after merge

# ❌ Giant PRs (> 400 lines changed)
# → Hard to review, high risk, discourages thorough review
# → Split into smaller PRs that each add value independently

# ❌ Inconsistent naming
# → my-changes, temp, johns-work, JIRA-1234, fix
# → Makes it impossible to understand what's in a branch at a glance

# ✅ Instead:
# Merge frequently (at least daily)
# Keep PRs small and focused
# Delete branches immediately after merge
# Use consistent naming: type/description
# Let CI enforce standards (don't rely on humans)
```