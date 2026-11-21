#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB

# 1. Buat wrapper systemctl lengkap (support --now, is-active, show, dan anti-hang)
cat << 'SHIM' > /usr/bin/systemctl
#!/bin/bash
ACTION=""
SVC=""
NOW=0
VALUE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --now) NOW=1 ;;
    --value) VALUE_ONLY=1 ;;
    -p|--property) ;;
    ActiveState|SubState|LoadState) ;;
    -*) ;;
    *)
      if [ -z "$ACTION" ]; then ACTION="$arg"
      elif [ -z "$SVC" ]; then SVC="${arg%.service}"
      fi ;;
  esac
done

[ "$ACTION" = "enable" ] && [ "$NOW" -eq 1 ] && ACTION="start"

is_running() {
  pgrep -f "[/]${1}" >/dev/null 2>&1 || pgrep -x "${1}" >/dev/null 2>&1 || pgrep -x "${1}d" >/dev/null 2>&1
}

case "$ACTION" in
  daemon-reload|enable|disable|mask|unmask) exit 0 ;;
  is-active)
    if is_running "$SVC"; then echo "active"; exit 0
    else echo "inactive"; exit 3; fi ;;
  show)
    if is_running "$SVC"; then
      [ "$VALUE_ONLY" -eq 1 ] && echo "active" || echo "ActiveState=active"
    else
      [ "$VALUE_ONLY" -eq 1 ] && echo "inactive" || echo "ActiveState=inactive"
    fi
    exit 0 ;;
  stop)
    setsid bash -c "service '$SVC' stop; pkill -x '$SVC'; pkill -x '${SVC}d'" </dev/null >/dev/null 2>&1 || true
    exit 0 ;;
  start|restart|reload)
    mkdir -p /run/haproxy /var/lib/vnstat /var/log/nginx /run
    if [ "$SVC" = "vnstat" ]; then
      setsid vnstatd -d </dev/null >/dev/null 2>&1 &
      exit 0
    fi
    if [ "$SVC" = "nginx" ]; then
      grep -rl '\[::\]:' /etc/nginx/ 2>/dev/null | xargs -r sed -i '/\[::\]:/d'
      pkill -x nginx >/dev/null 2>&1 || true
      while pgrep -x nginx >/dev/null 2>&1; do sleep 0.2; done
      /usr/sbin/nginx >/var/log/nginx/startup.log 2>&1 || true
      sleep 0.5
      exit 0
    fi
    UNIT=$(find /etc/systemd/system /lib/systemd/system -name "${SVC}.service" 2>/dev/null | head -n 1)
    if [ -n "$UNIT" ]; then
      CMD=$(grep -E '^ExecStart=' "$UNIT" | head -n 1 | cut -d'=' -f2- | sed 's/^-//')
      if [ -n "$CMD" ]; then
        pkill -x "$SVC" >/dev/null 2>&1 || true
        sleep 0.3
        setsid bash -c "$CMD" </dev/null >/var/log/${SVC}.log 2>&1 &
        for i in 1 2 3 4 5 6; do
          is_running "$SVC" && exit 0
          sleep 0.3
        done
      fi
    fi
    setsid bash -c "service '$SVC' '$ACTION' || service '$SVC' start" </dev/null >/dev/null 2>&1 &
    for i in 1 2 3 4 5 6; do
      is_running "$SVC" && exit 0
      sleep 0.3
    done
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

# 4. Jalankan Nginx, Xray, dan Cloudflared jika config sudah ada (saat restart)
if [ -f /etc/xray/config.json ]; then
    grep -rl '\[::\]:' /etc/nginx/ 2>/dev/null | xargs -r sed -i '/\[::\]:/d'
    [ -f /etc/nginx/nginx.conf ] && /usr/sbin/nginx >/dev/null 2>&1 || true
    setsid /usr/local/bin/xray run -config /etc/xray/config.json </dev/null >/dev/null 2>&1 &
fi
[ -f /etc/systemd/system/cloudflared.service ] && systemctl start cloudflared

# 5. Jalankan panel NoobzVPN
cd /etc/noobzvpns
NODE_ENV=production /etc/noobzvpns/noobzvpns-api > /var/log/noobzvpns.log 2>&1 &

# 6. Tahan kontainer tetap hidup
if [ -n "$CF_TOKEN" ] && ! pgrep -x cloudflared >/dev/null 2>&1; then
    setsid /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" </dev/null >/var/log/cloudflared.log 2>&1 &
fi
tail -f /dev/null
