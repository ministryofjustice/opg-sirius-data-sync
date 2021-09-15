FROM alpine:3 as base

FROM base as builder

RUN mkdir /install
RUN apk update && apk add postgresql-dev gcc python3-dev py3-pip musl-dev
WORKDIR /install
RUN pip install --prefix=/install psycopg2


FROM alpine:3

COPY --from=builder /install/lib/python3.9/site-packages/ /usr/lib/python3.9/site-packages/
COPY scripts /app
WORKDIR /app/

RUN apk --update --no-cache add \
  postgresql \
  python3 \
  bash \
  curl \
  jq \
  py3-pip \
  && pip install --no-cache-dir awscli -r requirements.txt \
  && rm -rf /var/cache/apk/* /root/.cache/pip/*
