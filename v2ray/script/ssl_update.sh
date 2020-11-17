#!/usr/bin/env sh

nginx -s stop
sleep 1
${HOME}/acme.sh --cron --home "/root/.acme.sh" &>/dev/null
${HOME}/.acme.sh/acme.sh --installcert -d ${DOMAIN} --fullchainpath ${CERT_PATH} --keypath /${KEY_PATH} --ecc --force
sleep 1
nginx -g 'daemon off;' &
