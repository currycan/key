#!/usr/bin/env sh

rc-service nginx stop
sleep 1
${HOME}/.acme.sh/acme.sh --cron --home ${HOME}/.acme.sh &>/dev/null
${HOME}/.acme.sh/acme.sh --installcert -d ${DOMAIN} --fullchainpath ${SSL_PATH}/${DOMAIN}.crt --keypath ${SSL_PATH}/${DOMAIN}.key --ecc --force
sleep 1
rc-service nginx start
