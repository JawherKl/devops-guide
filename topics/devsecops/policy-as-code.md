# 📏 Policy as Code

> Policy as Code means writing security and compliance rules in machine-readable files that are version-controlled, tested, and automatically enforced — just like application code. In a Kubernetes cluster, admission controllers intercept every API request and run your policies before the resource is created. A pod that violates policy is rejected at `kubectl apply` time, not discovered months later in a security audit.

---

## Why Policy as Code

```
Without policy as code:
  Developer runs: kubectl apply -f pod.yaml
         │
         ▼
  Pod starts running as root
  No resource limits
  Image pulled from unverified registry
  Privileged mode enabled
         │
         ▼
  Security team finds it 3 months later in a scan

With policy as code (OPA Gatekeeper or Kyverno):
  Developer runs: kubectl apply -f pod.yaml
         │
         ▼
  Admission Webhook intercepts the request
  Policies evaluated against the manifest
         │
    ┌────┴────────────────────────────────────────┐
    │                                             │
  Pass ✅                                    Fail ❌
  Resource created                           Rejected immediately:
                                             Error: [denied by require-non-root]
                                             containers must not run as root
```

---

## OPA Gatekeeper

OPA (Open Policy Agent) Gatekeeper enforces policies written in **Rego** — a declarative query language. Policies are defined as `ConstraintTemplates` (the rule logic) and `Constraints` (the instances that activate them).

### Installation

```bash
# Install Gatekeeper into the cluster
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.15/deploy/gatekeeper.yaml

# Verify
kubectl get pods -n gatekeeper-system
# NAME                                             READY   STATUS
# gatekeeper-audit-XXXX                           1/1     Running
# gatekeeper-controller-manager-XXXX              1/1     Running
# gatekeeper-controller-manager-XXXX              1/1     Running

# Check webhook
kubectl get validatingwebhookconfiguration gatekeeper-validating-webhook-configuration
```

### ConstraintTemplate + Constraint Pattern

Every Gatekeeper policy has two parts:

1. **ConstraintTemplate** — defines the Rego logic and the CRD schema
2. **Constraint** — activates the template with specific parameters and scope

```yaml
# ── Example 1: Require non-root containers ──────────────────────────────────

# Step 1: ConstraintTemplate (defines the rule)
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequirenonroot
spec:
  crd:
    spec:
      names:
        kind: K8sRequireNonRoot
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequirenonroot

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.securityContext.runAsNonRoot
          msg := sprintf("Container '%v' must set securityContext.runAsNonRoot=true", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          container.securityContext.runAsUser == 0
          msg := sprintf("Container '%v' must not run as UID 0 (root)", [container.name])
        }

        # Also check initContainers
        violation[{"msg": msg}] {
          container := input.review.object.spec.initContainers[_]
          container.securityContext.runAsUser == 0
          msg := sprintf("initContainer '%v' must not run as UID 0", [container.name])
        }
---
# Step 2: Constraint (activates the template)
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireNonRoot
metadata:
  name: require-non-root-all-namespaces
spec:
  enforcementAction: deny         # deny | dryrun | warn
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system               # system pods may need root
      - gatekeeper-system
```

```yaml
# ── Example 2: Require resource limits ──────────────────────────────────────

apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequireresourcelimits
spec:
  crd:
    spec:
      names:
        kind: K8sRequireResourceLimits
      validation:
        openAPIV3Schema:
          properties:
            cpu:
              type: string
            memory:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireresourcelimits

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.memory
          msg := sprintf("Container '%v' must set resources.limits.memory", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.cpu
          msg := sprintf("Container '%v' must set resources.limits.cpu", [container.name])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireResourceLimits
metadata:
  name: require-resource-limits
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces: [kube-system, monitoring]
```

