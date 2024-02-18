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
    if [ -f ${CERT_PATH} ] && [ -f ${KEY_PATH} ]; then
        echo "证书文件已存在"
    else
        # ${HOME}/.acme.sh/acme.sh --register-account -m ansandy@foxmail.com
        registerEmail
        if [[ -f "${HOME}/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key" && -f "$HOME/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.cer" ]]; then
            echo "cer 证书文件已存在"
        else
            ${HOME}/.acme.sh/acme.sh --issue -d ${DOMAIN} --standalone --keylength ec-256 --days ${acmeSSLDays} --server ${acmeSSLServerName} --force
        fi
        ${HOME}/.acme.sh/acme.sh --installcert -d ${DOMAIN} --fullchainpath ${CERT_PATH} --keypath /${KEY_PATH} --ecc --force
    fi
}

function createConfig() {
    export DOLLAR='$'
    export V2RAY_PORT=$((RANDOM + 10000))
    export VMESS_ID=$(cat /proc/sys/kernel/random/uuid)
    export URL_PATH=/$(head /dev/urandom | tr -dc a-z0-9 | head -c 20)/
    export GEOIP_INFO=`curl http://www.ip111.cn/ -s | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>'`
    if [ ! -f /etc/nginx/conf.d/nginx-v2ray.conf ];then
        envsubst </templates/nginx-v2ray.conf >/etc/nginx/conf.d/nginx-v2ray.conf
    fi
    if [ ! -f /etc/v2ray/v2ray-config.json ]; then
        envsubst </templates/v2ray-config.json >/etc/v2ray/v2ray-config.json
        envsubst </templates/vmess_qr.json >/etc/v2ray/vmess_qr.json
    fi
}

if [ "${1#-}" = 'supervisord' -a "$(id -u)" = '0' ]; then
    createConfig
    getHTTPSCertificateWithAcme
    set "$@" -c "/v2ray/config/supervisord.conf"
fi
exec "$@"
