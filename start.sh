#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB

# 1. Buat wrapper systemctl anti-hang (lepas pipe dengan setsid)
cat << 'SHIM' > /usr/bin/systemctl
#!/bin/bash
ACTION=""
SVC=""
NOW=0
for arg in "$@"; do
  case "$arg" in
    --now) NOW=1 ;;
    -*) ;;
    *)
      if [ -z "$ACTION" ]; then ACTION="$arg"
      elif [ -z "$SVC" ]; then SVC="${arg%.service}"
      fi ;;
  esac
done

[ "$ACTION" = "enable" ] && [ "$NOW" -eq 1 ] && ACTION="start"

case "$ACTION" in
  daemon-reload|enable|disable|mask|unmask) exit 0 ;;
  is-active)
    if pgrep -f "[/]${SVC}" >/dev/null 2>&1 || pgrep -x "${SVC}" >/dev/null 2>&1 || pgrep -x "${SVC}d" >/dev/null 2>&1; then
      echo "active"; exit 0
    else
      echo "inactive"; exit 3
    fi ;;
  stop)
    setsid bash -c "service '$SVC' stop; pkill -x '$SVC'; pkill -x '${SVC}d'" </dev/null >/dev/null 2>&1 || true
    exit 0 ;;
  start|restart|reload)
    mkdir -p /run/haproxy /var/lib/vnstat
    if [ "$SVC" = "vnstat" ]; then
      setsid vnstatd -d </dev/null >/dev/null 2>&1 &
      exit 0
    fi
    setsid bash -c "service '$SVC' '$ACTION' || service '$SVC' start" </dev/null >/dev/null 2>&1 &
    for i in 1 2 3 4 5; do
      pgrep -f "[/]${SVC}" >/dev/null 2>&1 && exit 0
      sleep 0.3
    done
    UNIT=$(find /etc/systemd/system /lib/systemd/system -name "${SVC}.service" 2>/dev/null | head -n 1)
    if [ -n "$UNIT" ]; then
      CMD=$(grep -E '^ExecStart=' "$UNIT" | head -n 1 | cut -d'=' -f2-)
      if [ -n "$CMD" ]; then
        BIN_NAME=$(basename "$(echo "$CMD" | awk '{print $1}')")
        pkill -x "$BIN_NAME" >/dev/null 2>&1 || true
        setsid bash -c "$CMD" </dev/null >/dev/null 2>&1 &
        sleep 1
      fi
    fi
    exit 0 ;;
esac
exit 0
SHIM
chmod +x /usr/bin/systemctl

# 2. Export variabel autentikasi & tulis .env
export PORT=3000
export API_PASSWORD="${API_PASSWORD:-noobzvpns}"
export KEY_SALT="${KEY_SALT:-$(head -c 64 /dev/urandom | sha256sum | awk '{print $1}')}"

cat << EOF > /etc/noobzvpns/.env
PORT=$PORT
API_PASSWORD=$API_PASSWORD
KEY_SALT=$KEY_SALT
EOF

# 3. Nyalakan HAProxy sejak awal
mkdir -p /run/haproxy
setsid service haproxy start </dev/null >/dev/null 2>&1 &

# 4. Jalankan Nginx dan Xray jika config sudah ada
if [ -f /etc/xray/config.json ]; then
    [ -f /etc/nginx/nginx.conf ] && setsid service nginx start </dev/null >/dev/null 2>&1 &
    setsid /usr/local/bin/xray run -config /etc/xray/config.json </dev/null >/dev/null 2>&1 &
fi

# 5. Jalankan panel NoobzVPN
cd /etc/noobzvpns
NODE_ENV=production /etc/noobzvpns/noobzvpns-api > /var/log/noobzvpns.log 2>&1 &

# 6. Jalankan Cloudflare Tunnel jika CF_TOKEN diisi
if [ -n "$CF_TOKEN" ]; then
    exec /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN"
else
    tail -f /dev/null
fi
