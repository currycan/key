#!/bin/sh -e

set -exou pipefail

if [ "${1:0:1}" = '-' ]; then
    set -- /usr/bin/ss-server -s ${server_addr} \
    -p ${server_port} \
    -k ${password:-$(hostname)} \
    -m ${method} \
    -t ${timeout} \
    -d ${dns_addrs} \
    -u \
    --fast-open \
    --mtu ${mtu} \
    --no-delay \
    ${args} \
    "$@"
fi
exec "$@"
