# 💻 Language

<p align="center">
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white"/>
  <img src="https://img.shields.io/badge/Go-00ADD8?style=for-the-badge&logo=go&logoColor=white"/>
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white"/>
  <img src="https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black"/>
</p>

> DevOps engineering is not just pipelines and YAML. You write real code every day: automation scripts, CLI tools, infrastructure helpers, data-pipeline glue, health-check services, and deployment bots. This topic covers the four languages most used in DevOps workflows, focused entirely on practical automation — not academic exercises.

---

## Which Language for Which Job?

| Task | Best choice | Why |
|------|-------------|-----|
| Shell automation, quick scripts | **Bash** | Native on every Linux box, no install |
| System automation, ops tooling | **Python** | Rich stdlib, boto3/ansible/k8s SDKs |
| CLI tools, high-perf daemons | **Go** | Single binary, fast, strong stdlib |
| Build tooling, Node.js services | **JavaScript** | npm ecosystem, same language as app |
| Infrastructure (Terraform providers) | **Go** | Official provider SDK is Go |
| Data processing, ML pipelines | **Python** | NumPy, pandas, scikit-learn |
| Lambda functions, FaaS | **Python** or **Go** | Fast cold start, small binary |

---

## 📋 Contents

| Folder | Files | Focus |
|--------|-------|-------|
| [bash/](./bash/) | `scripting.md` · `automation.md` | Robust scripts, error handling, DevOps automation patterns |
| [python/](./python/) | `scripting.md` · `automation.md` | Ops scripting, subprocess, boto3, Kubernetes SDK |
| [go/](./go/) | `basics.md` · `cli-tools.md` | Go for DevOps, building CLI tools, single-binary deployment |
| [javascript/](./javascript/) | `basics.md` · `automation.md` | Node.js scripting, package tooling, CI automation |

---

## 🗺️ Learning Path

```
1. bash/          ← master the shell you already have everywhere
    ↓
2. python/        ← extend with a real language: SDKs, APIs, data
    ↓
3. go/            ← build distributable CLI tools and services
    ↓
4. javascript/    ← automate Node.js ecosystems and build tooling
```

---

## 🔗 Related Topics

- [Linux](../linux/) — POSIX scripting, shell fundamentals
- [CI/CD](../ci-cd/) — run scripts and tools in pipelines
- [Containers](../containers/) — package your tools as Docker images
- [Infrastructure](../infrastructure/) — Terraform uses Go providers; Ansible uses Python