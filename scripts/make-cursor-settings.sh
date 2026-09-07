#!/usr/bin/env bash
# Собирает готовый фрагмент settings.json из .env / аргументов.
#
# Использование:
#   ./scripts/make-cursor-settings.sh
#   PROXY_HOST=1.2.3.4 ./scripts/make-cursor-settings.sh
#   ./scripts/make-cursor-settings.sh http://user:pass@host:3128

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "$ROOT/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$ROOT/.env"
  set +a
fi

PROXY_URL="${1:-}"
PROXY_HOST="${PROXY_HOST:-}"
PROXY_USER="${PROXY_USER:-cursor}"
PROXY_PASSWORD="${PROXY_PASSWORD:-}"
HTTP_PORT="${HTTP_PORT:-3128}"

if [[ -z "$PROXY_URL" ]]; then
  if [[ -z "$PROXY_HOST" || -z "$PROXY_PASSWORD" ]]; then
    echo "Нужен PROXY_HOST и PROXY_PASSWORD (в .env) либо полный URL:" >&2
    echo "  $0 'http://user:pass@vps:3128'" >&2
    exit 1
  fi
  PROXY_URL="http://${PROXY_USER}:${PROXY_PASSWORD}@${PROXY_HOST}:${HTTP_PORT}"
fi

# Экранируем для JSON
json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

PROXY_JSON="$(json_escape "$PROXY_URL")"

cat <<EOF
{
  "http.proxy": ${PROXY_JSON},
  "http.proxySupport": "override",
  "http.proxyStrictSSL": true,
  "http.noProxy": [
    "localhost",
    "127.0.0.1",
    "::1"
  ],
  "cursor.general.disableHttp2": true
}
EOF
