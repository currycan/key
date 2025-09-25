#!/usr/bin/env bash

# 加载环境变量
ENV_FILE="/.env/xray"
[ -f "$ENV_FILE" ] || error_exit "环境文件不存在: $ENV_FILE"
source "$ENV_FILE"

NODE_NAME="${DOMAIN%%.*}"
NODE_IP=${GEOIP_INFO#*|}
REGION_INFO=${GEOIP_INFO%%|*}

show_clash_subscribe() {
    # 生成各订阅文件
    # 生成 Clash proxy providers 订阅文件
    CLASH_SUBSCRIBE="proxies:
"
    # xtls-reality
    CLASH_XTLS_REALITY="- {name: \"${GEOIP_INFO}|${NODE_NAME}|xtls-reality\", type: vless, server: ${DOMAIN}, port: ${PORT_XTLS_REALITY}, uuid: ${SB_UUID}, network: tcp, udp: true, tls: true, servername: addons.mozilla.org, client-fingerprint: chrome, reality-opts: {public-key: ${SB_REALITY_PUBLIC_KEY}, short-id: \"\"}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_XTLS_REALITY
"
    # hysteria2
    CLASH_HYSTERIA2="- {name: \"${GEOIP_INFO}|${NODE_NAME}|hysteria2\", type: hysteria2, server: ${NODE_IP}, port: ${PORT_HYSTERIA2}, up: \"2000 Mbps\", down: \"2500 Mbps\", password: ${SB_UUID}, skip-cert-verify: true}"
    CLASH_SUBSCRIBE+="  $CLASH_HYSTERIA2
"
    # ShadowTLS
    CLASH_SHADOWTLS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|ShadowTLS\", type: ss, server: ${DOMAIN}, port: ${PORT_SHADOWTLS}, cipher: 2022-blake3-aes-128-gcm, password: ${SHADOWTLS_PASSWORD}, plugin: shadow-tls, client-fingerprint: chrome, plugin-opts: {host: addons.mozilla.org, password: \"${SB_UUID}\", version: 3}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_SHADOWTLS
"
    # shadowsocks
    CLASH_SHADOWSOCKS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|shadowsocks\", type: ss, server: ${DOMAIN}, port: ${PORT_SHADOWSOCKS}, cipher: aes-128-gcm, password: ${SB_UUID}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_SHADOWSOCKS
"
    # trojan
    CLASH_TROJAN="- {name: \"${GEOIP_INFO}|${NODE_NAME}|trojan\", type: trojan, server: ${DOMAIN}, port: ${PORT_TROJAN}, password: ${SB_UUID}, client-fingerprint: random, skip-cert-verify: true, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_TROJAN
"
    # vmess-ws
    CLASH_VMESS_WS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\", type: vmess, server: ${DOMAIN}, port: 443, uuid: ${SB_UUID}, udp: true, tls: true, alterId: 0, cipher: auto, skip-cert-verify: true, network: ws, ws-opts: { path: \"/${SB_UUID}-vmess\", headers: {Host: ${DOMAIN}} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_VMESS_WS
"
    # vless-ws-tls
    CLASH_VLESS_WS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls\", type: vless, server: ${DOMAIN}, port: 443, uuid: ${SB_UUID}, udp: true, tls: true, servername: ${DOMAIN}, network: ws, skip-cert-verify: true, ws-opts: { path: \"/${SB_UUID}-vless\", headers: {Host: ${DOMAIN}}, max-early-data: 2048, early-data-header-name: Sec-WebSocket-Protocol }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_VLESS_WS
"
    # grpc-reality
    CLASH_GRPC_REALITY="- {name: \"${GEOIP_INFO}|${NODE_NAME}|grpc-reality\", type: vless, server: ${DOMAIN}, port: ${PORT_GRPC_REALITY}, uuid: ${SB_UUID}, network: grpc, tls: true, udp: true, flow: , client-fingerprint: chrome, servername: addons.mozilla.org, grpc-opts: {  grpc-service-name: \"grpc\" }, reality-opts: { public-key: ${SB_REALITY_PUBLIC_KEY}, short-id: \"\" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_GRPC_REALITY
"
    # vmess ws tls
    CLASH_VMESS_WS_TLS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|VMESS\", type: vmess, server: ${DOMAIN}, port: ${LISTENING_PORT}, cipher: auto, uuid: ${V2RAY_UUID}, alterId: ${ALTERID}, tls: true, ${NETWORK}: ws, ws-opts: {path: /${V2RAY_URL_PATH}, headers: {Host: ${DOMAIN}}}, servername: ${DOMAIN} }"
    CLASH_SUBSCRIBE+="  $CLASH_VMESS_WS_TLS
"
    # vless XTLS(Vision)+Reality直连
    CLASH_VLESS_XTLS_REALITY="- {type: vless, name: \"${REGION_INFO}|${NODE_NAME}|XTLS(Vision)+Reality直连\", server: ${DOMAIN}, port: ${LISTENING_PORT}, uuid: ${XRAY_REALITY_SHORTID}, tls: true, flow: xtls-rprx-vision, client-fingerprint: chrome, skip-cert-verify: false, reality-opts: {public-key: ${XRAY_REALITY_PUBLIC_KEY}, short-id: ${XRAY_REALITY_SHORTID}, _spider-x: /}, network: tcp, servername: ${DOMAIN} }"
    CLASH_SUBSCRIBE+="  $CLASH_VLESS_XTLS_REALITY
"
    # echo -n "${CLASH_SUBSCRIBE}" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' > ${WORKDIR}/subscribe/statsh
    export CLASH_SUBSCRIBE=${CLASH_SUBSCRIBE}
    envsubst </templates/client_template/statsh.yaml >${WORKDIR}/subscribe/statsh.yaml

    # vless Xhttp+Reality直连
    CLASH_VLESS_XHTTP_REALITY="- {type: vless, name: \"${REGION_INFO}|${NODE_NAME}|Xhttp+Reality直连\", server: ${DOMAIN}, port: ${LISTENING_PORT}, uuid: ${XRAY_XHTTP_UUID}, tls: true, client-fingerprint: chrome, skip-cert-verify: false, reality-opts: {public-key: ${XRAY_REALITY_PUBLIC_KEY}, short-id: ${XRAY_REALITY_SHORTID}}, network: xhttp, xhttp-opts: {path: /${XRAY_XHTTP_URL_PATH}}, servername: ${DOMAIN} }"
    CLASH_SUBSCRIBE+="  $CLASH_VLESS_XHTTP_REALITY
"
    # vless 上行Xhttp+TLS+CDN | 下行Xhttp+Reality
    CLASH_VLESS_XHTTP_TLS_CDN_UP_REALITY_DOWN="- {type: vless, name: \"${REGION_INFO}|${NODE_NAME}|上行Xhttp+TLS+CDN|下行Xhttp+Reality\", server: ${DOMAIN}, port: ${LISTENING_PORT}, uuid: ${XRAY_XHTTP_UUID}, tls: true, client-fingerprint: chrome, alpn: [h2], skip-cert-verify: false, network: xhttp, xhttp-opts: {headers: {Host: ${CDNDOMAIN}}, path: /${XRAY_XHTTP_URL_PATH}}, servername: ${CDNDOMAIN} }"
    CLASH_SUBSCRIBE+="  $CLASH_VLESS_XHTTP_TLS_CDN_UP_REALITY_DOWN
"
    # vless 上行Xhttp+Reality | 下行Xhttp+TLS+CDN
    CLASH_VLESS_XHTTP_REALITY_UP_TLS_CDN_DOWN="- {type: vless, name: \"${REGION_INFO}|${NODE_NAME}|上行Xhttp+Reality|下行Xhttp+TLS+CDN\", server: ${DOMAIN}, port: ${LISTENING_PORT}, uuid: ${XRAY_XHTTP_UUID}, tls: true, client-fingerprint: chrome, alpn: [h2], skip-cert-verify: false, reality-opts: {public-key: ${XRAY_REALITY_PUBLIC_KEY}, short-id: ${XRAY_REALITY_SHORTID}}, network: xhttp, xhttp-opts: {path: /${XRAY_XHTTP_URL_PATH}}, servername: ${DOMAIN} }"
    CLASH_SUBSCRIBE+="  $CLASH_VLESS_XHTTP_REALITY_UP_TLS_CDN_DOWN
"
    # vless Xhttp+TLS+CDN上下行不分离
    CLASH_VLESS_XHTTP_TLS_CDN="- {type: vless, name: \"${REGION_INFO}|${NODE_NAME}|Xhttp+TLS+CDN上下行不分离\", server: ${DOMAIN}, port: ${LISTENING_PORT}, uuid: ${XRAY_XHTTP_UUID}, tls: true, client-fingerprint: chrome, alpn: [h2], skip-cert-verify: false, network: xhttp, xhttp-opts: {headers: {Host: ${CDNDOMAIN}}, path: /${XRAY_XHTTP_URL_PATH}}, servername: ${CDNDOMAIN} }"
    CLASH_SUBSCRIBE+="  $CLASH_VLESS_XHTTP_TLS_CDN
"
    # tuic
    CLASH_TUIC="- {name: \"${GEOIP_INFO}|${NODE_NAME}|tuic\", type: tuic, server: ${NODE_IP}, port: ${PORT_TUIC}, uuid: ${SB_UUID}, password: ${SB_UUID}, alpn: [h3], disable-sni: true, reduce-rtt: true, request-timeout: 8000, udp-relay-mode: native, congestion-controller: bbr, skip-cert-verify: true}"
    CLASH_SUBSCRIBE+="  $CLASH_TUIC
"
    # anytls
    CLASH_ANYTLS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|anytls\", type: anytls, server: ${NODE_IP}, port: ${PORT_ANYTLS}, password: ${SB_UUID}, client-fingerprint: chrome, udp: true, idle-session-check-interval: 30, idle-session-timeout: 30, skip-cert-verify: true }"
    CLASH_SUBSCRIBE+="  $CLASH_ANYTLS
"
    echo -n "${CLASH_SUBSCRIBE}" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' > ${WORKDIR}/subscribe/proxies

    # 生成 clash 订阅配置文件
    # 模板: 使用 proxy providers
    # cat /templates/client_template/clash | sed "s#NODE_NAME#${NODE_NAME}#g; s#PROXY_PROVIDERS_URL#https://${DOMAIN}/sb-xray/proxies#" > ${WORKDIR}/subscribe/clash
}

show_shadowrocket_link() {
    # 生成 ShadowRocket 订阅配置文件
    SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${SB_UUID}@${DOMAIN}:${PORT_XTLS_REALITY}" | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|xtls-reality&obfs=none&tls=1&peer=addons.mozilla.org&mux=1&pbk=${SB_REALITY_PUBLIC_KEY}
"
    SHADOWROCKET_SUBSCRIBE+="
hysteria2://${SB_UUID}@${NODE_IP}:${PORT_HYSTERIA2}?insecure=1&obfs=none#${GEOIP_INFO}|${NODE_NAME}|hysteria2
"
    SHADOWROCKET_SUBSCRIBE+="
tuic://${SB_UUID}:${SB_UUID}@${NODE_IP}:${PORT_TUIC}?congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${GEOIP_INFO}|${NODE_NAME}|tuic
"
    SHADOWROCKET_SUBSCRIBE+="
ss://$(echo -n "2022-blake3-aes-128-gcm:${SHADOWTLS_PASSWORD}@${DOMAIN}:${PORT_SHADOWTLS}" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"addons.mozilla.org\",\"password\":\"${SB_UUID}\"}" | base64 -w0)#${GEOIP_INFO}|${NODE_NAME}|ShadowTLS
"
    SHADOWROCKET_SUBSCRIBE+="
ss://$(echo -n "aes-128-gcm:${SB_UUID}@${DOMAIN}:${PORT_SHADOWSOCKS}" | base64 -w0)#${GEOIP_INFO}|${NODE_NAME}|shadowsocks
"
    SHADOWROCKET_SUBSCRIBE+="
trojan://${SB_UUID}@${DOMAIN}:${PORT_TROJAN}?allowInsecure=1#${GEOIP_INFO}|${NODE_NAME}|trojan
"
    SHADOWROCKET_SUBSCRIBE+="
vmess://$(echo -n "auto:${SB_UUID}@${DOMAIN}:443" | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls&obfsParam=${DOMAIN}&path=/${SB_UUID}-vmess&obfs=websocket&alterId=0&tls=1&peer=${DOMAIN}&allowInsecure=1
"
    SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${SB_UUID}@${DOMAIN}:443" | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls&obfsParam=${DOMAIN}&path=/${SB_UUID}-vless?ed=2048&obfs=websocket&tls=1&peer=${DOMAIN}&allowInsecure=1
"
    SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n auto:${SB_UUID}@${DOMAIN}:${PORT_H2_REALITY} | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|h2-reality&path=/&obfs=h2&tls=1&peer=addons.mozilla.org&alpn=h2&mux=1&pbk=${SB_REALITY_PUBLIC_KEY}
"
    SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${SB_UUID}@${DOMAIN}:${PORT_GRPC_REALITY}" | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|grpc-reality&path=grpc&obfs=grpc&tls=1&peer=addons.mozilla.org&pbk=${SB_REALITY_PUBLIC_KEY}
"
    SHADOWROCKET_SUBSCRIBE+="
anytls://${SB_UUID}@${NODE_IP}:${PORT_ANYTLS}?insecure=1&udp=1#${GEOIP_INFO}|${NODE_NAME}|&anytls
"
    hint "ShadowRocket 订阅链接内容如下:
${SHADOWROCKET_SUBSCRIBE}"
    echo -n "$SHADOWROCKET_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > ${WORKDIR}/subscribe/shadowrocket
}

show_v2rayn_link() {
    # 生成 V2rayN 订阅文件
    V2RAYN_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:${PORT_XTLS_REALITY}?encryption=none&security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=tcp&headerType=none&host=${DOMAIN}#${GEOIP_INFO}|${NODE_NAME}|xtls-reality
"
    V2RAYN_SUBSCRIBE+="
hysteria2://${SB_UUID}@${NODE_IP}:${PORT_HYSTERIA2}/?alpn=h3&insecure=1#${GEOIP_INFO}|${NODE_NAME}|hysteria2
"
    V2RAYN_SUBSCRIBE+="
# 需把 tls 里的 inSecure 设置为 true
tuic://${SB_UUID}:${SB_UUID}@${NODE_IP}:${PORT_TUIC}?alpn=h3&congestion_control=bbr#${GEOIP_INFO}|${NODE_NAME}|tuic
"
    V2RAYN_SUBSCRIBE+="
ss://$(echo -n "aes-128-gcm:${SB_UUID}@${DOMAIN}:${PORT_SHADOWSOCKS}" | base64 -w0)#${GEOIP_INFO}|${NODE_NAME}|shadowsocks
"
    V2RAYN_SUBSCRIBE+="
trojan://${SB_UUID}@${DOMAIN}:${PORT_TROJAN}?security=tls&type=tcp&headerType=none#${GEOIP_INFO}|${NODE_NAME}|trojan
"
    V2RAYN_SUBSCRIBE+="
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\", \"add\": \"${DOMAIN}\", \"port\": \"443\", \"id\": \"${SB_UUID}\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${DOMAIN}\", \"path\": \"/${SB_UUID}-vmess\", \"tls\": \"tls\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)
"
    V2RAYN_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F${SB_UUID}-vless%3Fed%3D2048#${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls
"
    V2RAYN_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:${PORT_GRPC_REALITY}?encryption=none&security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=grpc&serviceName=grpc&mode=gun#${GEOIP_INFO}|${NODE_NAME}|grpc-reality
"
    V2RAYN_SUBSCRIBE+="
# 需把 tls 里的 inSecure 设置为 true
anytls://${SB_UUID}@${NODE_IP}:${PORT_ANYTLS}?security=tls&type=tcp#${GEOIP_INFO}|${NODE_NAME}|&anytls
"
    # vmess ws tls
    V2RAYN_SUBSCRIBE+="
vmess://$(echo -n "{\"add\":\"${DOMAIN}\",\"aid\":\"${ALTERID}\",\"host\":\"${DOMAIN}\",\"id\":\"${V2RAY_UUID}\",\"net\":\"${NETWORK}\",\"path\":\"/${V2RAY_URL_PATH}\",\"port\":\"${LISTENING_PORT}\",\"ps\":\"${GEOIP_INFO}|${DOMAIN}-VMESS\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)
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
    info "V2RAYN 订阅链接内容如下:
${V2RAYN_SUBSCRIBE}"
    # echo -n "$V2RAYN_SUBSCRIBE" | sed -E '/^[ ]*#|^[ ]+|^--|^\{|^\}/d' | sed '/^$/d' | base64 -w0 > ${WORKDIR}/subscribe/v2rayn
    echo -n "$V2RAYN_SUBSCRIBE" | sed '/^# 需把 tls 里的 inSecure 设置为 true$/d' | base64 -w0 > ${WORKDIR}/subscribe/v2rayn
}

show_netbox_link() {
    # 生成 NekoBox 订阅文件
    NEKOBOX_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:${PORT_XTLS_REALITY}?security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=tcp&encryption=none#${GEOIP_INFO}|${NODE_NAME}|xtls-reality
"
    NEKOBOX_SUBSCRIBE+="
hy2://${SB_UUID}@${NODE_IP}:${PORT_HYSTERIA2}?insecure=1#${GEOIP_INFO}|${NODE_NAME}|hysteria2
"
    NEKOBOX_SUBSCRIBE+="
tuic://${SB_UUID}:${SB_UUID}@${NODE_IP}:${PORT_TUIC}?congestion_control=bbr&alpn=h3&udp_relay_mode=native&allow_insecure=1&disable_sni=1#${GEOIP_INFO}|${NODE_NAME}|tuic
"
    NEKOBOX_SUBSCRIBE+="
nekoray://custom#$(echo -n "{\"_v\":0,\"addr\":\"127.0.0.1\",\"cmd\":[\"\"],\"core\":\"internal\",\"cs\":\"{\n    \\\"password\\\": \\\"${SB_UUID}\\\",\n    \\\"server\\\": \\\"${DOMAIN}\\\",\n    \\\"server_port\\\": ${PORT_SHADOWTLS},\n    \\\"tag\\\": \\\"shadowtls-out\\\",\n    \\\"tls\\\": {\n        \\\"enabled\\\": true,\n        \\\"server_name\\\": \\\"addons.mozilla.org\\\"\n    },\n    \\\"type\\\": \\\"shadowtls\\\",\n    \\\"version\\\": 3\n}\n\",\"mapping_port\":0,\"name\":\"${GEOIP_INFO}|${NODE_NAME}|ss-custom\",\"port\":1080,\"socks_port\":0}" | base64 -w0)

nekoray://shadowsocks#$(echo -n "{\"_v\":0,\"method\":\"2022-blake3-aes-128-gcm\",\"name\":\"${GEOIP_INFO}|${NODE_NAME}|ss-tls\",\"pass\":\"${SHADOWTLS_PASSWORD}\",\"port\":0,\"stream\":{\"ed_len\":0,\"insecure\":false,\"mux_s\":0,\"net\":\"tcp\"},\"uot\":0}" | base64 -w0)
"
    NEKOBOX_SUBSCRIBE+="
ss://$(echo -n "aes-128-gcm:${SB_UUID}" | base64 -w0)@${DOMAIN}:${PORT_SHADOWSOCKS}#${GEOIP_INFO}|${NODE_NAME}|shadowsocks
"
    NEKOBOX_SUBSCRIBE+="
trojan://${SB_UUID}@${DOMAIN}:${PORT_TROJAN}?security=tls&allowInsecure=1&fp=random&type=tcp#${GEOIP_INFO}|${NODE_NAME}|trojan
"
    NEKOBOX_SUBSCRIBE+="
vmess://$(echo -n "{\"add\":\"${DOMAIN}\",\"aid\":\"0\",\"host\":\"${DOMAIN}\",\"id\":\"${SB_UUID}\",\"net\":\"ws\",\"path\":\"/${SB_UUID}-vmess\",\"port\":\"443\",\"ps\":\"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\",\"scy\":\"auto\",\"sni\":\"\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)
"
    NEKOBOX_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:443?security=tls&sni=${DOMAIN}&type=ws&path=/${SB_UUID}-vless?ed%3D2048&host=${DOMAIN}#${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls
"
    NEKOBOX_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:${PORT_H2_REALITY}?security=reality&sni=addons.mozilla.org&alpn=h2&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=http&encryption=none#${GEOIP_INFO}|${NODE_NAME}|h2-reality
"
    NEKOBOX_SUBSCRIBE+="
vless://${SB_UUID}@${DOMAIN}:${PORT_GRPC_REALITY}?security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=grpc&serviceName=grpc&encryption=none#${GEOIP_INFO}|${NODE_NAME}|grpc-reality
"
    hint "NEKOBOX 订阅链接内容如下:
$NEKOBOX_SUBSCRIBE"
    echo -n "$NEKOBOX_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > ${WORKDIR}/subscribe/neko
}

show_singbox_link() {
    # 生成 Sing-box 订阅文件
    INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|xtls-reality\", \"server\":\"${DOMAIN}\", \"server_port\":${PORT_XTLS_REALITY}, \"uuid\":\"${SB_UUID}\", \"flow\":\"\", \"tls\":{ \"enabled\":true, \"server_name\":\"addons.mozilla.org\", \"utls\":{ \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${SB_REALITY_PUBLIC_KEY}\", \"short_id\":\"\" } }, \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|xtls-reality\","

    INBOUND_REPLACE+=" { \"type\": \"hysteria2\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|hysteria2\", \"server\": \"${NODE_IP}\", \"server_port\": ${PORT_HYSTERIA2},"
    [[ -n "${PORT_HOPPING_START}" && -n "${PORT_HOPPING_END}" ]] && INBOUND_REPLACE+=" \"server_ports\": [ \"${PORT_HOPPING_START}:${PORT_HOPPING_END}\" ],"
    INBOUND_REPLACE+=" \"up_mbps\": 2000, \"down_mbps\": 2500, \"password\": \"${SB_UUID}\", \"tls\": { \"enabled\": true, \"insecure\": true, \"server_name\": \"\", \"alpn\": [ \"h3\" ] } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|hysteria2\","

    INBOUND_REPLACE+=" { \"type\": \"tuic\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|tuic\", \"server\": \"${NODE_IP}\", \"server_port\": ${PORT_TUIC}, \"uuid\": \"${SB_UUID}\", \"password\": \"${SB_UUID}\", \"congestion_control\": \"bbr\", \"udp_relay_mode\": \"native\", \"zero_rtt_handshake\": false, \"heartbeat\": \"10s\", \"tls\": { \"enabled\": true, \"insecure\": true, \"server_name\": \"\", \"alpn\": [ \"h3\" ] } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|tuic\","

    INBOUND_REPLACE+=" { \"type\": \"shadowsocks\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|ShadowTLS\", \"method\": \"2022-blake3-aes-128-gcm\", \"password\": \"${SHADOWTLS_PASSWORD}\", \"detour\": \"shadowtls-out\", \"udp_over_tcp\": false, \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } }, { \"type\": \"shadowtls\", \"tag\": \"shadowtls-out\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_SHADOWTLS}, \"version\": 3, \"password\": \"${SB_UUID}\", \"tls\": { \"enabled\": true, \"server_name\": \"addons.mozilla.org\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" } } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|ShadowTLS\","

    INBOUND_REPLACE+=" { \"type\": \"shadowsocks\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|shadowsocks\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_SHADOWSOCKS}, \"method\": \"aes-128-gcm\", \"password\": \"${SB_UUID}\", \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|shadowsocks\","

    INBOUND_REPLACE+=" { \"type\": \"trojan\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|trojan\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_TROJAN}, \"password\": \"${SB_UUID}\", \"tls\": { \"enabled\":true, \"insecure\": true, \"server_name\":\"\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|trojan\","

    INBOUND_REPLACE+=" { \"type\": \"vmess\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\", \"server\":\"${DOMAIN}\", \"server_port\":443, \"uuid\": \"${SB_UUID}\", \"security\": \"auto\", \"transport\": { \"type\":\"ws\", \"path\":\"/${SB_UUID}-vmess\", \"headers\": { \"Host\": \"${DOMAIN}\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } }," && NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\","

    INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls\", \"server\":\"${DOMAIN}\", \"server_port\":443, \"uuid\": \"${SB_UUID}\", \"tls\": { \"enabled\":true, \"server_name\":\"${DOMAIN}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" } }, \"transport\": { \"type\":\"ws\", \"path\":\"/${SB_UUID}-vless\", \"headers\": { \"Host\": \"${DOMAIN}\" }, \"max_early_data\":2048, \"early_data_header_name\":\"Sec-WebSocket-Protocol\" }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls\","

    INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|h2-reality\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_H2_REALITY}, \"uuid\":\"${SB_UUID}\", \"tls\": { \"enabled\":true, \"server_name\":\"addons.mozilla.org\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${SB_REALITY_PUBLIC_KEY}\", \"short_id\":\"\" } }, \"transport\": { \"type\": \"http\" } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|h2-reality\","

    INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|grpc-reality\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_GRPC_REALITY}, \"uuid\":\"${SB_UUID}\", \"tls\": { \"enabled\":true, \"server_name\":\"addons.mozilla.org\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${SB_REALITY_PUBLIC_KEY}\", \"short_id\":\"\" } }, \"transport\": { \"type\": \"grpc\", \"service_name\": \"grpc\" } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|grpc-reality\","

    INBOUND_REPLACE+=" { \"type\": \"anytls\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|anytls\", \"server\": \"${NODE_IP}\", \"server_port\": ${PORT_ANYTLS}, \"password\": \"${SB_UUID}\", \"idle_session_check_interval\": \"30s\", \"idle_session_timeout\": \"30s\", \"min_idle_session\": 5, \"tls\": { \"enabled\": true, \"insecure\": true, \"server_name\": \"\" } },"
    NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|anytls\","

    cat /templates/client_template/sing-box1 | sed 's#, {[^}]\+"tun-in"[^}]\+}##' | sed "s#\"<INBOUND_REPLACE>\",#$INBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" | jq > ${WORKDIR}/subscribe/sing-box-pc

    cat /templates/client_template/sing-box1 | sed 's# {[^}]\+"mixed"[^}]\+},##; s#, "auto_detect_interface": true##' | sed "s#\"<INBOUND_REPLACE>\",#$INBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" | jq > ${WORKDIR}/subscribe/sing-box-phone
}

