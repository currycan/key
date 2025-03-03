#!/usr/bin/env bash

set -eou pipefail

# 证书类型映射表 (类型: [域名变量名,DNS服务商])
declare -A CERT_TYPE_MAP=(
    ["normal"]="DOMAIN ali"
    ["cdn"]="CDNDOMAIN cf"
)

function registerAccount() {
    local server_name="${ACMESH_SERVER_NAME}"
    local email="${ACMESH_REGISTER_EMAIL:-}"

    # 设置默认CA并检查协议版本
    acme.sh --set-default-ca --server "${server_name}"

    case "${server_name}" in
        buypass | letsencrypt)
            acme.sh --register-account -m "${email}"
            ;;
        zerossl | google)
            local eab_args=()
            [[ "${server_name}" == "google" ]] && email="${GOOGLE_EMAIL:-$email}"
            eab_args+=("--eab-kid" "${server_name^^}_EAB_ID" "--eab-hmac-key" "${server_name^^}_EAB_KEY")
            acme.sh --register-account -m "${email}" "${eab_args[@]}"
            ;;
        *)
            echo "错误：不支持的CA服务商 '${server_name}'" >&2
            echo "可用选项: buypass/zerossl/google/letsencrypt" >&2
            exit 1
            ;;
    esac
}

function setDnsApi() {
    local dns_api="${DNS_API,,}"
    case "$dns_api" in
        ali)
            [[ -z "${ALI_KEY}" || -z "${ALI_SECRET}" ]] && {
                echo "错误：阿里云DNS需要 ALI_KEY 和 ALI_SECRET" >&2
                exit 1
            }
            export Ali_Key="$ALI_KEY" Ali_Secret="$ALI_SECRET" DnsProvider="dns_ali"
            ;;
        cf)
            [[ -z "${CF_KEY}" || -z "${CF_EMAIL}" ]] && {
                echo "错误：Cloudflare需要 CF_KEY 和 CF_EMAIL" >&2
                exit 1
            }
            export CF_Key="$CF_KEY" CF_Email="$CF_EMAIL" DnsProvider="dns_cf"
            ;;
        *)
            echo "错误：不支持的DNS服务商 '$dns_api'" >&2
            exit 1
            ;;
    esac
}

function issueCertificate() {
    local cert_type=$1
    [[ -z "${CERT_TYPE_MAP[$cert_type]}" ]] && {
        echo "错误：无效证书类型 '$cert_type'" >&2
        exit 1
    }

    # 解析域名和DNS配置
    IFS=' ' read -r domain_var dns_provider <<< "${CERT_TYPE_MAP[$cert_type]}"
    local domain="${!domain_var}"
    local cert_file="${SSL_PATH}/${domain}.crt"

    # 跳过已存在的证书
    [[ -f "$cert_file" && -f "${SSL_PATH}/${domain}.key" ]] && {
        echo "证书已存在: $domain"
        return 0
    }

    registerAccount
    export DNS_API="$dns_provider"
    setDnsApi

    # 动态构建域名参数（buypass不支持通配符）
    local domains=("-d" "$domain")
    if [[ "$ACMESH_SERVER_NAME" != "buypass" ]]; then
        domains+=("-d" "*.$domain")
    fi

    # 申请并安装证书
    acme.sh --issue --dns "$DnsProvider" "${domains[@]}" || {
        echo "证书申请失败: $domain" >&2
        exit 1
    }

    acme.sh --install-cert -d "$domain" \
        --key-file "${SSL_PATH}/${domain}.key" \
        --fullchain-file "$cert_file" \
        --ca-file "${SSL_PATH}/${domain}-ca.crt"
}
