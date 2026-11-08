FROM haproxy:2.8-alpine

USER root
RUN apk add --no-cache gettext ca-certificates curl

COPY haproxy.cfg /etc/haproxy/haproxy.cfg.template
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
