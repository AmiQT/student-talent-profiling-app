# syntax=docker/dockerfile:1
# Multi-stage build — builder compiles deps, production is minimal runtime

# -----------------------------------------------------------------------------
# Stage 1: Builder
# -----------------------------------------------------------------------------
FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    FASTEMBED_CACHE_PATH=/opt/fastembed_cache

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# BuildKit cache mount — pip wheels cached between builds, not baked into image
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt

# Pre-download models into known paths so production stage can copy them
# spaCy model lands inside /opt/venv (auto-included below)
RUN python -m spacy download en_core_web_sm

# fastembed model lands in FASTEMBED_CACHE_PATH (/opt/fastembed_cache)
RUN python -c "from fastembed import TextEmbedding; TextEmbedding('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')"

# -----------------------------------------------------------------------------
# Stage 2: Production
# -----------------------------------------------------------------------------
FROM python:3.11-slim AS production

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8000 \
    FASTEMBED_CACHE_PATH=/opt/fastembed_cache

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 curl \
    && rm -rf /var/lib/apt/lists/*

# Copy venv (includes spaCy model inside site-packages)
COPY --from=builder /opt/venv /opt/venv

# Copy fastembed model (fix: was missing, caused re-download on every cold start)
COPY --from=builder /opt/fastembed_cache /opt/fastembed_cache

COPY . .

RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app /opt/fastembed_cache
USER appuser

EXPOSE 8000

# start-period=60s — give AI models time to load before health checks start
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
