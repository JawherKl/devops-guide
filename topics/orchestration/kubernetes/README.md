# ☸️ Kubernetes

> The industry-standard platform for automating deployment, scaling, and management of containerized applications. Work through each section in order to build a solid, practical foundation.

---

## 📋 Sections

| Section | Files | What you'll learn |
|---------|-------|-------------------|
| [basics/](./basics/) | pod.yaml · deployment.yaml · service.yaml | The three core primitives every K8s engineer must master |
| [advanced/configmap-secrets/](./advanced/configmap-secrets/) | configmap.yaml · secret.yaml | Injecting config and credentials into Pods |
| [advanced/ingress/](./advanced/ingress/) | ingress.yaml | HTTP routing, host-based rules, TLS |
| [advanced/multi-container-pod/](./advanced/multi-container-pod/) | pod.yaml | Sidecar, init container, shared volume patterns |
| [advanced/statefulsets/](./advanced/statefulsets/) | statefulset.yaml | Ordered rollout, stable network IDs, PVCs |
| [example/](./example/) | deployment.yaml · hpa-v2.yaml | Full app with autoscaling |

---

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                   Control Plane                     │ │
│  │  kube-apiserver · etcd · scheduler · controller-mgr │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Worker 1   │  │   Worker 2   │  │   Worker 3   │    │
│  │  ┌────────┐  │  │  ┌────────┐  │  │  ┌────────┐  │    │
│  │  │ Pod(s) │  │  │  │ Pod(s) │  │  │  │ Pod(s) │  │    │
│  │  └────────┘  │  │  └────────┘  │  │  └────────┘  │    │
│  │  kubelet     │  │  kubelet     │  │  kubelet     │    │
│  │  kube-proxy  │  │  kube-proxy  │  │  kube-proxy  │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
└──────────────────────────────────────────────────────────┘
       ↑ kubectl / Helm / CI/CD applies manifests via API
```

---

## ⚡ Essential kubectl Commands

```bash
# Cluster info
kubectl cluster-info
kubectl get nodes -o wide

# Apply / delete manifests
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml

# Inspect resources
kubectl get pods -A                    # all namespaces
kubectl get pods -n default -o wide    # with node and IP
kubectl describe pod <name>            # full details + events
kubectl logs <pod> -f                  # follow logs
kubectl logs <pod> -c <container>      # specific container

# Execute into a pod
kubectl exec -it <pod> -- sh
kubectl exec -it <pod> -c <container> -- bash

# Port-forward for local testing
kubectl port-forward pod/<name> 8080:3000
kubectl port-forward svc/<name> 8080:80

# Watch resources change
kubectl get pods -w
kubectl get events --sort-by=.lastTimestamp

# Scale
kubectl scale deployment <name> --replicas=5

# Rollout management
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout undo deployment/<name> --to-revision=2
```

---

**Start here →** [basics/](./basics/)