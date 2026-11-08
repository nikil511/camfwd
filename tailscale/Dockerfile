FROM tailscale/tailscale:stable

RUN apk add --no-cache ca-certificates iptables iproute2 jq

COPY entry.sh /usr/local/bin/entry.sh
RUN chmod +x /usr/local/bin/entry.sh

ENTRYPOINT ["/usr/local/bin/entry.sh"]
