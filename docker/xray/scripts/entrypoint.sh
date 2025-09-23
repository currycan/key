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

# 生成环境变量
function generateEnv() {
    local env_file="/.env/xray"

    if [ ! -f "$env_file" ]; then
        log INFO "Generating environment variables..."

        # 生成X25519密钥
        gen_x25519_key() {
            log DEBUG "Generating Xray x25519 key"
            local x25519_reality_xhttp_secret=$(xray x25519)
            echo "$(echo "${x25519_reality_xhttp_secret}" | sed -n '1p' | awk -F': ' '{print $2}') $(echo "${x25519_reality_xhttp_secret}" | sed -n '2p' | awk -F': ' '{print $2}')"
        }

        local reality_private_key reality_public_key
        read -r reality_private_key reality_public_key <<<$(gen_x25519_key)

        # # 获取地理位置信息
        log DEBUG "Generating geographical location information"
        local geo_output=$(curl -fsSL --max-time 10 --retry 2 http://www.ip111.cn/ | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>')

        # 生成随机参数
        declare -A config=(
            ["XUI_LOCAL_PORT"]=$(generateRandomStr port)
            ["DUFS_PORT"]=$(generateRandomStr port)
            ["PASSWORD"]=$(generateRandomStr password 16)
            ["XRAY_REALITY_UUID"]=$(generateRandomStr uuid)
            ["XRAY_REALITY_PRIVATE_KEY"]=${reality_private_key}
            ["XRAY_REALITY_PUBLIC_KEY"]=${reality_public_key}
            ["XRAY_REALITY_SHORTID"]=$(openssl rand -hex 8)
            ["XRAY_XHTTP_UUID"]=$(generateRandomStr uuid)
            ["XRAY_XHTTP_URL_PATH"]=$(generateRandomStr path 20)
            ["V2RAY_LOCAL_PORT"]=$(generateRandomStr port)
            ["V2RAY_UUID"]=$(generateRandomStr uuid)
            ["V2RAY_URL_PATH"]=$(generateRandomStr path 20)
            ["GEOIP_INFO"]=${geo_output}
        )

        # 写入文件
        mkdir -p "$(dirname "$env_file")"
        for key in "${!config[@]}"; do
            echo "export $key='${config[$key]}'" >>"$env_file"
        done
        log INFO "Environment file generated"
        cat $env_file
    fi

    # 解密密钥文件
    local secret_file="/.env/secret"
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

# 生成配置文件
function createConfig() {
    log INFO "Creating configurations..."
    source "/.env/xray"
    source "/.env/secret"

    # 提取所有环境变量名，生成用于envsubst的变量列表
    ENV_LIST=$(env | grep -v '^_' | cut -d= -f1 | sed 's/^/${/;s/$/}/' | xargs)

    # 生成Supervisord配置
    if [ ! -f /etc/supervisord.conf ]; then
        log DEBUG "Generating supervisord /etc/supervisord.conf"
        envsubst </templates/supervisord/supervisord.conf >/etc/supervisord.conf
    fi
    if [ ! -f /etc/supervisor.d/daemon.ini ]; then
        mkdir -p /etc/supervisor.d/
        log DEBUG "Generating supervisord /etc/supervisor.d/daemon.ini"
        envsubst </templates/supervisord/daemon.ini >/etc/supervisor.d/daemon.ini
    fi

    # 生成Nginx配置
    log DEBUG "Generating Nginx nginx.conf"
    envsubst "${ENV_LIST}" </templates/nginx/nginx.conf >/etc/nginx/nginx.conf
    cp -f /templates/nginx/network_internal.conf /etc/nginx/network_internal.conf
    if [ ! -f /etc/nginx/conf.d/http.conf ]; then
        mkdir -p /etc/nginx/conf.d/
        log DEBUG "Generating Nginx http.conf"
        envsubst "${ENV_LIST}" </templates/nginx/http.conf >/etc/nginx/conf.d/http.conf
    fi
    if [ ! -f /etc/nginx/stream.d/tcp.conf ]; then
        mkdir -p /etc/nginx/stream.d/
        log DEBUG "Generating Nginx tcp.conf"
        envsubst "${ENV_LIST}" </templates/nginx/tcp.conf >/etc/nginx/stream.d/tcp.conf
    fi

    # 生成Xray配置
    if [ ! -f "${WORKDIR}/xray/*.json" ]; then
        mkdir -p "${WORKDIR}/xray/"
        for template in /templates/xray/*.json; do
            local output="${WORKDIR}/xray/$(basename "$template")"
            log DEBUG "Generating $output"
            envsubst <"$template" >"$output"
        done
    fi

    # 生成V2ray配置
    if [ ! -f "${WORKDIR}/v2ray/*.json" ]; then
        mkdir -p "${WORKDIR}/v2ray/"
        envsubst </templates/v2ray/config.json >${WORKDIR}/v2ray/config.json
    fi

    # 生成Dufs配置
    if [ ! -f "${WORKDIR}/dufs/conf.yml" ]; then
        mkdir -p "${WORKDIR}/dufs"
        log DEBUG "Generating Dufs config"
        envsubst <"/templates/dufs/conf.yml" >"${WORKDIR}/dufs/conf.yml"
    fi
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

# 证书类型映射表 (类型: [域名变量名,DNS服务商])
declare -A CERT_TYPE_MAP=(
    ["normal"]="DOMAIN ali"
    ["cdn"]="CDNDOMAIN cf"
)

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
    local dns_api="${DNS_API,,}"

    case "${dns_api}" in
        ali)
            checkRequiredEnv "ALI_KEY" "ALI_SECRET"
            export Ali_Key="${ALI_KEY}" Ali_Secret="${ALI_SECRET}"
            DNS_PROVIDER="dns_ali"
            ;;
        cf)
            checkRequiredEnv "CF_TOKEN" "CF_ZONE_ID" "CF_ACCOUNT_ID"
            export CF_Token="${CF_TOKEN}" CF_Zone_ID="${CF_ZONE_ID}" CF_Account_ID="${CF_ACCOUNT_ID}"
            DNS_PROVIDER="dns_cf"
            ;;
        *)
            log ERROR "错误：不支持的DNS服务商 '${dns_api}'" >&2
            exit 1
            ;;
    esac
}

# https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_cf
function issueCertificate() {
    export DEBUG=${ACMESH_DEBUG}
    local cert_type=$1
    [[ -z "${CERT_TYPE_MAP[${cert_type}]}" ]] && {
        log ERROR "错误：无效证书类型 '${cert_type}'" >&2
        exit 1
    }

    # 解析域名和DNS配置
    IFS=' ' read -r domain_var dns_provider <<< "${CERT_TYPE_MAP[${cert_type}]}"
    local domain="${!domain_var}"
    local cert_file="${SSL_PATH}/${domain}.crt"

    # 跳过已存在的证书
    [[ -f "$cert_file" && -f "${SSL_PATH}/${domain}.key" ]] && {
        log INFO "证书已存在: ${domain}"
        return 0
    }

    registerAccount
    export DNS_API="${dns_provider}"
    setDnsApi

    # 动态构建域名参数（buypass不支持通配符）
    local domains=("-d" "${domain}")
    if [[ "${ACMESH_SERVER_NAME}" == "letsencrypt" ]]; then
        domains+=("-d" "*.${domain}")
    fi

    # 申请并安装证书
    set +e
    acme_output=$(acme.sh --issue --dns "${DNS_PROVIDER}" "${domains[@]}" 2>&1)
    exit_code=$?
    set -e
    # 根据退出码和输出内容判断是否为正常跳过
    if [[ $exit_code -ne 0 ]]; then
        if echo "$acme_output" | grep -e "Skipping. Next renewal"; then
            log INFO "证书未到期，跳过续期。"
        else
            log ERROR "证书申请失败: ${domain}" >&2
            exit 1
        fi
    fi

    acme.sh --install-cert -d "${domain}" \
        --key-file "${SSL_PATH}/${domain}.key" \
        --fullchain-file "${cert_file}" \
        --ca-file "${SSL_PATH}/${domain}-ca.crt" \
        --reloadcmd "nginx -s reload"
}

# 主执行流程
if [ "${1#-}" = 'supervisord' ] && [ "$(id -u)" = '0' ]; then
    mkdir -p ${LOGDIR}/{supervisor,xray,v2ray,dufs,nginx,x-ui}

    generateEnv
    createConfig

    setupDhParam

    log INFO "Obtaining SSL certificate..."
    checkRequiredEnv ACMESH_REGISTER_EMAIL
    # 生成证书
    issueCertificate "normal"
    sleep 5
    issueCertificate "cdn"

    log INFO "Initializing X-UI..."
    x-ui setting -username "${XUI_ACCOUNT}" -password "${PASSWORD}" -port "${XUI_LOCAL_PORT}" -webBasePath "${XUI_WEBBASEPATH}"

    log INFO "Starting fail2ban..."
    fail2ban-client -x start

    [[ ! -f "/usr/local/bin/show" ]] && ln -sf "/scripts/show-config.sh" "/usr/local/bin/show"

    set -- "$@" -n -c /etc/supervisord.conf
fi

exec "$@"
