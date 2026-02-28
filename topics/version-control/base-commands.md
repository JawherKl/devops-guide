# 🔧 Base Commands

> These are the Git commands you will use every single day. Each one is annotated with what it actually does internally, common options, and real-world usage patterns — not just the syntax.

---

## Initial Setup (once per machine)

```bash
# Identity — embedded in every commit you make
git config --global user.name  "Jawher Kl"
git config --global user.email "jawher@example.com"

# Default branch name for new repos
git config --global init.defaultBranch main

# Editor for commit messages (choose one)
git config --global core.editor "vim"
git config --global core.editor "code --wait"    # VS Code
git config --global core.editor "nano"

# Default push behaviour: push only the current branch
git config --global push.default current

# Rebase instead of merge when pulling (cleaner history)
git config --global pull.rebase true

# Always prune deleted remote branches on fetch
git config --global fetch.prune true

# Better diff output: highlight changed words, not just lines
git config --global diff.colorMoved zebra

# Verify your config
git config --global --list
cat ~/.gitconfig
```

---

## Creating & Cloning

```bash
# ── Init: start a new repo in the current directory ──────────────────────────
git init
git init my-project          # creates my-project/ folder and inits inside

# ── Clone: download a repo and all its history ───────────────────────────────
git clone https://github.com/JawherKl/devops-guide.git
git clone https://github.com/JawherKl/devops-guide.git my-local-name
git clone --depth 1 https://github.com/JawherKl/devops-guide.git  # shallow clone (faster, no history)
git clone --branch develop https://github.com/org/repo.git        # clone specific branch

# SSH clone (no password prompts after key setup)
git clone git@github.com:JawherKl/devops-guide.git
```

---

## Staging & Committing

```bash
# ── Status: see what's changed ───────────────────────────────────────────────
git status           # full output
git status -s        # short output: M=modified, A=added, ??=untracked, D=deleted

# ── Add: stage changes for the next commit ───────────────────────────────────
git add file.txt             # stage one file
git add src/                 # stage entire directory
git add .                    # stage everything in current directory (use carefully)
git add -p                   # interactive: review each change chunk before staging
                             # (y=stage, n=skip, s=split hunk, e=edit manually)
git add -u                   # stage only tracked files (skip new untracked files)

# ── Commit: create a snapshot of staged changes ──────────────────────────────
git commit -m "feat: add user authentication"
git commit                   # opens editor for multi-line message
git commit -am "fix: correct typo"   # stage ALL tracked files + commit in one step
                                     # WARNING: skips review, use only for trivial fixes

# ── Amend: fix the most recent commit (before pushing) ───────────────────────
git commit --amend -m "feat: add user authentication via JWT"  # change message
git commit --amend --no-edit   # add staged changes to last commit, keep message
                                # useful when you forgot a file

# ── Conventional Commits format (used with semantic-release, changelogs) ──────
# <type>(scope): <short description>
# Types:
#   feat     → new feature (triggers minor version bump)
#   fix      → bug fix (triggers patch version bump)
#   docs     → documentation only
#   style    → formatting, no logic change
#   refactor → code restructuring, no feature/fix
#   test     → add or update tests
#   chore    → build, deps, tooling
#   perf     → performance improvement
#   ci       → CI/CD config changes
#   BREAKING CHANGE → in footer, triggers major version bump

git commit -m "feat(auth): add JWT token refresh endpoint"
git commit -m "fix(api): handle null user in /profile response"
git commit -m "chore(deps): upgrade express from 4.18 to 4.19"
git commit -m "feat!: remove support for Node.js 16"   # ! = breaking change
```

---

## Branches

```bash
# ── List branches ─────────────────────────────────────────────────────────────
git branch              # local branches
git branch -r           # remote branches
git branch -a           # all branches (local + remote)
git branch -v           # with last commit info
git branch --merged     # branches already merged into current (safe to delete)
git branch --no-merged  # branches NOT yet merged (work still in progress)

# ── Create & switch ───────────────────────────────────────────────────────────
git switch -c feature/user-auth           # create + switch (modern syntax)
git checkout -b feature/user-auth         # same, older syntax
git switch main                           # switch to existing branch
git switch -                              # switch to previous branch

# ── Create from a specific point ─────────────────────────────────────────────
git switch -c hotfix/login-crash main     # branch from main
git switch -c release/v2.1.0 v2.0.0      # branch from a tag

# ── Rename ────────────────────────────────────────────────────────────────────
git branch -m old-name new-name           # rename local branch
git branch -m new-name                    # rename current branch

# ── Delete ────────────────────────────────────────────────────────────────────
git branch -d feature/user-auth           # safe delete (only if merged)
git branch -D feature/dead-end            # force delete (even if not merged)
git push origin --delete feature/user-auth  # delete on remote

# ── Track remote branches ─────────────────────────────────────────────────────
git branch -u origin/feature/user-auth   # set upstream for current branch
git push -u origin feature/user-auth     # push + set upstream in one step
```

---

## Remote Operations

