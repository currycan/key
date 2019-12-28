#!/bin/sh

/usr/bin/ss-server -s ${server_addr} \
  -p ${server_port} \
  -k ${password:-$(hostname)} \
  -m ${method} \
  -t ${timeout} \
  -d ${dns_addrs} \
  -u \
  --fast-open \
  --mtu 1200 \
  --no-delay \
  ${args} \
  $1

