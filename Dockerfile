FROM alpine:3 AS builder

RUN mkdir /install
RUN apk update && apk add postgresql13-dev gcc python3-dev py3-pip musl-dev
WORKDIR /install
RUN pip install --prefix=/install psycopg2


FROM alpine:3

COPY --from=builder /install/lib/python3.11/site-packages/ /usr/lib/python3.11/site-packages/
WORKDIR /app/

COPY scripts/requirements.txt /app/requirements.txt
RUN apk --update --no-cache add \
  postgresql13 \
  python3 \
  bash \
  curl \
  jq \
  py3-pip \
  && pip install --no-cache-dir awscli -r requirements.txt \
  && rm -rf /var/cache/apk/* /root/.cache/pip/*

# Patch Vulnerable Packages
RUN apk upgrade --no-cache nghttp2-libs libcrypto3 libssl3

COPY scripts /app
