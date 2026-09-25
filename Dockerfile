# ==============================================================================
# Dockerfile — Image de PRODUCTION (multi-stage, minimale, sécurisée)
# ==============================================================================

# ---------- STAGE 1 : builder ------------------------------------------------
# Compile les dépendances en wheels, pour une installation propre à l'étape finale.
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
# Le requirements.txt fourni avec le projet contient aussi pytest (dépendance
# de dev). On l'exclut pour l'image de PRODUCTION : seules les dépendances
# d'exécution doivent y figurer (voir consigne "SANS pytest en production").
RUN grep -viE '^(pytest|httpx|pytest-)' requirements.txt > requirements-prod.txt \
    && pip wheel --no-cache-dir --no-deps --wheel-dir /build/wheels -r requirements-prod.txt

# ---------- STAGE 2 : image finale -------------------------------------------
FROM python:3.12-slim AS final

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Utilisateur non-root dédié (UID/GID fixes, sans accès shell interactif)
RUN groupadd -g 10001 appgroup \
    && useradd -u 10001 -g appgroup -s /usr/sbin/nologin -m appuser

# Récupération des wheels pré-compilées depuis le stage builder
COPY --from=builder /build/requirements-prod.txt .
COPY --from=builder /build/wheels /wheels

# Installation des dépendances de PRODUCTION uniquement (pas de pytest/httpx)
RUN pip install --no-cache-dir --no-index --find-links=/wheels -r requirements-prod.txt \
    && rm -rf /wheels

# Copie uniquement du code applicatif nécessaire à l'exécution
COPY app/ ./app/

RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8000

# Healthcheck via la librairie standard Python (pas besoin d'installer curl)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=3)" || exit 1

# Stratégie "image unique" : l'API démarre par défaut.
# Le service `agent` du docker-compose.yaml surcharge cette commande avec :
#   command: ["python", "-m", "app.agent"]
CMD ["uvicorn", "app.api:app", "--host", "0.0.0.0", "--port", "8000"]
