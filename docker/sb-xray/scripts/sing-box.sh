#!/usr/bin/env bash

# 加载环境变量
ENV_FILE="/.env/xray"
[ -f "$ENV_FILE" ] || error_exit "环境文件不存在: $ENV_FILE"
source "$ENV_FILE"

NODE_NAME="${DOMAIN%%.*}"

XTLS_REALITY=true
HYSTERIA2=true
TUIC=true
SHADOWTLS=true
SHADOWSOCKS=true
TROJAN=true
VMESS_WS=true
VLESS_WS=true
H2_REALITY=true
GRPC_REALITY=true

show_clash_subscribe() {
    # 生成各订阅文件
    # 生成 Clash proxy providers 订阅文件
    CLASH_SUBSCRIBE="proxies:"
    # xtls-reality
    [ "${XTLS_REALITY}" = 'true' ] && local CLASH_XTLS_REALITY="- {name: \"${GEOIP_INFO}|${NODE_NAME}|xtls-reality\", type: vless, server: ${DOMAIN}, port: ${PORT_XTLS_REALITY}, uuid: ${SB_UUID}, network: tcp, udp: true, tls: true, servername: addons.mozilla.org, client-fingerprint: chrome, reality-opts: {public-key: ${SB_REALITY_PUBLIC_KEY}, short-id: \"\"}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_SHADOWSOCKS
"

    [ "${XTLS_REALITY}" = 'true' ] && local CLASH_XTLS_REALITY="- {name: \"${NODE_NAME} xtls-reality\", type: vless, server: ${SERVER_IP}, port: ${PORT_XTLS_REALITY}, uuid: ${UUID}, network: tcp, udp: true, tls: true, servername: addons.mozilla.org, client-fingerprint: chrome, reality-opts: {public-key: ${REALITY_PUBLIC}, short-id: \"\"}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '1000 Mbps', down: '1000 Mbps' } }" &&
    local CLASH_SUBSCRIBE+="  $CLASH_XTLS_REALITY
"
    # hysteria2
    [ "${HYSTERIA2}" = 'true' ] && local CLASH_HYSTERIA2="- {name: \"${GEOIP_INFO}|${NODE_NAME}|hysteria2\", type: hysteria2, server: ${DOMAIN}, port: ${PORT_HYSTERIA2}, up: \"2000 Mbps\", down: \"2500 Mbps\", password: ${SB_UUID}, skip-cert-verify: true}"
    CLASH_SUBSCRIBE+="  $CLASH_HYSTERIA2
"
    # tuic
    [ "${TUIC}" = 'true' ] && local CLASH_TUIC="- {name: \"${GEOIP_INFO}|${NODE_NAME}|tuic\", type: tuic, server: ${DOMAIN}, port: ${PORT_TUIC}, uuid: ${SB_UUID}, password: ${SB_UUID}, alpn: [h3], disable-sni: true, reduce-rtt: true, request-timeout: 8000, udp-relay-mode: native, congestion-controller: bbr, skip-cert-verify: true}"
    CLASH_SUBSCRIBE+="  $CLASH_TUIC
"
    # ShadowTLS
    [ "${SHADOWTLS}" = 'true' ] && local CLASH_SHADOWTLS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|ShadowTLS\", type: ss, server: ${DOMAIN}, port: ${PORT_SHADOWTLS}, cipher: 2022-blake3-aes-128-gcm, password: ${SHADOWTLS_PASSWORD}, plugin: shadow-tls, client-fingerprint: chrome, plugin-opts: {host: addons.mozilla.org, password: \"${SB_UUID}\", version: 3}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_SHADOWTLS
"
    # shadowsocks
    [ "${SHADOWSOCKS}" = 'true' ] && local CLASH_SHADOWSOCKS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|shadowsocks\", type: ss, server: ${DOMAIN}, port: $PORT_SHADOWSOCKS, cipher: aes-128-gcm, password: ${SB_UUID}, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_SHADOWSOCKS
"
    # trojan
    [ "${TROJAN}" = 'true' ] && local CLASH_TROJAN="- {name: \"${GEOIP_INFO}|${NODE_NAME}|trojan\", type: trojan, server: ${DOMAIN}, port: $PORT_TROJAN, password: ${SB_UUID}, client-fingerprint: random, skip-cert-verify: true, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_TROJAN
"
    # vmess-ws
    [ "${VMESS_WS}" = 'true' ] && local CLASH_VMESS_WS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|-tls\", type: vmess, server: ${DOMAIN}, port: 443, uuid: ${SB_UUID}, udp: true, tls: true, alterId: 0, cipher: auto, skip-cert-verify: true, network: ws, ws-opts: { path: \"/${SB_UUID}-vmess\", headers: {Host: ${DOMAIN}} }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_VMESS_WS
"
    # vless-ws-tls
    [ "${VLESS_WS}" = 'true' ] && local CLASH_VLESS_WS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls\", type: vless, server: ${DOMAIN}, port: 443, uuid: ${SB_UUID}, udp: true, tls: true, servername: ${DOMAIN}, network: ws, skip-cert-verify: true, ws-opts: { path: \"/${SB_UUID}-vless\", headers: {Host: ${DOMAIN}}, max-early-data: 2048, early-data-header-name: Sec-WebSocket-Protocol }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_VLESS_WS
"
    # Clash 的 H2 传输层未实现多路复用功能，在 Clash.Meta 中更建议使用 gRPC 协议，故不输出相关配置。 https://wiki.metacubex.one/config/proxies/vless/
    [ "${H2_REALITY}" = 'true' ]
    # grpc-reality
    [ "${GRPC_REALITY}" = 'true' ] && local CLASH_GRPC_REALITY="- {name: \"${GEOIP_INFO}|${NODE_NAME}|grpc-reality\", type: vless, server: ${DOMAIN}, port: ${PORT_GRPC_REALITY}, uuid: ${SB_UUID}, network: grpc, tls: true, udp: true, flow: , client-fingerprint: chrome, servername: addons.mozilla.org, grpc-opts: {  grpc-service-name: \"grpc\" }, reality-opts: { public-key: ${SB_REALITY_PUBLIC_KEY}, short-id: \"\" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false }, brutal-opts: { enabled: ${IS_BRUTAL}, up: '2500 Mbps', down: '2500 Mbps' } }"
    CLASH_SUBSCRIBE+="  $CLASH_GRPC_REALITY
"
    # anytls
    [ "${ANYTLS}" = 'true' ] && local CLASH_ANYTLS="- {name: \"${GEOIP_INFO}|${NODE_NAME}|anytls\", type: anytls, server: ${DOMAIN}, port: $PORT_ANYTLS, password: ${SB_UUID}, client-fingerprint: chrome, udp: true, idle-session-check-interval: 30, idle-session-timeout: 30, skip-cert-verify: true }"
    CLASH_SUBSCRIBE+="  $CLASH_ANYTLS
"

    echo -n "${CLASH_SUBSCRIBE}" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' > ${WORKDIR}/subscribe/proxies

    # 生成 clash 订阅配置文件
    # 模板: 使用 proxy providers
    cat /templates/client_template/clash | sed "s#NODE_NAME#${NODE_NAME}#g; s#PROXY_PROVIDERS_URL#https://${DOMAIN}/all-sing-box/proxies#" > ${WORKDIR}/subscribe/clash
}

