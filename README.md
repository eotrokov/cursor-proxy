# cursor-proxy

Прокси для Cursor IDE: трафик к сервисам Cursor идёт через ваш VPS за пределами РФ.

## Что внутри

| Компонент | Назначение |
|-----------|------------|
| `docker-compose.yml` | HTTP `:3128` и SOCKS5 `:1080` с логином/паролем ([gost](https://github.com/ginuerzh/gost)) |
| `client/cursor-settings.json` | Шаблон настроек Cursor |
| `client/ssh-tunnel.sh` | Локальный SOCKS через SSH, без открытых портов прокси |
| `client/sing-box-selective.json` | Опционально: через прокси только домены Cursor |
| `scripts/check-connectivity.sh` | Проверка доступа к API Cursor через прокси |
| `scripts/make-cursor-settings.sh` | Генерация готового `settings.json` |
| `domains/cursor-domains.txt` | Список доменов Cursor |

## Быстрый старт (VPS)

Нужен любой Linux VPS вне РФ (NL/DE/FI и т.п.) с Docker.

```bash
git clone https://github.com/eotrokov/cursor-proxy.git
cd cursor-proxy
cp .env.example .env
# задайте PROXY_USER и PROXY_PASSWORD (обязательно смените)
nano .env

docker compose up -d
docker compose ps
docker compose logs -f
```

Откройте в файрволе порты `3128/tcp` и (по желанию) `1080/tcp` **только для своего IP**.

Проверка с вашего ПК:

```bash
PROXY_URL='http://USER:PASS@VPS_IP:3128' ./scripts/check-connectivity.sh
```

## Настройка Cursor

1. Сгенерируйте фрагмент настроек:

```bash
PROXY_HOST=VPS_IP ./scripts/make-cursor-settings.sh
# или
./scripts/make-cursor-settings.sh 'http://USER:PASS@VPS_IP:3128'
```

2. В Cursor: `Ctrl/Cmd+Shift+P` → **Preferences: Open User Settings (JSON)** — вставьте поля:

```json
{
  "http.proxy": "http://USER:PASS@VPS_IP:3128",
  "http.proxySupport": "override",
  "http.proxyStrictSSL": true,
  "http.noProxy": ["localhost", "127.0.0.1", "::1"],
  "cursor.general.disableHttp2": true
}
```

3. **Полностью закройте Cursor** (не Reload Window) и откройте снова.

`disableHttp2: true` нужен: в новых версиях Cursor HTTP/2 часто обходит `http.proxy`, из‑за чего запросы идут с вашего реального IP.

## Вариант без открытого прокси: SSH-туннель

Если на VPS есть только SSH:

```bash
./client/ssh-tunnel.sh user@VPS_IP
```

В Cursor:

```json
{
  "http.proxy": "socks5://127.0.0.1:1080",
  "http.proxySupport": "override",
  "cursor.general.disableHttp2": true
}
```

Терминал с туннелем оставляйте открытым.

## Опционально: только домены Cursor (sing-box)

Если не хотите гнать весь трафик IDE через VPS — подставьте данные VPS в `client/sing-box-selective.json`, запустите sing-box локально на `127.0.0.1:7890`, а в Cursor укажите:

```json
"http.proxy": "http://127.0.0.1:7890"
```

Список доменов: `domains/cursor-domains.txt` (по [документации Cursor](https://cursor.com/docs/enterprise/network-configuration)).

## Безопасность

- Смените пароль в `.env`, не коммитьте `.env`.
- Ограничьте доступ к портам прокси своим IP (`ufw` / security group):
  `MY_IP=x.x.x.x sudo -E ./scripts/ufw-allow-my-ip.sh`
- Не делитесь URL с логином/паролем — он попадёт в `settings.json` на диске.
- Для максимальной осторожности используйте SSH-туннель вместо публичного `:3128`.

## Типичные проблемы

| Симптом | Что сделать |
|---------|-------------|
| Network error / модели недоступны | Проверьте прокси `check-connectivity.sh`, убедитесь что `disableHttp2: true`, полный рестарт Cursor |
| Работает chat, не работает Agent | HTTP/2/стриминг: оставьте `disableHttp2`, проверьте что прокси не буферизует SSE |
| Extension host / зависания при VPN TUN | Не пускайте loopback (`127.0.0.0/8`) в TUN; лучше SOCKS/`http.proxy`, не системный TUN |
| Пароль со спецсимволами ломает URL | Сгенерируйте пароль без `@ : / ? #`, либо URL-encode |

## Ограничения

Это обычный исходящий HTTP/SOCKS прокси для легитимного доступа к Cursor с вашего аккаунта. Он не обходит оплату, лимиты подписки и не является «взломом» Cursor.
