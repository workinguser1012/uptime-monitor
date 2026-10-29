FROM python:3.12 AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

ARG GIT_SHA=dev
ENV GIT_SHA=$GIT_SHA

COPY --from=builder /install /usr/local

COPY worker.py .

RUN useradd --uid 10001 --no-create-home appuser

USER appuser

CMD ["python", "worker.py"]
