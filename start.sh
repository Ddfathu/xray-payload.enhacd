#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB
NEW_SALT=$(head -c 64 /dev/urandom | sha256sum | cut -d ' ' -f1)
if grep -q '^KEY_SALT=' /etc/noobzvpns/.env; then
  sed -i "s|^KEY_SALT=.*|KEY_SALT=${NEW_SALT}|" /etc/noobzvpns/.env
else
  echo "KEY_SALT=${NEW_SALT}" >> /etc/noobzvpns/.env
fi

[ -f /etc/nginx/nginx.conf ] && nginx >/dev/null 2>&1 || true
[ -f /etc/xray/config.json ] && setsid /usr/local/bin/xray run -config /etc/xray/config.json </dev/null >/var/log/xray.log 2>&1 &

cd /etc/noobzvpns
NODE_ENV=production /etc/noobzvpns/noobzvpns-api 2>&1 | sed 's/^/[PANEL] /' &
sleep 3
echo "[CHECK] Listening ports:"
ss -tlnp || netstat -tlnp || true

exec /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN"
