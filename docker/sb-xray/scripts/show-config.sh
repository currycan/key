#!/usr/bin/env bash
set -eou pipefail

# Colors
RED="\033[31m"; GREEN="\033[32m"; YELLOW="\033[33m"; BLUE="\033[34m"; MAGENTA="\033[35m"; CYAN="\033[36m"; PURPLE="\033[0;35m"; RESET="\033[0m"

# Env
ENV_FILE="/.env/xray"
[ -f "$ENV_FILE" ] || { echo -e "${RED}Error: $ENV_FILE missing${RESET}"; exit 1; }
source "$ENV_FILE"

# Ensure output directory exists immediately
mkdir -p "${WORKDIR}/subscribe"

# Node Info
export NODE_NAME="${DOMAIN%%.*}"
export NODE_IP="${GEOIP_INFO#*|}"
export REGION_INFO="${GEOIP_INFO%%|*}"
export NODE_SUFFIX="|备"
[[ "$DOMAIN" =~ ^(dmit|dc|jp) ]] && export NODE_SUFFIX="|优"
[[ "$DOMAIN" == zorocloud* ]] && export NODE_SUFFIX="|中"

# Helpers
print_colored() { echo -e "$1$2${RESET}\n"; }

show_qrcode() {
    local content="$1" remark="$2"
    local qr_params="-s 8 -m 4 -l H -v 10 -d 300 -k 2"
    qrencode $qr_params -o "/tmp/qr_${remark}.png" "$content"
    echo -e "${GREEN}== ${remark} QR Code ==${RESET}"
    echo "$content" | qrencode -o - -t utf8 $qr_params -f 0 -b 255
}

generate_links() {
    local region_name="${REGION_INFO}|${NODE_NAME}" h2_alpn="alpn=h3&insecure=1"
    local vmes_json="{\"v\":\"2\",\"ps\":\"${region_name}|V2ray-TLS-WS${NODE_SUFFIX}\",\"add\":\"${CDNDOMAIN}\",\"port\":\"${LISTENING_PORT}\",\"id\":\"${XRAY_UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${CDNDOMAIN}\",\"path\":\"/${XRAY_URL_PATH}-vmessws\",\"tls\":\"tls\",\"sni\":\"${CDNDOMAIN}\",\"alpn\":\"h2\",\"fp\":\"chrome\"}"

    # 基础链接 (Clash 支持部分)
    local link_hysteria2="hysteria2://${SB_UUID}@${DOMAIN}:${PORT_HYSTERIA2}/?${h2_alpn}#${region_name}|hysteria2${NODE_SUFFIX}"
    local link_tuic="tuic://${SB_UUID}:${SB_UUID}@${DOMAIN}:${PORT_TUIC}?${h2_alpn}&congestion_control=bbr#${region_name}|tuic${NODE_SUFFIX}"
    local link_anytls="anytls://${SB_UUID}@${DOMAIN}:${PORT_ANYTLS}?security=tls&allowInsecure=1&type=tcp#${region_name}|anytls${NODE_SUFFIX}"
    local link_vmess="vmess://$(echo -n "$vmes_json" | base64 -w0)"
    local link_vless_vision="vless://${XRAY_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${DEST_HOST}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&spx=%2F&type=tcp&headerType=none#${region_name}|XTLS(Vision)+Reality直连${NODE_SUFFIX}"

    # 加上注释 (保留原样格式)
    local part1="${link_hysteria2}
# 需把 tls 里的 inSecure 设置为 true
${link_tuic}
# 需把 tls 里的 inSecure 设置为 true
${link_anytls}
${link_vmess}
${link_vless_vision}"

    CLASH_SUBSCRIBE="${part1}"

    # 高级/Xhttp 链接 (仅 V2rayN/Sing-box 支持)
    local xhttp_base="encryption=mlkem768x25519plus.native.0rtt.${XRAY_MLKEM768_CLIENT}&security=reality&sni=${DEST_HOST}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_URL_PATH}-xhttp&mode=auto"
    local link_xhttp_reality="vless://${XRAY_UUID}@${DOMAIN}:${LISTENING_PORT}?${xhttp_base}&extra=%22host%22%3A%20%22%22%2C%22path%22%3A%20%22%2F${XRAY_URL_PATH}-xhttp%22%2C%22mode%22%3A%20%22auto%22#${region_name}|Xhttp+Reality直连${NODE_SUFFIX}"

    # 复杂的 CDN/Reality 混合模式 json
    local down_settings="%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22reality%22%2C%0D%0A%20%20%22realitySettings%22%3A%20%7B%0D%0A%20%20%20%20%22show%22%3A%20false%2C%0D%0A%20%20%20%20%22serverName%22%3A%20%22${DEST_HOST}%22%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%2C%0D%0A%20%20%20%20%22publicKey%22%3A%20%22${XRAY_REALITY_PUBLIC_KEY}%22%2C%0D%0A%20%20%20%20%22shortId%22%3A%20%22${XRAY_REALITY_SHORTID}%22%2C%0D%0A%20%20%20%20%22spiderX%22%3A%20%22%2F%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_URL_PATH}-xhttp%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%7D"

    local link_up_cdn_down_reality="vless://${XRAY_UUID}@${CDNDOMAIN}:${LISTENING_PORT}?encryption=mlkem768x25519plus.native.0rtt.${XRAY_MLKEM768_CLIENT}&security=tls&sni=${CDNDOMAIN}&alpn=h2&fp=chrome&type=xhttp&host=${CDNDOMAIN}&path=%2F${XRAY_URL_PATH}-xhttp&mode=auto&extra=${down_settings}#${region_name}|上行Xhttp+TLS+CDN|下行Xhttp+Reality${NODE_SUFFIX}"

    local tls_settings="%22downloadSettings%22%3A%20%7B%0D%0A%20%20%22address%22%3A%20%22${DOMAIN}%22%2C%0D%0A%20%20%20%22port%22%3A%20${LISTENING_PORT}%2C%0D%0A%20%20%22network%22%3A%20%22xhttp%22%2C%0D%0A%20%20%22security%22%3A%20%22tls%22%2C%0D%0A%20%20%22tlsSettings%22%3A%20%7B%0D%0A%20%20%20%20%22serverName%22%3A%20%22${CDNDOMAIN}%22%2C%0D%0A%20%20%20%20%22allowInsecure%22%3A%20false%2C%0D%0A%20%20%20%20%22alpn%22%3A%20%5B%22h2%22%5D%2C%0D%0A%20%20%20%20%22fingerprint%22%3A%20%22chrome%22%0D%0A%20%20%7D%2C%0D%0A%20%20%22xhttpSettings%22%3A%20%7B%0D%0A%20%20%20%20%22host%22%3A%20%22${CDNDOMAIN}%22%2C%0D%0A%20%20%20%20%22path%22%3A%20%22%2F${XRAY_URL_PATH}-xhttp%22%2C%0D%0A%20%20%20%20%22mode%22%3A%20%22auto%22%0D%0A%20%20%20%20%7D%0D%0A%20%20%7D%0D%0A%7D"

    local link_up_reality_down_cdn="vless://${XRAY_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=mlkem768x25519plus.native.0rtt.${XRAY_MLKEM768_CLIENT}&security=reality&sni=${DEST_HOST}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=%2F${XRAY_URL_PATH}-xhttp&mode=auto&extra=${tls_settings}#${region_name}|上行Xhttp+Reality|下行 Xhttp+TLS+CDN${NODE_SUFFIX}"

    local link_mix="vless://${XRAY_UUID}@${CDNDOMAIN}:${LISTENING_PORT}?encryption=mlkem768x25519plus.native.0rtt.${XRAY_MLKEM768_CLIENT}&security=tls&sni=${CDNDOMAIN}&alpn=h2&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&host=${CDNDOMAIN}&path=%2F${XRAY_URL_PATH}-xhttp&mode=auto#${region_name}|Xhttp+TLS+CDN上下行不分离${NODE_SUFFIX}"

    V2RAYN_SUBSCRIBE="${part1}
${link_xhttp_reality}
${link_up_cdn_down_reality}
${link_up_reality_down_cdn}
${link_mix}
"
    print_colored ${PURPLE} "V2RAYN 订阅链接内容如下:\n${V2RAYN_SUBSCRIBE}"
    echo -n "$V2RAYN_SUBSCRIBE" | sed '/^# 需把 tls 里的 inSecure 设置为 true$/d' | base64 -w0 > ${WORKDIR}/subscribe/v2rayn
    echo -n "$CLASH_SUBSCRIBE" | sed '/^# 需把 tls 里的 inSecure 设置为 true$/d' | base64 -w0 > ${WORKDIR}/subscribe/clashsub
}

