# ☸️ Orchestration

<p align="center">
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
  <img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white"/>
  <img src="https://img.shields.io/badge/Kustomize-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
  <img src="https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker_Swarm-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
</p>

> From containers to clusters. This topic covers Kubernetes, Helm, Kustomize, GitOps with ArgoCD, and Docker Swarm — the complete orchestration stack used across the industry.

---

## 📋 Table of Contents

| Tool | Section | What you'll learn |
|------|---------|-------------------|
| ☸️ Kubernetes | [basics/](./kubernetes/basics/) | Pods, Deployments, Services |
| ☸️ Kubernetes | [advanced/configmap-secrets/](./kubernetes/advanced/configmap-secrets/) | Config injection, secrets management |
| ☸️ Kubernetes | [advanced/ingress/](./kubernetes/advanced/ingress/) | HTTP routing, TLS termination |
| ☸️ Kubernetes | [advanced/multi-container-pod/](./kubernetes/advanced/multi-container-pod/) | Sidecar, init container, shared volumes |
| ☸️ Kubernetes | [advanced/statefulsets/](./kubernetes/advanced/statefulsets/) | Ordered deploys, stable identities, PVCs |
| ☸️ Kubernetes | [example/](./kubernetes/example/) | Full app: Deployment + HPA autoscaling |
| ⎈ Helm | [basics/my-first-chart/](./helm/basics/my-first-chart/) | Chart structure, templates, values |
| ⎈ Helm | [advanced/custom-resources/](./helm/advanced/custom-resources/) | ConfigMap + Secret + multi-resource chart |
| ⎈ Helm | [advanced/multi-service-app/](./helm/advanced/multi-service-app/) | Web + DB chart, helpers, named templates |
| 🔧 Kustomize | [basics/](./kustomize/basics/) | Base manifests, configMapGenerator, images |
| 🔧 Kustomize | [overlays/dev/](./kustomize/overlays/dev/) | Dev: 1 replica, debug logging, light resources |
| 🔧 Kustomize | [overlays/staging/](./kustomize/overlays/staging/) | Staging: 2 replicas, RC tag |
| 🔧 Kustomize | [overlays/production/](./kustomize/overlays/production/) | Prod: 4 replicas, HPA, PDB |
| 🔧 Kustomize | [advanced/](./kustomize/advanced/) | Components, transformers, replacements |
| 🔄 GitOps | [gitops/argocd/basics/](./gitops/argocd/basics/) | Install ArgoCD, Application CRD, AppProject |
| 🔄 GitOps | [gitops/argocd/advanced/app-of-apps/](./gitops/argocd/advanced/app-of-apps/) | Manage many apps from one root app |
| 🔄 GitOps | [gitops/argocd/advanced/sync-waves/](./gitops/argocd/advanced/sync-waves/) | Ordered deployment with waves |
| 🔄 GitOps | [gitops/argocd/example/](./gitops/argocd/example/) | ArgoCD deploying a Helm chart from Git |
| 🐝 Docker Swarm | [docker-swarm/basics/](./docker-swarm/basics/) | Stack deploy, services, overlay networks |
| 🐝 Docker Swarm | [advanced/secrets/](./docker-swarm/advanced/secrets/) | Encrypted secrets, rotation |
| 🐝 Docker Swarm | [advanced/configs/](./docker-swarm/advanced/configs/) | Config files via Swarm configs |
| 🐝 Docker Swarm | [advanced/rolling-update/](./docker-swarm/advanced/rolling-update/) | Zero-downtime rolling updates |
| 🐝 Docker Swarm | [example/](./docker-swarm/example/) | Full stack: Traefik + API + PostgreSQL + Redis |

---

## 🗺️ Learning Path

```
Containers (../containers/)
        ↓
 Kubernetes basics/           ← Pods, Deployments, Services
        ↓
 Kubernetes advanced/         ← ConfigMaps, Secrets, Ingress, StatefulSets
        ↓
 Kubernetes example/          ← HPA, production patterns
        ↓
    ┌───┴────────────┐
    ↓                ↓
  Helm              Kustomize
  Package your      Patch manifests
  app as a chart    per environment
    ↓                ↓
    └───┬────────────┘
        ↓
   GitOps / ArgoCD             ← Automate deployments from Git
        ↓
   Docker Swarm                ← Lightweight alternative for smaller teams
```

---

## ⚡ Quick Start by Tool

```bash
# ── Kubernetes ──────────────────────────────────────────────────────────────
kubectl apply -f kubernetes/basics/pod.yaml
kubectl get pods -w

# ── Helm ────────────────────────────────────────────────────────────────────
helm install myapp helm/basics/my-first-chart
helm list

# ── Kustomize ───────────────────────────────────────────────────────────────
kubectl apply -k kustomize/overlays/production/
kubectl kustomize kustomize/overlays/dev/     # preview without applying

# ── ArgoCD ──────────────────────────────────────────────────────────────────
kubectl apply -f gitops/argocd/basics/application.yaml -n argocd
argocd app sync taskapp

# ── Docker Swarm ─────────────────────────────────────────────────────────────
docker swarm init
docker stack deploy -c docker-swarm/basics/stack.yml myapp
docker stack services myapp
```

---

## 🛠️ Prerequisites

| Tool | Install | Purpose |
|------|---------|---------|
| `kubectl` | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI |
| `minikube` or `kind` | [minikube](https://minikube.sigs.k8s.io/) / [kind](https://kind.sigs.k8s.io/) | Local K8s cluster |
| `helm` | [helm.sh](https://helm.sh/docs/intro/install/) | Kubernetes package manager |
| `kustomize` | built into `kubectl` | YAML overlay tool |
| `argocd` CLI | [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io/en/stable/cli_installation/) | GitOps CLI |
| `docker` | [docker.com](https://docs.docker.com/get-docker/) | Docker Swarm |

---

## 🔗 Related Topics

- [Containers](../containers/) — prerequisite: images and Docker
- [CI/CD](../ci-cd/) — trigger Helm/ArgoCD deployments from pipelines
- [Monitoring](../monitoring/) — Prometheus + Grafana on Kubernetes
- [DevSecOps](../devsecops/) — image scanning, RBAC, Pod security