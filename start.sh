#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB

# 1. Buat file .env otomatis dengan salt acak 64 karakter dan port 3000
NEW_SALT=$(head -c 64 /dev/urandom | sha256sum | awk '{print $1}')
cat << EOF > /etc/noobzvpns/.env
PORT=3000
API_PASSWORD=${API_PASSWORD:-noobzvpns}
KEY_SALT=${KEY_SALT:-$NEW_SALT}
EOF

# 2. Jalankan HAProxy, Nginx, dan Xray jika konfigurasinya sudah ada
if [ -f /etc/xray/config.json ]; then
    [ -f /etc/haproxy/haproxy.cfg ] && setsid haproxy -f /etc/haproxy/haproxy.cfg </dev/null >/dev/null 2>&1 &
    [ -f /etc/nginx/nginx.conf ] && nginx
    setsid /usr/local/bin/xray run -config /etc/xray/config.json </dev/null >/dev/null 2>&1 &
fi

# 3. Jalankan panel NoobzVPN di Port 3000
cd /etc/noobzvpns
PORT=3000 NODE_ENV=production /etc/noobzvpns/noobzvpns-api > /var/log/noobzvpns.log 2>&1 &

# 4. Jalankan Cloudflare Tunnel jika CF_TOKEN diisi
if [ -n "$CF_TOKEN" ]; then
    exec /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN"
else
    echo "Info: CF_TOKEN belum diisi, Cloudflare Tunnel dilewati."
    tail -f /dev/null
fi
