# 🔄 Git Workflow

> A Git workflow is the day-to-day cycle that turns individual commits into shipped code. This file covers the full loop: setting up your repo, making changes, keeping in sync with teammates, and handling the situations that always come up in team work — conflicts, mistakes, and emergency fixes.

---

## Repository Setup

### New Project

```bash
# 1. Create the repository on GitHub/GitLab, then clone
git clone git@github.com:JawherKl/my-project.git
cd my-project

# 2. Set up the initial structure
mkdir -p src tests docs
touch README.md .gitignore .editorconfig

# 3. Create a .gitignore immediately (before first commit)
cat > .gitignore << 'EOF'
node_modules/
dist/
.env
.env.local
*.log
.DS_Store
coverage/
EOF

# 4. Initial commit
git add .
git commit -m "chore: initial project structure"
git push origin main

# 5. Protect main branch (do this in GitHub/GitLab settings):
#    Settings → Branches → Add rule → main
#    ✅ Require pull request before merging
#    ✅ Require status checks (CI)
#    ✅ Require linear history
#    ✅ Include administrators
```

### Joining an Existing Project (Fork Workflow)

```bash
# 1. Fork the repo on GitHub (click Fork)

# 2. Clone YOUR fork
git clone git@github.com:YourUsername/devops-guide.git
cd devops-guide

# 3. Add the original repo as "upstream"
git remote add upstream git@github.com:JawherKl/devops-guide.git

# 4. Verify remotes
git remote -v
# origin    git@github.com:YourUsername/devops-guide.git (fetch)
# origin    git@github.com:YourUsername/devops-guide.git (push)
# upstream  git@github.com:JawherKl/devops-guide.git (fetch)
# upstream  git@github.com:JawherKl/devops-guide.git (push)

# 5. Never commit to main in your fork — always work in branches
git switch -c feature/my-contribution
```

---

## The Daily Development Cycle

### Full Cycle (GitHub Flow)

```bash
# ── Morning: sync with team ────────────────────────────────────────────────
git switch main
git pull --rebase origin main       # get latest changes
git branch --merged | grep -v main | xargs git branch -d  # clean merged branches

# ── Start work: new branch ─────────────────────────────────────────────────
git switch -c feature/user-notifications

# ── During work: small focused commits ────────────────────────────────────
# Make a change, test it, commit
git status                          # check what changed
git diff                            # review unstaged changes
git add -p                          # interactive staging: review each hunk
git commit -m "feat(notifications): add email notification service"

# Another round of changes
git add src/notifications/sms.ts
git commit -m "feat(notifications): add SMS notification service"

# ── Push early (backup + enables PR draft) ────────────────────────────────
git push -u origin feature/user-notifications

# ── Mid-day: keep your branch up to date ──────────────────────────────────
git fetch origin
git rebase origin/main              # replay your commits on latest main
# If conflicts: resolve → git add . → git rebase --continue
git push --force-with-lease         # update remote after rebase

# ── End of day: ensure pushed ─────────────────────────────────────────────
git push origin feature/user-notifications
```

### Writing Good Commit Messages

```bash
# ── Anatomy of a good commit message ─────────────────────────────────────
# Line 1 (subject): ≤72 chars, imperative mood, type prefix
# Line 2: blank
# Lines 3+: body — WHAT changed and WHY (not HOW — the diff shows how)
# Last lines: footer — breaking changes, issue refs

git commit
# Opens editor — write:

feat(notifications): add email notification on order dispatch

Previously, users had no visibility into order status after checkout.
This commit adds an email notification triggered when an order moves
to DISPATCHED status via the OrderEventHandler.

Email is sent via the existing EmailService using the new
ORDER_DISPATCHED template (templates/order-dispatched.html).

Closes #234
Reviewed-by: Alice Smith

# ── Quick commits for obvious changes (no body needed) ────────────────────
git commit -m "fix: correct typo in README"
git commit -m "chore: add .env to .gitignore"
git commit -m "docs: add API endpoint documentation"
git commit -m "style: run prettier on src/"

# ── Bad commit messages (avoid these) ────────────────────────────────────
# ❌ "fix"          → what did you fix?
# ❌ "wip"          → use a draft PR instead
# ❌ "changes"      → obvious and useless
# ❌ "john's work"  → author is in git log already
# ❌ "JIRA-1234"    → where's the description?
# ❌ "asdfasdf"     → not even trying
```

