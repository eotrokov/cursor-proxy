#!/usr/bin/env bash
# Поднимает локальный SOCKS5 (127.0.0.1:1080) через SSH на ваш VPS.
# Удобно, если не хотите открывать порты прокси наружу.
#
# Использование:
#   ./client/ssh-tunnel.sh user@your-vps.example
#   LOCAL_PORT=1088 ./client/ssh-tunnel.sh user@your-vps.example
#
# Затем в Cursor settings.json:
#   "http.proxy": "socks5://127.0.0.1:1080"

set -euo pipefail

REMOTE="${1:-}"
LOCAL_PORT="${LOCAL_PORT:-1080}"

if [[ -z "$REMOTE" ]]; then
  echo "Usage: $0 user@vps-host" >&2
  exit 1
fi

echo "SOCKS5 → socks5://127.0.0.1:${LOCAL_PORT} via ${REMOTE}"
echo "Оставьте этот терминал открытым. Ctrl+C — остановить туннель."
exec ssh -N -D "127.0.0.1:${LOCAL_PORT}" \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  "$REMOTE"
