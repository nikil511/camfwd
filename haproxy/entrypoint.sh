#!/bin/sh
set -eu

# Sanitized defaults (override in balenaCloud Fleet/Device Environment Variables)
export ROUTER_HOST="${ROUTER_HOST:-192.0.2.1:80}"
export CAMERA1_HOST="${CAMERA1_HOST:-192.0.2.101:80}"
export CAMERA1_RTSP_HOST="${CAMERA1_RTSP_HOST:-192.0.2.101:554}"
export CAMERA2_HOST="${CAMERA2_HOST:-192.0.2.102:80}"
export CAMERA2_RTSP_HOST="${CAMERA2_RTSP_HOST:-192.0.2.102:554}"
export FRIGATE_HOST="${FRIGATE_HOST:-192.0.2.110:5000}"

envsubst '${ROUTER_HOST} ${CAMERA1_HOST} ${CAMERA1_RTSP_HOST} ${CAMERA2_HOST} ${CAMERA2_RTSP_HOST} ${FRIGATE_HOST}' \
    < /etc/haproxy/haproxy.cfg.template > /tmp/haproxy.cfg

echo "[camfwd-proxy] Validating HAProxy configuration..."
haproxy -c -f /tmp/haproxy.cfg

echo "[camfwd-proxy] Starting HAProxy forwarder:"
echo "  HTTP :80   -> /camera1 (${CAMERA1_HOST}), /camera2 (${CAMERA2_HOST}), /frigate (${FRIGATE_HOST}), / (${ROUTER_HOST})"
echo "  HTTP :8081 -> Camera 1 direct (${CAMERA1_HOST})"
echo "  HTTP :8082 -> Camera 2 direct (${CAMERA2_HOST})"
echo "  RTSP :5541 / :8554 -> Camera 1 RTSP (${CAMERA1_RTSP_HOST})"
echo "  RTSP :5542 / :8555 -> Camera 2 RTSP (${CAMERA2_RTSP_HOST})"

exec haproxy -W -db -f /tmp/haproxy.cfg
