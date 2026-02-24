# ☸️ Orchestration

<p align="center">
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
  <img src="https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white"/>
</p>

> From containers to clusters. This topic covers Kubernetes — the industry-standard container orchestration platform — and Helm, its package manager. Every section is hands-on with real, runnable manifests and charts.

---

## 📋 Table of Contents

| Tool | Section | What you'll learn |
|------|---------|-------------------|
| ☸️ Kubernetes | [basics/](./kubernetes/basics/) | Pods, Deployments, Services — the three primitives |
| ☸️ Kubernetes | [advanced/configmap-secrets/](./kubernetes/advanced/configmap-secrets/) | Config injection · secrets management |
| ☸️ Kubernetes | [advanced/ingress/](./kubernetes/advanced/ingress/) | HTTP routing · TLS termination · path-based rules |
| ☸️ Kubernetes | [advanced/multi-container-pod/](./kubernetes/advanced/multi-container-pod/) | Sidecar · init container · shared volumes |
| ☸️ Kubernetes | [advanced/statefulsets/](./kubernetes/advanced/statefulsets/) | Ordered deploys · stable identities · persistent storage |
| ☸️ Kubernetes | [example/](./kubernetes/example/) | Full app: Deployment + HPA autoscaling |
| ⎈ Helm | [basics/my-first-chart/](./helm/basics/my-first-chart/) | Chart structure · templates · values |
| ⎈ Helm | [advanced/custom-resources/](./helm/advanced/custom-resources/) | ConfigMap · Secret · multi-resource chart |
| ⎈ Helm | [advanced/multi-service-app/](./helm/advanced/multi-service-app/) | Web + DB chart · helpers · named templates |

---

## 🗺️ Learning Path

```
Containers (../containers/)
        ↓
 Kubernetes basics/           ← Pods, Deployments, Services
        ↓
 Kubernetes advanced/         ← ConfigMaps, Secrets, Ingress,
        ↓                        StatefulSets, Sidecars
 Kubernetes example/          ← HPA, production patterns
        ↓
 Helm basics/                 ← Package your manifests as charts
        ↓
 Helm advanced/               ← Multi-service charts, templating
        ↓
 CI/CD (../ci-cd/)            ← Automate deployments with Helm
```

---

## ⚡ Quick Start

```bash
# Verify tools
kubectl version --client
helm version

# Local cluster options
minikube start                    # lightweight local cluster
kind create cluster               # Kubernetes IN Docker
k3d cluster create devops-guide   # k3s in Docker

# Apply your first manifest
kubectl apply -f kubernetes/basics/pod.yaml
kubectl get pods -w

# Install your first Helm chart
helm install my-app helm/basics/my-first-chart
helm list
```

---

## 🛠️ Prerequisites

| Tool | Install | Purpose |
|------|---------|---------|
| `kubectl` | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI |
| `minikube` or `kind` | [minikube](https://minikube.sigs.k8s.io/) / [kind](https://kind.sigs.k8s.io/) | Local cluster |
| `helm` | [helm.sh/docs](https://helm.sh/docs/intro/install/) | Package manager |

---

## 🔑 Concepts at a Glance

| Concept | One-liner |
|---------|-----------|
| **Pod** | Smallest deployable unit — one or more containers sharing network + storage |
| **Deployment** | Manages a ReplicaSet — rolling updates, rollbacks, scaling |
| **Service** | Stable DNS name + load balancing across Pod replicas |
| **ConfigMap** | Inject non-secret config data into Pods as env vars or files |
| **Secret** | Base64-encoded (not encrypted) sensitive values injected into Pods |
| **Ingress** | HTTP/HTTPS routing rules — host + path → Service |
| **StatefulSet** | Like Deployment but with stable hostname and ordered rollout |
| **HPA** | Horizontal Pod Autoscaler — scale replicas based on CPU/memory |
| **Helm Chart** | Reusable, versioned package of Kubernetes manifests |
| **Release** | An installed instance of a Helm chart in a cluster |

---

## 🔗 Related Topics

- [Containers](../containers/) — prerequisite: images and Docker
- [CI/CD](../ci-cd/) — automate `helm upgrade` in pipelines
- [Monitoring](../monitoring/) — Prometheus + Grafana on Kubernetes
- [DevSecOps](../devsecops/) — image scanning, RBAC, Pod security