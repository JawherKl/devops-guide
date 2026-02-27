# Istio Installation

## Prerequisites

- Kubernetes cluster ≥ 1.25 (minikube, kind, k3d, or cloud)
- `kubectl` configured and connected
- 4+ GB RAM available in the cluster (Istio control plane is heavy)
- `istioctl` CLI installed

---

## Install `istioctl`

```bash
# macOS / Linux — latest release
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# macOS via Homebrew
brew install istioctl

# Verify
istioctl version
```

---

## Install Istio on the Cluster

Istio ships with several built-in **profiles** — choose based on your needs:

| Profile | Use case | Components |
|---------|----------|------------|
| `minimal` | CI, testing | istiod only |
| `default` | Production | istiod + ingress gateway |
| `demo` | Learning | istiod + ingress + egress gateways |
| `external` | Remote cluster | Connects to external control plane |

```bash
# For local learning (enables all addons)
istioctl install --set profile=demo -y

# For production (ingress gateway only)
istioctl install --set profile=default -y

# Custom: default profile + disable egress gateway
istioctl install --set profile=default \
  --set components.egressGateways[0].enabled=false -y

# Verify control plane is healthy
kubectl get pods -n istio-system
istioctl verify-install
```

---

## Enable Sidecar Injection

Istio automatically injects the Envoy sidecar into new Pods when the namespace has the injection label.

```bash
# Enable injection for the default namespace
kubectl label namespace default istio-injection=enabled

# Enable for a custom namespace
kubectl label namespace my-app istio-injection=enabled

# Verify label is set
kubectl get namespace -L istio-injection

# Inject manually into existing Deployments (no namespace label needed)
kubectl rollout restart deployment/my-app

# Disable injection for a specific Pod (add to pod spec):
# annotations:
#   sidecar.istio.io/inject: "false"
```

---

## Install Observability Addons

```bash
# Install Kiali (service graph UI), Jaeger (tracing), Prometheus, Grafana
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml

# Wait for addons
kubectl rollout status deployment/kiali -n istio-system

# Open dashboards
istioctl dashboard kiali    # service topology + traffic flow
istioctl dashboard jaeger   # distributed tracing
istioctl dashboard grafana  # metrics dashboards
```

---

## Verify Sidecar Injection

```bash
# Deploy a test app — should have 2/2 containers (app + envoy sidecar)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/httpbin.yaml
kubectl get pods
# NAME                       READY   STATUS    RESTARTS
# httpbin-xxxxxxxxxx-xxxxx   2/2     Running   0
#                            ^^^^ 2/2 = app + sidecar injected

# Check proxy config
istioctl proxy-status
istioctl proxy-config cluster deploy/httpbin
```

---

## Uninstall

```bash
istioctl uninstall --purge -y
kubectl delete namespace istio-system
kubectl label namespace default istio-injection-
```