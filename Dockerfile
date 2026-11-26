FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/home/user \
    PORT=10000 \
    UVICORN_WORKERS=1 \
    CLIP_JOBS_DIR=/tmp/clip_jobs \
    CLIPS_ROOT_DIR=/tmp/clip_jobs

# সিস্টেম ডিপেন্ডেন্সি ও ফন্ট ক্যাশ সেটআপ
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    fontconfig \
    fonts-dejavu-core \
    fonts-liberation \
    curl \
    ca-certificates \
    && fc-cache -f \
    && rm -rf /var/lib/apt/lists/*

# UID 1000 কনফ্লিক্ট এড়িয়ে নিরাপদভাবে নন-রুট ইউজার তৈরি
RUN if ! id -u 1000 >/dev/null 2>&1; then \
        useradd -m -u 1000 -s /bin/sh user; \
    else \
        EXISTING_USER=$(id -nu 1000); \
        if [ "$EXISTING_USER" != "user" ]; then \
            usermod -l user -d /home/user -m "$EXISTING_USER"; \
        fi; \
    fi

WORKDIR /app

RUN mkdir -p /app /home/user /tmp/clip_jobs && \
    chown -R user:user /app /home/user /tmp/clip_jobs

COPY --chown=user:user requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir --upgrade "yt-dlp[default]"

COPY --chown=user:user . .

USER user

EXPOSE 10000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT:-10000}/health" || exit 1

CMD ["sh", "-c", "mkdir -p \"${CLIP_JOBS_DIR:-/tmp/clip_jobs}\" \"${CLIPS_ROOT_DIR:-/tmp/clip_jobs}\" && exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-10000} --workers ${UVICORN_WORKERS:-1} --timeout-keep-alive 120 --limit-concurrency 100 --proxy-headers --forwarded-allow-ips='*'"]
