# 🐍 Python Scripting

> Python is the dominant language for DevOps automation. Its readable syntax, enormous standard library, and rich ecosystem of cloud/infra SDKs (`boto3`, `kubernetes`, `ansible`, `fabric`) make it the right choice whenever Bash becomes unwieldy. This file covers Python scripting patterns specifically for infrastructure and operations work.

---

## Project Setup

```bash
# ── Python version management ─────────────────────────────────────────────────
pyenv install 3.12.0          # install specific version
pyenv local 3.12.0            # set version for current directory (.python-version)
pyenv global 3.12.0           # set system default

# ── Virtual environments ──────────────────────────────────────────────────────
python3 -m venv .venv                    # create venv
source .venv/bin/activate                # activate
deactivate                               # deactivate

# ── Project with pyproject.toml (modern) ──────────────────────────────────────
# pyproject.toml:
[project]
name = "devops-tools"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    "boto3>=1.34",
    "kubernetes>=29.0",
    "pydantic>=2.0",
    "httpx>=0.27",
    "click>=8.1",
    "rich>=13.0",
]

[project.scripts]
deploy = "devops_tools.deploy:main"
healthcheck = "devops_tools.health:main"

# Install:
pip install -e ".[dev]"
```

---

## CLI Scripts with Click

```python
#!/usr/bin/env python3
"""deploy.py — application deployment CLI."""
import sys
import time
import subprocess
from pathlib import Path
import click
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

console = Console()

@click.group()
@click.option("--env", "-e",
    type=click.Choice(["dev", "staging", "production"]),
    default="dev",
    envvar="DEPLOY_ENV",
    help="Target environment")
@click.option("--verbose", "-v", is_flag=True, help="Verbose output")
@click.pass_context
def cli(ctx: click.Context, env: str, verbose: bool) -> None:
    """DevOps deployment tool."""
    ctx.ensure_object(dict)
    ctx.obj["env"] = env
    ctx.obj["verbose"] = verbose

@cli.command()
@click.argument("service")
@click.argument("image_tag")
@click.option("--timeout", "-t", default=300, help="Deployment timeout in seconds")
@click.option("--dry-run", "-n", is_flag=True, help="Show what would happen")
@click.pass_context
def deploy(
    ctx: click.Context,
    service: str,
    image_tag: str,
    timeout: int,
    dry_run: bool,
) -> None:
    """Deploy SERVICE to IMAGE_TAG."""
    env = ctx.obj["env"]
    console.print(f"[bold blue]Deploying[/] {service}:{image_tag} → {env}")

    if dry_run:
        console.print("[yellow]DRY RUN — no changes made[/]")
        return

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task("Rolling out...", total=None)
        result = _kubectl_rollout(service, image_tag, env, timeout)
        progress.update(task, completed=True)

    if result.returncode == 0:
        console.print(f"[bold green]✓[/] Deployed {service}:{image_tag}")
    else:
        console.print(f"[bold red]✗[/] Deployment failed", err=True)
        sys.exit(1)

def _kubectl_rollout(service: str, tag: str, env: str, timeout: int) -> subprocess.CompletedProcess:
    """Run kubectl deployment commands."""
    ns = f"{service}-{env}"
    cmds = [
        ["kubectl", "set", "image", f"deployment/{service}",
         f"{service}=registry.example.com/{service}:{tag}", "-n", ns],
        ["kubectl", "rollout", "status", f"deployment/{service}",
         "-n", ns, f"--timeout={timeout}s"],
    ]
    for cmd in cmds:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            console.print(result.stderr, err=True)
            return result
    return result

if __name__ == "__main__":
    cli()
```

---

## subprocess — Running System Commands

```python
import subprocess
import shlex
from typing import Optional

def run(
    cmd: str | list[str],
    *,
    check: bool = True,
    capture: bool = True,
    timeout: int = 60,
    env: Optional[dict] = None,
) -> subprocess.CompletedProcess:
    """
    Run a shell command safely.
    
    Args:
        cmd:     Command as string (shell=True) or list (safer, no injection)
        check:   Raise CalledProcessError on non-zero exit
        capture: Capture stdout/stderr (vs printing to terminal)
        timeout: Seconds before TimeoutExpired
        env:     Environment variables (merged with current env if needed)
    """
    if isinstance(cmd, str):
        args = shlex.split(cmd)       # parse safely: handles quotes, spaces
    else:
        args = cmd
    
    return subprocess.run(
        args,
        check=check,
        capture_output=capture,
        text=True,               # decode bytes to str automatically
        timeout=timeout,
        env=env,
    )

# ── Usage examples ────────────────────────────────────────────────────────────

# Simple command:
result = run(["git", "rev-parse", "--short", "HEAD"])
git_sha = result.stdout.strip()

# Command that might fail (check=False):
result = run(["systemctl", "is-active", "nginx"], check=False)
is_running = result.returncode == 0

# Stream output in real time (don't capture — let it print directly):
subprocess.run(
    ["kubectl", "rollout", "status", "deployment/myapp", "--timeout=120s"],
    check=True,
    timeout=130,
)

# Pipe between commands:
ps = subprocess.Popen(["ps", "aux"], stdout=subprocess.PIPE, text=True)
grep = subprocess.Popen(["grep", "nginx"], stdin=ps.stdout,
                         stdout=subprocess.PIPE, text=True)
ps.stdout.close()
output, _ = grep.communicate()

# Using shell=True (AVOID for user input — command injection risk):
# subprocess.run("ls | grep .py", shell=True)   # only for trusted strings
```

