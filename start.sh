#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB

# 1. Buat file .env otomatis dengan salt acak dan format baris yang benar
NEW_SALT=$(head -c 64 /dev/urandom | sha256sum | awk '{print $1}')
cat << EOF > /etc/noobzvpns/.env
PORT=${PORT:-3000}
API_PASSWORD=${API_PASSWORD:-noobzvpns}
KEY_SALT=${KEY_SALT:-$NEW_SALT}
EOF

# 2. Jalankan HAProxy, Nginx, dan Xray jika konfigurasinya sudah terpasang
if [ -f /etc/xray/config.json ]; then
    [ -f /etc/haproxy/haproxy.cfg ] && setsid haproxy -f /etc/haproxy/haproxy.cfg </dev/null >/dev/null 2>&1 &
    [ -f /etc/nginx/nginx.conf ] && nginx
    setsid /usr/local/bin/xray run -config /etc/xray/config.json </dev/null >/dev/null 2>&1 &
fi

# 3. Jalankan panel NoobzVPN dari direktorinya
cd /etc/noobzvpns
PORT=${PORT:-3000} NODE_ENV=production /etc/noobzvpns/noobzvpns-api &

# 4. Jalankan Cloudflare Tunnel jika CF_TOKEN diisi; jika kosong, tahan kontainer tetap hidup
if [ -n "$CF_TOKEN" ]; then
    exec /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN"
else
    echo "Info: CF_TOKEN belum diisi, Cloudflare Tunnel dilewati."
    tail -f /dev/null
fi
