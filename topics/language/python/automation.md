# 🤖 Python Automation

> Python shines in DevOps automation because every major cloud and infrastructure platform ships a Python SDK. This file covers AWS with boto3, Kubernetes with the Python client, and practical automation patterns for real operations work.

---

## AWS Automation with boto3

```python
"""aws_ops.py — common AWS operations with boto3."""
import boto3
import time
import logging
from typing import Iterator
from botocore.exceptions import ClientError, WaiterError

logger = logging.getLogger(__name__)

# ── Session and client setup ──────────────────────────────────────────────────
def get_session(region: str = "us-east-1", profile: str | None = None) -> boto3.Session:
    """Create a boto3 session. Uses instance profile in EC2/ECS/Lambda automatically."""
    return boto3.Session(region_name=region, profile_name=profile)

# ── EC2 Operations ────────────────────────────────────────────────────────────
class EC2Manager:
    def __init__(self, session: boto3.Session):
        self.ec2 = session.resource("ec2")
        self.client = session.client("ec2")

    def list_instances(self, filters: list[dict] | None = None) -> list[dict]:
        """List EC2 instances with optional filters."""
        filters = filters or []
        instances = []
        for reservation in self.client.describe_instances(Filters=filters)["Reservations"]:
            for inst in reservation["Instances"]:
                name = next(
                    (t["Value"] for t in inst.get("Tags", []) if t["Key"] == "Name"),
                    "unnamed",
                )
                instances.append({
                    "id": inst["InstanceId"],
                    "name": name,
                    "state": inst["State"]["Name"],
                    "type": inst["InstanceType"],
                    "private_ip": inst.get("PrivateIpAddress"),
                    "public_ip": inst.get("PublicIpAddress"),
                })
        return instances

    def wait_for_running(self, instance_id: str, timeout: int = 300) -> None:
        """Wait for an instance to reach running state."""
        logger.info("Waiting for %s to be running...", instance_id)
        try:
            waiter = self.client.get_waiter("instance_running")
            waiter.wait(
                InstanceIds=[instance_id],
                WaiterConfig={"Delay": 5, "MaxAttempts": timeout // 5},
            )
            logger.info("%s is running", instance_id)
        except WaiterError as exc:
            raise RuntimeError(f"Timed out waiting for {instance_id}") from exc

    def stop_instances_by_tag(self, tag_key: str, tag_value: str) -> list[str]:
        """Stop all instances matching a tag."""
        instances = self.list_instances([
            {"Name": f"tag:{tag_key}", "Values": [tag_value]},
            {"Name": "instance-state-name", "Values": ["running"]},
        ])
        ids = [i["id"] for i in instances]
        if ids:
            self.client.stop_instances(InstanceIds=ids)
            logger.info("Stopping %d instances: %s", len(ids), ids)
        return ids

# ── S3 Operations ─────────────────────────────────────────────────────────────
class S3Manager:
    def __init__(self, session: boto3.Session):
        self.s3 = session.client("s3")

    def upload_file(self, local_path: str, bucket: str, s3_key: str,
                    extra_args: dict | None = None) -> None:
        """Upload a file to S3 with optional metadata/encryption."""
        extra_args = extra_args or {"ServerSideEncryption": "AES256"}
        logger.info("Uploading %s → s3://%s/%s", local_path, bucket, s3_key)
        self.s3.upload_file(local_path, bucket, s3_key, ExtraArgs=extra_args)

    def list_objects(self, bucket: str, prefix: str = "") -> Iterator[dict]:
        """Paginated list of objects (handles >1000 items)."""
        paginator = self.s3.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
            yield from page.get("Contents", [])

    def delete_old_objects(self, bucket: str, prefix: str, days: int) -> int:
        """Delete objects older than `days` days. Returns count deleted."""
        import datetime
        cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
        to_delete = [
            {"Key": obj["Key"]}
            for obj in self.list_objects(bucket, prefix)
            if obj["LastModified"] < cutoff
        ]
        if to_delete:
            # S3 delete_objects handles up to 1000 at a time
            for i in range(0, len(to_delete), 1000):
                batch = to_delete[i:i+1000]
                self.s3.delete_objects(Bucket=bucket, Delete={"Objects": batch})
            logger.info("Deleted %d objects from s3://%s/%s", len(to_delete), bucket, prefix)
        return len(to_delete)

# ── SSM Parameter Store ───────────────────────────────────────────────────────
class ParameterStore:
    def __init__(self, session: boto3.Session):
        self.ssm = session.client("ssm")

    def get(self, name: str, decrypt: bool = True) -> str:
        """Get a single parameter value."""
        resp = self.ssm.get_parameter(Name=name, WithDecryption=decrypt)
        return resp["Parameter"]["Value"]

    def get_by_path(self, path: str) -> dict[str, str]:
        """Get all parameters under a path (e.g. /myapp/prod/)."""
        params = {}
        paginator = self.ssm.get_paginator("get_parameters_by_path")
        for page in paginator.paginate(Path=path, WithDecryption=True, Recursive=True):
            for p in page["Parameters"]:
                key = p["Name"].removeprefix(path).lstrip("/")
                params[key] = p["Value"]
        return params

    def put(self, name: str, value: str, secure: bool = True) -> None:
        """Put/update a parameter."""
        self.ssm.put_parameter(
            Name=name,
            Value=value,
            Type="SecureString" if secure else "String",
            Overwrite=True,
        )
```

