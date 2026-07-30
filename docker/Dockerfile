FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS content

WORKDIR /content
COPY html/ ./
RUN test -s index.html

FROM nginxinc/nginx-unprivileged:1.31-alpine3.24@sha256:59ccf0943b0b8e8d9e6ea9039a39555730f544701a655c596f7df7d096c593f5

COPY --chown=0:0 nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=content --chown=0:0 /content/ /usr/share/nginx/html/

USER 101
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1