show_info_links() {
    print_colored ${GREEN} "\n******************************************************************\n  *        Sing-box / Xray 多协议多传输客户端配置文件汇总         *\n"
    print_colored ${RED} "Index:\nhttps://${CDNDOMAIN}/sb-xray/"
    print_colored ${YELLOW} "全部订阅:\nhttps://${CDNDOMAIN}/sb-xray/proxies"
    print_colored ${MAGENTA} "Clash 订阅:\nhttps://${CDNDOMAIN}/sb-xray/clashsub"
    print_colored ${CYAN} "V2rayN 订阅:\nhttps://${CDNDOMAIN}/sb-xray/v2rayn"
    print_colored ${GREEN} "\n*                                                                *\n *        Sing-box / Xray 多协议多传输客户端配置文件汇总         *\n******************************************************************"
}

xui_info() {
    echo -e "${GREEN}=== x-ui 用户信息 ===${RESET}"
    /usr/local/bin/x-ui setting --show
    echo ""
    print_colored ${CYAN} ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> ${PUBLIC_USER} <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
    print_colored ${CYAN} ">>>>>>>>>>>>>>>>>>>>>>>>>>>>> ${PUBLIC_PASSWORD} <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
}

main() {
    mkdir -p ${WORKDIR}/subscribe
    xui_info
    generate_links
    show_info_links

    # 批量处理简单模板
    for t in all:proxies clash stash surge surge.conf; do
        local src="${t%:*}" dst="${t#*:}"
        local path="/templates/proxies/${src}"
        [[ "$src" == "surge.conf" ]] && path="/templates/client_template/surge.conf"

        [ -f "$path" ] && envsubst < "$path" > "${WORKDIR}/subscribe/${dst}"
    done

    # Client Templates
    for c in /templates/client_template/*.yaml; do
        [ -f "$c" ] && envsubst < "$c" > "${WORKDIR}/subscribe/$(basename "$c")"
    done

    cp -a /sources/* ${WORKDIR}/subscribe 2>/dev/null || true
}

main | tee >(sed 's/\x1b\[[0-9;]*m//g' > ${WORKDIR}/subscribe/show-config)
