# DELIBERATELY VULNERABLE: used only to prove the Trivy gate blocks.
# Debian 10 (buster) is end-of-life and carries many CRITICAL CVEs, and the
# dependency pins are the ones the app shipped with in May 2026.
# Never deploy this image. scripts/prove-trivy-gate.sh builds and scans it.
FROM python:3.8-slim-buster

WORKDIR /app
RUN pip install --no-cache-dir flask==2.3.3 gunicorn==21.2.0 werkzeug==2.3.7
COPY app/ .

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
