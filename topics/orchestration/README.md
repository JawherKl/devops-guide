# ☸️ Orchestration

<p align="center">
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
  <img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white"/>
  <img src="https://img.shields.io/badge/Kustomize-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
  <img src="https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white"/>
  <img src="https://img.shields.io/badge/Flux-5468FF?style=for-the-badge&logo=flux&logoColor=white"/>
  <img src="https://img.shields.io/badge/Istio-466BB0?style=for-the-badge&logo=istio&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker_Swarm-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
</p>

> From containers to clusters. This topic covers the complete orchestration stack: Kubernetes, Helm, Kustomize, GitOps (ArgoCD + Flux), Service Mesh (Istio), and Docker Swarm.

---

## 📋 Table of Contents

| Tool | Section | What you'll learn |
|------|---------|-------------------|
| ☸️ **Kubernetes** | [basics/](./kubernetes/basics/) | Pods, Deployments, Services |
| ☸️ Kubernetes | [advanced/configmap-secrets/](./kubernetes/advanced/configmap-secrets/) | Config injection, secrets management |
| ☸️ Kubernetes | [advanced/ingress/](./kubernetes/advanced/ingress/) | HTTP routing, TLS termination |
| ☸️ Kubernetes | [advanced/multi-container-pod/](./kubernetes/advanced/multi-container-pod/) | Sidecar, init container, shared volumes |
| ☸️ Kubernetes | [advanced/statefulsets/](./kubernetes/advanced/statefulsets/) | Ordered deploys, stable identities, PVCs |
| ☸️ Kubernetes | [example/](./kubernetes/example/) | Full app: Deployment + HPA autoscaling |
| ⎈ **Helm** | [basics/my-first-chart/](./helm/basics/my-first-chart/) | Chart structure, templates, values |
| ⎈ Helm | [advanced/custom-resources/](./helm/advanced/custom-resources/) | ConfigMap + Secret + multi-resource chart |
| ⎈ Helm | [advanced/multi-service-app/](./helm/advanced/multi-service-app/) | Web + DB chart, helpers, named templates |
| 🔧 **Kustomize** | [basics/](./kustomize/basics/) | Base manifests, configMapGenerator, images |
| 🔧 Kustomize | [overlays/dev/](./kustomize/overlays/dev/) | Dev: 1 replica, debug logging, light resources |
| 🔧 Kustomize | [overlays/staging/](./kustomize/overlays/staging/) | Staging: 2 replicas, RC image tag |
| 🔧 Kustomize | [overlays/production/](./kustomize/overlays/production/) | Prod: 4 replicas, HPA, PodDisruptionBudget |
| 🔧 Kustomize | [advanced/](./kustomize/advanced/) | Components, transformers, replacements |
| 🔄 **GitOps — ArgoCD** | [gitops/argocd/basics/](./gitops/argocd/basics/) | Install ArgoCD, Application CRD, AppProject RBAC |
| 🔄 GitOps — ArgoCD | [gitops/argocd/advanced/app-of-apps/](./gitops/argocd/advanced/app-of-apps/) | Manage many apps from one root Application |
| 🔄 GitOps — ArgoCD | [gitops/argocd/advanced/sync-waves/](./gitops/argocd/advanced/sync-waves/) | Ordered deployment: DB → API → Ingress |
| 🔄 GitOps — ArgoCD | [gitops/argocd/example/](./gitops/argocd/example/) | ArgoCD deploying a Helm chart from Git |
| 🔄 **GitOps — Flux** | [gitops/flux/basics/](./gitops/flux/basics/) | Bootstrap Flux, GitRepository, Kustomization |
| 🔄 GitOps — Flux | [gitops/flux/advanced/helm-releases/](./gitops/flux/advanced/helm-releases/) | HelmRelease CRD: Flux-managed Helm lifecycle |
| 🔄 GitOps — Flux | [gitops/flux/advanced/image-automation/](./gitops/flux/advanced/image-automation/) | Auto-commit new image tags to Git on CI push |
| 🔄 GitOps — Flux | [gitops/flux/example/](./gitops/flux/example/) | Full stack: HelmRelease + image automation + alerts |
| 🕸️ **Service Mesh** | [service-mesh/istio/basics/](./service-mesh/istio/basics/) | Install Istio, sidecar injection, VirtualService |
| 🕸️ Service Mesh | [service-mesh/istio/advanced/traffic-management/](./service-mesh/istio/advanced/traffic-management/) | Canary deploys, fault injection, retries |
| 🕸️ Service Mesh | [service-mesh/istio/advanced/security/](./service-mesh/istio/advanced/security/) | mTLS enforcement, AuthorizationPolicy |
| 🕸️ Service Mesh | [service-mesh/istio/advanced/observability/](./service-mesh/istio/advanced/observability/) | Telemetry, tracing, ServiceEntry |
| 🕸️ Service Mesh | [service-mesh/istio/example/](./service-mesh/istio/example/) | Bookinfo: canary + mTLS + Gateway wired together |
| 🐝 **Docker Swarm** | [docker-swarm/basics/](./docker-swarm/basics/) | Stack deploy, overlay networks, routing mesh |
| 🐝 Docker Swarm | [docker-swarm/advanced/secrets/](./docker-swarm/advanced/secrets/) | Encrypted secrets, creation, rotation |
| 🐝 Docker Swarm | [docker-swarm/advanced/configs/](./docker-swarm/advanced/configs/) | Non-secret config files via Swarm configs |
| 🐝 Docker Swarm | [docker-swarm/advanced/rolling-update/](./docker-swarm/advanced/rolling-update/) | Zero-downtime rolling updates, all knobs |
| 🐝 Docker Swarm | [docker-swarm/example/](./docker-swarm/example/) | Full stack: Traefik + API + PostgreSQL + Redis |

