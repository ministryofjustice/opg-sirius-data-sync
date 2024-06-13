FROM alpine:3.20 AS builder

RUN mkdir /install
RUN apk update && apk add postgresql13-dev gcc python3-dev py3-pip musl-dev
WORKDIR /install
RUN pip install --prefix=/install psycopg2


FROM alpine:3.20

COPY --from=builder /install/lib/python3.11/site-packages/ /usr/lib/python3.11/site-packages/
WORKDIR /app/

COPY scripts/requirements.txt /app/requirements.txt
RUN apk --update --no-cache add \
  aws-cli \
  postgresql13 \
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