---

## Kubernetes Automation

```python
"""k8s_ops.py — Kubernetes automation with the Python client."""
from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException
import logging

logger = logging.getLogger(__name__)

# ── Setup ─────────────────────────────────────────────────────────────────────
def load_kube_config(in_cluster: bool = False) -> None:
    """Load kubeconfig from cluster (pod) or local ~/.kube/config."""
    if in_cluster:
        config.load_incluster_config()    # when running inside a pod
    else:
        config.load_kube_config()         # from ~/.kube/config

# ── Deployment operations ─────────────────────────────────────────────────────
class DeploymentManager:
    def __init__(self):
        self.apps = client.AppsV1Api()
        self.core = client.CoreV1Api()

    def get_deployment(self, name: str, namespace: str) -> client.V1Deployment:
        return self.apps.read_namespaced_deployment(name=name, namespace=namespace)

    def update_image(self, deployment: str, namespace: str,
                     container: str, image: str) -> None:
        """Update a container's image in a deployment."""
        logger.info("Updating %s/%s container %s → %s",
                    namespace, deployment, container, image)
        patch = {
            "spec": {
                "template": {
                    "spec": {
                        "containers": [{"name": container, "image": image}]
                    }
                }
            }
        }
        self.apps.patch_namespaced_deployment(
            name=deployment, namespace=namespace, body=patch
        )

    def wait_for_rollout(self, deployment: str, namespace: str,
                         timeout: int = 300) -> bool:
        """Watch deployment events until all replicas are ready."""
        logger.info("Waiting for %s/%s rollout...", namespace, deployment)
        w = watch.Watch()
        start = __import__("time").time()

        for event in w.stream(
            self.apps.list_namespaced_deployment,
            namespace=namespace,
            field_selector=f"metadata.name={deployment}",
            timeout_seconds=timeout,
        ):
            dep = event["object"]
            spec_replicas = dep.spec.replicas or 1
            ready = dep.status.ready_replicas or 0
            updated = dep.status.updated_replicas or 0

            logger.info("Rollout: %d/%d ready, %d updated", ready, spec_replicas, updated)

            if ready == spec_replicas == updated:
                w.stop()
                logger.info("✓ Rollout complete")
                return True

            if (__import__("time").time() - start) > timeout:
                w.stop()
                logger.error("✗ Rollout timed out")
                return False
        return False

    def scale(self, deployment: str, namespace: str, replicas: int) -> None:
        """Scale a deployment."""
        patch = {"spec": {"replicas": replicas}}
        self.apps.patch_namespaced_deployment_scale(
            name=deployment, namespace=namespace, body=patch
        )
        logger.info("Scaled %s/%s to %d replicas", namespace, deployment, replicas)

    def get_pods(self, deployment: str, namespace: str) -> list[client.V1Pod]:
        """List pods belonging to a deployment."""
        dep = self.get_deployment(deployment, namespace)
        selector = dep.spec.selector.match_labels
        label_selector = ",".join(f"{k}={v}" for k, v in selector.items())
        pods = self.core.list_namespaced_pod(
            namespace=namespace, label_selector=label_selector
        )
        return pods.items

    def exec_command(self, pod_name: str, namespace: str,
                     command: list[str]) -> str:
        """Execute a command in a pod and return stdout."""
        from kubernetes.stream import stream
        resp = stream(
            self.core.connect_get_namespaced_pod_exec,
            pod_name,
            namespace,
            command=command,
            stderr=True, stdin=False, stdout=True, tty=False,
        )
        return resp

# ── Secret management ─────────────────────────────────────────────────────────
class SecretManager:
    def __init__(self):
        self.core = client.CoreV1Api()

    def upsert(self, name: str, namespace: str, data: dict[str, str]) -> None:
        """Create or update a Kubernetes Secret."""
        import base64
        encoded = {k: base64.b64encode(v.encode()).decode() for k, v in data.items()}
        secret = client.V1Secret(
            metadata=client.V1ObjectMeta(name=name, namespace=namespace),
            data=encoded,
        )
        try:
            self.core.create_namespaced_secret(namespace=namespace, body=secret)
            logger.info("Created secret %s/%s", namespace, name)
        except ApiException as exc:
            if exc.status == 409:   # already exists — update it
                self.core.replace_namespaced_secret(name=name, namespace=namespace, body=secret)
                logger.info("Updated secret %s/%s", namespace, name)
            else:
                raise
```

