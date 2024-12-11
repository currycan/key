#!/bin/sh -e

set -eou pipefail

#fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

vmess_qr_config_tls_ws(){
    echo -e "${Red} V2ray 配置详情： ${Font}"
    cat /etc/v2ray/vmess_qr.json
    vmess_link="vmess://$(base64 -w 0 /etc/v2ray/vmess_qr.json)"
    echo -e "${Red} URL导入链接:${vmess_link} ${Font}"
    echo -e "$Red 二维码: $Font"
    echo -n "${vmess_link}" | qrencode -o - -t utf8
}

vless_qr_config_xtls(){
    # xray_link="vless://${UUID}@${DOMAIN}:4433?encryption=none&security=${SECURITY}&type=${XRAY_NETWORK}&sni=${DOMAIN}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORTID}&flow=xtls-rprx-vision#${GEOIP_INFO}|${DOMAIN}|xray"
    xray_link_tcp="vless://${UUID}@${DOMAIN}:4433?encryption=none&security=reality&type=tcp&sni=${DOMAIN}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORTID}&flow=xtls-rprx-vision#${GEOIP_INFO}|${DOMAIN}|tcp"
    xray_link_grpc="vless://${UUID}@${DOMAIN}:4433?encryption=none&security=reality&type=grpc&sni=${DOMAIN}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORTID}&path=grpc&serviceName=grpc#${GEOIP_INFO}|${DOMAIN}|grpc"
    xray_link_xhttp="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=xhttp&host=${DOMAIN}&path=%2F${UUID}#${GEOIP_INFO}|${DOMAIN}|xhttp"

    echo -e "${Red} xray tcp 导入链接: ${xray_link_tcp} ${Font}"
    echo -n "${xray_link_tcp}" | qrencode -o - -t utf8
    echo -e "${Red} xray grpc 导入链接: ${xray_link_grpc} ${Font}"
    echo -n "${xray_link_grpc}" | qrencode -o - -t utf8
    echo -e "${Red} xray xhttp 导入链接: ${xray_link_xhttp} ${Font}"
    echo -n "${xray_link_xhttp}" | qrencode -o - -t utf8
}

xui_info(){
    echo -e "${Red} x-ui 用户信息如下: ${Font}"
    /usr/local/bin/x-ui setting --show
}

source /v2ray/config/.env/v2ray

vmess_qr_config_tls_ws
vless_qr_config_xtls
xui_info
