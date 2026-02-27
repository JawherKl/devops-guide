# Flux Installation

## Prerequisites

- Kubernetes cluster ≥ 1.25
- `kubectl` configured
- A GitHub / GitLab / Bitbucket account
- Personal Access Token with `repo` scope

---

## Install the Flux CLI

```bash
# macOS / Linux
curl -s https://fluxcd.io/install.sh | sudo bash

# macOS via Homebrew
brew install fluxcd/tap/flux

# Windows (Scoop)
scoop bucket add fluxcd https://github.com/fluxcd/flux2
scoop install flux

# Verify prerequisites
flux check --pre
```

---

## Bootstrap Flux onto your Cluster

`flux bootstrap` installs Flux CRDs + controllers AND commits the install
manifests to your Git repo. It then watches that repo forever.

```bash
# ── GitHub ──────────────────────────────────────────────────────────────────
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx   # personal access token

flux bootstrap github \
  --owner=JawherKl \
  --repository=devops-guide \
  --branch=main \
  --path=topics/orchestration/gitops/flux \
  --personal \
  --token-auth

# ── GitLab ──────────────────────────────────────────────────────────────────
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx

flux bootstrap gitlab \
  --owner=your-group \
  --repository=devops-guide \
  --branch=main \
  --path=topics/orchestration/gitops/flux \
  --token-auth

# ── Generic Git (self-hosted) ─────────────────────────────────────────────
flux bootstrap git \
  --url=ssh://git@git.company.com/platform/gitops \
  --branch=main \
  --path=clusters/production \
  --private-key-file=/home/user/.ssh/id_ed25519
```

What `bootstrap` does:
1. Installs Flux controllers in the `flux-system` namespace
2. Creates a `GitRepository` source pointing to your repo
3. Creates a `Kustomization` that applies everything in `--path`
4. Commits and pushes the install manifests to your repo
5. Flux immediately reconciles — the cluster is now managed from Git

---

## Verify Installation

```bash
# Check all Flux components are running
flux check

# Watch reconciliation events
flux get all

# List Flux components
kubectl get pods -n flux-system
# NAME                                       READY   STATUS
# helm-controller-xxxx                       1/1     Running
# kustomize-controller-xxxx                  1/1     Running
# notification-controller-xxxx               1/1     Running
# source-controller-xxxx                     1/1     Running
# image-automation-controller-xxxx           1/1     Running
# image-reflector-controller-xxxx            1/1     Running
```

---

## ArgoCD vs Flux

| | ArgoCD | Flux |
|--|--------|------|
| UI | Full web UI | CLI-first (optional Weave GitOps UI) |
| Config | CRD + UI | CRD only (Git-native) |
| Multi-tenancy | AppProject | Namespace isolation |
| Image automation | External (Argo CD Image Updater) | Built-in controllers |
| Helm support | Full | Full (HelmRelease CRD) |
| Notification | Separate install | Built-in controller |
| Philosophy | Declarative + visual | Pure GitOps, automation-first |