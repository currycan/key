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
log() {
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
check_required_env() {
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

# 生成DH参数
setup_dhparam() {
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

# 生成随机字符串
generate_random() {
    local type=$1
    local length=${2:-12}
    local charset

    case $type in
        "port") shuf -i 32000-38000 -n 1 ;;
        "uuid") xray uuid ;;
        "password")
            charset='A-Za-z0-9!@#%^&*()_+{}|:<>?='
            LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$length"
            ;;
        "path")
            charset='a-z0-9'
            LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$length"
            ;;
    esac
}

# 生成环境变量
generate_env() {
    local env_file="/xray/config/.env/xray"

    if [ ! -f "$env_file" ]; then
        log INFO "Generating environment variables..."

        # 生成X25519密钥
        gen_x25519_key() {
            log DEBUG "Generating Xray x25519 key"
            local x25519_reality_xhttp_secret=$(xray x25519)
            echo "$(echo "${x25519_reality_xhttp_secret}" | head -1 | awk '{print $3}') $(echo "${x25519_reality_xhttp_secret}" | tail -n 1 | awk '{print $3}')"
        }

        local reality_private_key reality_public_key
        read -r reality_private_key reality_public_key <<<$(gen_x25519_key)
        local reality_xhttp_private_key reality_xhttp_public_key
        read -r reality_private_key reality_public_key <<<$(gen_x25519_key)

        # # 获取地理位置信息
        log DEBUG "Generating geographical location information"
        local geo_output=$(curl -fsSL --max-time 10 --retry 2 http://www.ip111.cn/ | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>')

        # 生成随机参数
        declare -A config=(
            ["XUI_LOCAL_PORT"]=$(generate_random port)
            ["DUFS_PORT"]=$(generate_random port)
            ["PASSWORD"]=$(generate_random password 16)
            ["XRAY_REALITY_UUID"]=$(generate_random uuid)
            ["XRAY_REALITY_PRIVATE_KEY"]=${reality_private_key}
            ["XRAY_REALITY_PUBLIC_KEY"]=${reality_public_key}
            ["XRAY_REALITY_SHORTID"]=$(openssl rand -hex 8)
            ["XRAY_XHTTP_UUID"]=$(generate_random uuid)
            ["XRAY_XHTTP_URL_PATH"]=$(generate_random path 20)
            # ["XRAY_REALITY_XHTTP_UUID"]=$(generate_random uuid)
            # ["XRAY_REALITY_XHTTP_URL_PATH"]=$(generate_random path 20)
            # ["XRAY_REALITY_XHTTP_PRIVATE_KEY"]=${reality_xhttp_private_key}
            # ["XRAY_REALITY_XHTTP_PUBLIC_KEY"]=${reality_xhttp_public_key}
            # ["XRAY_REALITY_XHTTP_SHORTID"]=$(openssl rand -hex 8)
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
    local secret_file="/xray/config/.env/secret"
    if [ ! -f "$secret_file" ]; then
        check_required_env DECODE
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
create_config() {
    log INFO "Creating configurations..."
    source "/xray/config/.env/xray"
    source "/xray/config/.env/secret"

    # 生成Nginx配置
    export DOLLAR='$'
    if [ ! -f /etc/nginx/conf.d/http.conf ]; then
        mkdir -p /etc/nginx/conf.d/
        log DEBUG "Generating Nginx http.conf"
        envsubst </templates/nginx/http.conf >/etc/nginx/conf.d/http.conf
    fi
    if [ ! -f /etc/nginx/stream.d/tcp.conf ]; then
        mkdir -p /etc/nginx/stream.d/
        log DEBUG "Generating Nginx tcp.conf"
        envsubst </templates/nginx/tcp.conf >/etc/nginx/stream.d/tcp.conf
    fi

    # 生成Xray配置
    if [ ! -d "/etc/xray/conf" ]; then
        mkdir -p "/etc/xray/conf"
        for template in /templates/xray/*.json; do
            local output="/etc/xray/conf/$(basename "$template")"
            log DEBUG "Generating $output"
            envsubst <"$template" >"$output"
        done
    fi

    # 生成Dufs配置
    if [ ! -f "/etc/dufs/conf.yml" ]; then
        mkdir -p "/etc/dufs"
        log DEBUG "Generating Dufs config"
        envsubst <"/templates/dufs/conf.yml" >"/etc/dufs/conf.yml"
    fi
}

# 主执行流程
if [ "${1#-}" = 'supervisord' ] && [ "$(id -u)" = '0' ]; then
    generate_env
    create_config
    setup_dhparam

    log INFO "Obtaining SSL certificate..."
    check_required_env ACMESH_REGISTER_EMAIL
    source "/scripts/updatessl.sh"
    normalHTTPSCertificateWithAcme
    cdnHTTPSCertificateWithAcme

    log INFO "Initializing X-UI..."
    x-ui setting -username "${XUI_ACCOUNT}" -password "${PASSWORD}" -port "${XUI_LOCAL_PORT}" -webBasePath "${XUI_WEBBASEPATH}"

    log INFO "Starting fail2ban..."
    fail2ban-client -x start

    [[ ! -f "/usr/local/bin/show" ]] && ln -sf "/scripts/show-config.sh" "/usr/local/bin/show"

    set -- "$@" -n -c "/xray/config/supervisord.conf"
fi

exec "$@"
