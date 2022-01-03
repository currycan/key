#!/usr/bin/env sh

rc-service nginx stop
sleep 1
${HOME}/.acme.sh/acme.sh --cron --home /acme.sh &>/dev/null
${HOME}/.acme.sh/acme.sh --installcert -d ${DOMAIN} --fullchainpath ${CERT_PATH} --keypath ${KEY_PATH} --ecc --force
sleep 1
rc-service nginx start
