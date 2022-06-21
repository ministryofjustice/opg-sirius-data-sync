FROM alpine:3 as builder

RUN mkdir /install
RUN apk update && apk add postgresql-dev gcc python3-dev py3-pip musl-dev
WORKDIR /install
RUN pip install --prefix=/install psycopg2


FROM alpine:3

COPY --from=builder /install/lib/python3.10/site-packages/ /usr/lib/python3.10/site-packages/
WORKDIR /app/

COPY scripts/requirements.txt /app/requirements.txt
RUN apk --update --no-cache add \
  postgresql \
  python3 \
  bash \
  curl \
  jq \
  py3-pip \
  && pip install --no-cache-dir awscli -r requirements.txt \
  && rm -rf /var/cache/apk/* /root/.cache/pip/*

COPY scripts /app