---

## 🗺️ Learning Path

```
Containers (../containers/)
        ↓
 ┌─────────────────────────────────────────────────┐
 │              Kubernetes                         │
 │  basics/ → advanced/ → example/                 │
 └─────────────────────────────────────────────────┘
        ↓
 ┌──────────────────┐    ┌─────────────────────────┐
 │      Helm        │    │        Kustomize        │
 │  Package your    │    │  Patch per environment  │
 │  app as a chart  │    │  dev / staging / prod   │
 └──────────────────┘    └─────────────────────────┘
        ↓                          ↓
        └──────────┬───────────────┘
                   ↓
 ┌─────────────────────────────────────────────────┐
 │                  GitOps                         │
 │  ArgoCD (UI-first)  ←→  Flux (automation-first) │
 └─────────────────────────────────────────────────┘
        ↓
 ┌─────────────────────────────────────────────────┐
 │              Service Mesh — Istio               │
 │  mTLS · canary · fault injection · tracing      │
 └─────────────────────────────────────────────────┘
        ↓
 ┌─────────────────────────────────────────────────┐
 │              Docker Swarm                       │
 │  Lightweight K8s alternative for smaller teams  │
 └─────────────────────────────────────────────────┘
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
kubectl kustomize kustomize/overlays/dev/

# ── ArgoCD ──────────────────────────────────────────────────────────────────
kubectl apply -f gitops/argocd/basics/application.yaml -n argocd
argocd app sync taskapp

# ── Flux ────────────────────────────────────────────────────────────────────
flux bootstrap github --owner=JawherKl --repository=devops-guide \
  --path=topics/orchestration/gitops/flux --personal
flux get all

# ── Istio ───────────────────────────────────────────────────────────────────
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled
kubectl apply -f service-mesh/istio/example/bookinfo-deploy.yaml
kubectl apply -f service-mesh/istio/example/gateway.yaml

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
| `argocd` CLI | [argo-cd.readthedocs.io](https://argo-cd.readthedocs.io/en/stable/cli_installation/) | ArgoCD GitOps CLI |
| `flux` CLI | [fluxcd.io](https://fluxcd.io/flux/installation/) | Flux GitOps CLI |
| `istioctl` | [istio.io/docs](https://istio.io/latest/docs/setup/getting-started/) | Istio service mesh CLI |
| `docker` | [docker.com](https://docs.docker.com/get-docker/) | Docker + Swarm mode |

---

## 📁 Folder Structure

```
orchestration/
├── kubernetes/          ☸️  Pods, Deployments, Services, StatefulSets
│   ├── basics/
│   ├── advanced/
│   └── example/
├── helm/                ⎈  Chart packaging, templates, multi-service charts
│   ├── basics/
│   └── advanced/
├── kustomize/           🔧  Environment overlays (dev/staging/prod), patches
│   ├── basics/
│   ├── overlays/
│   └── advanced/
├── gitops/              🔄  Git as source of truth
│   ├── argocd/          →  UI-first GitOps, app-of-apps, sync-waves
│   └── flux/            →  Automation-first, image automation, HelmRelease
├── service-mesh/        🕸️  Service-to-service traffic, mTLS, canary
│   └── istio/
│       ├── basics/
│       ├── advanced/
│       └── example/
└── docker-swarm/        🐝  Lightweight orchestration built into Docker
    ├── basics/
    ├── advanced/
    └── example/
```

---

## 🔗 Related Topics

- [Containers](../containers/) — prerequisite: images, Dockerfile, Docker Compose
- [Server Management](../server-management/) — Nginx, reverse proxy, firewall basics
- [CI/CD](../ci-cd/) — trigger Helm/ArgoCD/Flux deployments from pipelines
- [Monitoring](../monitoring/) — Prometheus + Grafana on Kubernetes
- [DevSecOps](../devsecops/) — image scanning, RBAC, Pod security policies