```yaml
# ── Example 3: Allowed image registries ──────────────────────────────────────

apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRepos
      validation:
        openAPIV3Schema:
          properties:
            repos:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sallowedrepos

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not allowed_repo(container.image)
          msg := sprintf("Container '%v' image '%v' is not from an allowed registry. Allowed: %v",
            [container.name, container.image, input.parameters.repos])
        }

        allowed_repo(image) {
          repo := input.parameters.repos[_]
          startswith(image, repo)
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: allowed-registries
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
  parameters:
    repos:
      - "gcr.io/my-company/"
      - "registry.example.com/"
      - "ghcr.io/my-org/"
```

```yaml
# ── Example 4: Require specific labels ───────────────────────────────────────

apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Resource is missing required labels: %v", [missing])
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-team-labels
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
  parameters:
    labels:
      - "app.kubernetes.io/name"
      - "app.kubernetes.io/version"
      - "team"
      - "environment"
```

### Gatekeeper Enforcement Actions

```yaml
# enforcementAction options:

# deny: reject the request — hard enforcement
enforcementAction: deny

# warn: allow but emit a warning — soft enforcement (good for rollout)
enforcementAction: warn
# Result: resource is created, but kubectl shows:
# Warning: [require-resource-limits] Container 'api' must set resources.limits.memory

# dryrun: audit only — never block (use during policy development)
enforcementAction: dryrun
# Check what WOULD be denied:
kubectl get K8sRequireNonRoot -o yaml
kubectl describe K8sRequireNonRoot require-non-root-all-namespaces
```

### Gatekeeper Audit

Audit mode checks existing resources (not just new ones):

```bash
# View audit results for a constraint
kubectl describe k8srequirenonroot require-non-root-all-namespaces
# Shows: totalViolations: 3
#        violations:
#          - message: "Container 'api' must set runAsNonRoot=true"
#            resource: {group: "", version: "v1", kind: "Pod", namespace: "default", name: "api-xyz"}

# List all violations across all constraints
kubectl get constraints -A
kubectl get constraints -o json | jq '.items[] | {name: .metadata.name, violations: .status.totalViolations}'
```

---

## Kyverno

Kyverno uses pure YAML policies — no Rego. This makes it more accessible. It supports validating, mutating (auto-fixing), and generating resources.

### Installation

```bash
# Install with Helm
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set replicaCount=3          # 3 replicas for HA

# Verify
kubectl get pods -n kyverno
```

### Validate Policies (Block Bad Resources)

```yaml
# ── Require non-root ─────────────────────────────────────────────────────────
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-run-as-non-root
  annotations:
    policies.kyverno.io/title: Require Non-Root Containers
    policies.kyverno.io/severity: high
    policies.kyverno.io/description: >-
      Containers must not run as root. Set securityContext.runAsNonRoot=true.
spec:
  validationFailureAction: Enforce    # Enforce (block) | Audit (log only)
  background: true                    # also check existing resources
  rules:
    - name: check-containers
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: ["default", "production", "staging"]
      exclude:
        any:
          - resources:
              namespaces: [kube-system]
      validate:
        message: "Containers must not run as root. Set securityContext.runAsNonRoot=true"
        pattern:
          spec:
            containers:
              - securityContext:
                  runAsNonRoot: "true"
```

```yaml
# ── Disallow privileged containers ────────────────────────────────────────────
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-privileged
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        message: "Privileged mode is not allowed. Remove securityContext.privileged=true"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.containers[].securityContext.privileged | to_boolean(@) }}"
                operator: AnyIn
                value: [true]
```

```yaml
# ── Require resource limits ────────────────────────────────────────────────────
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: validate-limits
      match:
        any:
          - resources:
              kinds: [Pod]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, monitoring]
      validate:
        message: "Resource limits for CPU and memory are required"
        pattern:
          spec:
            containers:
              - name: "?*"
                resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

### Mutate Policies (Auto-Fix on Admission)

Mutate policies automatically modify resources to comply — great for adding required labels or security defaults without burdening developers.

```yaml
# ── Auto-add security context defaults ────────────────────────────────────────
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-security-context
spec:
  rules:
    - name: add-security-context
      match:
        any:
          - resources:
              kinds: [Pod]
      mutate:
        patchStrategicMerge:
          spec:
            securityContext:
              +(runAsNonRoot): true          # + = add only if not present
              +(seccompProfile):
                type: RuntimeDefault
            containers:
              - (name): "?*"
                securityContext:
                  +(allowPrivilegeEscalation): false
                  +(readOnlyRootFilesystem): true
                  +(runAsNonRoot): true
