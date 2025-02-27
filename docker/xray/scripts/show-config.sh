#!/usr/bin/env bash

set -eou pipefail

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
RESET="\033[0m"

# 错误退出函数
error_exit() {
    echo "${RED}错误: $1${RESET}" >&2
    exit 1
}

# 带颜色输出函数（带空行间隔）
print_colored() {
    local color=$1
    local content=$2
    echo -e "${color}${content}${RESET}\n"
}

# 显示二维码函数
show_qrcode() {
    local content="$1"
    local remark="$2"

    qr_params="-s 8 -m 4 -l H -v 10 -d 300 -k 2"
    qrencode $qr_params -o "/xray/config/qr_${remark}.png" "$content"
    echo -e "${YELLOW}== ${remark} QR Code ==${RESET}"
    echo "$content" | qrencode -o - -t utf8 $qr_params --foreground=000000 --background=FFFFFF
}

# 主配置生成函数
vless_link() {
    reality="vless://${XRAY_REALITY_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&spx=%2F&type=tcp&headerType=none#${GEOIP_INFO}|${DOMAIN}|XTLS+Reality"

    xhttp_reality="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22host%22%3A%20%22%22%2C%0A%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0A%22mode%22%3A%20%22auto%22#${GEOIP_INFO}|${DOMAIN}|xhttp+Reality上下行不分离"

    up_cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${CDNDOMAIN}&alpn=h2&fp=chrome&type=xhttp&host=${CDNDOMAIN}&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22reality%22%2C%0D%0A%20%20%22realitySettings%22%3A%20%7B%0D%0A%20%20%20%20%22show%22%3A%20false%2C%0D%0A%20%20%20%20%22serverName%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%2C%0D%0A%20%20%20%20%22publicKey%22%3A%20%22${XRAY_REALITY_PUBLIC_KEY}%22%2C%0D%0A%20%20%20%20%22shortId%22%3A%20%22${XRAY_REALITY_SHORTID}%22%2C%0D%0A%20%20%20%20%22spiderX%22%3A%20%22%2F%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%7D#${GEOIP_INFO}|${DOMAIN}|上行xhttp+TLS+CDN-下行xhttp+Reality"

    down_cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=reality&sni=${DOMAIN}&alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22tls%22%2C%0D%0A%20%20%22tlsSettings%22%3A%20%7B%0D%0A%20%20%20%20%22serverName%22%3A%20%22${CDNDOMAIN}%22%2C%0D%0A%20%20%20%20%22allowInsecure%22%3A%20false%2C%0D%0A%20%20%20%20%22alpn%22%3A%20%5B%22h2%22%5D%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22${CDNDOMAIN}%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%20%20%7D%0D%0A%7D#${GEOIP_INFO}|${DOMAIN}|上行xhttp+Reality-下行xhttp+TLS+CDN"

    full_cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${CDNDOMAIN}&alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&host=${CDNDOMAIN}&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto#${GEOIP_INFO}|${DOMAIN}|xhttp+TLS+CDN上下行不分离"

    # 显示配置信息
    print_colored ${RED} "${reality}"
    print_colored ${GREEN} "${xhttp_reality}"
    print_colored ${YELLOW} "${up_cdn}"
    print_colored ${BLUE} "${down_cdn}"
    print_colored ${MAGENTA} "${full_cdn}"
}

vless_qr() {
    # 显示二维码
    show_qrcode "$reality" "XTLS+Reality"
    show_qrcode "$xhttp_reality" "xhttp+Reality上下行不分离"
    show_qrcode "$up_cdn" "上行xhttp+TLS+CDN-下行xhttp+Reality"
    show_qrcode "$down_cdn" "上行xhttp+Reality-下行xhttp+TLS+CDN"
    show_qrcode "$full_cdn" "xhttp+TLS+CDN上下行不分离"
}

xui_info() {
    echo -e "${GREEN}=== x-UI 用户信息 ===${RESET}"
    /usr/local/bin/x-ui setting --show
    echo ""
}

main() {
    # 加载环境变量
    ENV_FILE="/xray/config/.env/xray"
    [ -f "$ENV_FILE" ] || error_exit "环境文件不存在: $ENV_FILE"
    source "$ENV_FILE"

    xui_info
    vless_link
    vless_qr
}

main() {
    local show_qr=false

    # 添加参数判断逻辑
    if [[ $# -ge 1 && "$1" == "qr" ]]; then
        show_qr=true
    fi

    # 加载环境变量
    ENV_FILE="/xray/config/.env/xray"
    [ -f "$ENV_FILE" ] || error_exit "环境文件不存在: $ENV_FILE"
    source "$ENV_FILE"

    vless_link  # 默认显示链接
    xui_info

    # 根据参数决定是否显示二维码
    if $show_qr; then
        vless_qr
    fi
}

main "$@"
