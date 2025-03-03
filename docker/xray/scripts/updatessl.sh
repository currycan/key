#!/usr/bin/env bash

set -eou pipefail

function checkZerosslEAB(){
    if [[ ! -n "${ZEROSSL_EAB_ID}" ]] || [[ ! -n "${ZEROSSL_EAB_KEY}" ]];then
        echo "ZerosslEAB 变量为空!!"
        exit 1
    fi
}

function checkGoogleEAB(){
    if [[ ! -n "${GOOGLE_EAB_ID}" ]] || [[ ! -n "${GOOGLE_EAB_KEY}" ]];then
        echo "GoogleEAB 变量为空!!"
        exit 1
    fi
}

function registerEmail() {
    local server_name="${ACMESH_SERVER_NAME}"
    local email="${ACMESH_REGISTER_EMAIL}"

    # 设置默认 CA
    acme.sh --set-default-ca --server "${server_name}"

    case "${server_name}" in
        buypass )
            acme.sh --register-account --accountemail "${email}"
            ;;
        # https://github.com/acmesh-official/acme.sh/wiki/ZeroSSL.com-CA
        zerossl )
            # ZeroSSL 需要 EAB 认证
            checkZerosslEAB
            acme.sh --register-account -m "${email}" \
                --eab-kid "${ZEROSSL_EAB_ID}" \
                --eab-hmac-key "${ZEROSSL_EAB_KEY}"
            ;;
        # 请先按照如下链接申请 google Public CA  https://hostloc.com/thread-993780-1-1.html
        # 具体可参考 https://github.com/acmesh-official/acme.sh/wiki/Google-Trust-Services-CA
        # https://console.cloud.google.com/?cloudshell=true&hl=zh-cn
        # EAB 有效期只有 7天
        google )
            # Google Trust Services 需要 EAB 认证
            checkGoogleEAB
            email=${GOOGLE_EMAIL}
            acme.sh --register-account -m "${email}" \
                --eab-kid "${GOOGLE_EAB_ID}" \
                --eab-hmac-key "${GOOGLE_EAB_KEY}"
            ;;
        letsencrypt )
            acme.sh --register-account -m "${email}"
            ;;
        * )
            # 错误处理标准化
            echo "错误：无效的 ACMESH_SERVER_NAME 配置" >&2
            echo "可用选项: [buypass/zerossl/google/letsencrypt]" >&2
            return 1
            ;;
    esac

    # 添加执行状态检查
    if [[ $? -ne 0 ]]; then
        echo "账户注册失败" >&2
        return 1
    fi
}

# https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_cf
function setDnsApi() {
    # 转换为小写避免大小写敏感问题
    local dns_api="${DNS_API,,}"

    case "$dns_api" in
        ali)
            # 检查必要环境变量是否存在
            if [[ -z "${ALI_KEY}" || -z "${ALI_SECRET}" ]]; then
                echo "错误：使用阿里云DNS需要配置 ALI_KEY 和 ALI_SECRET 环境变量"
                exit 1
            fi

            export Ali_Key="${ALI_KEY}"
            export Ali_Secret="${ALI_SECRET}"
            export DnsProvider="dns_ali"
            ;;
        cf)
            # 检查必要环境变量是否存在
            if [[ -z "${CF_KEY}" || -z "${CF_EMAIL}" ]]; then
                echo "错误：使用Cloudflare DNS需要配置 CF_KEY 和 CF_EMAIL 环境变量"
                exit 1
            fi

            export CF_Key="${CF_KEY}"
            export CF_Email="${CF_EMAIL}"
            export DnsProvider="dns_cf"
            ;;
        *)
            # 显示当前错误值并退出
            echo "错误：DNS_API 配置错误，当前值为 '${DNS_API}'，请从 [ali/cf] 中选择"
            exit 1
            ;;
    esac
}

function normalHTTPSCertificateWithAcme() {
    if [ -f ${SSL_PATH}/${DOMAIN}.crt ] && [ -f ${SSL_PATH}/${DOMAIN}.key ]; then
        echo "证书文件已存在"
    else
        registerEmail
        export DNS_API=ali
        setDnsApi
        acme.sh --issue --dns ${DnsProvider} -d ${DOMAIN} -d *.${DOMAIN}
        acme.sh --install-cert -d ${DOMAIN} -d *.${DOMAIN} \
            --key-file "${SSL_PATH}/${DOMAIN}.key" \
            --fullchain-file "${SSL_PATH}/${DOMAIN}.crt" \
            --ca-file "${SSL_PATH}/${DOMAIN}-ca.crt"
            # --reloadcmd "nginx -t && nginx -s stop"
        # nginx -t && nginx -s reload
    fi
}

function cdnHTTPSCertificateWithAcme() {
    if [ -f ${SSL_PATH}/${CDNDOMAIN}.crt ] && [ -f ${SSL_PATH}/${CDNDOMAIN}.key ]; then
        echo "证书文件已存在"
    else
        registerEmail
        export DNS_API=cf
        setDnsApi
        acme.sh --issue --dns ${DnsProvider} -d ${CDNDOMAIN} -d *.${CDNDOMAIN}
        acme.sh --install-cert -d ${CDNDOMAIN} -d *.${CDNDOMAIN} \
            --key-file "${SSL_PATH}/${CDNDOMAIN}.key" \
            --fullchain-file "${SSL_PATH}/${CDNDOMAIN}.crt" \
            --ca-file "${SSL_PATH}/${CDNDOMAIN}-ca.crt"
            # --reloadcmd "nginx -t && nginx -s stop"
        # nginx -t && nginx -s reload
    fi
}
