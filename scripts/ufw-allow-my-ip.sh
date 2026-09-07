#!/usr/bin/env bash
# Ограничивает доступ к портам прокси вашим IP (ufw).
# Запускать на VPS от root:
#   MY_IP=1.2.3.4 ./scripts/ufw-allow-my-ip.sh

set -euo pipefail

MY_IP="${MY_IP:-}"
HTTP_PORT="${HTTP_PORT:-3128}"
SOCKS_PORT="${SOCKS_PORT:-1080}"

if [[ -z "$MY_IP" ]]; then
  echo "Задайте MY_IP=ваш.публичный.ip" >&2
  exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
  echo "ufw не установлен. Пример iptables:" >&2
  echo "  iptables -A INPUT -p tcp -s ${MY_IP} --dport ${HTTP_PORT} -j ACCEPT" >&2
  echo "  iptables -A INPUT -p tcp --dport ${HTTP_PORT} -j DROP" >&2
  exit 1
fi

ufw allow OpenSSH
ufw allow from "$MY_IP" to any port "$HTTP_PORT" proto tcp comment 'cursor-proxy-http'
ufw allow from "$MY_IP" to any port "$SOCKS_PORT" proto tcp comment 'cursor-proxy-socks'
ufw --force enable
ufw status numbered