show_shadowrocket_link() {
    # 生成 ShadowRocket 订阅配置文件
    [ "${XTLS_REALITY}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
vless://$(echo -n "auto:${SB_UUID}@${DOMAIN}:${PORT_XTLS_REALITY}" | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|xtls-reality&obfs=none&tls=1&peer=addons.mozilla.org&mux=1&pbk=${SB_REALITY_PUBLIC_KEY}
"
    [ "${HYSTERIA2}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
hysteria2://${SB_UUID}@${DOMAIN}:${PORT_HYSTERIA2}?insecure=1&obfs=none#${GEOIP_INFO}|${NODE_NAME}|hysteria2
"
    [ "${TUIC}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
tuic://${SB_UUID}:${SB_UUID}@${DOMAIN}:${PORT_TUIC}?congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#${GEOIP_INFO}|${NODE_NAME}|tuic
"
    [ "${SHADOWTLS}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
ss://$(echo -n "2022-blake3-aes-128-gcm:${SHADOWTLS_PASSWORD}@${DOMAIN}:${PORT_SHADOWTLS}" | base64 -w0)?shadow-tls=$(echo -n "{\"version\":\"3\",\"host\":\"addons.mozilla.org\",\"password\":\"${SB_UUID}\"}" | base64 -w0)#${GEOIP_INFO}|${NODE_NAME}|ShadowTLS
"
    [ "${SHADOWSOCKS}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
ss://$(echo -n "aes-128-gcm:${SB_UUID}@${DOMAIN}:$PORT_SHADOWSOCKS" | base64 -w0)#${GEOIP_INFO}|${NODE_NAME}|shadowsocks
"
    [ "${TROJAN}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
trojan://${SB_UUID}@${DOMAIN}:$PORT_TROJAN?allowInsecure=1#${GEOIP_INFO}|${NODE_NAME}|trojan
"
    [ "${VMESS_WS}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
vmess://$(echo -n "auto:${SB_UUID}@${DOMAIN}:443" | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls&obfsParam=${DOMAIN}&path=/${SB_UUID}-vmess&obfs=websocket&alterId=0&tls=1&peer=${DOMAIN}&allowInsecure=1
"
    [ "${VLESS_WS}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
vless://$(echo -n "auto:${SB_UUID}@${DOMAIN}:443" | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls&obfsParam=${DOMAIN}&path=/${SB_UUID}-vless?ed=2048&obfs=websocket&tls=1&peer=${DOMAIN}&allowInsecure=1
"
    [ "${H2_REALITY}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
    ----------------------------
vless://$(echo -n auto:${SB_UUID}@${DOMAIN}:${PORT_H2_REALITY} | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|h2-reality&path=/&obfs=h2&tls=1&peer=addons.mozilla.org&alpn=h2&mux=1&pbk=${SB_REALITY_PUBLIC_KEY}
"
    [ "${GRPC_REALITY}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
vless://$(echo -n "auto:${SB_UUID}@${DOMAIN}:${PORT_GRPC_REALITY}" | base64 -w0)?remarks=${GEOIP_INFO}|${NODE_NAME}|grpc-reality&path=grpc&obfs=grpc&tls=1&peer=addons.mozilla.org&pbk=${SB_REALITY_PUBLIC_KEY}
"
    [ "${ANYTLS}" = 'true' ] && SHADOWROCKET_SUBSCRIBE+="
anytls://${SB_UUID}@${DOMAIN}:${PORT_ANYTLS}?insecure=1&udp=1#${GEOIP_INFO}|${NODE_NAME}|&anytls
"
    echo -n "$SHADOWROCKET_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > ${WORKDIR}/subscribe/shadowrocket
}

show_v2rayn_link() {
    # 生成 V2rayN 订阅文件
    [ "${XTLS_REALITY}" = 'true' ] && V2RAYN_SUBSCRIBE+="
    ----------------------------
vless://${SB_UUID}@${DOMAIN}:${PORT_XTLS_REALITY}?encryption=none&security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=tcp&headerType=none&host=${DOMAIN}#${GEOIP_INFO}|${NODE_NAME}|xtls-reality
"

    [ "${HYSTERIA2}" = 'true' ] && V2RAYN_SUBSCRIBE+="
    ----------------------------
hysteria2://${SB_UUID}@${DOMAIN}:${PORT_HYSTERIA2}/?alpn=h3&insecure=1#${GEOIP_INFO}|${NODE_NAME}|hysteria2
"

    [ "${TUIC}" = 'true' ] && V2RAYN_SUBSCRIBE+="
    ----------------------------
tuic://${SB_UUID}:${SB_UUID}@${DOMAIN}:${PORT_TUIC}?alpn=h3&congestion_control=bbr#${GEOIP_INFO}|${NODE_NAME}|tuic
"

    info "ShadowTLS 配置文件内容，需要更新 sing_box 内核"
    [ "${SHADOWTLS}" = 'true' ] && V2RAYN_SUBSCRIBE+="
----------------------------
{
  \"log\":{
      \"level\":\"warn\"
  },
  \"inbounds\":[
      {
          \"listen\":\"127.0.0.1\",
          \"listen_port\":${PORT_SHADOWTLS},
          \"sniff\":true,
          \"sniff_override_destination\":false,
          \"tag\": \"ShadowTLS\",
          \"type\":\"mixed\"
      }
  ],
  \"outbounds\":[
      {
          \"detour\":\"shadowtls-out\",
          \"method\":\"2022-blake3-aes-128-gcm\",
          \"password\":\"${SHADOWTLS_PASSWORD}\",
          \"type\":\"shadowsocks\",
          \"udp_over_tcp\": false,
          \"multiplex\": {
            \"enabled\": true,
            \"protocol\": \"h2mux\",
            \"max_connections\": 8,
            \"min_streams\": 16,
            \"padding\": true
          }
      },
      {
          \"password\":\"${SB_UUID}\",
          \"server\":\"${DOMAIN}\",
          \"server_port\":${PORT_SHADOWTLS},
          \"tag\": \"shadowtls-out\",
          \"tls\":{
              \"enabled\":true,
              \"server_name\":\"addons.mozilla.org\",
              \"utls\": {
                \"enabled\": true,
                \"fingerprint\": \"chrome\"
              }
          },
          \"type\":\"shadowtls\",
          \"version\":3
      }
  ]
}"
    [ "${SHADOWSOCKS}" = 'true' ] && V2RAYN_SUBSCRIBE+="
----------------------------
ss://$(echo -n "aes-128-gcm:${SB_UUID}@${DOMAIN}:$PORT_SHADOWSOCKS" | base64 -w0)#${GEOIP_INFO}|${NODE_NAME}|shadowsocks
"

    [ "${TROJAN}" = 'true' ] && V2RAYN_SUBSCRIBE+="
----------------------------
trojan://${SB_UUID}@${DOMAIN}:$PORT_TROJAN?security=tls&type=tcp&headerType=none#${GEOIP_INFO}|${NODE_NAME}|trojan
"

    [ "${VMESS_WS}" = 'true' ] && V2RAYN_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{ \"v\": \"2\", \"ps\": \"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\", \"add\": \"${DOMAIN}\", \"port\": \"443\", \"id\": \"${SB_UUID}\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${DOMAIN}\", \"path\": \"/${SB_UUID}-vmess\", \"tls\": \"tls\", \"sni\": \"\", \"alpn\": \"\" }" | base64 -w0)
"

    [ "${VLESS_WS}" = 'true' ] && V2RAYN_SUBSCRIBE+="
----------------------------
vless://${SB_UUID}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F${SB_UUID}-vless%3Fed%3D2048#${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls
"

    [ "${H2_REALITY}" = 'true' ] && V2RAYN_SUBSCRIBE+="
----------------------------
vless://${SB_UUID}@${DOMAIN}:${PORT_H2_REALITY}?encryption=none&security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=http#${GEOIP_INFO}|${NODE_NAME}|h2-reality
"

    [ "${GRPC_REALITY}" = 'true' ] && V2RAYN_SUBSCRIBE+="
----------------------------
vless://${SB_UUID}@${DOMAIN}:${PORT_GRPC_REALITY}?encryption=none&security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=grpc&serviceName=grpc&mode=gun#${GEOIP_INFO}|${NODE_NAME}|grpc-reality
"

    [ "${ANYTLS}" = 'true' ] && V2RAYN_SUBSCRIBE+="
----------------------------
{
    \"log\":{
        \"level\":\"warn\"
    },
    \"inbounds\":[
        {
            \"listen\":\"127.0.0.1\",
            \"listen_port\":${PORT_ANYTLS},
            \"sniff\":true,
            \"sniff_override_destination\":false,
            \"tag\": \"AnyTLS\",
            \"type\":\"mixed\"
        }
    ],
    \"outbounds\":[
        {
            \"type\": \"anytls\",
            \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|anytls\",
            \"server\": \"${DOMAIN}\",
            \"server_port\": ${PORT_ANYTLS},
            \"password\": \"${SB_UUID}\",
            \"idle_session_check_interval\": \"30s\",
            \"idle_session_timeout\": \"30s\",
            \"min_idle_session\": 5,
            \"tls\": {
              \"enabled\": true,
              \"insecure\": true,
              \"server_name\": \"\"
            }
        }
    ]
}"

    echo -n "$V2RAYN_SUBSCRIBE" | sed -E '/^[ ]*#|^[ ]+|^--|^\{|^\}/d' | sed '/^$/d' | base64 -w0 > ${WORKDIR}/subscribe/v2rayn
}