```

```yaml
# ── Auto-add required labels ──────────────────────────────────────────────────
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-labels
spec:
  rules:
    - name: add-labels
      match:
        any:
          - resources:
              kinds: [Deployment, StatefulSet, DaemonSet]
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              +(managed-by): kyverno
              +(environment): "{{ request.namespace }}"
```

### Generate Policies (Create Resources Automatically)

```yaml
# ── Auto-create NetworkPolicy when a namespace is created ─────────────────────
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: default-deny-network-policy
spec:
  rules:
    - name: generate-network-policy
      match:
        any:
          - resources:
              kinds: [Namespace]
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny-all
        namespace: "{{ request.object.metadata.name }}"
        synchronize: true     # keep in sync with this policy
        data:
          spec:
            podSelector: {}   # selects all pods in namespace
            policyTypes:
              - Ingress
              - Egress
            # No ingress/egress rules = default deny all
```

### Policy Reports

```bash
# Kyverno generates PolicyReport and ClusterPolicyReport resources
kubectl get policyreport -A
kubectl get clusterpolicyreport

# View violations for a specific namespace
kubectl get policyreport -n production -o yaml

# Count violations per policy
kubectl get policyreport -A -o json | \
  jq '.items[].results[] | select(.result == "fail") | .policy' | \
  sort | uniq -c | sort -rn
```

---

## OPA Conftest — Policy Testing in CI (Pre-Deploy)

Conftest uses OPA Rego to validate configuration files BEFORE they reach the cluster — in CI, during `helm template`, or as a pre-commit hook.

```bash
# Install
brew install conftest
# or:
go install github.com/open-policy-agent/conftest@latest

# Download community policies
conftest pull github.com/instrumenta/policies
```

### Write Conftest Policies

```rego
# policy/kubernetes.rego
package main

# Deny pods running as root
deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  container.securityContext.runAsUser == 0
  msg := sprintf("Container '%v' runs as root (UID 0)", [container.name])
}

# Deny missing resource limits
deny[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("Container '%v' has no memory limit", [container.name])
}

# Warn about latest tag
warn[msg] {
  input.kind == "Pod"
  container := input.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%v' uses ':latest' tag — pin to a specific version", [container.name])
}
```

```bash
# Test Kubernetes YAML files
conftest test deployment.yaml
conftest test manifests/

# Test Helm chart output
helm template my-app ./chart | conftest test -

# Test with multiple policy directories
conftest test manifests/ --policy policy/ --policy shared-policy/

# Output formats
conftest test deployment.yaml --output table
conftest test deployment.yaml --output json
conftest test deployment.yaml --output junit    # for CI

# Return codes:
# 0 = all tests passed
# 1 = test failures (deny rules triggered)
```

### Conftest in CI

```yaml
# .github/workflows/policy-check.yml
name: Policy as Code

on:
  pull_request:
    paths:
      - "k8s/**"
      - "helm/**"
      - "policy/**"

