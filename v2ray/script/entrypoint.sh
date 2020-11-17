#!/bin/sh -e

set -eou pipefail

tls() {
  if [ -f ${CERT_PATH} ] && [ -f ${KEY_PATH} ]; then
    echo "证书文件已存在"
  else
    if [[ -f "${HOME}/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key" && -f "$HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.cer" ]]; then
      echo "cer 证书文件已存在"
    else
      ${HOME}/.acme.sh/acme.sh --issue -d ${DOMAIN} --standalone -k ec-256 --force
    fi
    ${HOME}/.acme.sh/acme.sh --installcert -d ${DOMAIN} --fullchainpath ${CERT_PATH} --keypath /${KEY_PATH} --ecc --force
  fi
}

create_config() {
  if [ ! -f /etc/nginx/conf.d/nginx-v2ray.conf ] && [ ! -f /etc/v2ray/v2ray-config.json ]; then
    export DOLLAR='$'
    export V2RAY_PORT=$((RANDOM + 10000))
    export VMESS_ID=$(cat /proc/sys/kernel/random/uuid)
    export URL_PATH=/$(head /dev/urandom | tr -dc a-z0-9 | head -c 20)/
    envsubst </templates/nginx-v2ray.conf >/etc/nginx/conf.d/nginx-v2ray.conf
    envsubst </templates/v2ray-config.json >/etc/v2ray/v2ray-config.json
    envsubst </templates/vmess_qr.json >/etc/v2ray/vmess_qr.json
  fi
}

if [ "${1#-}" = 'supervisord' -a "$(id -u)" = '0' ]; then
  create_config
  tls
  set "$@" -c "/v2ray/config/supervisord.conf"
fi
exec "$@"
