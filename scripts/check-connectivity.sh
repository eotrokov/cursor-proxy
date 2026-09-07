#!/usr/bin/env bash
# Проверяет доступность Cursor API через HTTP/SOCKS прокси.
#
# Примеры:
#   PROXY_URL=http://user:pass@vps:3128 ./scripts/check-connectivity.sh
#   PROXY_URL=socks5h://127.0.0.1:1080 ./scripts/check-connectivity.sh

set -eu

PROXY_URL="${PROXY_URL:-}"

if [ -z "$PROXY_URL" ]; then
  echo "Задайте PROXY_URL, например:" >&2
  echo "  PROXY_URL=http://user:pass@HOST:3128 $0" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Нужен curl" >&2
  exit 1
fi

masked="$(printf '%s' "$PROXY_URL" | sed -E 's#(://[^:/@]+:)[^@/]+@#\1***@#')"
echo "Прокси: ${masked}"
echo

fail=0

probe() {
  url="$1"
  label="$2"
  printf '%-40s ' "$url"
  # -w пишет код даже при ошибке CONNECT; не добавляем || echo (иначе 000000)
  code="$(curl -s -o /dev/null -w '%{http_code}' \
    --connect-timeout 10 --max-time 25 \
    -x "$PROXY_URL" "$url" || true)"
  if [ -z "$code" ]; then
    code="000"
  fi
  case "$code" in
    [1-5][0-9][0-9])
      echo "OK HTTP ${code}"
      ;;
    *)
      if [ "$label" = "required" ]; then
        echo "FAIL (код=${code})"
        fail=1
      else
        echo "WARN (код=${code}, пропуск)"
      fi
      ;;
  esac
}

probe "https://api2.cursor.sh" required
probe "https://cursor.com" required
probe "https://api5.cursor.sh" optional
probe "https://authenticator.cursor.sh" optional

echo
if [ "$fail" -eq 0 ]; then
  echo "OK: HTTPS до сервисов Cursor через прокси проходит."
  echo "Дальше: вставьте настройки в Cursor и полностью перезапустите IDE."
else
  echo "Есть ошибки. Проверьте: VPS онлайн, порты открыты, логин/пароль, файрвол."
  exit 1
fi

echo
echo "Тест HTTP/1.1 streaming (ответ должен идти постепенно, не одним куском через 5с):"
set +e
python3 -c 'import sys; sys.stdout.buffer.write(b"\x00\x00\x00\x00\x11{\"payload\":\"foo\"}")' | \
  curl --http1.1 -No - -XPOST \
    -x "$PROXY_URL" \
    -H "Content-Type: application/connect+json" \
    --data-binary @- \
    --connect-timeout 10 --max-time 20 \
    "https://api2.cursor.sh/aiserver.v1.HealthService/StreamSSE"
stream_rc=$?
set -e
echo
if [ "$stream_rc" -ne 0 ]; then
  echo "(streaming-тест завершился с кодом ${stream_rc} — прокси может буферизовать ответы)"
fi