---

## File & Path Operations

```python
from pathlib import Path
import json
import yaml          # pip install pyyaml
import tomllib       # stdlib in Python 3.11+
import shutil
import tempfile
import os

# ── pathlib: the right way to handle paths ───────────────────────────────────
config_dir = Path("/etc/myapp")
config_file = config_dir / "config.yaml"    # path joining with /

config_file.exists()            # True/False
config_file.is_file()
config_file.is_dir()
config_file.stat().st_size      # file size in bytes
config_file.stat().st_mtime     # modification timestamp

# Read/write:
text = config_file.read_text(encoding="utf-8")
config_file.write_text("key: value\n", encoding="utf-8")
data = config_file.read_bytes()

# Create dirs:
(config_dir / "ssl").mkdir(parents=True, exist_ok=True)

# Iterate:
for f in Path("/var/log").glob("*.log"):
    print(f.name, f.stat().st_size)

for f in Path("/etc").rglob("*.conf"):   # recursive
    print(f)

# ── Atomic write: temp file + rename ─────────────────────────────────────────
def atomic_write(path: Path, content: str) -> None:
    """Write to temp file then atomically rename — prevents partial writes."""
    tmp = path.with_suffix(".tmp")
    try:
        tmp.write_text(content, encoding="utf-8")
        tmp.rename(path)          # atomic on same filesystem
    except Exception:
        tmp.unlink(missing_ok=True)
        raise

# ── Config file handling ──────────────────────────────────────────────────────
def load_config(path: Path) -> dict:
    """Load YAML, JSON, or TOML based on extension."""
    suffix = path.suffix.lower()
    text = path.read_text(encoding="utf-8")
    match suffix:
        case ".yaml" | ".yml":
            return yaml.safe_load(text)        # safe_load: no arbitrary Python objects
        case ".json":
            return json.loads(text)
        case ".toml":
            return tomllib.loads(text)
        case _:
            raise ValueError(f"Unsupported config format: {suffix}")

# ── Environment variables ─────────────────────────────────────────────────────
import os
from dataclasses import dataclass

@dataclass
class Config:
    db_host: str
    db_port: int
    db_name: str
    debug: bool = False
    log_level: str = "INFO"

    @classmethod
    def from_env(cls) -> "Config":
        return cls(
            db_host=os.environ["DB_HOST"],                     # required
            db_port=int(os.environ.get("DB_PORT", "5432")),    # optional with default
            db_name=os.environ["DB_NAME"],
            debug=os.environ.get("DEBUG", "false").lower() == "true",
            log_level=os.environ.get("LOG_LEVEL", "INFO").upper(),
        )
```

---

## HTTP Requests with httpx

```python
import httpx
import json
from typing import Any

# ── Synchronous client (simple scripts) ──────────────────────────────────────
def check_health(base_url: str, timeout: float = 10.0) -> dict[str, Any]:
    """Hit a health endpoint and return parsed JSON."""
    with httpx.Client(timeout=timeout) as client:
        response = client.get(f"{base_url}/health")
        response.raise_for_status()      # raises HTTPStatusError on 4xx/5xx
        return response.json()

# ── With retry (using tenacity) ───────────────────────────────────────────────
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

@retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=2, max=30),
    retry=retry_if_exception_type((httpx.ConnectError, httpx.TimeoutException)),
)
def fetch_with_retry(url: str) -> httpx.Response:
    with httpx.Client() as client:
        return client.get(url, timeout=15)

# ── Async client (concurrent checks) ─────────────────────────────────────────
import asyncio

async def check_all_services(services: list[str]) -> dict[str, bool]:
    """Check multiple services concurrently."""
    async with httpx.AsyncClient(timeout=10) as client:
        tasks = {svc: client.get(f"https://{svc}/health") for svc in services}
        results = {}
        for svc, coro in tasks.items():
            try:
                resp = await coro
                results[svc] = resp.status_code == 200
            except Exception:
                results[svc] = False
        return results

# Usage:
statuses = asyncio.run(check_all_services(["api.example.com", "auth.example.com"]))
```

---

## Logging

```python
import logging
import sys
from pythonjsonlogger import jsonlogger   # pip install python-json-logger

def setup_logging(level: str = "INFO", json_output: bool = False) -> logging.Logger:
    """
    Configure structured logging.
    Use JSON in production (log aggregators parse it).
    Use human-readable in development.
    """
    logger = logging.getLogger("devops_tools")
    logger.setLevel(getattr(logging, level.upper()))

    handler = logging.StreamHandler(sys.stdout)

    if json_output:
        formatter = jsonlogger.JsonFormatter(
            fmt="%(asctime)s %(name)s %(levelname)s %(message)s",
            datefmt="%Y-%m-%dT%H:%M:%SZ",
        )
    else:
        formatter = logging.Formatter(
            fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            datefmt="%H:%M:%S",
        )

    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger

# Usage:
logger = setup_logging(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    json_output=os.environ.get("LOG_FORMAT", "text") == "json",
)

logger.info("Deployment started", extra={"service": "api", "version": "1.2.3"})
logger.error("Deploy failed", extra={"error": str(exc), "service": "api"})
```