```bash
# ── Remote management ────────────────────────────────────────────────────────
git remote -v                                           # list remotes with URLs
git remote add origin git@github.com:org/repo.git      # add a remote
git remote add upstream git@github.com:orig/repo.git   # add upstream (for forks)
git remote set-url origin git@github.com:org/new.git   # change remote URL
git remote rename origin backup                         # rename a remote
git remote remove backup                                # remove a remote

# ── Fetch: download changes WITHOUT merging ───────────────────────────────────
git fetch origin               # fetch all branches from origin
git fetch --all                # fetch from all remotes
git fetch --prune              # fetch + delete local refs to deleted remote branches
git fetch origin main          # fetch only the main branch

# ── Pull: fetch + merge/rebase into current branch ────────────────────────────
git pull                       # uses configured strategy (merge or rebase)
git pull --rebase              # rebase local commits on top of fetched commits
git pull origin main           # pull main from origin into current branch
git pull --no-rebase           # explicit merge (creates a merge commit)

# ── Push: upload local commits to remote ─────────────────────────────────────
git push origin feature/my-work          # push branch
git push -u origin feature/my-work       # push + track remote
git push --force-with-lease              # force push (safe: fails if remote changed since last fetch)
git push --force                         # force push (dangerous: overwrites remote — never on main)
git push origin --tags                   # push all tags
git push origin v2.1.0                   # push a specific tag
git push origin --delete feature/old     # delete remote branch
```

---

## Merging & Rebasing

```bash
# ── Merge: bring changes from one branch into another ────────────────────────
git switch main
git merge feature/user-auth             # merge feature into main
git merge --no-ff feature/user-auth     # always create a merge commit (preserves branch history)
git merge --squash feature/user-auth    # squash all commits into one staged change
                                         # (then commit manually: git commit -m "feat: user auth")
git merge --abort                        # cancel an in-progress merge

# ── Rebase: replay commits on top of another branch ──────────────────────────
# Before opening a PR: rebase onto latest main to keep history linear
git switch feature/user-auth
git fetch origin
git rebase origin/main                  # replay feature commits on top of latest main
git rebase --interactive HEAD~3         # interactive: squash/reword/reorder last 3 commits
git rebase --abort                      # cancel in-progress rebase
git rebase --continue                   # after resolving conflict: continue rebase
git rebase --skip                       # skip a conflicting commit

# ── Interactive rebase: clean up commits before a PR ─────────────────────────
git rebase -i HEAD~5                    # edit last 5 commits
# Commands in the editor:
#   pick   = use commit as-is
#   reword = change commit message
#   edit   = pause to amend the commit
#   squash = combine with previous commit (keeps both messages)
#   fixup  = combine with previous commit (discards this message)
#   drop   = remove the commit entirely
```

---

## History & Inspection

```bash
# ── Log: browse commit history ────────────────────────────────────────────────
git log                                     # full log
git log --oneline                           # compact: one line per commit
git log --oneline --graph --all             # visual branch graph (all branches)
git log --oneline -20                       # last 20 commits
git log --author="Jawher"                   # filter by author
git log --since="2 weeks ago"               # filter by date
git log --grep="fix:"                       # filter by commit message
git log --follow src/auth/login.ts          # history of a specific file (follows renames)
git log main..feature/user-auth             # commits in feature not yet in main
git log --stat                              # show changed files per commit
git log --patch                             # show full diff per commit (very verbose)

# ── Show: inspect a specific commit ──────────────────────────────────────────
git show abc1234                            # show commit diff + metadata
git show HEAD                               # show latest commit
git show HEAD~2                             # show 2 commits ago
git show HEAD:src/app.js                    # show file content at a commit

# ── Diff: compare states ──────────────────────────────────────────────────────
git diff                                    # unstaged changes (working dir vs index)
git diff --staged                           # staged changes (index vs last commit)
git diff HEAD                               # all changes since last commit
git diff main..feature/user-auth            # all changes between two branches
git diff HEAD~3..HEAD                       # last 3 commits worth of changes
git diff HEAD -- src/auth/                  # changes in a specific path only
git diff --stat main..feature               # summary: which files changed, how many lines

# ── Blame: who changed which line ────────────────────────────────────────────
git blame src/app.js                        # annotate each line with author + commit
git blame -L 10,25 src/app.js              # only lines 10–25
git blame --ignore-revs-file .git-blame-ignore-revs src/app.js  # ignore formatting commits
```

---

## Undoing Changes

