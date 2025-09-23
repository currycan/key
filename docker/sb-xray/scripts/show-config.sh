#!/usr/bin/env bash

set -eou pipefail

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
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
    qrencode $qr_params -o "/tmp/qr_${remark}.png" "$content"
    echo -e "${GREEN}== ${remark} QR Code ==${RESET}"
    echo "$content" | qrencode -o - -t utf8 $qr_params --foreground=000000 --background=FFFFFF
}

# 主配置生成函数
all_links() {
    name="${DOMAIN%%.*}"

    vmess_link="vmess://$(echo -n "{\"add\":\"${DOMAIN}\",\"aid\":\"${ALTERID}\",\"host\":\"${DOMAIN}\",\"id\":\"${V2RAY_UUID}\",\"net\":\"${NETWORK}\",\"path\":\"/${V2RAY_URL_PATH}\",\"port\":\"${LISTENING_PORT}\",\"ps\":\"${GEOIP_INFO}|${DOMAIN}-VMESS\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)"


    reality="vless://${XRAY_REALITY_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&spx=%2F&type=tcp&headerType=none#${GEOIP_INFO}|${name}|XTLS(Vision)+Reality直连"

    xhttp_reality="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22host%22%3A%20%22%22%2C%0A%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0A%22mode%22%3A%20%22auto%22#${GEOIP_INFO}|${name}|Xhttp+Reality直连"

    up_cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${CDNDOMAIN}&alpn=h2&fp=chrome&type=xhttp&host=${CDNDOMAIN}&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22reality%22%2C%0D%0A%20%20%22realitySettings%22%3A%20%7B%0D%0A%20%20%20%20%22show%22%3A%20false%2C%0D%0A%20%20%20%20%22serverName%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%2C%0D%0A%20%20%20%20%22publicKey%22%3A%20%22${XRAY_REALITY_PUBLIC_KEY}%22%2C%0D%0A%20%20%20%20%22shortId%22%3A%20%22${XRAY_REALITY_SHORTID}%22%2C%0D%0A%20%20%20%20%22spiderX%22%3A%20%22%2F%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%7D#${GEOIP_INFO}|${name}|上行Xhttp+TLS+CDN|下行Xhttp+Reality"

    down_cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=reality&sni=${DOMAIN}&alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22tls%22%2C%0D%0A%20%20%22tlsSettings%22%3A%20%7B%0D%0A%20%20%20%20%22serverName%22%3A%20%22${CDNDOMAIN}%22%2C%0D%0A%20%20%20%20%22allowInsecure%22%3A%20false%2C%0D%0A%20%20%20%20%22alpn%22%3A%20%5B%22h2%22%5D%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22${CDNDOMAIN}%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%20%20%7D%0D%0A%7D#${GEOIP_INFO}|${name}|上行Xhttp+Reality|下行 Xhttp+TLS+CDN"

    full_cdn="vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${CDNDOMAIN}&alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&host=${CDNDOMAIN}&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto#${GEOIP_INFO}|${name}|Xhttp+TLS+CDN上下行不分离"

    # 显示配置信息
    echo -e "${GREEN}=== 链接信息 ===${RESET}\n"
    print_colored ${CYAN} "${vmess_link}"
    print_colored ${RED} "${reality}"
    print_colored ${GREEN} "${xhttp_reality}"
    print_colored ${YELLOW} "${up_cdn}"
    print_colored ${BLUE} "${down_cdn}"
    print_colored ${MAGENTA} "${full_cdn}"
}

all_qrs() {
    # 显示二维码
    # echo -n "${vmess_link}" | qrencode -o - -t utf8
    show_qrcode "$vmess_link" "Vmess"
    show_qrcode "$reality" "XTLS+Reality"
    show_qrcode "$xhttp_reality" "xhttp+Reality上下行不分离"
    show_qrcode "$up_cdn" "上行xhttp+TLS+CDN-下行xhttp+Reality"
    show_qrcode "$down_cdn" "上行xhttp+Reality-下行xhttp+TLS+CDN"
    show_qrcode "$full_cdn" "xhttp+TLS+CDN上下行不分离"
}

xui_info() {
    echo -e "${GREEN}=== x-ui 用户信息 ===${RESET}"
    /usr/local/bin/x-ui setting --show
    echo ""
}

main() {
    local show_qr=false

    # 添加参数判断逻辑
    if [[ $# -ge 1 && "$1" == "qr" ]]; then
        show_qr=true
    fi

    # 加载环境变量
    ENV_FILE="/.env/xray"
    [ -f "$ENV_FILE" ] || error_exit "环境文件不存在: $ENV_FILE"
    source "$ENV_FILE"

    all_links  # 默认显示链接
    xui_info
    print_colored ${CYAN} "${PASSWORD}"

    # 根据参数决定是否显示二维码
    if $show_qr; then
        all_qrs
    fi
}

main "$@"
