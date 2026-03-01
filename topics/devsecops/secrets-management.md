# 🔑 Secrets Management

> Secrets — API keys, database passwords, TLS certificates, SSH keys — are the keys to your kingdom. A single leaked credential can compromise an entire production environment. The rule is simple: secrets never live in source code, never in environment files committed to Git, and never in container images. This file covers the tools and patterns to manage secrets correctly at every stage of the DevOps lifecycle.

---

## Why Secrets Leak (and How to Stop It)

```
Common causes of credential exposure:
  ❌ Hardcoded in source code:    DB_PASSWORD = "prod-secret-123"
  ❌ In .env committed to Git:    echo ".env" forgotten in .gitignore
  ❌ In Dockerfile ENV:           ENV API_KEY=abc123  (visible in image layers)
  ❌ In CI logs:                  echo $SECRET printed during debug step
  ❌ In Kubernetes ConfigMap:     wrong resource type (use Secret, not ConfigMap)
  ❌ In Helm values.yaml:         committed with real values instead of placeholders

Prevention layers:
  ✅ Pre-commit hooks:            detect-secrets, Gitleaks block commits
  ✅ CI scanning:                 TruffleHog, Gitleaks scan every push
  ✅ Secrets manager:             Vault, AWS Secrets Manager — secrets injected at runtime
  ✅ Kubernetes:                  Sealed Secrets or External Secrets Operator
  ✅ Never log secrets:           mask in CI, never echo in scripts
```

---

## detect-secrets — Pre-commit Hook

detect-secrets scans staged files before every commit and blocks those containing credentials.

```bash
# ── Install ────────────────────────────────────────────────────────────────────
pip install detect-secrets

# ── Create a baseline (scan existing codebase, mark known false positives) ───
detect-secrets scan > .secrets.baseline
# Review .secrets.baseline — audit each entry, mark false positives as audited

# ── Audit the baseline (interactive) ─────────────────────────────────────────
detect-secrets audit .secrets.baseline
# For each potential secret, you answer: real (needs remediation) or false positive

# ── Set up pre-commit hook ────────────────────────────────────────────────────
# .pre-commit-config.yaml:
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: package.lock.json

# Install hooks:
pip install pre-commit
pre-commit install

# ── Manual scan ───────────────────────────────────────────────────────────────
detect-secrets scan src/          # scan a directory
detect-secrets scan --list-all-plugins  # see which patterns are detected
```

---

## Gitleaks — Git History Scanner