---

## Infrastructure Inventory

```python
"""inventory.py — generate a dynamic inventory of infrastructure."""
import json
import boto3
from dataclasses import dataclass, asdict

@dataclass
class Server:
    id: str
    name: str
    ip: str
    region: str
    environment: str
    role: str
    os: str

def build_inventory(regions: list[str] | None = None) -> dict:
    """Scan EC2 across regions and produce an Ansible-compatible inventory."""
    regions = regions or ["us-east-1", "eu-west-1"]
    servers: list[Server] = []

    for region in regions:
        ec2 = boto3.client("ec2", region_name=region)
        paginator = ec2.get_paginator("describe_instances")

        for page in paginator.paginate(Filters=[
            {"Name": "instance-state-name", "Values": ["running"]}
        ]):
            for reservation in page["Reservations"]:
                for inst in reservation["Instances"]:
                    tags = {t["Key"]: t["Value"] for t in inst.get("Tags", [])}
                    servers.append(Server(
                        id=inst["InstanceId"],
                        name=tags.get("Name", inst["InstanceId"]),
                        ip=inst.get("PrivateIpAddress", ""),
                        region=region,
                        environment=tags.get("Environment", "unknown"),
                        role=tags.get("Role", "unknown"),
                        os=tags.get("OS", "linux"),
                    ))

    # Build Ansible-style inventory grouped by role and environment
    inventory: dict = {"_meta": {"hostvars": {}}}
    for s in servers:
        for group in [s.role, s.environment, f"{s.environment}_{s.role}"]:
            inventory.setdefault(group, {"hosts": [], "vars": {}})
            inventory[group]["hosts"].append(s.ip)
        inventory["_meta"]["hostvars"][s.ip] = asdict(s)

    return inventory

if __name__ == "__main__":
    print(json.dumps(build_inventory(), indent=2))
```

---

## CI/CD Automation

```python
"""ci_helpers.py — utilities for CI pipeline scripts."""
import os
import subprocess
import sys
from pathlib import Path

def get_git_info() -> dict[str, str]:
    """Extract git metadata useful for CI tagging."""
    def git(*args: str) -> str:
        return subprocess.check_output(["git", *args], text=True).strip()

    return {
        "sha": git("rev-parse", "HEAD"),
        "short_sha": git("rev-parse", "--short", "HEAD"),
        "branch": os.environ.get("CI_COMMIT_BRANCH") or git("rev-parse", "--abbrev-ref", "HEAD"),
        "tag": git("describe", "--tags", "--abbrev=0") if _has_tags() else "",
        "is_tagged": _is_tagged(),
        "repo": git("remote", "get-url", "origin").split("/")[-1].removesuffix(".git"),
    }

def _has_tags() -> bool:
    result = subprocess.run(["git", "tag"], capture_output=True, text=True)
    return bool(result.stdout.strip())

def _is_tagged() -> bool:
    result = subprocess.run(
        ["git", "describe", "--exact-match", "--tags"],
        capture_output=True,
    )
    return result.returncode == 0

def compute_image_tags(registry: str, image: str, git_info: dict) -> list[str]:
    """Compute Docker image tags based on git state."""
    tags = [f"{registry}/{image}:{git_info['short_sha']}"]

    branch = git_info["branch"]
    if branch == "main":
        tags.append(f"{registry}/{image}:latest")
    elif branch.startswith("release/"):
        tags.append(f"{registry}/{image}:{branch.removeprefix('release/')}")

    if git_info["is_tagged"] and git_info["tag"]:
        tags.append(f"{registry}/{image}:{git_info['tag']}")

    return tags

def run_step(name: str, cmd: list[str]) -> None:
    """Run a CI step with clear output formatting."""
    print(f"\n{'─' * 60}")
    print(f"▶ {name}")
    print(f"  {' '.join(cmd)}")
    print(f"{'─' * 60}")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print(f"\n✗ Step '{name}' failed (exit {result.returncode})", file=sys.stderr)
        sys.exit(result.returncode)
    print(f"✓ {name}")

# Usage in a CI script:
if __name__ == "__main__":
    git_info = get_git_info()
    REGISTRY = os.environ["REGISTRY"]
    IMAGE = os.environ["IMAGE_NAME"]

    tags = compute_image_tags(REGISTRY, IMAGE, git_info)
    tag_args = [arg for t in tags for arg in ("-t", t)]

    run_step("Build image", ["docker", "build", *tag_args, "."])
    run_step("Scan image", ["trivy", "image", "--exit-code", "1",
                             "--severity", "HIGH,CRITICAL", tags[0]])
    for tag in tags:
        run_step(f"Push {tag}", ["docker", "push", tag])
```