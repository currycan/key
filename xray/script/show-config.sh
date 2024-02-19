#!/bin/sh -e

set -eou pipefail

#fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

echoContent() {
    case $1 in
    # 红色
    "red")
        # shellcheck disable=SC2154
        ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # 天蓝色
    "skyBlue")
        ${echoType} "\033[1;36m${printN}$2 \033[0m"
        ;;
        # 绿色
    "green")
        ${echoType} "\033[32m${printN}$2 \033[0m"
        ;;
        # 白色
    "white")
        ${echoType} "\033[37m${printN}$2 \033[0m"
        ;;
    "magenta")
        ${echoType} "\033[31m${printN}$2 \033[0m"
        ;;
        # 黄色
    "yellow")
        ${echoType} "\033[33m${printN}$2 \033[0m"
        ;;
    esac
}


vless_qr_config_xtls() {
    source ~/.xray
    xray_link="vless://${UUID}@${DOMAIN}:${XRAY_PORT}?encryption=none&security=${SECURITY}&flow=${FLOW}&fp=chrome&utls=chrome&pbk=${PUBLIC_KEY}&sni=${DEST_HOST}&sid=${SHORTID}&type=${XRAY_NETWORK}&host=${DOMAIN}#${GEOIP_INFO}|${DOMAIN}"
    echo -e "${Red} xray 导入链接: ${xray_link} ${Font}"
    echo -n "${xray_link}" | qrencode -o - -t utf8
}

vless_qr_config_xtls
