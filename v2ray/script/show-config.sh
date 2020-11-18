#!/bin/sh -e

set -eou pipefail

#fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

vmess_qr_config_tls_ws() {
  echo -e "${Red} V2ray 配置详情： ${Font}"
  cat /etc/v2ray/vmess_qr.json
  vmess_link="vmess://$(base64 -w 0 /etc/v2ray/vmess_qr.json)"
  echo -e "${Red} URL导入链接:${vmess_link} ${Font}"
  echo -e "$Red 二维码: $Font"
  echo -n "${vmess_link}" | qrencode -o - -t utf8
}

vmess_qr_config_tls_ws
