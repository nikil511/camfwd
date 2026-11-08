#!/bin/sh
set -eu

mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200 || true
fi

# Enable IPv4/IPv6 forwarding for Tailscale subnet routing
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null 2>&1 || true

STATE_DIR="/var/lib/tailscale"
STATE_FILE="${STATE_DIR}/tailscaled.state"
SOCKET="/var/run/tailscale/tailscaled.sock"
mkdir -p "${STATE_DIR}" /var/run/tailscale

echo "[camfwd-tailscale] Starting tailscaled..."
tailscaled --state="${STATE_FILE}" --socket="${SOCKET}" &
TS_PID=$!

# Wait for tailscaled socket to become ready
for _ in $(seq 1 30); do
    if tailscale --socket="${SOCKET}" status >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

AUTH_KEY="${TS_AUTHKEY:-${TS_AUTH_KEY:-}}"
HOSTNAME_ARG="${TS_HOSTNAME:-${BALENA_DEVICE_NAME_AT_INIT:-camfwd}}"
ROUTES_ARG="${TS_ROUTES:-}"
EXTRA_ARGS="${TS_EXTRA_ARGS:---accept-routes}"

UP_ARGS="--hostname=${HOSTNAME_ARG} ${EXTRA_ARGS}"
if [ -n "${ROUTES_ARG}" ]; then
    UP_ARGS="${UP_ARGS} --advertise-routes=${ROUTES_ARG}"
fi

BACKEND_STATE="$(tailscale --socket="${SOCKET}" status --json 2>/dev/null | jq -r '.BackendState // empty' || true)"
echo "[camfwd-tailscale] Current BackendState: ${BACKEND_STATE:-unknown}"

if [ "${BACKEND_STATE}" = "Running" ]; then
    echo "[camfwd-tailscale] Node already authenticated; updating runtime flags (${UP_ARGS})..."
    # shellcheck disable=SC2086
    tailscale --socket="${SOCKET}" up ${UP_ARGS} || true
elif [ -n "${AUTH_KEY}" ]; then
    echo "[camfwd-tailscale] Authenticating with TS_AUTHKEY (${UP_ARGS})..."
    # shellcheck disable=SC2086
    if ! tailscale --socket="${SOCKET}" up --authkey="${AUTH_KEY}" ${UP_ARGS}; then
        echo "[camfwd-tailscale] WARN: TS_AUTHKEY failed or expired; falling back to interactive login URL..."
        # shellcheck disable=SC2086
        tailscale --socket="${SOCKET}" up ${UP_ARGS} &
    fi
else
    echo "[camfwd-tailscale] No TS_AUTHKEY set; requesting interactive login URL..."
    # shellcheck disable=SC2086
    tailscale --socket="${SOCKET}" up ${UP_ARGS} &
fi

wait "${TS_PID}"
