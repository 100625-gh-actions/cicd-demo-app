# ============================================================
# Dockerfile - Multi-stage build for CI/CD Demo Flask App
# ============================================================
# This Dockerfile uses a multi-stage build strategy to create
# a small, secure, production-ready Docker image.
#
# WHY multi-stage?
#   - Stage 1 (builder) installs dependencies, which may pull
#     in compilers, headers, and build tools we don't need at
#     runtime.
#   - Stage 2 (production) copies ONLY the virtual environment
#     and application code, resulting in a much smaller image.
#
# Build examples:
#   docker build -t cicd-demo-app .
#
#   docker build \
#     --build-arg APP_VERSION=1.2.3 \
#     --build-arg BUILD_SHA=$(git rev-parse --short HEAD) \
#     -t cicd-demo-app:1.2.3 .
# ============================================================


# ----------------------------------------------------------
# Stage 1: Builder - Install dependencies into a virtual env
# ----------------------------------------------------------
# We use python:3.12-slim as the base because it includes pip
# and the Python runtime but skips extras like gcc, man pages,
# and documentation that a full image carries.
FROM python:3.12-slim AS builder

# Set the working directory for the build stage
WORKDIR /build

# Copy only the requirements file first.
# WHY? Docker caches each layer. If requirements.txt hasn't
# changed, Docker reuses the cached layer and skips the slow
# pip install step -- this dramatically speeds up rebuilds.
COPY app/requirements.txt .

# Create a virtual environment and install dependencies.
# Using a venv makes it easy to copy all installed packages
# to the production stage in a single COPY command.
RUN python -m venv /opt/venv

# Activate the venv by putting it first on PATH.
# This ensures pip installs packages INTO the venv.
ENV PATH="/opt/venv/bin:$PATH"

# Install production dependencies (no cache to keep layer small)
RUN pip install --no-cache-dir -r requirements.txt


# ----------------------------------------------------------
# Stage 2: Production - Lean runtime image
# ----------------------------------------------------------
# Start from a fresh slim image -- none of the build artifacts
# from stage 1 are carried over unless we explicitly COPY them.
FROM python:3.12-slim AS production

# LABEL helps identify the image in registries and tooling.
# OCI-standard labels are widely supported by container tools.
LABEL org.opencontainers.image.title="cicd-demo-app" \
      org.opencontainers.image.description="CI/CD Lifecycle Demo Flask Application" \
      org.opencontainers.image.source="https://github.com/example/cicd-demo"

# ----------------------------------------------------------
# Build arguments for version injection
# ----------------------------------------------------------
# These ARGs are passed in at build time (e.g., from a CI/CD
# pipeline) and converted to ENV vars below so the running
# application can read them.
#
# Usage in CI:
#   docker build --build-arg APP_VERSION=${{ github.ref_name }} \
#                --build-arg BUILD_SHA=${{ github.sha }} ...
ARG APP_VERSION=0.1.0
ARG BUILD_SHA=unknown

# ----------------------------------------------------------
# Environment variables
# ----------------------------------------------------------
# Convert build args to runtime environment variables.
# PYTHONUNBUFFERED=1 ensures print() and log output appear
# immediately in docker logs (no buffering).
# PYTHONDONTWRITEBYTECODE=1 prevents .pyc file creation,
# keeping the container filesystem clean.
ENV APP_VERSION=${APP_VERSION} \
    BUILD_SHA=${BUILD_SHA} \
    ENVIRONMENT=production \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# ----------------------------------------------------------
# Security: Create a non-root user
# ----------------------------------------------------------
# Running as root inside a container is a security risk.
# If an attacker breaks out of the app, they get root on the
# container. A non-root user limits the blast radius.
RUN groupadd --system appuser && \
    useradd --system --gid appuser --no-create-home appuser

# Set the working directory for the application
WORKDIR /app

# ----------------------------------------------------------
# Copy the virtual environment from the builder stage
# ----------------------------------------------------------
# This is the key benefit of multi-stage builds: we only copy
# the pre-built venv, not pip, setuptools, wheel, or any
# build-time packages.
COPY --from=builder /opt/venv /opt/venv

# Make sure the venv's bin directory is on PATH so Python
# finds the installed packages (flask, gunicorn, etc.)
ENV PATH="/opt/venv/bin:$PATH"

# ----------------------------------------------------------
# Copy application source code
# ----------------------------------------------------------
# The .dockerignore file prevents unnecessary files (tests,
# terraform, docs, etc.) from being included in the build
# context, keeping the COPY fast and the image small.
COPY app/ .

# ----------------------------------------------------------
# Switch to non-root user
# ----------------------------------------------------------
# From this point on, all commands (including CMD) run as
# appuser, not root.
USER appuser

# ----------------------------------------------------------
# Expose the application port
# ----------------------------------------------------------
# EXPOSE is documentation -- it tells users and orchestrators
# which port the app listens on. It does NOT publish the port;
# you still need -p 5000:5000 when running.
EXPOSE 5000

# ----------------------------------------------------------
# Health check
# ----------------------------------------------------------
# Docker (and orchestrators like ECS, Kubernetes) use this to
# determine if the container is healthy. If the health check
# fails repeatedly, the container is restarted.
#
# --interval   : Time between checks (every 30 seconds)
# --timeout    : Max time for a single check (5 seconds)
# --start-period: Grace period after start (10 seconds)
# --retries    : Failures before marking unhealthy (3)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/api/health')" || exit 1

# ----------------------------------------------------------
# Start the application
# ----------------------------------------------------------
# We use gunicorn (a production WSGI server) instead of
# Flask's built-in development server because:
#   - It handles multiple concurrent requests via workers
#   - It is designed for production stability and performance
#   - Flask's dev server is single-threaded and not secure
#
# Options:
#   --bind 0.0.0.0:5000  : Listen on all interfaces, port 5000
#   --workers 2          : Spawn 2 worker processes
#   --access-logfile -   : Write access logs to stdout (for docker logs)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
