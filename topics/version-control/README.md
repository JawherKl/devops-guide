# 🗂️ Version Control

<p align="center">
  <img src="https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white"/>
  <img src="https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white"/>
  <img src="https://img.shields.io/badge/GitLab-FC6D26?style=for-the-badge&logo=gitlab&logoColor=white"/>
  <img src="https://img.shields.io/badge/Bitbucket-0052CC?style=for-the-badge&logo=bitbucket&logoColor=white"/>
</p>

> Version control is the foundation of every engineering practice in this guide. Git tracks every change to every file, lets teams collaborate without overwriting each other, enables rollbacks, and powers CI/CD pipelines. Everything from containers to Kubernetes deployments starts with a Git push.

---

## 💡 Why Git Matters in DevOps

```
Developer workstation
  └── git commit + git push
          │
          ▼
    Git Repository (GitHub / GitLab / Bitbucket)
          │
          ├── Pull Request → code review → merge
          │
          ├── Webhook → triggers CI/CD pipeline
          │          → builds Docker image
          │          → runs tests
          │          → deploys to Kubernetes
          │
          └── ArgoCD / Flux watches repo → syncs cluster state
```

Git is not just a backup tool. In a DevOps workflow it is the **trigger** for everything downstream: tests, builds, deployments, and infrastructure changes.

---

## 📋 Files in This Topic

| File | What you'll learn |
|------|-------------------|
| [base-commands.md](./base-commands.md) | The 20 commands every engineer uses daily — with annotated examples |
| [branching-strategy.md](./branching-strategy.md) | Git Flow, GitHub Flow, Trunk-Based Development — when to use each |
| [git-workflow.md](./git-workflow.md) | Complete team workflow: fork, clone, branch, commit, push, sync |
| [pull-request.md](./pull-request.md) | Writing PRs, reviewing code, merge strategies, protecting branches |

---

## 🗺️ Learning Path

```
1. base-commands.md         ← master the core Git primitives
        ↓
2. branching-strategy.md    ← choose the right branching model for your team
        ↓
3. git-workflow.md          ← apply it: daily commit and collaboration cycle
        ↓
4. pull-request.md          ← code review, merge strategy, branch protection
```

---

## ⚡ The 10 Commands You'll Use Every Day

```bash
git status                        # what changed?
git add -p                        # stage changes interactively (review before committing)
git commit -m "feat: add login"   # commit with conventional message
git pull --rebase origin main     # sync with remote, keep history clean
git push origin feature/my-work   # push branch to remote
git log --oneline --graph         # visualize history
git diff main..feature/my-work    # compare branches
git stash && git stash pop        # save/restore uncommitted work
git switch -c feature/new-thing   # create and switch to a new branch
git restore .                     # discard all uncommitted changes (careful!)
```

---

## 🔗 Related Topics

- [CI/CD](../ci-cd/) — every pipeline starts with a Git event (push, PR, tag)
- [Orchestration / GitOps](../orchestration/gitops/) — Git as the source of truth for Kubernetes state
- [Server Management](../server-management/) — deploy config files managed in Git
- [DevSecOps](../devsecops/) — secret scanning, signed commits, branch protection rules