#!/usr/bin/env bash

set -eou pipefail

# 颜色定义（仅在终端生效）
if [ -t 1 ]; then
    RED='\033[1;31m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[1;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# 日志记录函数
function log() {
    local level=$1
    shift
    local msg=$*
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local color=""

    case $level in
    INFO) color="${GREEN}" ;;
    WARN) color="${YELLOW}" ;;
    ERROR) color="${RED}" ;;
    DEBUG) color="${CYAN}" ;;
    *) color="${NC}" ;;
    esac

    echo -e "${color}[${timestamp}] [${level}] ${msg}${NC}" >&2
}

# 检查必要环境变量
function checkRequiredEnv() {
    local missing_vars=()

    # 遍历所有传入的参数作为变量名
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        log ERROR "Missing required environment variables: ${missing_vars[*]}"
        exit 1
    fi
}

detect_ip_strategy_api() {
    log DEBUG "Getting IP strategy..."
    local IS_IPV4=""
    local IS_IPV6=""

    # IPv4 检测
    if curl -4 --connect-timeout 2 -s https://api.ip.sb/ip >/dev/null; then
        IS_IPV4="yes"
    fi
    # IPv6 检测
    if curl -6 --connect-timeout 2 -s https://api.ip.sb/ip >/dev/null; then
        IS_IPV6="yes"
    fi

    if [[ "$IS_IPV4" == "yes" && "$IS_IPV6" == "yes" ]]; then
        echo prefer_ipv4
    elif [[ "$IS_IPV6" == "yes" ]]; then
        echo ipv6_only
    else
        echo ipv4_only
    fi
}

# 检测 ChatGPT 可用性函数
# 返回值：
#   direct   -> 直连可用
#   warp-ep  -> 需要代理
check_chatgpt_access() {
    log DEBUG "Checking chatgpt accessibility..."
    local CURL_OPTS=(
        --max-time 2
        --retry 2
        --retry-delay 1
        --retry-connrefused
        -sSL
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    )

    # ===== API 检测 =====
    local API_URL="https://api.openai.com/compliance/cookie_requirements"
    local API_HEADERS=(
        -H "Authorization: Bearer null"
        -H "Accept: */*"
        -H "Origin: https://platform.openai.com"
        -H "Referer: https://platform.openai.com/"
    )
    local CHECK_RESULT
    CHECK_RESULT=$(curl "${CURL_OPTS[@]}" "${API_HEADERS[@]}" "$API_URL")

    if [[ -z "$CHECK_RESULT" ]] || grep -qi "unsupported_country" <<< "$CHECK_RESULT"; then
        log WARN "ChatGPT access requires proxy (warp-ep)"
        echo "warp-ep"
    else
        echo "direct"
    fi
}

# 生成随机字符串
function generateRandomStr() {
    local type=$1
    local length=${2:-12}
    local charset

    case $type in
        "port") shuf -i 32000-38000 -n 1 ;;
        "uuid") xray uuid ;;
        "password")
            # charset='A-Za-z0-9!@#%^&*()_+{}|:<>?='
            charset='A-Za-z0-9'
            LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$length"
            ;;
        "path")
            charset='a-z0-9'
            LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$length"
            ;;
    esac
}

function decryptSecretsEnv() {
    # 解密密钥文件
    local secret_file="/.env/secret"
    mkdir -p "$(dirname "${secret_file}")"

    if [ ! -f "$secret_file" ]; then
        checkRequiredEnv DECODE
        log INFO "Downloading encrypted secrets..."

        if ! curl -fsSLo /tmp/tmp.bin "https://raw.githubusercontent.com/currycan/key/master/tmp.bin"; then
            log ERROR "Failed to download secret file"
            exit 1
        fi

        if ! crypctl decrypt -i /tmp/tmp.bin -o "$secret_file" -k "${DECODE}"; then
            log ERROR "Secret decryption failed, check DECODE environment variable"
            exit 1
        fi
        rm -f /tmp/tmp.bin
        log INFO "Secrets decrypted successfully"
    fi
}

