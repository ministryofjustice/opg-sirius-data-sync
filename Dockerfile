FROM python:3.14-alpine@sha256:003970a263347645cd23d4f90929ad16ba7ce7d808ee4674ffcc93cb21cc289f AS builder

RUN mkdir /install
RUN apk update && apk add postgresql17-dev gcc musl-dev
WORKDIR /install
RUN pip install --prefix=/install psycopg2 psycopg


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

COPY scripts/requirements.txt /app/requirements.txt
RUN apk --update --no-cache add \
  aws-cli \
  postgresql17 \
  python3 \
  bash \
  curl \
  jq \
  py3-pip

RUN pip install --break-system-packages --no-cache-dir -r requirements.txt \
  && rm -rf /var/cache/apk/* /root/.cache/pip/*

# Patch Vulnerable Packages
RUN apk upgrade --no-cache busybox nghttp2-libs libcrypto3 libssl3 musl musl-utils zlib

COPY scripts /app
COPY sirius-roles /app
COPY sirius-maintenance /app
COPY sirius-dms /app

USER data-sync-user
