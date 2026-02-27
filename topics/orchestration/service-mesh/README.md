# 🕸️ Service Mesh

<p align="center">
  <img src="https://img.shields.io/badge/Istio-466BB0?style=for-the-badge&logo=istio&logoColor=white"/>
</p>

> A service mesh adds a dedicated infrastructure layer for **service-to-service communication** — handling traffic routing, security (mTLS), observability, and resilience **without changing your application code**. Istio is the CNCF-graduated standard.

---

## 💡 Why a Service Mesh?

Without a service mesh, each microservice must implement its own:
- Retries and timeouts
- Circuit breaking
- mTLS encryption between services
- Distributed tracing
- Traffic splitting for canary deploys

With Istio, all of this is handled by **sidecar proxies (Envoy)** injected into every Pod — the application code stays the same.

```
Without Istio                     With Istio
──────────────────────────────    ────────────────────────────────────────────
  Service A  ──HTTP──▶  Service B  Service A ──▶ [Envoy] ──mTLS──▶ [Envoy] ──▶ Service B
  (app handles TLS,                (sidecar handles TLS, retries,
   retries, tracing)                tracing — app is unaware)
```

---

## 🏗️ Istio Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Control Plane (istiod)                │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────┐  │
│  │    Pilot     │  │    Citadel     │  │   Galley    │  │
│  │ (xDS config) │  │ (cert/mTLS)    │  │ (config     │  │
│  │              │  │                │  │  validation)│  │
│  └──────────────┘  └────────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────┘
             │ xDS API (config push)
             ▼
┌────────────────────────────────────┐
│           Data Plane               │
│  Pod A                Pod B        │
│  ┌──────┐  ┌───────┐  ┌──────┐    │
│  │ App  │  │Envoy  │  │ App  │    │
│  │      │◀─│sidecar│  │      │    │
│  └──────┘  └───────┘  └──────┘    │
│               ▲ mTLS               │
└────────────────────────────────────┘
```

---

## 📋 Sections

| Section | What you'll learn |
|---------|-------------------|
| [istio/basics/](./istio/basics/) | Install Istio, enable sidecar injection, first VirtualService |
| [istio/advanced/traffic-management/](./istio/advanced/traffic-management/) | Canary deploys, fault injection, retries, timeouts |
| [istio/advanced/security/](./istio/advanced/security/) | mTLS enforcement, AuthorizationPolicy, PeerAuthentication |
| [istio/advanced/observability/](./istio/advanced/observability/) | Telemetry, Kiali, Jaeger tracing, Prometheus metrics |
| [istio/example/](./istio/example/) | Full Bookinfo app: canary + mTLS + tracing wired together |

---

## ⚡ Essential Commands

```bash
# ── Install ──────────────────────────────────────────────────────────────────
istioctl install --set profile=default -y
kubectl label namespace default istio-injection=enabled

# ── Status ───────────────────────────────────────────────────────────────────
istioctl proxy-status                    # all sidecar sync status
istioctl analyze                         # lint all Istio configs
kubectl get pods -n istio-system         # control plane health

# ── Traffic ──────────────────────────────────────────────────────────────────
kubectl get virtualservices -A
kubectl get destinationrules -A
kubectl get gateways -A
istioctl proxy-config routes deploy/myapp   # routes seen by a proxy

# ── Security ─────────────────────────────────────────────────────────────────
kubectl get peerauthentication -A           # mTLS policies
kubectl get authorizationpolicy -A          # RBAC policies

# ── Observability ─────────────────────────────────────────────────────────────
kubectl get telemetry -A
istioctl dashboard kiali                    # open Kiali UI
istioctl dashboard jaeger                   # open Jaeger UI
```

---

**Start here →** [istio/basics/](./istio/basics/)