jobs:
  conftest:
    name: Conftest Policy Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Helm
        uses: azure/setup-helm@v3

      - name: Install conftest
        run: |
          VERSION=$(curl -s https://api.github.com/repos/open-policy-agent/conftest/releases/latest | jq -r .tag_name)
          curl -Lo conftest.tar.gz "https://github.com/open-policy-agent/conftest/releases/download/${VERSION}/conftest_${VERSION#v}_Linux_x86_64.tar.gz"
          tar xzf conftest.tar.gz conftest
          sudo mv conftest /usr/local/bin/

      - name: Test raw Kubernetes manifests
        run: conftest test k8s/ --policy policy/ --output table

      - name: Test Helm chart output
        run: |
          helm template my-app ./helm/my-app \
            -f helm/my-app/values.yaml \
            | conftest test - --policy policy/

      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: conftest-results
          path: conftest-results.json
```

---

## Gatekeeper vs Kyverno — Decision Guide

| Factor | OPA Gatekeeper | Kyverno |
|--------|---------------|---------|
| Policy language | Rego (powerful, steep curve) | YAML patterns (easy, approachable) |
| Learning curve | High | Low |
| Flexibility | Very high (Rego = general purpose) | High (covers 90% of use cases) |
| Mutation | No | Yes |
| Generate resources | No | Yes |
| Policy reports | Via audit | Built-in `PolicyReport` CRDs |
| Community policies | Gatekeeper Library | Kyverno Policies repo |
| Best for | Teams with OPA experience, complex logic | Teams new to policy-as-code, fast adoption |

```bash
# Browse the community policy libraries:
# Gatekeeper: https://open-policy-agent.github.io/gatekeeper-library/
# Kyverno:    https://kyverno.io/policies/

# Install all Gatekeeper library policies at once:
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper-library/master/library/general/allowedrepos/template.yaml

# Install Kyverno pod security policies (NSA/CISA hardening baseline):
kubectl apply -f https://kyverno.io/policies/pod-security/
```

---

## Testing Policies

Always test policies before enforcing them — especially mutation and generate policies.

```bash
# Gatekeeper: use dryrun mode first, then switch to warn, then deny
# 1. Start with dryrun:
kubectl patch constraint require-non-root --type=merge \
  -p '{"spec":{"enforcementAction":"dryrun"}}'

# 2. Check audit results:
kubectl describe constraint require-non-root

# 3. Switch to warn (still allows, but developers see warnings):
kubectl patch constraint require-non-root --type=merge \
  -p '{"spec":{"enforcementAction":"warn"}}'

# 4. After teams have fixed violations, switch to deny:
kubectl patch constraint require-non-root --type=merge \
  -p '{"spec":{"enforcementAction":"deny"}}'

# Kyverno: use Audit mode first, then Enforce
# 1. Start with Audit:
kubectl patch cpol require-run-as-non-root --type=merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'

# 2. Review PolicyReport violations:
kubectl get policyreport -A -o json | jq '.items[].results[] | select(.result=="fail")'

# 3. Switch to Enforce after cleanup:
kubectl patch cpol require-run-as-non-root --type=merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

### Unit Testing Rego Policies (OPA)

```bash
# Install OPA CLI
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
chmod +x opa && sudo mv opa /usr/local/bin/

# Write a test file alongside your policy
# policy/k8s_test.rego
package k8srequirenonroot_test

import data.k8srequirenonroot

# Test: root container should fail
test_root_container_denied {
  count(k8srequirenonroot.violation) > 0 with input as {
    "review": {
      "object": {
        "spec": {
          "containers": [{
            "name": "api",
            "securityContext": {"runAsUser": 0}
          }]
        }
      }
    }
  }
}

# Test: non-root container should pass
test_non_root_container_allowed {
  count(k8srequirenonroot.violation) == 0 with input as {
    "review": {
      "object": {
        "spec": {
          "containers": [{
            "name": "api",
            "securityContext": {"runAsNonRoot": true, "runAsUser": 1000}
          }]
        }
      }
    }
  }
}

# Run all policy tests
opa test policy/ -v
```

---

## Rollout Strategy

```
Week 1: Audit
  └── Deploy Gatekeeper/Kyverno with enforcementAction: Audit/dryrun
  └── Generate policy reports — inventory all violations

Week 2–3: Warn
  └── Switch to warn mode
  └── Notify teams of violations with ticket numbers
  └── Add exemptions for legacy workloads (with expiry dates)

Week 4+: Enforce
  └── Switch to Enforce/deny for new namespaces first
  └── Roll out enforcement namespace by namespace
  └── Keep audit running on excluded namespaces to track progress

Ongoing:
  └── Conftest in every PR (pre-admission check)
  └── Weekly policy report review
  └── Add new policies for new CVE classes
  └── Automate exemption expiry reviews
```