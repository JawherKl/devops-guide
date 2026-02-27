# 🔧 Kustomize

<p align="center">
  <img src="https://img.shields.io/badge/Kustomize-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
  <img src="https://img.shields.io/badge/kubectl-built--in-informational?style=for-the-badge"/>
</p>

> Kustomize lets you customize Kubernetes YAML for multiple environments **without templating** — no `{{ }}` syntax, no chart packaging. It ships inside `kubectl` and works by layering patches on top of a base configuration.

---

## 💡 Kustomize vs Helm

| | Kustomize | Helm |
|--|-----------|------|
| Syntax | Plain YAML + patches | Go templates |
| Distribution | Built into kubectl | Separate install |
| Approach | Overlay / patch | Package / template |
| Best for | Environment variants of your own app | Distributing apps to others |
| Learning curve | Low | Medium |

> 💡 They complement each other: use **Helm** to package and **Kustomize** to customize per-environment.

---

## 📋 Sections

| Section | What you'll learn |
|---------|-------------------|
| [basics/](./basics/) | kustomization.yaml, resources, commonLabels, configMapGenerator |
| [overlays/dev/](./overlays/dev/) | Patch replicas to 1, override image tag |
| [overlays/staging/](./overlays/staging/) | Override resource limits, add namespace |
| [overlays/production/](./overlays/production/) | Scale replicas, enable HPA patch |
| [advanced/components/](./advanced/components/) | Reusable Kustomize components |
| [advanced/transformers/](./advanced/transformers/) | namePrefix, nameSuffix, namespace transformer |

---

## 🏗️ How Kustomize Works

```
base/                          overlays/production/
├── kustomization.yaml    +    ├── kustomization.yaml   →   kubectl apply -k overlays/production/
├── deployment.yaml            └── patch-replicas.yaml
└── service.yaml
          ↓                              ↓
     base resources            overlay patches
          └──────────── merge ───────────┘
                          ↓
                    final rendered YAML
```

---

## ⚡ Essential Commands

```bash
# Apply an overlay (renders base + patches, then applies)
kubectl apply -k overlays/production/

# Preview what would be applied (dry run)
kubectl kustomize overlays/production/

# Delete resources
kubectl delete -k overlays/production/

# Apply base directly
kubectl apply -k basics/

# Diff current cluster state vs kustomize output
kubectl diff -k overlays/production/
```

---

## 🔑 Patch Types

| Type | Use case | Example |
|------|----------|---------|
| `Strategic Merge Patch` | Merge/replace fields | Change replicas, add env var |
| `JSON 6902 Patch` | Precise add/replace/remove ops | Replace specific array item |
| `Replacement` | Substitute value from one resource into another | Sync image tag across Deployment + CronJob |

---

**Start here →** [basics/](./basics/)
