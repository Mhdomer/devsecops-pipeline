# Multi-stage build — keeps the final image lean
# Base image pinned by digest so every build (and every Trivy scan) sees the same layers.
# Dependabot (.github/dependabot.yml) opens a PR when the digest moves.
FROM python:3.11-slim-trixie@sha256:e41613d42d4891e4930f79523f93f81bbc7632584ec65e36ab055f41a800b41e AS builder

WORKDIR /build
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- final stage ---
FROM python:3.11-slim-trixie@sha256:e41613d42d4891e4930f79523f93f81bbc7632584ec65e36ab055f41a800b41e

# Apply Debian security fixes released after the base image was built, then remove
# pip/setuptools/wheel: the app never installs anything at runtime, and their
# vendored packages carry CVEs of their own.
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/* \
    && python -m pip uninstall -y setuptools wheel pip

# Run as non-root (security best practice Trivy will check for)
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

WORKDIR /app

COPY --from=builder /install /usr/local
COPY app/ .

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
