# Multi-stage build — keeps the final image lean
# Base image pinned by digest so every build (and every Trivy scan) sees the same layers.
# Dependabot (.github/dependabot.yml) opens a PR when the digest moves.
FROM python:3.15-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928 AS builder

WORKDIR /build
COPY app/requirements.txt .
# Hash-locked (app/requirements.txt is compiled from requirements.in with pip-compile
# --generate-hashes) and wheels only: no package setup script runs during the build.
RUN pip install --no-cache-dir --require-hashes --only-binary :all: --prefix=/install -r requirements.txt

# --- final stage ---
FROM python:3.15-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928

# Apply Debian security fixes released after the base image was built, then remove
# pip/setuptools/wheel: the app never installs anything at runtime, and their
# vendored packages carry CVEs of their own. Also creates the non-root user the
# app runs as (a container breakout lands as appuser, not root).
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && python -m pip uninstall -y setuptools wheel pip \
    && addgroup --system appgroup \
    && adduser --system --ingroup appgroup appuser

WORKDIR /app

COPY --from=builder /install /usr/local
COPY app/ .

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
