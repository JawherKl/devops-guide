# ArgoCD Installation

## Prerequisites

- Kubernetes cluster (minikube, kind, k3d, or cloud)
- `kubectl` configured
- `helm` (optional, for Helm chart installation method)

---

## Method 1: kubectl apply (quickest)

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD (stable release)
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Check pods
kubectl get pods -n argocd
```

## Method 2: Helm chart (recommended for production)

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --set configs.params."server\.insecure"=true
```

---

## Access the UI

```bash
# Port-forward (works everywhere)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Change password after first login (security best practice)
argocd account update-password
```

---

## Install ArgoCD CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd-linux-amd64 \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64 && sudo mv argocd-linux-amd64 /usr/local/bin/argocd

# Windows (Scoop)
scoop install argocd

# Login
argocd login localhost:8080 --username admin --password <password> --insecure
```

---

## Register your Git repository

```bash
# HTTPS (public repo — no credentials needed)
argocd repo add https://github.com/JawherKl/devops-guide

# HTTPS (private repo)
argocd repo add https://github.com/yourorg/private-repo \
  --username git \
  --password <personal-access-token>

# SSH
argocd repo add git@github.com:yourorg/private-repo \
  --ssh-private-key-path ~/.ssh/id_rsa
```