---

## Keeping in Sync with Teammates

### Syncing a Feature Branch with Latest Main

```bash
# Option A: Rebase (preferred — linear history, cleaner PRs)
git fetch origin
git rebase origin/main

# If there are conflicts:
# Git pauses at the conflicting commit and shows:
# CONFLICT (content): Merge conflict in src/app.js
#
# 1. Open the file and resolve:
#    <<<<<<< HEAD (your commit)
#    const port = 3001;
#    =======
#    const port = 3000;
#    >>>>>>> origin/main
#    → Choose one, or combine both:
#    const port = process.env.PORT || 3000;
#
# 2. Stage the resolved file
git add src/app.js
#
# 3. Continue the rebase
git rebase --continue
#
# 4. Push (force needed since history was rewritten)
git push --force-with-lease

# Option B: Merge (creates a merge commit — noisier history, but safer)
git merge origin/main
git push origin feature/my-work
```

### Fork Workflow: Syncing with Upstream

```bash
# Keep your fork's main in sync with the original repo
git fetch upstream
git switch main
git rebase upstream/main        # or: git merge upstream/main
git push origin main            # update your fork on GitHub

# Sync your feature branch
git switch feature/my-contribution
git rebase origin/main
git push --force-with-lease
```

### When You Have Conflicts

```bash
# Show the files with conflicts
git status | grep "both modified"

# Use a merge tool (configured with: git config --global merge.tool vimdiff)
git mergetool

# Or open the file and resolve the conflict markers manually:
# <<<<<<< HEAD
# your change
# =======
# their change
# >>>>>>> origin/main

# After resolving all files:
git add .
git rebase --continue    # if rebasing
# or:
git merge --continue     # if merging
# or:
git commit               # if doing a manual merge

# Abort if it's too complex (start over)
git rebase --abort
git merge --abort
```

---

## Handling Emergencies

### Emergency Hotfix on Production

```bash
# Production is broken. Don't branch from develop — branch from the production tag.

# 1. Branch from the currently deployed version
git switch main
git pull origin main
git switch -c hotfix/fix-login-crash

# 2. Make the minimal fix
git commit -m "fix(auth): prevent crash when user cookie is malformed"

# 3. Test locally, then push and open an emergency PR
git push -u origin hotfix/fix-login-crash
# → PR with description: HOTFIX - no reviews required - P0 incident

# 4. Merge to main immediately (skip normal review ceremony if P0)
# 5. Tag the fix
git switch main
git pull
git tag -a v2.1.1 -m "Hotfix: prevent crash on malformed auth cookie"
git push origin main --tags

# 6. Backport to develop if using Git Flow
git switch develop
git cherry-pick <hotfix-commit-sha>
git push origin develop
```

### You Committed to the Wrong Branch

```bash
# Scenario: accidentally committed to main instead of your feature branch

# 1. Create the correct branch at the current (wrong) position
git switch -c feature/correct-branch

# 2. Go back to main and reset it to before your commit
git switch main
git reset --hard HEAD~1         # removes the commit from main

# 3. Force push main to undo the accident (only if it wasn't pushed yet)
#    If already pushed:
git push --force-with-lease origin main   # requires no branch protection, use carefully

# 4. Your work is now safely on feature/correct-branch
git push -u origin feature/correct-branch
```

### You Pushed Sensitive Data (Passwords, Keys)

```bash
# 1. Immediately revoke/rotate the exposed credential (do this FIRST)
# 2. Remove it from history

# If the commit was just pushed (not yet seen by others):
git reset --hard HEAD~1
git push --force origin main

# If it's been in the repo for a while — use git filter-repo (not filter-branch):
pip install git-filter-repo

git filter-repo --path-glob '*.env' --invert-paths   # remove all .env files
# or target specific content:
git filter-repo --replace-text <(echo 'ghp_actual_token==>REMOVED')

# Force push all branches
git push origin --force --all
git push origin --force --tags

# 3. Notify your team — anyone who cloned must re-clone
# 4. GitHub has a secret scanning feature that will notify you anyway
# 5. Add the file to .gitignore immediately
echo ".env" >> .gitignore
git commit -m "chore: add .env to gitignore"
```

