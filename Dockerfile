# ==============================================================================
# Dockerfile - Image de PRODUCTION (multi-stage, minimale, securisee)
# ==============================================================================

# ---------- STAGE 1 : builder ------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN grep -viE '^(pytest|httpx|pytest-)' requirements.txt > requirements-prod.txt \
    && pip wheel --no-cache-dir --wheel-dir /build/wheels -r requirements-prod.txt

# ---------- STAGE 2 : image finale -------------------------------------------
FROM python:3.12-slim AS final

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 10001 appgroup \
    && useradd -u 10001 -g appgroup -s /usr/sbin/nologin -m appuser

COPY --from=builder /build/requirements-prod.txt .
COPY --from=builder /build/wheels /wheels

RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements-prod.txt \
    && rm -rf /wheels

COPY app/ ./app/

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=3)" || exit 1

CMD ["uvicorn", "app.api:app", "--host", "0.0.0.0", "--port", "8000"]