```bash
# ── Restore: discard changes (safe, doesn't touch history) ───────────────────
git restore src/app.js                  # discard unstaged changes to a file
git restore .                           # discard ALL unstaged changes (working dir)
git restore --staged src/app.js         # unstage a file (keep changes in working dir)
git restore --staged .                  # unstage everything

# ── Reset: move HEAD (and optionally staging/working dir) ────────────────────
git reset HEAD~1                        # undo last commit, keep changes staged
git reset --soft HEAD~1                 # undo commit, keep changes staged
git reset --mixed HEAD~1                # undo commit, keep changes unstaged (default)
git reset --hard HEAD~1                 # undo commit AND discard all changes (destructive!)
git reset --hard origin/main            # reset local branch to match remote exactly

# ── Revert: safely undo a commit by creating a new one ────────────────────────
# Use this on shared branches (main, develop) — safe for public history
git revert abc1234                      # create a new commit that undoes abc1234
git revert HEAD                         # revert most recent commit
git revert HEAD~3..HEAD                 # revert last 3 commits (one revert commit each)
git revert --no-commit HEAD~3..HEAD     # stage all reversions, then commit once

# ── Clean: remove untracked files ─────────────────────────────────────────────
git clean -n                            # dry-run: show what would be removed
git clean -fd                           # remove untracked files + directories
git clean -fdx                          # also remove files ignored by .gitignore (nuclear)
```

---

## Stash

```bash
# Save uncommitted work temporarily (to switch branch without committing)
git stash                               # stash all uncommitted changes
git stash push -m "WIP: auth refactor" # stash with a description
git stash push -p                       # interactive: choose which hunks to stash
git stash push -- src/auth/             # stash only a specific path
git stash push --include-untracked      # also stash untracked files

git stash list                          # see all stashes
git stash show                          # summary of most recent stash
git stash show -p stash@{1}            # diff of a specific stash

git stash pop                           # apply + remove most recent stash
git stash apply stash@{2}              # apply without removing (keep in stash list)
git stash drop stash@{0}               # delete a specific stash
git stash clear                         # delete ALL stashes (careful!)

git stash branch feature/wip stash@{1} # create a new branch from a stash
```

---

## Tags

```bash
# Tags mark specific commits as important — typically release versions.
# Lightweight tags = just a pointer; annotated tags = full object with metadata

# ── Annotated tags (recommended for releases) ─────────────────────────────────
git tag -a v2.1.0 -m "Release 2.1.0 — adds JWT refresh"
git tag -a v2.1.0 abc1234 -m "Tag previous commit"   # tag a specific commit

# ── Lightweight tags ──────────────────────────────────────────────────────────
git tag v2.1.0-rc1                     # lightweight (no metadata)

# ── List and inspect ──────────────────────────────────────────────────────────
git tag                                # list all tags
git tag -l "v2.*"                      # filter tags by pattern
git show v2.1.0                        # show tag details + commit

# ── Push tags ─────────────────────────────────────────────────────────────────
git push origin v2.1.0                 # push one tag
git push origin --tags                 # push all tags

# ── Delete tags ───────────────────────────────────────────────────────────────
git tag -d v2.0.0-rc1                  # delete local tag
git push origin --delete v2.0.0-rc1   # delete remote tag
```

---

## Cherry-pick & Bisect

```bash
# ── Cherry-pick: apply a specific commit to current branch ───────────────────
# Use case: hotfix committed to main, need it in the release branch too
git cherry-pick abc1234                 # apply one commit
git cherry-pick abc1234..def5678       # apply a range of commits
git cherry-pick --no-commit abc1234    # apply changes but don't commit yet
git cherry-pick --abort                # cancel if there's a conflict

# ── Bisect: binary-search for the commit that introduced a bug ────────────────
git bisect start
git bisect bad                          # current commit is bad
git bisect good v2.0.0                  # last known good version

# Git checks out a middle commit — you test it, then:
git bisect good    # if this commit is OK (bug not here yet)
git bisect bad     # if this commit has the bug

# After ~7 steps, Git identifies the exact bad commit.
git bisect reset   # return to original state

# Automate bisect with a test script
git bisect run npm test                 # run tests automatically per step
```

---

## .gitignore

```bash
# /path/to/repo/.gitignore

# ── Build outputs ─────────────────────────────────────────────────────────────
node_modules/
dist/
build/
*.pyc
__pycache__/
*.class
target/

# ── Environment and secrets ───────────────────────────────────────────────────
.env
.env.local
.env.*.local
*.pem
*.key
secrets/

# ── IDE and editor files ──────────────────────────────────────────────────────
.vscode/
.idea/
*.swp
*.swo
.DS_Store
Thumbs.db

# ── Test coverage ─────────────────────────────────────────────────────────────
coverage/
.nyc_output/
*.lcov

# ── Logs ─────────────────────────────────────────────────────────────────────
*.log
logs/

# ── OS files ─────────────────────────────────────────────────────────────────
.DS_Store
*.tmp

# Patterns:
#   file.txt       exact file in any directory
#   /file.txt      only in root of repo
#   dir/           ignore entire directory
#   *.log          all .log files anywhere
#   !important.log exception: don't ignore this specific log file
#   **/*.log       all .log files in any nested directory
```

```bash
# Force-add a file that is gitignored (use sparingly)
git add -f path/to/important.pem

# Check why a file is being ignored
git check-ignore -v filename.log

# Remove a file from Git tracking without deleting from disk
git rm --cached .env
git rm -r --cached node_modules/

# Apply .gitignore to already-tracked files (after editing .gitignore)
git rm -r --cached .
git add .
git commit -m "chore: apply updated .gitignore"
```