#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB

# 1. Buat & export variabel autentikasi langsung ke sistem + file .env
export PORT=3000
export API_PASSWORD="${API_PASSWORD:-noobzvpns}"
export KEY_SALT="${KEY_SALT:-$(head -c 64 /dev/urandom | sha256sum | awk '{print $1}')}"

cat << EOF > /etc/noobzvpns/.env
PORT=$PORT
API_PASSWORD=$API_PASSWORD
KEY_SALT=$KEY_SALT
EOF

# 2. Jalankan HAProxy, Nginx, dan Xray jika konfigurasinya sudah ada
if [ -f /etc/xray/config.json ]; then
    [ -f /etc/haproxy/haproxy.cfg ] && setsid haproxy -f /etc/haproxy/haproxy.cfg </dev/null >/dev/null 2>&1 &
    [ -f /etc/nginx/nginx.conf ] && nginx
    setsid /usr/local/bin/xray run -config /etc/xray/config.json </dev/null >/dev/null 2>&1 &
fi

# 3. Jalankan panel NoobzVPN dengan variabel yang sudah ter-export
cd /etc/noobzvpns
NODE_ENV=production /etc/noobzvpns/noobzvpns-api > /var/log/noobzvpns.log 2>&1 &

# 4. Jalankan Cloudflare Tunnel jika CF_TOKEN diisi
if [ -n "$CF_TOKEN" ]; then
    exec /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN"
else
    echo "Info: CF_TOKEN belum diisi, Cloudflare Tunnel dilewati."
    tail -f /dev/null
fi
