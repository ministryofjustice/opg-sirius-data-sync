FROM ghcr.io/astral-sh/uv:0.12.6@sha256:88bc6eb1ccd4b82efd0e1b530caffabddf50dc2bf612e66c14ea25b8ee8a4d3d AS uv

FROM python:3.14-alpine@sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92 AS builder

RUN mkdir /install
RUN apk update && apk add postgresql17-dev gcc musl-dev
WORKDIR /install
COPY scripts/data-sync-builder.requirements data-sync-builder.requirements
COPY scripts/data-sync-builder.requirements.lock data-sync-builder.requirements.lock
RUN --mount=from=uv,source=/uv,target=/bin/uv \
    --mount=type=cache,target=/root/.cache/uv \
    uv export --script data-sync-builder.requirements --frozen --no-editable -o requirements-builder.txt && \
    uv pip install --prefix=/install --requirements requirements-builder.txt


FROM alpine:3@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid 65532 \
    data-sync-user

COPY --from=builder /install/lib/python3.14/site-packages/ /usr/lib/python3.14/site-packages/
WORKDIR /app/

RUN apk --update --no-cache add \
aws-cli \
postgresql17 \
python3 \
bash \
curl \
jq \
py3-pip

COPY scripts/data-sync-script.requirements data-sync-script.requirements
COPY scripts/data-sync-script.requirements.lock data-sync-script.requirements.lock
RUN --mount=from=uv,source=/uv,target=/bin/uv \
    --mount=type=cache,target=/root/.cache/uv \
    uv export --script data-sync-script.requirements --frozen --no-editable -o requirements-script.txt && \
    uv pip install --system --break-system-packages --no-cache-dir --requirements requirements-script.txt \
    && rm -rf /var/cache/apk/* /root/.cache/pip/*

# Patch Vulnerable Packages
RUN apk upgrade --no-cache busybox nghttp2-libs libcrypto3 libssl3 musl musl-utils zlib

COPY scripts /app
COPY sirius-roles /app
COPY sirius-maintenance /app
COPY sirius-dms /app

USER data-sync-user
