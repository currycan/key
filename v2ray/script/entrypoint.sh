#!/bin/sh -e

set -eou pipefail


function checkGoogleEA(){
    if [[ ! -n "$GoogleEABKey" ]] || [[ ! -n "$GoogleEABKey" ]];then
        echo "GoogleEAB变量为空!!"
        exit 1
    fi
}

function registerEmail(){
    acmeSSLDays="89"
    if [[ "$SSL_PROVIDER" == "1" ]]; then
        acmeSSLDays="179"
        acmeSSLServerName="buypass"
        acme.sh --register-account --accountemail ${SSLRegisterEmail} --server buypass

    elif [[ "$SSL_PROVIDER" == "2" ]]; then
        acmeSSLServerName="zerossl"
        acme.sh --register-account -m ${SSLRegisterEmail} --server zerossl

    elif [[ "$SSL_PROVIDER" == "3" ]]; then
        # 请先按照如下链接申请 google Public CA  https://hostloc.com/thread-993780-1-1.html
        # 具体可参考 https://github.com/acmesh-official/acme.sh/wiki/Google-Public-CA
        acmeSSLServerName="google"
        checkGoogleEA
        acme.sh --register-account -m ${SSLRegisterEmail} --server google --eab-kid ${GoogleEABId} --eab-hmac-key ${GoogleEABKey}
    else
        acmeSSLServerName="letsencrypt"
        acme.sh --register-account -m ${SSLRegisterEmail} --server letsencrypt
        # acme.sh --issue -d ${configSSLDomain} --webroot ${configWebsitePath} --keylength ec-256 --days 89 --server letsencrypt
    fi
}

function getHTTPSCertificateWithAcme() {
    if [ -f ${SSL_PATH}/${DOMAIN}.crt ] && [ -f ${SSL_PATH}/${DOMAIN}.key ]; then
        echo "证书文件已存在"
    else
        # ${HOME}/.acme.sh/acme.sh --register-account -m ansandy@foxmail.com
        registerEmail
        if [[ -f "${HOME}/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key" && -f "$HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.cer" ]]; then
            echo "cer 证书文件已存在"
        else
            ${HOME}/.acme.sh/acme.sh --issue -d ${DOMAIN} --standalone --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName} --force
        fi
        ${HOME}/.acme.sh/acme.sh --installcert -d ${DOMAIN} --fullchainpath ${SSL_PATH}/${DOMAIN}.crt --keypath /${SSL_PATH}/${DOMAIN}.key --ecc --force
    fi
}

function createConfig() {
    export DOLLAR='$'
    if [ ! -f /v2ray/config/.env/v2ray ];then
        XUI_LOCAL_PORT=$(shuf -i 35000-40000 -n 1)
        V2RAY_PORT=$((XUI_LOCAL_PORT + 1))
        XRAY_PORT=$((XUI_LOCAL_PORT + 2))
        DUFS_PORT=$((XUI_LOCAL_PORT + 3))
        UUID=$(cat /proc/sys/kernel/random/uuid)
        URL_PATH=/$(head /dev/urandom | tr -dc a-z0-9 | head -c 20)/
        x25519=$(xray x25519)
        PRIVATE_KEY=$(echo "${x25519}" | head -1 | awk '{print $3}')
        PUBLIC_KEY=$(echo "${x25519}" | tail -n 1 | awk '{print $3}')
        SHORTID=$(openssl rand -hex 8)
        XUI_PASSWORD=$(head /dev/urandom | tr -dc 'A-Za-z0-9!@#%^&*()_+{}|:<>?=' | head -c 12)
        GEOIP_INFO=`curl http://www.ip111.cn/ -s | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>'`
        echo "export XUI_LOCAL_PORT=$XUI_LOCAL_PORT" >> /v2ray/config/.env/v2ray
        echo "export V2RAY_PORT=$V2RAY_PORT" >> /v2ray/config/.env/v2ray
        echo "export XRAY_PORT=$XRAY_PORT" >> /v2ray/config/.env/v2ray
        echo "export DUFS_PORT=$DUFS_PORT" >> /v2ray/config/.env/v2ray
        echo "export UUID=$UUID" >> /v2ray/config/.env/v2ray
        echo "export URL_PATH=$URL_PATH" >> /v2ray/config/.env/v2ray
        echo "export PRIVATE_KEY=$PRIVATE_KEY" >> /v2ray/config/.env/v2ray
        echo "export PUBLIC_KEY=$PUBLIC_KEY" >> /v2ray/config/.env/v2ray
        echo "export SHORTID=$SHORTID" >> /v2ray/config/.env/v2ray
        echo "export XUI_PASSWORD=\"$XUI_PASSWORD\"" >> /v2ray/config/.env/v2ray
        echo "export GEOIP_INFO='$GEOIP_INFO'" >> /v2ray/config/.env/v2ray
    fi
    source /v2ray/config/.env/v2ray
    if [ ! -f /etc/nginx/conf.d/proxy.conf ];then
        envsubst </templates/nginx/proxy.conf >/etc/nginx/conf.d/proxy.conf
    fi
    if [ ! -f /etc/v2ray/config.json ]; then
        envsubst </templates/v2ray/config.json >/etc/v2ray/config.json
        envsubst </templates/v2ray/vmess_qr.json >/etc/v2ray/vmess_qr.json
    fi
    if [ ! -d /etc/xray/conf ]; then
        mkdir -p /etc/xray/conf
        envsubst </templates/xray/01_VLESS_TCP_inbounds.json >/etc/xray/conf/01_VLESS_TCP_inbounds.json
        envsubst </templates/xray/02_VLESS_vision_reality_inbounds.json >/etc/xray/conf/02_VLESS_vision_reality_inbounds.json
        envsubst </templates/xray/03_VLESS_vision_gRPC_inbounds.json >/etc/xray/conf/03_VLESS_vision_gRPC_inbounds.json
        cp /templates/xray/00_log.json /etc/xray/conf/00_log.json
        cp /templates/xray/04_routing.json /etc/xray/conf/04_routing.json
        cp /templates/xray/05_dns.json /etc/xray/conf/05_dns.json
        cp /templates/xray/06_policy.json /etc/xray/conf/06_policy.json
        cp /templates/xray/z_direct_outbound.json /etc/xray/conf/z_direct_outbound.json
    fi
    if [ ! -f /etc/dufs/conf.yml ]; then
        mkdir -p /etc/dufs
        envsubst </templates/dufs/conf.yml >/etc/dufs/conf.yml
    fi
    if [ ! -f /v2ray/config/supervisord.conf ]; then
        envsubst </templates/supervisord.conf >/v2ray/config/supervisord.conf
    fi
}

if [ "${1#-}" = 'supervisord' -a "$(id -u)" = '0' ]; then
    createConfig
    getHTTPSCertificateWithAcme
    fail2ban-client -x start
    x-ui setting -username ${XUI_ACCOUNT} -password "${XUI_PASSWORD}" -port ${XUI_LOCAL_PORT} -webBasePath ${XUI_WEBBASEPATH}
    set "$@" -c "/v2ray/config/supervisord.conf"
fi
exec "$@"
