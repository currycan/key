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
            ["SUB_STORE_FRONTEND_BACKEND_PATH"]="/$(generateRandomStr path 16)"
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

# 动态生成 ISP SOCKS5 出站配置
function generateIspSocks5Config() {
    export SB_SOCKS5_OUTBOUND_CONFIG="" # Ensure empty var is exported for template safety

    # 检查开关是否开启 (默认关闭)
    if [[ "${ENABLE_ISP_PROXY}" != "true" ]]; then
        log INFO "ISP Proxy feature disabled (ENABLE_ISP_PROXY=${ENABLE_ISP_PROXY}), skipping ISP SOCKS5 generation."
        export CUSTOM_OUTBOUNDS=""
        export SB_CUSTOM_OUTBOUNDS=""
        return
    fi

    local default_outbound=""
    local default_sb_outbound=""
    local other_outbounds=""
    local other_sb_outbounds=""

    # 获取所有以 _ISP_IP 结尾的变量名
    for var in $(compgen -v | grep "_ISP_IP$"); do
        prefix=${var%_IP} # 获取前缀，如 LA_ISP

        # 读取对应变量值
        s5_ip="${!var}"
        s5_port_var="${prefix}_PORT"
        s5_user_var="${prefix}_USER"
        s5_pass_var="${prefix}_SECRET"

        s5_port="${!s5_port_var}"
        s5_user="${!s5_user_var}"
        s5_pass="${!s5_pass_var}"

        if [ -n "$s5_ip" ] && [ -n "$s5_port" ]; then
            log INFO "Found Custom Proxy: ${prefix} -> $s5_ip:$s5_port"

            # 使用 lower case prefix 作为 tag 的一部分
            tag_suffix=$(echo "${prefix}" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
            tag_name="proxy-${tag_suffix}"

            # 构建 JSON 对象 (Xray)
            proxy_json="{\"tag\": \"${tag_name}\", \"protocol\": \"socks\", \"settings\": {\"servers\": [{\"address\": \"$s5_ip\", \"port\": $s5_port, \"users\": [{\"user\": \"$s5_user\", \"pass\": \"$s5_pass\"}]}]}},"

            # 构建 JSON 对象 (Sing-box)
            # Sing-box tag naming: use same tag for consistency? Yes.
            sb_proxy_json="{\"type\": \"socks\", \"tag\": \"${tag_name}\", \"server\": \"$s5_ip\", \"server_port\": $s5_port, \"username\": \"$s5_user\", \"password\": \"$s5_pass\"},"

            # 检查是否为默认出站
            if [ -n "${DEFAULT_ISP:-}" ] && [ "$prefix" == "$DEFAULT_ISP" ]; then
                log INFO "Setting ${prefix} as DEFAULT outbound."
                default_outbound="${proxy_json}"
                default_sb_outbound="${sb_proxy_json}"
            else
                other_outbounds="${other_outbounds}${proxy_json}"
                other_sb_outbounds="${other_sb_outbounds}${sb_proxy_json}"
            fi
        else
            log WARN "Incomplete config for ${prefix}, skipping..."
        fi
    done

    # 将默认出站放入最前
    export CUSTOM_OUTBOUNDS="${default_outbound}${other_outbounds}"
    export SB_CUSTOM_OUTBOUNDS="${default_sb_outbound}${other_sb_outbounds}"
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

# https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_cf
function issueCertificate() {

    local cert_name="$1"      # 参数 1: 证书任务标识名 (如: my_sites_bundle)
    local domain_params=$2    # 配置字符串 (如: "example.com:dns_ali|example.io:dns_cf")

    # 1. 提取第一个域名作为 acme.sh 的内部索引 ID
    local first_domain="${domain_params%%:*}"

    # 2. 定义基于 cert_name 的标准路径
    local cert_file="${SSL_PATH}/${cert_name}.crt"
    local key_file="${SSL_PATH}/${cert_name}.key"
    local ca_file="${SSL_PATH}/${cert_name}-ca.crt"

    # 3. 检查证书是否已存在
    if [[ -f "${cert_file}" && -f "${key_file}" && -f "${ca_file}" ]];then
        log INFO "证书任务 [$cert_name] 已存在，跳过申请阶段。"
        return 0
    fi

    # 4. 检查 acme.sh 内部数据库缓存
    if ! acme.sh --list | grep -q "${first_domain}"; then
        log INFO "未检测到缓存，开始执行任务 [$cert_name] 的新证书申请..."
        checkRequiredEnv "ACMESH_SERVER_NAME" "ACMESH_REGISTER_EMAIL" "ALI_KEY" "ALI_SECRET" "CF_TOKEN" "CF_ZONE_ID" "CF_ACCOUNT_ID"
        # 配置调试模式
        export DEBUG=${ACMESH_DEBUG:-0}
        # 导出 API 密钥环境
        export Ali_Key="${ALI_KEY}" Ali_Secret="${ALI_SECRET}" CF_Token="${CF_TOKEN}" CF_Zone_ID="${CF_ZONE_ID}" CF_Account_ID="${CF_ACCOUNT_ID}"
        log INFO "Set default server: ${ACMESH_SERVER_NAME}"
        acme.sh --set-default-ca --server "${ACMESH_SERVER_NAME}"
        log INFO "Registering account: ${ACMESH_REGISTER_EMAIL}"
        acme.sh --register-account -m "${ACMESH_REGISTER_EMAIL}"
        # 动态构建 acme.sh 参数数组
        local _args=("--issue" "--ecc" "--server" "${ACMESH_SERVER_NAME:-letsencrypt}")
        # 解析 domain_params
        IFS='|' read -ra ENTRIES <<< "$domain_params"
        for entry in "${ENTRIES[@]}"; do
            local _dom="${entry%%:*}"
            local _prov="${entry#*:}"
            # 添加域名本身
            _args+=("-d" "${_dom}" "--dns" "${_prov}")
            # 自动添加通配符 (仅限 LetsEncrypt 且排除 IP 格式)
            if [[ "${ACMESH_SERVER_NAME}" == "letsencrypt" && ! "${_dom}" =~ ^[0-9.]+$ ]]; then
                _args+=("-d" "*.${_dom}" "--dns" "${_prov}")
            fi
        done
        # 执行申请
        log DEBUG "执行命令: acme.sh ${_args[*]}"
        acme.sh "${_args[@]}" || { log ERROR "任务 [$cert_name] 申请失败"; return 1; }
    fi

    # 5. 安装/部署阶段
    log WARN "正在清理旧 Nginx 配置并安装证书文件: ${cert_name}"
    # 清理现有的 Nginx 配置目录，防止路径报错
    rm -f /etc/nginx/conf.d/* /etc/nginx/stream.d/*
    # 安装证书并配置 Nginx 重启逻辑
    acme.sh --upgrade
    acme.sh --install-cert --ecc -d "${first_domain}" \
        --key-file       "${key_file}" \
        --fullchain-file "${cert_file}" \
        --ca-file        "${ca_file}" \
        --reloadcmd "/usr/sbin/nginx"
    /usr/sbin/nginx -s quit && rm -f var/run/nginx/nginx.pid
    log INFO "证书任务 [$cert_name] 部署成功。"
}

# 主执行流程
if [ "${1#-}" = 'supervisord' ] && [ "$(id -u)" = '0' ]; then
    mkdir -p ${LOGDIR}/{supervisor,xray,sing-box,dufs,nginx,x-ui,s-ui}
    mkdir -p "${SUI_DB_FOLDER}"
    mkdir -p "${SUB_STORE_DATA_BASE_PATH}"

    decryptSecretsEnv
    generateEnv
    source "/.env/secret"
    source "/.env/xray"
    cat "/.env/xray"

    log INFO "Obtaining SSL certificate..."
    # 生成证书
    issueCertificate "sb_xray_bundle" "${DOMAIN}:dns_ali|${CDNDOMAIN}:dns_cf"
    # 创建 nginx dhparam 证书
    setupDhParam

    log INFO "Updating GeoIP and GeoSite databases..."
    /scripts/geo_update.sh

    # 动态生成 ISP SOCKS5 出站配置
    log INFO "Generating ISP SOCKS5 outbounds..."
    generateIspSocks5Config

    # 生成配置文件
    createConfig

    # 配置 x-ui
    log INFO "Initializing X-UI..."
    x-ui setting -username "${PUBLIC_USER}" -password "${PUBLIC_PASSWORD}" -port "${XUI_LOCAL_PORT}" -webBasePath "${XUI_WEBBASEPATH}"

    # 配置 s-ui
    log INFO "Initializing S-UI..."
    sui setting -port "${SUI_PORT}" -subPort "${SUI_SUB_PORT}" -path "/${SUI_WEBBASEPATH}" -subPath "/${SUI_SUB_PATH}"
    sui admin -password "${PUBLIC_PASSWORD}" -username "${PUBLIC_USER}"

    # 强制更新 s-ui 数据库中的 subDomain，确保订阅链接使用域名而非 IP
    # s-uiCLI 不支持 -subDomain 参数，因此直接操作数据库
    if [ -f "${SUI_DB_FOLDER}/s-ui.db" ]; then
        log INFO "Updating s-ui subDomain to: ${DOMAIN}"
        # 强制设置 subURI 以覆盖默认生成的带端口 URL
        sqlite3 "${SUI_DB_FOLDER}/s-ui.db" "UPDATE settings SET value='https://${DOMAIN}/${SUI_SUB_PATH}/' WHERE key='subURI';"
    fi

    # 配置 sub-store
    log INFO "Initializing Sub-Store..."
    log INFO "Sub-Store API Path: ${SUB_STORE_FRONTEND_BACKEND_PATH}"

    log INFO "Starting fail2ban..."
    fail2ban-client -x start

    # 配置定时任务
    log INFO "Setting up cron job for geo update..."
    CRON_FILE="/var/spool/cron/crontabs/root"
    # 确保文件存在
    touch "$CRON_FILE"
    # 删除旧的 geo_update 任务（如果存在），避免重复
    sed -i '/geo_update.sh/d' "$CRON_FILE"
    # 追加新任务
    echo "0 3 * * * /scripts/geo_update.sh >> /var/log/geo_update.log 2>&1" >> "$CRON_FILE"
    chmod 0600 "$CRON_FILE"

    # 显示访问信息
    [[ ! -f "/usr/local/bin/show" ]] && ln -sf "/scripts/show-config.sh" "/usr/local/bin/show"
    /usr/local/bin/show

    set -- "$@" -n -c /etc/supervisord.conf
fi

exec "$@"
