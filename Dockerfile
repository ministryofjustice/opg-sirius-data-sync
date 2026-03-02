FROM alpine:3.23 AS builder

RUN mkdir /install
RUN apk update && apk add postgresql15-dev gcc python3-dev py3-pip musl-dev
WORKDIR /install
RUN pip install --prefix=/install psycopg2 psycopg


FROM alpine:3.23

COPY --from=builder /install/lib/python3.12/site-packages/ /usr/lib/python3.12/site-packages/
WORKDIR /app/

COPY scripts/requirements.txt /app/requirements.txt
RUN apk --update --no-cache add \
  aws-cli \
  postgresql15 \
  python3 \
  bash \
  curl \
  jq \
  py3-pip

RUN pip install --break-system-packages --no-cache-dir -r requirements.txt \
  && rm -rf /var/cache/apk/* /root/.cache/pip/*

# Patch Vulnerable Packages
RUN apk upgrade --no-cache busybox nghttp2-libs libcrypto3 libssl3

COPY scripts /app
COPY sirius-roles /app
COPY sirius-maintenance /app
