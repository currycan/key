#!/bin/sh -e

set -eou pipefail

#fonts color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"


vless_qr_config(){
    reality="vless://${XRAY_REALITY_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&spx=%2F&type=tcp&headerType=none#${GEOIP_INFO}|${DOMAIN}|XTLS+Reality"

    xhttp_reality="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22host%22%3A%20%22%22%2C%0A%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0A%22mode%22%3A%20%22auto%22#${GEOIP_INFO}|${DOMAIN}|xhttp+Reality 上下行不分离"

    up_cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${CDNDOMAIN} &alpn=h2&fp=chrome&type=xhttp&host=${CDNDOMAIN} &path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22reality%22%2C%0D%0A%20%20%22realitySettings%22%3A%20%7B%0D%0A%20%20%20%20%22show%22%3A%20false%2C%0D%0A%20%20%20%20%22serverName%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%2C%0D%0A%20%20%20%20%22publicKey%22%3A%20%22${XRAY_REALITY_PUBLIC_KEY}%22%2C%0D%0A%20%20%20%20%22shortId%22%3A%20%22${XRAY_REALITY_SHORTID}%22%2C%0D%0A%20%20%20%20%22spiderX%22%3A%20%22%2F%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%7D#${GEOIP_INFO}|${DOMAIN}|上行 xhttp+TLS+CDN | 下行 xhttp+Reality"

    down_cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=reality&sni=${DOMAIN}&alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22tls%22%2C%0D%0A%20%20%22tlsSettings%22%3A%20%7B%0D%0A%20%20%20%20%22serverName%22%3A%20%22${CDNDOMAIN} %22%2C%0D%0A%20%20%20%20%22allowInsecure%22%3A%20false%2C%0D%0A%20%20%20%20%22alpn%22%3A%20%5B%22h2%22%5D%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22${CDNDOMAIN} %22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%20%20%7D%0D%0A%7D#${GEOIP_INFO}|${DOMAIN}|上行 xhttp+Reality | 下行 xhttp+TLS+CDN"

    cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${CDNDOMAIN} &alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&host=${CDNDOMAIN} &path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto#${GEOIP_INFO}|${DOMAIN}|xhttp+TLS+CDN 上下行不分离"


    echo -e "${Red} XTLS+Reality 导入链接: ${reality} ${Font}"
    echo -n "${reality}" | qrencode -o - -t utf8

    echo -e "${Red} xhttp+Reality 上下行不分离 导入链接: ${xhttp_reality} ${Font}"
    echo -n "${xhttp_reality}" | qrencode -o - -t utf8

    echo -e "${Red} 上行 xhttp+TLS+CDN | 下行 xhttp+Reality 导入链接: ${up_cdn} ${Font}"
    echo -n "${up_cdn}" | qrencode -o - -t utf8

    echo -e "${Red} 上行 xhttp+Reality | 下行 xhttp+TLS+CDN 导入链接: ${down_cdn} ${Font}"
    echo -n "${down_cdn}" | qrencode -o - -t utf8

    echo -e "${Red} xhttp+TLS+CDN 上下行不分离 导入链接: ${cdn} ${Font}"
    echo -n "${cdn}" | qrencode -o - -t utf8

}

xui_info(){
    echo -e "${Red} x-ui 用户信息如下: ${Font}"
    /usr/local/bin/x-ui setting --show
}

source /xray/config/.env/xray

vless_qr_config
xui_info
