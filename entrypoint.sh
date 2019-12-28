#!/bin/sh -e

set -exou pipefail

if [ "${1#-}" != "$1" ]; then
  set -- ss-server "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'ss-server' -a "$(id -u)" = '0' ]; then
  find . \! -user ssrkcp -exec chown ssrkcp '{}' +
  exec gosu ssrkcp "$0" "$@"
fi

exec "$@"
