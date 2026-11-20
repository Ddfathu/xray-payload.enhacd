FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y wget curl ca-certificates bash procps psmisc net-tools iproute2 libatomic1 openssl util-linux nginx \
    && rm -rf /var/lib/apt/lists/*

RUN cat << 'SHIM' > /usr/bin/systemctl
#!/bin/bash
export GOGC=30
export GOMEMLIMIT=85MiB
ACTION=""
SVC=""
for arg in "$@"; do
  case "$arg" in
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

case "$ACTION" in
  daemon-reload|enable|disable|mask|unmask)
    exit 0
    ;;
  is-active)
    pgrep -f "[/]${SVC}" >/dev/null 2>&1 && exit 0 || exit 1
    ;;
  stop)
    setsid bash -c "[ -x '/etc/init.d/$SVC' ] && /etc/init.d/'$SVC' stop; pkill -x '$SVC'" </dev/null >/dev/null 2>&1 || true
    exit 0
    ;;
  start|restart|reload)
    if [ -x "/etc/init.d/$SVC" ]; then
      setsid bash -c "/etc/init.d/'$SVC' '$ACTION' || /etc/init.d/'$SVC' start" </dev/null >/dev/null 2>&1 &
      exit 0
    fi
    UNIT=$(find /etc/systemd/system /lib/systemd/system -name "${SVC}.service" 2>/dev/null | head -n 1)
    if [ -n "$UNIT" ]; then
      CMD=$(grep -E '^ExecStart=' "$UNIT" | head -n 1 | cut -d'=' -f2-)
      if [ -n "$CMD" ]; then
        BIN_NAME=$(basename "$(echo "$CMD" | awk '{print $1}')")
        pkill -x "$BIN_NAME" >/dev/null 2>&1 || true
        setsid bash -c "$CMD" </dev/null >/var/log/${SVC}.log 2>&1 &
      fi
    fi
    exit 0
    ;;
esac
exit 0
SHIM
RUN chmod +x /usr/bin/systemctl

RUN curl -L -o /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    && chmod +x /usr/local/bin/cloudflared

RUN mkdir -p /etc/noobzvpns \
    && curl -fsSL "https://drive.usercontent.google.com/download?id=1gShx9t7V1DJs21Vmt7Ge8PFhpsPJqsZe&confirm=t" -o /etc/noobzvpns/noobzvpns-api \
    && curl -fsSL "https://drive.usercontent.google.com/download?id=19-UeoT1G7vu5cpg1doVaGwbdKdPWXqhh&confirm=t" -o /etc/noobzvpns/.env \
    && chmod +x /etc/noobzvpns/noobzvpns-api

WORKDIR /app
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh
CMD ["/app/start.sh"]
EOF

