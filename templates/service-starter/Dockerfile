FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
# Pick up OS security fixes so the Trivy gate in CI stays green.
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
COPY --chown=appuser main.py .
# A numeric non-root user: the CI guardrail and the cluster policy both require it.
USER 10001
EXPOSE 8080
CMD ["python", "main.py"]