# 生成环境变量
function generateEnv() {
    local env_file="/.env/xray"
    mkdir -p "$(dirname "${env_file}")"

    if [ ! -f "${env_file}" ]; then
        log INFO "Generating environment variables..."

        # 生成X25519密钥
        gen_x25519_key() {
            log DEBUG "Generating Xray x25519 key"
            local x25519_reality_xhttp_secret=$(xray x25519)
            echo "$(echo "${x25519_reality_xhttp_secret}" | sed -n '1p' | awk -F': ' '{print $2}') $(echo "${x25519_reality_xhttp_secret}" | sed -n '2p' | awk -F': ' '{print $2}')"
        }

        local reality_private_key reality_public_key
        read -r reality_private_key reality_public_key <<<$(gen_x25519_key)

        # 生成mlkem768加密密钥
        gen_mlkem768_secret() {
            log DEBUG "Generating Xray mlkem768 key"
            local mlkem768_secret=$(xray mlkem768)
            echo "$(echo "${mlkem768_secret}" | sed -n '1p' | awk -F': ' '{print $2}') $(echo "${mlkem768_secret}" | sed -n '2p' | awk -F': ' '{print $2}')"
        }

        local mlkem768_seed mlkem768_client
        read -r mlkem768_seed mlkem768_client <<<$(gen_mlkem768_secret)

        # # 获取地理位置信息
        log DEBUG "Generating geographical location information"
        local geo_output=$(curl -fsSL --max-time 10 --retry 2 https://ip111.cn/ | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>')

        # 检查系统是否已经安装 tcp-brutal
        log DEBUG "Checking brutal module"
        is_brutal=false
        if [ -d "/sys/module/brutal" ]; then
            is_brutal=true
        else
            log WARN "brutal module not detected, Xray XTLS Brutal will not be available"
        fi

        # 生成随机参数
        declare -A config=(
            ["XUI_LOCAL_PORT"]=$(generateRandomStr port)
            ["DUFS_PORT"]=$(generateRandomStr port)
            ["PASSWORD"]=$(generateRandomStr password 16)
            ["XRAY_UUID"]=$(generateRandomStr uuid)
            ["XRAY_MLKEM768_SEED"]=${mlkem768_seed}
            ["XRAY_MLKEM768_CLIENT"]=${mlkem768_client}
            ["XRAY_REALITY_PRIVATE_KEY"]=${reality_private_key}
            ["XRAY_REALITY_PUBLIC_KEY"]=${reality_public_key}
            ["XRAY_REALITY_SHORTID"]=$(openssl rand -hex 8)
            ["XRAY_URL_PATH"]=$(generateRandomStr path 32)
            ["GEOIP_INFO"]=${geo_output}
            ["IS_BRUTAL"]=${is_brutal}
            ["CHATGPT_OUT"]=$(check_chatgpt_access)
            ["STRATEGY"]=$(detect_ip_strategy_api)
            ["SB_UUID"]=$(generateRandomStr uuid)
            ["PORT_HYSTERIA2"]=$(generateRandomStr port)
            ["PORT_TUIC"]=$(generateRandomStr port)
            ["PORT_ANYTLS"]=$(generateRandomStr port)
        )

        # 写入文件
        log INFO "Environment file generated"
        for key in "${!config[@]}"; do
            echo "export $key='${config[$key]}'" >>"${env_file}"
        done
    fi
}

# 生成配置文件
function createConfig() {
    log INFO "Creating configurations..."

    # 提取所有环境变量名，生成用于envsubst的变量列表
    ENV_LIST=$(env | grep -v '^_' | cut -d= -f1 | sed 's/^/${/;s/$/}/' | xargs)

    # 生成Supervisord配置
    log DEBUG "Generating supervisord /etc/supervisord.conf"
    envsubst </templates/supervisord/supervisord.conf >/etc/supervisord.conf
    mkdir -p /etc/supervisor.d/
    log DEBUG "Generating supervisord /etc/supervisor.d/daemon.ini"
    envsubst </templates/supervisord/daemon.ini >/etc/supervisor.d/daemon.ini

    # 生成Nginx配置
    log DEBUG "Generating Nginx nginx.conf"
    envsubst "${ENV_LIST}" </templates/nginx/nginx.conf >/etc/nginx/nginx.conf
    cp -f /templates/nginx/network_internal.conf /etc/nginx/network_internal.conf
    mkdir -p /etc/nginx/conf.d/
    log DEBUG "Generating Nginx http.conf"
    export RANDOM_NUM=$(shuf -i 0-9 -n 1)
    envsubst "${ENV_LIST} \${RANDOM_NUM}" </templates/nginx/http.conf >/etc/nginx/conf.d/http.conf
    mkdir -p /etc/nginx/stream.d/
    log DEBUG "Generating Nginx tcp.conf"
    envsubst "${ENV_LIST}" </templates/nginx/tcp.conf >/etc/nginx/stream.d/tcp.conf

    # 生成Xray配置
    mkdir -p "${WORKDIR}/xray/"
    for template in /templates/xray/*.json; do
        output="${WORKDIR}/xray/$(basename "$template")"
        log DEBUG "Generating $output"
        envsubst <"$template" >"$output"
    done

    # 生成Sing-box配置
    mkdir -p "${WORKDIR}/sing-box/"
    for template in /templates/sing-box/*.json; do
        local output="${WORKDIR}/sing-box/$(basename "$template")"
        log DEBUG "Generating $output"
        envsubst <"$template" >"$output"
    done

    # 生成Dufs配置
    mkdir -p "${WORKDIR}/dufs"
    log DEBUG "Generating Dufs config"
    envsubst <"/templates/dufs/conf.yml" >"${WORKDIR}/dufs/conf.yml"
}

# 配置 nginx dhparam 证书
function setupDhParam() {
    local dhparam_path="/etc/nginx/dhparam/dhparam.pem"

    if [ ! -f "$dhparam_path" ]; then
        log INFO "Generating DH parameters..."
        mkdir -p "$(dirname "$dhparam_path")"

        if ! openssl dhparam -dsaparam -out "$dhparam_path" 4096; then
            log ERROR "Failed to generate DH parameters"
            exit 1
        fi
        log INFO "DH parameters generated successfully"
    fi
}

# https://github.com/acmesh-official/acme.sh/wiki/ZeroSSL.com-CA
function registerAccount() {
    checkRequiredEnv "ACMESH_SERVER_NAME" "ACMESH_REGISTER_EMAIL"
    log INFO "Set default server: ${ACMESH_SERVER_NAME}"
    acme.sh --set-default-ca --server "${ACMESH_SERVER_NAME}"
    log INFO "Registering account: ${ACMESH_REGISTER_EMAIL}"
    acme.sh --register-account -m "${ACMESH_REGISTER_EMAIL}"
}

# DNS服务商配置
function setDnsApi() {
    local dns_api=$1

    case "${dns_api}" in
        ali)
            checkRequiredEnv "ALI_KEY" "ALI_SECRET"
            export Ali_Key="${ALI_KEY}" Ali_Secret="${ALI_SECRET}"
            export DNS_PROVIDER="dns_ali"
            ;;
        cf)
            checkRequiredEnv "CF_TOKEN" "CF_ZONE_ID" "CF_ACCOUNT_ID"
            export CF_Token="${CF_TOKEN}" CF_Zone_ID="${CF_ZONE_ID}" CF_Account_ID="${CF_ACCOUNT_ID}"
            export DNS_PROVIDER="dns_cf"
            ;;
        *)
            log ERROR "错误：不支持的DNS服务商 '${dns_api}'" >&2
            exit 1
            ;;
    esac
}

# https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_cf
function issueCertificate() {
    local cert_type=$1

    [[ -z "${CERT_TYPE_MAP[${cert_type}]}" ]] && {
        log ERROR "错误：无效证书类型 '${cert_type}'" >&2
        exit 1
    }

    # 解析域名和DNS配置
    IFS=' ' read -r domain_var dns_provider <<< "${CERT_TYPE_MAP[${cert_type}]}"
    local domain="${!domain_var}"

    local cert_file="${SSL_PATH}/${domain}.crt"
    local key_file="${SSL_PATH}/${domain}.key"
    local ca_file="${SSL_PATH}/${domain}-ca.crt"

    # 申请证书并安装
    if [[ -f "${cert_file}" && -f "${key_file}" && -f "${ca_file}" ]];then
        log INFO "证书已存在: ${domain}"
    else
        if ls /acmecerts/${domain}*/${domain}.key >/dev/null 2>&1; then
            log INFO "acme ${domain} 证书已申请完成"
        else
            # 配置调试模式
            export DEBUG=${ACMESH_DEBUG}

            registerAccount
            setDnsApi ${dns_provider}

            # 动态构建域名参数（buypass不支持通配符）
            local domains=("-d" "${domain}")
            if [[ "${ACMESH_SERVER_NAME}" == "letsencrypt" ]]; then
                domains+=("-d" "*.${domain}")
            fi
            # 申请证书
            acme.sh --issue --dns "${DNS_PROVIDER}" "${domains[@]}"
        fi
        # 删除 nginx 配置，避免加载证书报错
        rm -f /etc/nginx/conf.d/* /etc/nginx/stream.d/*
        # 安装证书，并配置自动更新
        acme.sh --upgrade
        acme.sh --install-cert --ecc -d "${domain}" \
            --key-file "${SSL_PATH}/${domain}.key" \
            --fullchain-file "${cert_file}" \
            --ca-file "${SSL_PATH}/${domain}-ca.crt" \
            --reloadcmd "/usr/sbin/nginx"
        /usr/sbin/nginx -s quit && rm -f var/run/nginx/nginx.pid
    fi
}

# 主执行流程
if [ "${1#-}" = 'supervisord' ] && [ "$(id -u)" = '0' ]; then
    mkdir -p ${LOGDIR}/{supervisor,xray,sing-box,dufs,nginx,x-ui}

    decryptSecretsEnv
    generateEnv
    source "/.env/secret"
    source "/.env/xray"
    cat "/.env/xray"

    log INFO "Obtaining SSL certificate..."
    # 证书类型映射表 (类型: [域名变量名,DNS服务商])
    declare -A CERT_TYPE_MAP=(
        ["normal"]="DOMAIN ali"
        ["cdn"]="CDNDOMAIN cf"
    )
    # 生成证书
    issueCertificate "normal"
    issueCertificate "cdn"

    # 生成配置文件
    createConfig

    # 创建 nginx dhparam 证书
    setupDhParam

    # 配置 x-ui
    log INFO "Initializing X-UI..."
    x-ui setting -username "${XUI_ACCOUNT}" -password "${PASSWORD}" -port "${XUI_LOCAL_PORT}" -webBasePath "${XUI_WEBBASEPATH}"

    log INFO "Starting fail2ban..."
    fail2ban-client -x start

    # 显示访问信息
    [[ ! -f "/usr/local/bin/show" ]] && ln -sf "/scripts/show-config.sh" "/usr/local/bin/show"
    /usr/local/bin/show

    set -- "$@" -n -c /etc/supervisord.conf
fi

exec "$@"
