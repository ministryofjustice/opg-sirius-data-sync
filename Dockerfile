FROM ghcr.io/astral-sh/uv:0.13.5@sha256:32a7bb39b496babbd997b0a39a4d66c126bdaf5661b302bf6f06abda8deca6ff AS uv

FROM python:3.15-alpine@sha256:0f9552bb28711333da16915ec146f5e6bb44a7fdac9ced15dc17c2e0206346dd AS builder

RUN mkdir /install
RUN apk update && apk add postgresql17-dev gcc musl-dev
WORKDIR /install
COPY scripts/data-sync-builder.requirements data-sync-builder.requirements
COPY scripts/data-sync-builder.requirements.lock data-sync-builder.requirements.lock
RUN --mount=from=uv,source=/uv,target=/bin/uv \
    --mount=type=cache,target=/root/.cache/uv \
    uv export --script data-sync-builder.requirements --frozen --no-editable -o requirements-builder.txt && \
    uv pip install --prefix=/install --requirements requirements-builder.txt


FROM alpine:3@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

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
