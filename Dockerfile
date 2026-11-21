FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

ENV PORT=3000
ENV API_PASSWORD=noobzvpns
ENV KEY_SALT=""
ENV CF_TOKEN=""

RUN apt-get update && apt-get install -y \
    wget curl ca-certificates bash procps psmisc net-tools iproute2 \
    libatomic1 openssl util-linux nginx haproxy certbot vnstat jq socat cron \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/haproxy

RUN cat << 'SHIM' > /usr/bin/systemctl
#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB
ACTION=""
SVC=""
NOW=0
for arg in "$@"; do
  case "$arg" in
    --now) NOW=1 ;;
    -*) ;;
    *)
      if [ -z "$ACTION" ]; then
        ACTION="$arg"
      elif [ -z "$SVC" ]; then
        SVC="${arg%.service}"
      fi
      ;;
  esac
done

[ "$ACTION" = "enable" ] && [ "$NOW" -eq 1 ] && ACTION="start"

case "$ACTION" in
  daemon-reload|enable|disable|mask|unmask)
    exit 0
    ;;
  is-active)
    if pgrep -f "[/]${SVC}" >/dev/null 2>&1 || pgrep -x "${SVC}" >/dev/null 2>&1; then
      echo "active"
      exit 0
    else
      echo "inactive"
      exit 3
    fi
    ;;
  stop)
    setsid bash -c "[ -x '/etc/init.d/$SVC' ] && /etc/init.d/'$SVC' stop; pkill -x '$SVC'" </dev/null >/dev/null 2>&1 || true
    exit 0
    ;;
  start|restart|reload)
    mkdir -p /run/haproxy
    if [ -x "/etc/init.d/$SVC" ]; then
      /etc/init.d/"$SVC" "$ACTION" >/dev/null 2>&1 || /etc/init.d/"$SVC" start >/dev/null 2>&1 || true
      pgrep -f "[/]${SVC}" >/dev/null 2>&1 && exit 0
    fi
    UNIT=$(find /etc/systemd/system /lib/systemd/system -name "${SVC}.service" 2>/dev/null | head -n 1)
    if [ -n "$UNIT" ]; then
      CMD=$(grep -E '^ExecStart=' "$UNIT" | head -n 1 | cut -d'=' -f2-)
      if [ -n "$CMD" ]; then
        BIN_NAME=$(basename "$(echo "$CMD" | awk '{print $1}')")
        pkill -x "$BIN_NAME" >/dev/null 2>&1 || true
        setsid bash -c "$CMD" </dev/null >/var/log/${SVC}.log 2>&1 &
        for i in 1 2 3 4 5; do
          pgrep -f "[/]${SVC}" >/dev/null 2>&1 && exit 0
          sleep 0.3
        done
      fi
    fi
    exit 0
    ;;
esac
exit 0
SHIM
RUN chmod +x /usr/bin/systemctl

RUN curl -L -o /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    && chmod +x /usr/local/bin/cloudflared \
    && ln -sf /usr/local/bin/cloudflared /usr/bin/cloudflared

RUN mkdir -p /etc/noobzvpns \
    && curl -fsSL "https://drive.usercontent.google.com/download?id=1gShx9t7V1DJs21Vmt7Ge8PFhpsPJqsZe&confirm=t" -o /etc/noobzvpns/noobzvpns-api \
    && chmod +x /etc/noobzvpns/noobzvpns-api

WORKDIR /app
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh
CMD ["/app/start.sh"]
