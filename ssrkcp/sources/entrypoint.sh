#!/bin/sh -e

set -eou pipefail

create_config(){
  envsubst < /ssrkcp/templates/shadowsocks_tmpl.json > /ssrkcp/config/shadowsocks.json
  envsubst < /ssrkcp/templates/kcptun_tmpl.json > /ssrkcp/config/kcptun.json
  # Gen supervisord.conf
  cat > /ssrkcp/config/supervisord.conf <<EOF
[supervisord]
nodaemon=true
[program:shadowsocks]
command=/usr/bin/ss-server -c /ssrkcp/config/shadowsocks.json
autorestart=true
redirect_stderr=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
[program:kcptun]
command=/usr/bin/kcptun-server -c /ssrkcp/config/kcptun.json
autorestart=true
redirect_stderr=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
EOF
}

if [ "${1#-}" = 'supervisord' -a "$(id -u)" = '0' ]; then
  create_config
  set "$@" -c /ssrkcp/config/supervisord.conf
fi
exec "$@"
