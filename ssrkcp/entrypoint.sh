#!/bin/sh -e

set -eou pipefail

# allow the container to be started with `--user`
if [ "${1#-}" = 'ss-server' -a "$(id -u)" = '0' ]; then
  [[ ${enable_kcptun} == true ]] && set -- "$@" "--plugin kcptun-server-plugin --plugin-opts \"key=${key};raw=${raw}\""
  set -- "/sbin/tini" "$@"
  # exec gosu ssrkcp "$@"
  # exec su-exec ssrkcp "$@"
fi

echo "$@"
exec "$@"
