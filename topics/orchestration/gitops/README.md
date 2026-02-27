# 🔄 GitOps

<p align="center">
  <img src="https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white"/>
  <img src="https://img.shields.io/badge/Flux-5468FF?style=for-the-badge&logo=flux&logoColor=white"/>
</p>

> GitOps is an operational model where **Git is the single source of truth** for cluster state. Every desired state is committed to Git. A GitOps controller watches the repo and automatically reconciles the cluster to match — no manual `kubectl apply` or `helm upgrade` in production.

---

## 💡 GitOps Principles

```
Traditional CD                    GitOps
──────────────────────────────    ──────────────────────────────────────
CI pipeline → kubectl apply  →    Git commit → controller detects diff →
  cluster (push model)              controller syncs cluster (pull model)
```

| | Traditional CD | GitOps |
|--|---------------|--------|
| Deployment trigger | CI pipeline pushes | Controller pulls from Git |
| Desired state | Scattered in scripts | Always in Git |
| Rollback | Re-run old pipeline | `git revert` + auto-sync |
| Audit trail | CI logs | Git history |
| Drift detection | Manual | Automatic |

---

## 🧰 ArgoCD vs Flux

| | ArgoCD | Flux |
|--|--------|------|
| UI | Full web UI | CLI-first |
| Config | CRD + UI | CRD only (pure Git) |
| Multi-tenancy | AppProject | Namespace isolation |
| Image automation | Argo CD Image Updater (separate) | Built-in controllers |
| Helm support | Full | Full (HelmRelease CRD) |
| Notification | Built-in | Built-in controller |
| Philosophy | Declarative + visual | Automation-first |
| Best for | Teams that want a UI | Teams that want pure GitOps |

---

## 📋 Sections

| Section | What you'll learn |
|---------|-------------------|
| [argocd/basics/](./argocd/basics/) | Install ArgoCD, Application CRD, AppProject RBAC |
| [argocd/advanced/app-of-apps/](./argocd/advanced/app-of-apps/) | Manage 10+ apps from a single root Application |
| [argocd/advanced/sync-waves/](./argocd/advanced/sync-waves/) | Control deploy ordering: DB first, API second, Ingress third |
| [argocd/example/](./argocd/example/) | ArgoCD deploying a Helm chart with full production config |
| [flux/basics/](./flux/basics/) | Bootstrap Flux, GitRepository, Kustomization reconciler |
| [flux/advanced/helm-releases/](./flux/advanced/helm-releases/) | HelmRelease CRD: Flux-managed Helm upgrades |
| [flux/advanced/image-automation/](./flux/advanced/image-automation/) | Auto-commit new image tags to Git when CI pushes |
| [flux/example/](./flux/example/) | Full stack: Flux + HelmRelease + image automation + Slack alerts |

---

## ⚡ Quick Commands

```bash
# ── ArgoCD ──────────────────────────────────────────────────────────────────
kubectl apply -n argocd -f argocd/basics/application.yaml
argocd app sync taskapp
argocd app get  taskapp

# ── Flux ────────────────────────────────────────────────────────────────────
flux bootstrap github --owner=JawherKl --repository=devops-guide \
  --path=topics/orchestration/gitops/flux --personal
flux get all                        # status of all flux objects
flux reconcile kustomization taskapp  # force reconcile now
flux logs --all-namespaces          # live event stream
```

---

**Start ArgoCD →** [argocd/basics/](./argocd/basics/)  
**Start Flux →** [flux/basics/](./flux/basics/)