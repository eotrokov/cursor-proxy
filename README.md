# cursor-proxy

Прокси для Cursor IDE: трафик к сервисам Cursor идёт через ваш VPS за пределами РФ.

## Что сделать

### 1. На VPS вне РФ

```bash
git clone https://github.com/eotrokov/cursor-proxy.git
cd cursor-proxy
cp .env.example .env   # задайте PROXY_USER / PROXY_PASSWORD
docker compose up -d
```

Откройте в файрволе порты `3128/tcp` и (по желанию) `1080/tcp` **только для своего IP**.

### 2. В Cursor

`Ctrl/Cmd+Shift+P` → **Preferences: Open User Settings (JSON)** — вставьте:

```json
{
  "http.proxy": "http://USER:PASS@VPS_IP:3128",
  "http.proxySupport": "override",
  "http.proxyStrictSSL": true,
  "http.noProxy": ["localhost", "127.0.0.1", "::1"],
  "cursor.general.disableHttp2": true
}
```

Полностью закройте Cursor и откройте снова (не Reload Window).

`disableHttp2: true` обязателен: иначе в новых Cursor запросы часто идут мимо прокси с вашего реального IP.

### 3. Проверка

```bash
PROXY_URL='http://USER:PASS@VPS_IP:3128' ./scripts/check-connectivity.sh
```

Готовый фрагмент settings можно сгенерировать так:

```bash
PROXY_HOST=VPS_IP ./scripts/make-cursor-settings.sh
# или
./scripts/make-cursor-settings.sh 'http://USER:PASS@VPS_IP:3128'
```

## Варианты

- **Только SSH, без открытого `:3128`** — `./client/ssh-tunnel.sh user@VPS` и в Cursor `socks5://127.0.0.1:1080` (терминал с туннелем оставляйте открытым)
- **Только домены Cursor** — `client/sing-box-selective.json`, локальный sing-box на `127.0.0.1:7890`, в Cursor `"http.proxy": "http://127.0.0.1:7890"`
- **Ограничить порты своим IP** — `MY_IP=x.x.x.x sudo -E ./scripts/ufw-allow-my-ip.sh`

Для SSH-туннеля в Cursor:

```json
{
  "http.proxy": "socks5://127.0.0.1:1080",
  "http.proxySupport": "override",
  "cursor.general.disableHttp2": true
}
```

Список доменов Cursor: `domains/cursor-domains.txt` (по [документации Cursor](https://cursor.com/docs/enterprise/network-configuration)).

## Что внутри

| Компонент | Назначение |
|-----------|------------|
| `docker-compose.yml` | HTTP `:3128` и SOCKS5 `:1080` с логином/паролем ([gost](https://github.com/ginuerzh/gost)) |
| `client/cursor-settings.json` | Шаблон настроек Cursor |
| `client/ssh-tunnel.sh` | Локальный SOCKS через SSH, без открытых портов прокси |
| `client/sing-box-selective.json` | Опционально: через прокси только домены Cursor |
| `scripts/check-connectivity.sh` | Проверка доступа к API Cursor через прокси |
| `scripts/make-cursor-settings.sh` | Генерация готового `settings.json` |
| `scripts/ufw-allow-my-ip.sh` | Ограничение портов прокси вашим IP |
| `domains/cursor-domains.txt` | Список доменов Cursor |

## Безопасность

- Смените пароль в `.env`, не коммитьте `.env`.
- Ограничьте доступ к портам прокси своим IP (`ufw` / security group).
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
