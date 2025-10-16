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

# 加载环境变量
ENV_FILE="/.env/xray"
# SEC_FILE="/.env/secret"
[ -f "$ENV_FILE" ] || error_exit "环境文件不存在: $ENV_FILE"
# [ -f "$SEC_FILE" ] || error_exit "环境文件不存在: $SEC_FILE"
source "$ENV_FILE"
# source "$SEC_FILE"

export NODE_NAME="${DOMAIN%%.*}"
export NODE_IP=${GEOIP_INFO#*|}
export REGION_INFO=${GEOIP_INFO%%|*}

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

show_v2rayn_link() {
    # 生成 V2rayN 订阅文件
    V2RAYN_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:${PORT_XTLS_REALITY}?encryption=none&security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=tcp&headerType=none&host=${DOMAIN}#${REGION_INFO}|${NODE_NAME}|xtls-reality
"
    V2RAYN_SUBSCRIBE+="
hysteria2://${SB_UUID}@${DOMAIN}:${PORT_HYSTERIA2}/?alpn=h3&insecure=1#${REGION_INFO}|${NODE_NAME}|hysteria2
"
    V2RAYN_SUBSCRIBE+="
# 需把 tls 里的 inSecure 设置为 true
tuic://${SB_UUID}:${SB_UUID}@${DOMAIN}:${PORT_TUIC}?alpn=h3&congestion_control=bbr#${REGION_INFO}|${NODE_NAME}|tuic
"
    V2RAYN_SUBSCRIBE+="
ss://$(echo -n "aes-128-gcm:${SB_UUID}@${DOMAIN}:${PORT_SHADOWSOCKS}" | base64 -w0)#${REGION_INFO}|${NODE_NAME}|shadowsocks
"
    V2RAYN_SUBSCRIBE+="
trojan://${SB_UUID}@${DOMAIN}:${PORT_TROJAN}?security=tls&type=tcp&headerType=none#${REGION_INFO}|${NODE_NAME}|trojan
"
    V2RAYN_SUBSCRIBE+="
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${REGION_INFO}|${NODE_NAME}|vmess-ws-tls\", \"add\": \"${DOMAIN}\", \"port\": \"${LISTENING_PORT}\", \"id\": \"${SB_UUID}\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${DOMAIN}\", \"path\": \"/${SB_UUID}-vmess\", \"tls\": \"tls\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)
"
    V2RAYN_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F${SB_UUID}-vless%3Fed%3D2048#${REGION_INFO}|${NODE_NAME}|vless-ws-tls
"
    V2RAYN_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:${PORT_GRPC_REALITY}?encryption=none&security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=grpc&serviceName=grpc&mode=gun#${REGION_INFO}|${NODE_NAME}|grpc-reality
"
    V2RAYN_SUBSCRIBE+="
# 需把 tls 里的 inSecure 设置为 true
anytls://${SB_UUID}@${DOMAIN}:${PORT_ANYTLS}?security=tls&type=tcp#${REGION_INFO}|${NODE_NAME}|anytls
"
    # vmess ws tls
    V2RAYN_SUBSCRIBE+="
vmess://$(echo -n "{\"add\":\"${DOMAIN}\",\"aid\":\"${ALTERID}\",\"host\":\"${DOMAIN}\",\"id\":\"${V2RAY_UUID}\",\"net\":\"${NETWORK}\",\"path\":\"/${V2RAY_URL_PATH}\",\"port\":\"${LISTENING_PORT}\",\"ps\":\"${REGION_INFO}|${DOMAIN}-VMESS\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)
"
    # XTLS(Vision)+Reality直连
    V2RAYN_SUBSCRIBE+="
vless://${XRAY_REALITY_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&spx=%2F&type=tcp&headerType=none#${REGION_INFO}|${NODE_NAME}|XTLS(Vision)+Reality直连
"
    # Xhttp+Reality直连
    V2RAYN_SUBSCRIBE+="
vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=reality&sni=${DOMAIN}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22host%22%3A%20%22%22%2C%0A%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0A%22mode%22%3A%20%22auto%22#${REGION_INFO}|${NODE_NAME}|Xhttp+Reality直连
"
    # 上行 Xhttp+TLS+CDN | 下行 Xhttp+Reality
    V2RAYN_SUBSCRIBE+="
vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${CDNDOMAIN}&alpn=h2&fp=chrome&type=xhttp&host=${CDNDOMAIN}&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22reality%22%2C%0D%0A%20%20%22realitySettings%22%3A%20%7B%0D%0A%20%20%20%20%22show%22%3A%20false%2C%0D%0A%20%20%20%20%22serverName%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%2C%0D%0A%20%20%20%20%22publicKey%22%3A%20%22${XRAY_REALITY_PUBLIC_KEY}%22%2C%0D%0A%20%20%20%20%22shortId%22%3A%20%22${XRAY_REALITY_SHORTID}%22%2C%0D%0A%20%20%20%20%22spiderX%22%3A%20%22%2F%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%7D#${REGION_INFO}|${NODE_NAME}|上行Xhttp+TLS+CDN|下行Xhttp+Reality
"
    # 上行 Xhttp+Reality | 下行 Xhttp+TLS+CDN
    V2RAYN_SUBSCRIBE+="
vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=reality&sni=${DOMAIN}&alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto&extra=%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22tls%22%2C%0D%0A%20%20%22tlsSettings%22%3A%20%7B%0D%0A%20%20%20%20%22serverName%22%3A%20%22${CDNDOMAIN}%22%2C%0D%0A%20%20%20%20%22allowInsecure%22%3A%20false%2C%0D%0A%20%20%20%20%22alpn%22%3A%20%5B%22h2%22%5D%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22${CDNDOMAIN}%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_XHTTP_URL_PATH}%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%20%20%7D%0D%0A%7D#${REGION_INFO}|${NODE_NAME}|上行Xhttp+Reality|下行 Xhttp+TLS+CDN
"
    # Xhttp+TLS+CDN 上下行不分离
    V2RAYN_SUBSCRIBE+="
vless://${XRAY_XHTTP_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&security=tls&sni=${CDNDOMAIN}&alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&host=${CDNDOMAIN}&path=%2F${XRAY_XHTTP_URL_PATH}&mode=auto#${REGION_INFO}|${NODE_NAME}|Xhttp+TLS+CDN上下行不分离
"
    print_colored ${RED} "V2RAYN 订阅链接内容如下:
${V2RAYN_SUBSCRIBE}"
    echo -n "$V2RAYN_SUBSCRIBE" | sed '/^# 需把 tls 里的 inSecure 设置为 true$/d' | base64 -w0 > ${WORKDIR}/subscribe/v2rayn
}

