# =============================================================================
# python.dockerfile — Multi-stage Python build using virtualenv isolation
# =============================================================================
# Stages:
#   builder     — install gcc + build tools, compile packages into /opt/venv
#   production  — copy venv only (no gcc, no build tools, no source deps)
#
# Key insight: packages that need C compilation (psycopg2, Pillow, numpy)
# require gcc at INSTALL time but NOT at RUNTIME.
# The builder has gcc; the final image does not.
#
# Build:
#   docker build -f python.dockerfile -t myapp-python:prod --target production .
# =============================================================================

# syntax=docker/dockerfile:1

# ── Stage 1: Build — compile packages inside a virtualenv ─────────────────────
FROM python:3.12-slim AS builder

# Disable .pyc bytecode and buffered stdout (standard Python container practice)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Install C build tools (needed only for compiling Python extensions)
# libpq-dev  — needed to compile psycopg2 (PostgreSQL driver)
# gcc        — C compiler
# All of these are DISCARDED in the production stage.
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Create an isolated virtualenv — easy to copy as a unit to the final stage
RUN python -m venv /opt/venv

# Activate venv for subsequent RUN instructions
ENV PATH="/opt/venv/bin:$PATH"

# Cache-optimized: copy requirements first, install, then copy source
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Stage 2: Production runtime ───────────────────────────────────────────────
FROM python:3.12-slim AS production

# No gcc, no libpq-dev, no build tools in this image.
# Only the virtualenv (which contains the compiled .so files) is copied.

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Activate the virtualenv permanently in the final image
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000

# Install libpq runtime (smaller than libpq-dev, no headers or compiler)
# Needed at runtime by psycopg2 shared library to connect to PostgreSQL
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
RUN groupadd -r -g 1001 appgroup && \
    useradd  -r -u 1001 -g appgroup -s /sbin/nologin -d /home/appuser appuser && \
    mkdir -p /home/appuser && chown appuser:appgroup /home/appuser

# Copy the entire compiled virtualenv from builder
COPY --from=builder /opt/venv /opt/venv

WORKDIR /app

# Copy application source with correct ownership
COPY --chown=appuser:appgroup . .

USER 1001:1001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# Gunicorn: production WSGI server
# --workers: 2 × CPU cores + 1 is the standard formula
# --timeout: kill workers that don't respond within 120s (prevents hung workers)
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4", \
     "--timeout", "120", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "--log-level", "info", \
     "app:app"]