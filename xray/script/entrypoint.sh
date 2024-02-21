#!/bin/sh -e

set -eou pipefail

function createConfig() {
    if [ ! -f /etc/xray/xray-config.json ]; then
        envsubst </templates/xray-config.json >/etc/xray/xray-config.json
    fi
}

if [ "${1#-}" = 'supervisord' -a "$(id -u)" = '0' ]; then
    if [ ! -f /xray/config/.env/xray ];then
        XRAY_PORT=$((RANDOM + 10001))
        UUID=$(cat /proc/sys/kernel/random/uuid)
        PRIVATE_KEY=$(xray x25519 | head -1 | cut -d' ' -f3)
        PUBLIC_KEY=$(xray x25519 | tail -1 | cut -d' ' -f3)
        SHORTID=$(openssl rand -hex 8)
        GEOIP_INFO=`curl http://www.ip111.cn/ -s | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>'`
        echo "export XRAY_PORT=$XRAY_PORT" >> /xray/config/.env/xray
        echo "export UUID=$UUID" >> /xray/config/.env/xray
        echo "export PRIVATE_KEY=$PRIVATE_KEY" >> /xray/config/.env/xray
        echo "export PUBLIC_KEY=$PUBLIC_KEY" >> /xray/config/.env/xray
        echo "export SHORTID=$SHORTID" >> /xray/config/.env/xray
        echo "export GEOIP_INFO='$GEOIP_INFO'" >> /xray/config/.env/xray
    fi
    source /xray/config/.env/xray
    createConfig
    set "$@" -c "/xray/config/supervisord.conf"
fi
exec "$@"
