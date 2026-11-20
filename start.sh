#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB
NEW_SALT=$(head -c 64 /dev/urandom | sha256sum | cut -d ' ' -f1)
if grep -q '^KEY_SALT=' /etc/noobzvpns/.env; then
  sed -i "s|^KEY_SALT=.*|KEY_SALT=${NEW_SALT}|" /etc/noobzvpns/.env
else
  echo "KEY_SALT=${NEW_SALT}" >> /etc/noobzvpns/.env
fi

if [ -f /etc/xray/config.json ]; then
  [ -f /etc/haproxy/haproxy.cfg ] && setsid haproxy -f /etc/haproxy/haproxy.cfg </dev/null >/dev/null 2>&1 &
  [ -f /etc/nginx/nginx.conf ] && nginx >/dev/null 2>&1 || true
  setsid /usr/local/bin/xray run -config /etc/xray/config.json </dev/null >/var/log/xray.log 2>&1 &
fi

cd /etc/noobzvpns
PORT=3000 NODE_ENV=production /etc/noobzvpns/noobzvpns-api &

exec /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN"