### Undoing a Merge on Main

```bash
# Find the merge commit hash
git log --oneline --graph main | head -20

# Revert the merge commit (creates a new commit that undoes it — safe for public branches)
git revert -m 1 <merge-commit-sha>
# -m 1 means "keep the first parent" (main), discarding the merged branch

git push origin main

# NOTE: if you later re-merge the same branch, you'll need to revert the revert first
# See: https://git-scm.com/docs/howto/revert-a-faulty-merge
```

---

## Git Aliases — Speed Up Daily Work

```bash
# Add to ~/.gitconfig or run: git config --global alias.<name> '<command>'
git config --global alias.st    'status -s'
git config --global alias.lg    'log --oneline --graph --all --decorate'
git config --global alias.last  'log -1 HEAD --stat'
git config --global alias.co    'switch'
git config --global alias.br    'branch -v'
git config --global alias.unstage 'restore --staged'
git config --global alias.discard 'restore .'
git config --global alias.wip   '!git add -A && git commit -m "WIP: checkpoint"'
git config --global alias.undo  'reset HEAD~1 --mixed'

# ~/.gitconfig result:
# [alias]
#     st     = status -s
#     lg     = log --oneline --graph --all --decorate
#     last   = log -1 HEAD --stat
#     co     = switch
#     br     = branch -v
#     unstage = restore --staged
#     discard = restore .
#     wip    = !git add -A && git commit -m "WIP: checkpoint"
#     undo   = reset HEAD~1 --mixed

# Usage:
git st      # git status -s
git lg      # visual log
git co main # switch to main
git undo    # undo last commit, keep changes
```

---

## Git Hooks — Automate Checks Locally

Git hooks run scripts before/after Git operations. Store them in `.git/hooks/` or use a hook manager.

```bash
# ── pre-commit: run linter + formatter before every commit ───────────────
# .git/hooks/pre-commit (chmod +x)
#!/bin/sh
set -e

echo "Running pre-commit checks..."

# Run ESLint on staged JS/TS files
STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(js|ts|jsx|tsx)$' || true)
if [ -n "$STAGED" ]; then
    echo "$STAGED" | xargs npx eslint --max-warnings 0
fi

# Run Prettier check on staged files
if [ -n "$STAGED" ]; then
    echo "$STAGED" | xargs npx prettier --check
fi

echo "Pre-commit checks passed."

# ── commit-msg: enforce conventional commit format ───────────────────────
# .git/hooks/commit-msg (chmod +x)
#!/bin/sh
MSG_FILE=$1
MSG=$(cat "$MSG_FILE")
PATTERN='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?(!)?: .{1,72}$'

if ! echo "$MSG" | head -1 | grep -qE "$PATTERN"; then
    echo "❌ Commit message does not follow Conventional Commits format."
    echo "   Expected: type(scope): description"
    echo "   Example:  feat(auth): add JWT refresh endpoint"
    exit 1
fi

# ── Use Husky to manage hooks in a Node.js project ───────────────────────
npm install --save-dev husky
npx husky init

# .husky/pre-commit
npm run lint
npm run format:check

# .husky/commit-msg
npx --no-install commitlint --edit "$1"
```

---

## Multi-Repo & Monorepo Patterns

```bash
# ── Submodules: embed one repo inside another ─────────────────────────────
git submodule add git@github.com:org/shared-lib.git libs/shared
git submodule update --init --recursive     # after cloning a repo with submodules
git submodule update --remote               # update to latest commit in submodules

# ── Sparse checkout: clone only part of a large repo ─────────────────────
git clone --filter=blob:none --sparse https://github.com/org/monorepo.git
cd monorepo
git sparse-checkout init --cone
git sparse-checkout set services/api services/auth   # only these dirs

# ── Shallow clone: get recent history only (fast for CI) ──────────────────
git clone --depth 1 https://github.com/org/repo.git     # only latest commit
git clone --depth 50 https://github.com/org/repo.git    # last 50 commits

# Convert shallow clone to full if you need the full history:
git fetch --unshallow
```