show_netbox_link() {
    # 生成 NekoBox 订阅文件
    [ "${XTLS_REALITY}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${SB_UUID}@${DOMAIN}:${PORT_XTLS_REALITY}?security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=tcp&encryption=none#${GEOIP_INFO}|${NODE_NAME}|xtls-reality
"

    [ "${HYSTERIA2}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
hy2://${SB_UUID}@${DOMAIN}:${PORT_HYSTERIA2}?insecure=1#${GEOIP_INFO}|${NODE_NAME}|hysteria2
"

    [ "${TUIC}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
tuic://${SB_UUID}:${SB_UUID}@${DOMAIN}:${PORT_TUIC}?congestion_control=bbr&alpn=h3&udp_relay_mode=native&allow_insecure=1&disable_sni=1#${GEOIP_INFO}|${NODE_NAME}|tuic
"

    [ "${SHADOWTLS}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
nekoray://custom#$(echo -n "{\"_v\":0,\"addr\":\"127.0.0.1\",\"cmd\":[\"\"],\"core\":\"internal\",\"cs\":\"{\n    \\\"password\\\": \\\"${SB_UUID}\\\",\n    \\\"server\\\": \\\"${DOMAIN}\\\",\n    \\\"server_port\\\": ${PORT_SHADOWTLS},\n    \\\"tag\\\": \\\"shadowtls-out\\\",\n    \\\"tls\\\": {\n        \\\"enabled\\\": true,\n        \\\"server_name\\\": \\\"addons.mozilla.org\\\"\n    },\n    \\\"type\\\": \\\"shadowtls\\\",\n    \\\"version\\\": 3\n}\n\",\"mapping_port\":0,\"name\":\"1-tls-not-use\",\"port\":1080,\"socks_port\":0}" | base64 -w0)

nekoray://shadowsocks#$(echo -n "{\"_v\":0,\"method\":\"2022-blake3-aes-128-gcm\",\"name\":\"2-ss-not-use\",\"pass\":\"${SHADOWTLS_PASSWORD}\",\"port\":0,\"stream\":{\"ed_len\":0,\"insecure\":false,\"mux_s\":0,\"net\":\"tcp\"},\"uot\":0}" | base64 -w0)
"

    [ "${SHADOWSOCKS}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
ss://$(echo -n "aes-128-gcm:${SB_UUID}" | base64 -w0)@${DOMAIN}:$PORT_SHADOWSOCKS#${GEOIP_INFO}|${NODE_NAME}|shadowsocks
"

    [ "${TROJAN}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
trojan://${SB_UUID}@${DOMAIN}:$PORT_TROJAN?security=tls&allowInsecure=1&fp=random&type=tcp#${GEOIP_INFO}|${NODE_NAME}|trojan
"

    [ "${VMESS_WS}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
vmess://$(echo -n "{\"add\":\"${DOMAIN}\",\"aid\":\"0\",\"host\":\"${DOMAIN}\",\"id\":\"${SB_UUID}\",\"net\":\"ws\",\"path\":\"/${SB_UUID}-vmess\",\"port\":\"443\",\"ps\":\"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\",\"scy\":\"auto\",\"sni\":\"\",\"tls\":\"tls\",\"type\":\"\",\"v\":\"2\"}" | base64 -w0)
"

    [ "${VLESS_WS}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${SB_UUID}@${DOMAIN}:443?security=tls&sni=${DOMAIN}&type=ws&path=/${SB_UUID}-vless?ed%3D2048&host=${DOMAIN}#${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls
"

    [ "${H2_REALITY}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${SB_UUID}@${DOMAIN}:${PORT_H2_REALITY}?security=reality&sni=addons.mozilla.org&alpn=h2&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=http&encryption=none#${GEOIP_INFO}|${NODE_NAME}|h2-reality
"

    [ "${GRPC_REALITY}" = 'true' ] && NEKOBOX_SUBSCRIBE+="
----------------------------
vless://${SB_UUID}@${DOMAIN}:${PORT_GRPC_REALITY}?security=reality&sni=addons.mozilla.org&fp=chrome&pbk=${SB_REALITY_PUBLIC_KEY}&type=grpc&serviceName=grpc&encryption=none#${GEOIP_INFO}|${NODE_NAME}|grpc-reality
"

    echo -n "$NEKOBOX_SUBSCRIBE" | sed -E '/^[ ]*#|^--/d' | sed '/^$/d' | base64 -w0 > ${WORKDIR}/subscribe/neko
}

show_singbox_link() {
    # 生成 Sing-box 订阅文件
    [ "${XTLS_REALITY}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|xtls-reality\", \"server\":\"${DOMAIN}\", \"server_port\":${PORT_XTLS_REALITY}, \"uuid\":\"${SB_UUID}\", \"flow\":\"\", \"tls\":{ \"enabled\":true, \"server_name\":\"addons.mozilla.org\", \"utls\":{ \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${SB_REALITY_PUBLIC_KEY}\", \"short_id\":\"\" } }, \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|xtls-reality\","

    if [ "${HYSTERIA2}" = 'true' ]; then
        INBOUND_REPLACE+=" { \"type\": \"hysteria2\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|hysteria2\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_HYSTERIA2},"
        [[ -n "${PORT_HOPPING_START}" && -n "${PORT_HOPPING_END}" ]] && INBOUND_REPLACE+=" \"server_ports\": [ \"${PORT_HOPPING_START}:${PORT_HOPPING_END}\" ],"
        INBOUND_REPLACE+=" \"up_mbps\": 2000, \"down_mbps\": 2500, \"password\": \"${SB_UUID}\", \"tls\": { \"enabled\": true, \"insecure\": true, \"server_name\": \"\", \"alpn\": [ \"h3\" ] } },"
        local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|hysteria2\","
    fi

    [ "${TUIC}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"tuic\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|tuic\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_TUIC}, \"uuid\": \"${SB_UUID}\", \"password\": \"${SB_UUID}\", \"congestion_control\": \"bbr\", \"udp_relay_mode\": \"native\", \"zero_rtt_handshake\": false, \"heartbeat\": \"10s\", \"tls\": { \"enabled\": true, \"insecure\": true, \"server_name\": \"\", \"alpn\": [ \"h3\" ] } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|tuic\","

    [ "${SHADOWTLS}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"shadowsocks\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|ShadowTLS\", \"method\": \"2022-blake3-aes-128-gcm\", \"password\": \"${SHADOWTLS_PASSWORD}\", \"detour\": \"shadowtls-out\", \"udp_over_tcp\": false, \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } }, { \"type\": \"shadowtls\", \"tag\": \"shadowtls-out\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_SHADOWTLS}, \"version\": 3, \"password\": \"${SB_UUID}\", \"tls\": { \"enabled\": true, \"server_name\": \"addons.mozilla.org\", \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" } } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|ShadowTLS\","

    [ "${SHADOWSOCKS}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"shadowsocks\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|shadowsocks\", \"server\": \"${DOMAIN}\", \"server_port\": $PORT_SHADOWSOCKS, \"method\": \"aes-128-gcm\", \"password\": \"${SB_UUID}\", \"multiplex\": { \"enabled\": true, \"protocol\": \"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|shadowsocks\","

    [ "${TROJAN}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"trojan\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|trojan\", \"server\": \"${DOMAIN}\", \"server_port\": $PORT_TROJAN, \"password\": \"${SB_UUID}\", \"tls\": { \"enabled\":true, \"insecure\": true, \"server_name\":\"\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_connections\": 8, \"min_streams\": 16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|trojan\","

    [ "${VMESS_WS}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"vmess\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\", \"server\":\"${DOMAIN}\", \"server_port\":443, \"uuid\": \"${SB_UUID}\", \"security\": \"auto\", \"transport\": { \"type\":\"ws\", \"path\":\"/${SB_UUID}-vmess\", \"headers\": { \"Host\": \"${DOMAIN}\" } }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } }," && local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|vmess-ws-tls\","

    [ "${VLESS_WS}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls\", \"server\":\"${DOMAIN}\", \"server_port\":443, \"uuid\": \"${SB_UUID}\", \"tls\": { \"enabled\":true, \"server_name\":\"${DOMAIN}\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" } }, \"transport\": { \"type\":\"ws\", \"path\":\"/${SB_UUID}-vless\", \"headers\": { \"Host\": \"${DOMAIN}\" }, \"max_early_data\":2048, \"early_data_header_name\":\"Sec-WebSocket-Protocol\" }, \"multiplex\": { \"enabled\":true, \"protocol\":\"h2mux\", \"max_streams\":16, \"padding\": true, \"brutal\":{ \"enabled\":true, \"up_mbps\":2500, \"down_mbps\":2500 } } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|vless-ws-tls\","

    [ "${H2_REALITY}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|h2-reality\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_H2_REALITY}, \"uuid\":\"${SB_UUID}\", \"tls\": { \"enabled\":true, \"server_name\":\"addons.mozilla.org\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${SB_REALITY_PUBLIC_KEY}\", \"short_id\":\"\" } }, \"transport\": { \"type\": \"http\" } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|h2-reality\","

    [ "${GRPC_REALITY}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"vless\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|grpc-reality\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_GRPC_REALITY}, \"uuid\":\"${SB_UUID}\", \"tls\": { \"enabled\":true, \"server_name\":\"addons.mozilla.org\", \"utls\": { \"enabled\":true, \"fingerprint\":\"chrome\" }, \"reality\":{ \"enabled\":true, \"public_key\":\"${SB_REALITY_PUBLIC_KEY}\", \"short_id\":\"\" } }, \"transport\": { \"type\": \"grpc\", \"service_name\": \"grpc\" } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|grpc-reality\","

    [ "${ANYTLS}" = 'true' ] &&
    INBOUND_REPLACE+=" { \"type\": \"anytls\", \"tag\": \"${GEOIP_INFO}|${NODE_NAME}|anytls\", \"server\": \"${DOMAIN}\", \"server_port\": ${PORT_ANYTLS}, \"password\": \"${SB_UUID}\", \"idle_session_check_interval\": \"30s\", \"idle_session_timeout\": \"30s\", \"min_idle_session\": 5, \"tls\": { \"enabled\": true, \"insecure\": true, \"server_name\": \"\" } }," &&
    local NODE_REPLACE+="\"${GEOIP_INFO}|${NODE_NAME}|anytls\","


    cat /templates/client_template/sing-box1 | sed 's#, {[^}]\+"tun-in"[^}]\+}##' | sed "s#\"<INBOUND_REPLACE>\",#$INBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" | jq > ${WORKDIR}/subscribe/sing-box-pc

    cat /templates/client_template/sing-box1 | sed 's# {[^}]\+"mixed"[^}]\+},##; s#, "auto_detect_interface": true##' | sed "s#\"<INBOUND_REPLACE>\",#$INBOUND_REPLACE#; s#\"<NODE_REPLACE>\"#${NODE_REPLACE%,}#g" | jq > ${WORKDIR}/subscribe/sing-box-phone
}

show_all_link() {
    # 生成配置文件
    EXPORT_LIST_FILE="*******************************************
┌────────────────┐
│                │
│     $(warning "V2rayN")     │
│                │
└────────────────┘
$(info "${V2RAYN_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│  $(warning "ShadowRocket")  │
│                │
└────────────────┘
----------------------------
$(hint "${SHADOWROCKET_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│   $(warning "Clash Verge")  │
│                │
└────────────────┘
----------------------------

$(info "$(sed '1d' <<< "${CLASH_SUBSCRIBE}")")

*******************************************
┌────────────────┐
│                │
│    $(warning "NekoBox")     │
│                │
└────────────────┘
$(hint "${NEKOBOX_SUBSCRIBE}")

*******************************************
┌────────────────┐
│                │
│    $(warning "Sing-box")    │
│                │
└────────────────┘
----------------------------

$(info "$(echo "{ \"outbounds\":[ ${INBOUND_REPLACE%,} ] }" | jq)

各客户端配置文件路径: ${WORKDIR}/subscribe/\n 完整模板可参照:\n https://github.com/chika0801/sing-box-examples/tree/main/Tun")
"

    EXPORT_LIST_FILE+="

*******************************************

$(hint "Index:
https://${DOMAIN}/all-sing-box/

QR code:
https://${DOMAIN}/all-sing-box/qr

V2rayN 订阅:
https://${DOMAIN}/all-sing-box/v2rayn")

$(hint "NekoBox 订阅:
https://${DOMAIN}/all-sing-box/neko")

$(hint "Clash 订阅:
https://${DOMAIN}/all-sing-box/clash

sing-box for pc 订阅:
https://${DOMAIN}/all-sing-box/sing-box-pc

sing-box for cellphone 订阅:
https://${DOMAIN}/all-sing-box/sing-box-phone

ShadowRocket 订阅:
https://${DOMAIN}/all-sing-box/shadowrocket")

*******************************************

$(info " 自适应 Clash / V2rayN / NekoBox / ShadowRocket / SFI / SFA / SFM 客户端:
模版:
https://${DOMAIN}/all-sing-box/auto

订阅 QRcode:
模版:
https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://${DOMAIN}/all-sing-box/auto")

$(hint "模版:")
$(qrencode https://${DOMAIN}/all-sing-box/auto)
"

    # 生成并显示节点信息
    echo "$EXPORT_LIST_FILE" > ${WORKDIR}/list
    cat ${WORKDIR}/list
}

main() {
    show_clash_subscribe
    show_shadowrocket_link
    show_v2rayn_link
    show_netbox_link
    show_singbox_link
    show_all_link
}

# 自定义字体彩色，read 函数
warning() { echo -e "\033[31m\033[01m$*\033[0m"; }  # 红色
info() { echo -e "\033[32m\033[01m$*\033[0m"; }   # 绿色
hint() { echo -e "\033[33m\033[01m$*\033[0m"; }   # 黄色
mkdir -p ${WORKDIR}/subscribe
main

vless://99637539-72cc-4e92-b474-4d44df946542@dc99-3.ansandy.com:32102?encryption=none&security=reality&sni=addons.mozilla.org&fp=chrome&pbk=Xa2FtAAwyfvqRzMeWSF9DrqztAOTRxgFXAbZeFkFFh0&type=tcp&headerType=none&host=dc99-3.ansandy.com#%E7%BE%8E%E5%9B%BD%E6%B4%9B%E6%9D%89%E7%9F%B6%7C192.243.112.113%7Cdc99-3%7Cxtls-reality