show_all_link() {
    # 生成配置文件
    info "
******************************************************************
*                                                                *
  *        Sing-box / Xray 多协议多传输客户端配置文件汇总         *
各客户端配置文件路径: ${WORKDIR}/subscribe/\n 完整模板可参照:\n https://github.com/chika0801/sing-box-examples/tree/main/Tun
"

    hint "Index:
https://${DOMAIN}/sb-xray/"

    hint "V2rayN 订阅:
https://${DOMAIN}/sb-xray/v2rayn"

    hint "ShadowRocket 订阅:
https://${DOMAIN}/sb-xray/shadowrocket"

    hint "NekoBox 订阅:
https://${DOMAIN}/sb-xray/neko"

    hint "Clash 订阅:
https://${DOMAIN}/sb-xray/clash"

    hint "sing-box for pc 订阅:
https://${DOMAIN}/sb-xray/sing-box-pc

sing-box for cellphone 订阅:
https://${DOMAIN}/sb-xray/sing-box-phone"

    info " 自适应 Clash / V2rayN / NekoBox / ShadowRocket / SFI / SFA / SFM 客户端:
https://${DOMAIN}/all-sing-box/auto"
    info "******************************************************************"
}

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色

mkdir -p ${WORKDIR}/subscribe

source "/.env/xray"
source "/.env/secret"

show_clash_subscribe
show_shadowrocket_link
show_v2rayn_link
show_netbox_link
show_singbox_link
show_all_link