Gitleaks scans the entire Git history — not just current files — catching secrets that were committed and then "deleted" (deletion doesn't remove from history).

```bash
# ── Install ────────────────────────────────────────────────────────────────────
brew install gitleaks
# or Docker:
docker run --rm -v "$(pwd):/repo" zricethezav/gitleaks:latest detect --source=/repo

# ── Scan modes ────────────────────────────────────────────────────────────────
gitleaks detect                   # scan working directory (unstaged + staged)
gitleaks detect --staged          # scan only staged files (pre-commit use)
gitleaks detect --source .        # scan full repo including history
gitleaks git --log-opts="--all"  # scan all branches

# ── Output ────────────────────────────────────────────────────────────────────
gitleaks detect --report-format json --report-path leaks.json

# ── Custom rules ─────────────────────────────────────────────────────────────
# .gitleaks.toml:
[extend]
useDefault = true    # include built-in rules

[[rules]]
id          = "internal-api-key"
description = "Internal API key pattern"
regex       = '''MYAPP-[A-Z0-9]{32}'''
tags        = ["key", "internal"]

[[allowlist]]
description = "Test fixtures"
paths       = ["tests/fixtures/.*"]

# ── CI integration ────────────────────────────────────────────────────────────
# .github/workflows/secrets-scan.yml
- name: Gitleaks
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## HashiCorp Vault

Vault is the industry-standard secrets manager. It stores secrets centrally, controls access with policies, rotates credentials automatically, and provides a full audit log of every secret access.

```bash
# ── Start Vault in dev mode (local development only) ─────────────────────────
vault server -dev -dev-root-token-id="root"
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# ── KV Secrets Engine (Key-Value) ─────────────────────────────────────────────
# Enable KV v2:
vault secrets enable -path=secret kv-v2

# Write a secret:
vault kv put secret/myapp/production \
  db_password="super-secret" \
  api_key="abc123" \
  redis_url="redis://redis:6379"

# Read:
vault kv get secret/myapp/production
vault kv get -field=db_password secret/myapp/production   # single field
vault kv get -format=json secret/myapp/production | jq .data.data

# List:
vault kv list secret/myapp/

# Versioning (KV v2):
vault kv get -version=2 secret/myapp/production   # previous version
vault kv rollback -version=2 secret/myapp/production

# ── Dynamic Secrets — Database ────────────────────────────────────────────────
# Vault generates short-lived database credentials on demand.
# No shared static password — every app gets a unique credential that expires.

vault secrets enable database

vault write database/config/mydb \
  plugin_name=postgresql-database-plugin \
  allowed_roles="app-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/mydb" \
  username="vault-admin" \
  password="admin-password"

vault write database/roles/app-role \
  db_name=mydb \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Generate credentials (each call returns unique user/pass):
vault read database/creds/app-role
# → username: v-app-role-AbCd1234
# → password: A1b2C3d4...
# → expires in 1 hour, Vault revokes automatically

# ── Policies — least-privilege access ─────────────────────────────────────────
# vault-policy-myapp.hcl:
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

path "database/creds/app-role" {
  capabilities = ["read"]
}

# No access to other apps' secrets or admin paths.

vault policy write myapp-policy vault-policy-myapp.hcl

# ── Kubernetes Auth ────────────────────────────────────────────────────────────
# Pods authenticate to Vault using their Kubernetes service account JWT.
vault auth enable kubernetes

vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc"

vault write auth/kubernetes/role/myapp-role \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=production \
  policies=myapp-policy \
  ttl=1h

# In the pod — Vault Agent Injector (sidecar pattern):
# Annotate the deployment:
```

```yaml
# kubernetes/deployment.yaml — Vault Agent annotations
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp-role"
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/production"
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/data/myapp/production" -}}
          export DB_PASSWORD="{{ .Data.data.db_password }}"
          export API_KEY="{{ .Data.data.api_key }}"
          {{- end }}
# The injected file is at /vault/secrets/config
# Source it in your entrypoint: source /vault/secrets/config
```

---

## SOPS — Secrets in Version Control

SOPS (Secrets OPerationS) encrypts secret files so they can be safely committed to Git. The encrypted file is version-controlled; the key lives in KMS or PGP.

```bash
# ── Install ────────────────────────────────────────────────────────────────────
brew install sops
# or download from https://github.com/getsops/sops/releases

# ── Encrypt with AWS KMS ──────────────────────────────────────────────────────
# .sops.yaml — configure which keys to use per path:
creation_rules:
  - path_regex: k8s/.*\.yaml$
    kms: arn:aws:kms:us-east-1:123456789:key/mrk-abc123
    aws_profile: production

  - path_regex: terraform/.*\.tfvars$
    kms: arn:aws:kms:us-east-1:123456789:key/mrk-abc123

  - path_regex: \.env$
    pgp: FINGERPRINT1,FINGERPRINT2   # team members' GPG keys

# Encrypt a file:
sops --encrypt secrets.yaml > secrets.enc.yaml
# Or in-place (SOPS convention: keep as .yaml, encrypt values not keys):
sops --encrypt --in-place secrets.yaml

# Decrypt:
sops --decrypt secrets.enc.yaml
sops --decrypt --in-place secrets.yaml

# Edit encrypted file directly (decrypts → opens editor → re-encrypts):
sops secrets.yaml

# ── Use with Kubernetes manifests ─────────────────────────────────────────────
# Original secrets.yaml:
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
stringData:
  db-password: "plaintext-in-dev"
  api-key: "plaintext-in-dev"

# After sops --encrypt:
# stringData values are encrypted, keys remain readable.

# Apply to cluster (decrypt in pipeline):
sops --decrypt k8s/secrets.yaml | kubectl apply -f -

# ── Helm + SOPS (helm-secrets plugin) ────────────────────────────────────────
helm plugin install https://github.com/jkroepke/helm-secrets
helm secrets dec values-prod.enc.yaml          # decrypt
helm secrets install myapp ./chart -f values-prod.enc.yaml  # deploy with decrypted values
```

---

## Sealed Secrets (Kubernetes)

Sealed Secrets solves the "how do I store Kubernetes Secrets in Git" problem. A controller in the cluster holds the private key and decrypts SealedSecret objects into regular Secrets.

```bash
# ── Install controller ────────────────────────────────────────────────────────
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# ── Install kubeseal CLI ──────────────────────────────────────────────────────
brew install kubeseal

# ── Create a SealedSecret from a regular Secret ───────────────────────────────
# 1. Create the regular Secret (don't apply to cluster):
kubectl create secret generic myapp-secrets \
  --from-literal=db-password="super-secret" \
  --from-literal=api-key="abc123" \
  --namespace=production \
  --dry-run=client -o yaml > secret.yaml

# 2. Seal it (encrypted with cluster's public key):
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# 3. Commit sealed-secret.yaml to Git — it's safe to commit
git add sealed-secret.yaml
git commit -m "chore: add myapp sealed secrets"

# 4. Apply to cluster (controller decrypts → creates regular Secret):
kubectl apply -f sealed-secret.yaml

# ── Rotate the sealing key ────────────────────────────────────────────────────
# Keys rotate automatically every 30 days; old keys are retained for decryption.
# Force rotation:
kubectl -n kube-system delete secret -l sealedsecrets.bitnami.com/sealed-secrets-key

# Fetch current public key (for CI):
kubeseal --fetch-cert > pub-cert.pem
kubeseal --cert pub-cert.pem --format yaml < secret.yaml > sealed.yaml
```

---

## External Secrets Operator

External Secrets Operator syncs secrets from AWS Secrets Manager, GCP Secret Manager, Vault, etc. directly into Kubernetes Secrets.

```yaml
# ClusterSecretStore — connect to AWS Secrets Manager
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:                          # use IRSA (IAM Roles for Service Accounts)
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets

---
# ExternalSecret — pull a secret and create a Kubernetes Secret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-secrets
  namespace: production
spec:
  refreshInterval: 1h                 # re-sync every hour
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: myapp-secrets               # name of the resulting Kubernetes Secret
    creationPolicy: Owner
  data:
    - secretKey: db-password          # key in the K8s Secret
      remoteRef:
        key: production/myapp         # path in AWS Secrets Manager
        property: db_password         # field within the secret JSON
    - secretKey: api-key
      remoteRef:
        key: production/myapp
        property: api_key
```

---

## Emergency: Secret Already Committed

```bash
# ── Step 1: Revoke immediately (before anything else) ─────────────────────────
# Rotate the credential: regenerate API key, change DB password, etc.
# Assume the secret is already compromised.

# ── Step 2: Remove from Git history with git filter-repo ─────────────────────
pip install git-filter-repo

# Remove a specific file from all history:
git filter-repo --path secrets/.env --invert-paths

# Remove a specific string from all files in history:
git filter-repo --replace-text <(echo "ACTUAL_SECRET_VALUE==>REDACTED")

# ── Step 3: Force-push all branches ──────────────────────────────────────────
git push origin --force --all
git push origin --force --tags

# ── Step 4: Invalidate everyone's clones ─────────────────────────────────────
# Notify all team members — their clones still contain the secret.
# Everyone must re-clone:
# git clone <repo>  (not git pull)

# ── Step 5: Add to .gitignore and never again ─────────────────────────────────
echo ".env" >> .gitignore
echo "*.pem" >> .gitignore
echo "*.key" >> .gitignore
git commit -m "chore: prevent secret files from being tracked"

# Note: GitHub has secret scanning built-in — it will email you if a known
# provider token pattern is detected in a push. Enable it in repo Settings.
```