show_all_link() {
    # 生成配置文件
    print_colored ${GREEN} "
******************************************************************
*                                                                *
  *        Sing-box / Xray 多协议多传输客户端配置文件汇总         *
各客户端配置文件路径: ${WORKDIR}/subscribe/\n 完整模板可参照:\n https://github.com/chika0801/sing-box-examples/tree/main/Tun
"

    print_colored ${RED} "Index:
https://${DOMAIN}/sb-xray/
"

    print_colored ${MAGENTA} "通用链接:
https://${DOMAIN}/sb-xray/proxies"

    print_colored ${CYAN} "V2rayN 订阅:
https://${DOMAIN}/sb-xray/v2rayn"

    print_colored ${YELLOW} "clash 订阅:
https://${DOMAIN}/sb-xray/clash-${NODE_NAME}.yaml"

    print_colored ${BLUE} "stash 订阅:
https://${DOMAIN}/sb-xray/stash-${NODE_NAME}.yaml"

print_colored ${GREEN} "surge 订阅:
https://${DOMAIN}/sb-xray/surge-${NODE_NAME}.conf

******************************************************************"
}

xui_info() {
    echo -e "${GREEN}=== x-ui 用户信息 ===${RESET}"
    /usr/local/bin/x-ui setting --show
    echo ""
    print_colored ${CYAN} ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> ${DOMAIN} <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    print_colored ${CYAN} ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> ${PASSWORD} <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
}

mkdir -p ${WORKDIR}/subscribe

main() {
    xui_info
    show_v2rayn_link
    show_all_link
    envsubst </templates/client_template/proxies >${WORKDIR}/subscribe/proxies
    envsubst </templates/client_template/clash >${WORKDIR}/subscribe/clash
    envsubst </templates/client_template/stash >${WORKDIR}/subscribe/stash
    envsubst </templates/client_template/surge >${WORKDIR}/subscribe/surge

    CLIENTS=("clash" "stash")
    # 循环生成文件
    for CLIENT in "${CLIENTS[@]}"; do
        export CLIENT &&  envsubst </templates/client_template/clash.yaml >${WORKDIR}/subscribe/${CLIENT}-${NODE_NAME}.yaml
    done
    envsubst </templates/client_template/surge.conf >${WORKDIR}/subscribe/surge-${NODE_NAME}.conf
}

main | tee >(sed 's/\x1b\[[0-9;]*m//g' > ${WORKDIR}/subscribe/show-config)
