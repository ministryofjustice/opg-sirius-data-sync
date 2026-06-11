FROM python:3.12-alpine@sha256:4d5e6e9fdab73ef5833d6c9c4e12503e838b7e19a56362d51b7206b2739ca103 AS builder

RUN mkdir /install
RUN apk update && apk add postgresql17-dev gcc musl-dev
WORKDIR /install
RUN pip install --prefix=/install psycopg2 psycopg


FROM alpine:3@sha256:a2d49ea686c2adfe3c992e47dc3b5e7fa6e6b5055609400dc2acaeb241c829f4

COPY --from=builder /install/lib/python3.12/site-packages/ /usr/lib/python3.12/site-packages/
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
