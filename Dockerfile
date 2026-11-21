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

# 2. Nyalakan HAProxy dari awal agar lolos cek bootstrap panel (config bawaan tidak pakai port 80/443)
mkdir -p /run/haproxy
service haproxy start >/dev/null 2>&1 || true

# 3. Jalankan Nginx dan Xray jika konfigurasinya sudah terpasang
if [ -f /etc/xray/config.json ]; then
    [ -f /etc/nginx/nginx.conf ] && service nginx start >/dev/null 2>&1 || true
    setsid /usr/local/bin/xray run -config /etc/xray/config.json </dev/null >/dev/null 2>&1 &
fi

# 4. Jalankan panel NoobzVPN dengan variabel yang sudah ter-export
cd /etc/noobzvpns
NODE_ENV=production /etc/noobzvpns/noobzvpns-api > /var/log/noobzvpns.log 2>&1 &

# 5. Jalankan Cloudflare Tunnel jika CF_TOKEN diisi
if [ -n "$CF_TOKEN" ]; then
    exec /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN"
else
    echo "Info: CF_TOKEN belum diisi, Cloudflare Tunnel dilewati."
    tail -f /dev/null
fi
