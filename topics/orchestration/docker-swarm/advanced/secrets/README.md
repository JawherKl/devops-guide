# Docker Swarm Secrets

Swarm Secrets are **encrypted at rest** (in the Raft log) and **encrypted in transit** (TLS). They are only ever decrypted inside the container that needs them, mounted as a file at `/run/secrets/<name>`.

---

## Creating Secrets

```bash
# From stdin (most secure — never touches disk)
echo "supersecretpassword" | docker secret create db_password -
printf "myjwtkey" | docker secret create jwt_secret -

# From a file
docker secret create tls_cert ./certs/server.crt
docker secret create tls_key  ./certs/server.key

# From a password manager / vault (recommended)
vault kv get -field=password secret/db | docker secret create db_password -

# List all secrets
docker secret ls

# Inspect (shows metadata only — you can NEVER read the value back)
docker secret inspect db_password
```

---

## Rotating a Secret

Swarm secrets are immutable. To rotate:

```bash
# 1. Create new secret with a new name
echo "newpassword" | docker secret create db_password_v2 -

# 2. Update the service to use both secrets temporarily
docker service update \
  --secret-add db_password_v2 \
  --secret-rm db_password \
  mystack_api

# 3. Remove old secret
docker secret rm db_password

# 4. Rename: create a new one with the original name
echo "newpassword" | docker secret create db_password -
docker service update \
  --secret-add db_password \
  --secret-rm db_password_v2 \
  mystack_api
docker secret rm db_password_v2
```

---

## How secrets appear inside the container

```bash
# Inside the container, secrets are files at /run/secrets/<name>
cat /run/secrets/db_password    # "supersecretpassword"

# Read in your app:
# Node.js:
const dbPassword = fs.readFileSync('/run/secrets/db_password', 'utf8').trim();

# Python:
with open('/run/secrets/db_password') as f:
    db_password = f.read().strip()

# Shell:
DB_PASSWORD=$(cat /run/secrets/db_password)
```