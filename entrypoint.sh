#!/bin/sh

echo '=================================================='
echo

# Path Init
root_dir=${RUN_ROOT:-'/ssr'}
ssr_cli="${root_dir}/shadowsocks/server.py"
kcp_cli="${root_dir}/kcptun/server"
ssr_conf="${root_dir}/_shadowsocksr.json"
kcp_conf="${root_dir}/_kcptun.json"
cmd_conf="${root_dir}/_supervisord.conf"
ssr_port=2019
kcp_port=2020

# Gen ssr_conf
ssr2json(){
  ssr=$1
  ssr_redirect=$2
  ssr_obfs_param=$3
  ssr_protocol_param=$4
  json='"protocol": "\1",\n  "method": "\2",\n  "obfs": "\3",\n  "password": "\4"'
  cfg=$(echo ${ssr} | sed -n "s#ssr://\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\).*#${json}#p")
  cat <<EOF
{
  "server_port": "${ssr_port}",
  "server_ipv6": "[::]",
  ${cfg},
  "protocol_param": "${ssr_protocol_param}",
  "obfs_param": "${ssr_obfs_param}",
  "redirect": "${ssr_redirect}",
  "timeout": 120,
  "method": "none",
  "forbidden_port": "",
  "speed_limit_per_con": 0,
  "speed_limit_per_user": 0,
  "dns_ipv6": true,
  "fast_open": true,
  "transfer_enable": 900727656415232,
  "workers": 1
}
EOF
}

ssr2json ${SSR} "${SSR_REDIRECT}" ${SSR_OBFS_PARAM} ${SSR_PROTOCOL_PARAM} > ${ssr_conf}

# Gen kcp_conf
kcp2json(){
  kcp_key=$1
  kcp_crypt=$2
  kcp_mode=$3
  kcp_mtu=$4
  kcp_sndwnd=$5
  kcp_rcvwnd=$6
  cat <<EOF
{
  "listen": ":${kcp_port}",
  "target": "127.0.0.1:${ssr_port}",
  "key": "${kcp_key}",
  "crypt": "${kcp_crypt}",
  "mode": "${kcp_mode}",
  "mtu": ${kcp_mtu},
  "sndwnd": ${kcp_sndwnd},
  "rcvwnd": ${kcp_rcvwnd},
  "datashard": 10,
  "parityshard": 3,
  "dscp": 46,
  "nocomp": true,
  "acknodelay": false,
  "nodelay": 1,
  "interval": 10,
  "resend": 2,
  "nc": 1,
  "sockbuf": 16777217,
  "smuxver": 1,
  "smuxbuf": 16777217,
  "streambuf": 2097152,
  "keepalive": 10,
  "pprof":false,
  "quiet":false,
  "tcp":false
}
EOF
}
kcp2json "${KCP_KEY}" ${KCP_CRYPT} ${KCP_MODE} ${KCP_MTU} ${KCP_SNDWND} ${KCP_RCVWND} > ${kcp_conf}

# Gen supervisord.conf
cat > ${cmd_conf} <<EOF
[supervisord]
nodaemon=true

[program:shadowsocks]
command=/usr/bin/python ${ssr_cli} -c ${ssr_conf}
autorestart=true
redirect_stderr=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0

[program:kcptun]
command=${kcp_cli} -c ${kcp_conf}
autorestart=true
redirect_stderr=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0

EOF

/usr/bin/supervisord -c ${cmd_conf}
