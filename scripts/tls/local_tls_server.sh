#!/usr/bin/env bash

# Local TLS server helper using OpenSSL s_server
# Controls: start | stop | status
# Env vars:
#   FAFAFA_TLS_PORT           default 44330
#   FAFAFA_TLS_CERT           required for start
#   FAFAFA_TLS_KEY            required for start
#   FAFAFA_TLS_ALPN           e.g. "h2,http/1.1"
#   FAFAFA_TLS_REQUIRE_CLIENT 1 to require mTLS
#   FAFAFA_TLS_CA             path to CA file (PEM) for mTLS
#   FAFAFA_TLS_CADIR          path to CA dir (optional)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$ROOT_DIR/scripts/.local_tls_server.pid"
LOG_FILE="$ROOT_DIR/scripts/.local_tls_server.log"

port="${FAFAFA_TLS_PORT:-44330}"

ensure_openssl() {
  if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl not found" >&2
    exit 1
  fi
}

status() {
  if [[ -f "$PID_FILE" ]]; then
    local pid; pid=$(cat "$PID_FILE" || true)
    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
      echo "running (pid=$pid)"
      exit 0
    fi
  fi
  echo "stopped"
}

stop() {
  if [[ -f "$PID_FILE" ]]; then
    local pid; pid=$(cat "$PID_FILE" || true)
    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
      kill "$pid" || true
      sleep 0.5
      if ps -p "$pid" >/dev/null 2>&1; then kill -9 "$pid" || true; fi
    fi
    rm -f "$PID_FILE"
  fi
  echo "stopped"
}

start() {
  ensure_openssl

  : "${FAFAFA_TLS_CERT:?FAFAFA_TLS_CERT is required}"
  : "${FAFAFA_TLS_KEY:?FAFAFA_TLS_KEY is required}"

  local args=(s_server -quiet -www -accept "$port" -cert "$FAFAFA_TLS_CERT" -key "$FAFAFA_TLS_KEY")

  if [[ -n "${FAFAFA_TLS_ALPN:-}" ]]; then
    args+=( -alpn "$FAFAFA_TLS_ALPN" )
  fi

  if [[ "${FAFAFA_TLS_REQUIRE_CLIENT:-0}" == "1" ]]; then
    if [[ -n "${FAFAFA_TLS_CA:-}" ]]; then args+=( -CAfile "$FAFAFA_TLS_CA" ); fi
    if [[ -n "${FAFAFA_TLS_CADIR:-}" ]]; then args+=( -CApath "$FAFAFA_TLS_CADIR" ); fi
    args+=( -Verify 1 )
  fi

  if openssl s_server -help 2>&1 | grep -q -- "-min_protocol"; then
    args+=( -min_protocol TLSv1.2 -max_protocol TLSv1.3 )
  fi

  # Stop any existing first
  stop >/dev/null 2>&1 || true

  echo "Starting OpenSSL s_server on :$port ..."
  nohup openssl "${args[@]}" >"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 0.3

  pid=$(cat "$PID_FILE" || true)
  if [[ -z "$pid" ]] || ! ps -p "$pid" >/dev/null 2>&1; then
    echo "failed to start" >&2
    echo "--- s_server log (tail) ---" >&2
    tail -n 50 "$LOG_FILE" >&2 || true
    exit 1
  fi

  status
}

case "${1:-}" in
  start) start ;;
  stop)  stop ;;
  status) status ;;
  *) echo "Usage: $0 {start|stop|status}" >&2; exit 1 ;;
esac





















