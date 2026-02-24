# ⎈ Helm — Kubernetes Package Manager

> Helm packages Kubernetes manifests into reusable, versioned, configurable **charts** — eliminating copy-paste YAML across environments and enabling one-command application deployments.

---

## 💡 Why Helm?

Without Helm you manually manage dozens of YAML files, duplicating them for each environment. With Helm:

```
Without Helm:                      With Helm:
manifests/
  deployment-dev.yaml              helm install myapp ./my-chart \
  deployment-staging.yaml            --set image.tag=1.2.0 \
  deployment-prod.yaml               --set replicas=3
  service-dev.yaml                   --values prod-values.yaml
  service-staging.yaml
  service-prod.yaml                 # one chart, infinite environments
  configmap-dev.yaml
  configmap-prod.yaml
  secret-dev.yaml  ...
```

---

## 📋 Sections

| Section | What you'll learn |
|---------|-------------------|
| [basics/my-first-chart/](./basics/my-first-chart/) | Chart anatomy, templates, values, install/upgrade/rollback |
| [advanced/custom-resources/](./advanced/custom-resources/) | ConfigMap + Secret + Deployment + Service in one chart |
| [advanced/multi-service-app/](./advanced/multi-service-app/) | Named templates, helpers, multi-component chart |

---

## 🏗️ Chart Anatomy

```
my-chart/
├── Chart.yaml          # chart metadata (name, version, description)
├── values.yaml         # default values — overridden at install time
├── templates/          # Go-template YAML manifests
│   ├── _helpers.tpl    # named templates (reusable template fragments)
│   ├── deployment.yaml # uses {{ .Values.* }} and {{ include "..." }}
│   ├── service.yaml
│   ├── ingress.yaml
│   └── configmap.yaml
└── charts/             # chart dependencies (sub-charts)
```

---

## ⚡ Essential Helm Commands

```bash
# ── Install / Upgrade ──────────────────────────────────────────────────────
helm install   <release> <chart>                  # first install
helm upgrade   <release> <chart> --install        # upgrade or install
helm upgrade   <release> <chart> -f values.yaml   # with custom values
helm upgrade   <release> <chart> --set key=value  # inline value override
helm upgrade   <release> <chart> --atomic         # rollback on failure
helm upgrade   <release> <chart> --dry-run        # simulate without applying

# ── Inspect / Debug ─────────────────────────────────────────────────────────
helm list                          # list all releases
helm list -A                       # all namespaces
helm status  <release>             # release info
helm history <release>             # revision history
helm get values <release>          # see applied values
helm get manifest <release>        # see rendered YAML
helm template <release> <chart>    # render templates locally (no cluster)
helm lint <chart>                  # validate chart
helm test <release>                # run chart tests

# ── Rollback / Uninstall ─────────────────────────────────────────────────────
helm rollback <release>            # rollback to previous revision
helm rollback <release> 3          # rollback to revision 3
helm uninstall <release>           # remove release (keeps history by default)
helm uninstall <release> --keep-history  # keep history after uninstall

# ── Repositories ─────────────────────────────────────────────────────────────
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami/postgresql
helm pull bitnami/postgresql --untar  # download chart locally
```

---

## 🔑 Templating Quick Reference

```yaml
# values.yaml value          Template expression
image.repository: nginx  →   {{ .Values.image.repository }}
replicaCount: 3          →   {{ .Values.replicaCount }}
.Release.Name            →   {{ .Release.Name }}  (install-time release name)
.Chart.Name              →   {{ .Chart.Name }}
.Chart.Version           →   {{ .Chart.Version }}

# Conditionals
{{- if .Values.ingress.enabled }}
# render ingress
{{- end }}

# Loops
{{- range .Values.ingress.hosts }}
- host: {{ .host | quote }}
{{- end }}

# Named template (defined in _helpers.tpl)
{{ include "mychart.fullname" . }}

# Default value
{{ .Values.replicaCount | default 1 }}

# Quote string safely
{{ .Values.image.tag | quote }}

# toYaml + nindent (common for labels, env, resources)
{{- toYaml .Values.resources | nindent 12 }}
```

---

**Start here →** [basics/my-first-chart/](./basics/my-first-chart/)