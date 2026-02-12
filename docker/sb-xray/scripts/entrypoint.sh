#!/usr/bin/env bash
set -eou pipefail

# 颜色定义
if [ -t 1 ]; then
    RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

ENV_FILE="/.env/xray"

log() {
    local level=$1; shift
    local color="${NC}"; case $level in INFO) color="${GREEN}";; WARN) color="${YELLOW}";; ERROR) color="${RED}";; DEBUG) color="${CYAN}";; esac
    echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $*${NC}" >&2
}

# 检查必需环境变量，如有缺失则报错退出
checkRequiredEnv() {
    local missing=()
    for var in "$@"; do [ -z "${!var:-}" ] && missing+=("$var"); done
    [ ${#missing[@]} -eq 0 ] || { log ERROR "Missing required env: ${missing[*]}"; exit 1; }
}

# 检测 IP 策略 (IPv4/IPv6 优先)
detect_ip_strategy_api() {
    log DEBUG "Getting IP strategy..."
    local v4="" v6=""
    curl -4 -s --connect-timeout 2 https://api.ip.sb/ip >/dev/null && v4="yes"
    curl -6 -s --connect-timeout 2 https://api.ip.sb/ip >/dev/null && v6="yes"
    [[ "$v4" == "yes" && "$v6" == "yes" ]] && echo prefer_ipv4 && return
    [[ "$v6" == "yes" ]] && echo ipv6_only && return
    echo ipv4_only
}

# 检测 ChatGPT 访问状态
check_chatgpt_access() {
    log DEBUG "Checking ChatGPT..."
    local check_rs
    check_rs=$(curl -sSL --max-time 2 --retry 2 -A "Mozilla/5.0" \
        -H "Authorization: Bearer null" -H "Referer: https://platform.openai.com/" \
        "https://api.openai.com/compliance/cookie_requirements")
    if [[ -z "$check_rs" ]] || grep -qi "unsupported_country" <<< "$check_rs"; then
        log WARN "ChatGPT access requires proxy (ISP_TAG=${ISP_TAG:-empty})"
        if [ -n "${ISP_TAG:-}" ]; then
            echo "${ISP_TAG}"
        else
            echo "direct"
        fi
    else
        echo "direct"
    fi
}

# 检测 Netflix 访问状态
check_netflix_access() {
    log DEBUG "Checking Netflix..."
    local check_rs
    # Netflix 通过 curl 检测比较困难，普通的 403 或 fast.com 无法验证地理封锁。
    check_rs=$(curl -I -s -L --max-time 3 --retry 2 -A "Mozilla/5.0" "https://www.netflix.com/title/81249783" 2>/dev/null | head -n 1 | awk '{print $2}')
    if [[ "$check_rs" =~ ^2 ]] || [[ "$check_rs" =~ ^3 ]]; then
        echo "direct"
    else
        log WARN "Netflix access might be restricted ($check_rs)"
        if [ -n "${ISP_TAG:-}" ]; then
            echo "${ISP_TAG}"
        else
            echo "direct"
        fi
    fi
}

# 检测 Disney+ 访问状态
check_disney_access() {
    log DEBUG "Checking Disney+..."
    local check_rs
    check_rs=$(curl -I -s -L --max-time 3 --retry 2 -A "Mozilla/5.0" "https://www.disneyplus.com/" 2>/dev/null | head -n 1 | awk '{print $2}')
    if [[ "$check_rs" =~ ^2 ]] || [[ "$check_rs" =~ ^3 ]]; then
        echo "direct"
    else
        log WARN "Disney+ access might be restricted ($check_rs)"
        if [ -n "${ISP_TAG:-}" ]; then
            echo "${ISP_TAG}"
        else
            echo "direct"
        fi
    fi
}

# 检测 YouTube 访问状态
check_youtube_access() {
    log DEBUG "Checking YouTube..."
    # YouTube 很少完全封锁，但 Premium 功能可能会受限。
    local check_rs
    check_rs=$(curl -I -s -L --max-time 3 --retry 2 -A "Mozilla/5.0" "https://www.youtube.com/" 2>/dev/null | head -n 1 | awk '{print $2}')
    if [[ "$check_rs" =~ ^2 ]] || [[ "$check_rs" =~ ^3 ]]; then
        echo "direct"
    else
        if [ -n "${ISP_TAG:-}" ]; then
            echo "${ISP_TAG}"
        else
            echo "direct"
        fi
    fi
}

# 检测 Gemini 访问状态
check_gemini_access() {
    log DEBUG "Checking Gemini..."
    local check_rs
    # Gemini redirects to accounts.google.com if valid.
    check_rs=$(curl -I -s -L --max-time 3 --retry 2 -A "Mozilla/5.0" "https://gemini.google.com" 2>/dev/null | head -n 1 | awk '{print $2}')
    if [[ "$check_rs" =~ ^2 ]] || [[ "$check_rs" =~ ^3 ]]; then
        echo "direct"
    else
        log WARN "Gemini access might be restricted ($check_rs)"
        if [ -n "${ISP_TAG:-}" ]; then
            echo "${ISP_TAG}"
        else
            echo "direct"
        fi
    fi
}

# 检测 Claude 访问状态
check_claude_access() {
    log DEBUG "Checking Claude..."
    local check_rs
    check_rs=$(curl -I -s -L --max-time 3 --retry 2 -A "Mozilla/5.0" "https://claude.ai/login" 2>/dev/null | head -n 1 | awk '{print $2}')
    if [[ "$check_rs" =~ ^2 ]] || [[ "$check_rs" =~ ^3 ]]; then
        echo "direct"
    else
        log WARN "Claude access might be restricted ($check_rs)"
        if [ -n "${ISP_TAG:-}" ]; then
            echo "${ISP_TAG}"
        else
            echo "direct"
        fi
    fi
}

# 获取 ISP 优先策略 (如果可用则使用 ISP 代理)
get_isp_preferred_strategy() {
    # 如果当前不是 ISP IP 但存在可用的 ISP 代理，则优先使用 ISP 代理
    # 逻辑: IP_TYPE != isp 且 ISP_TAG 已设置 -> 返回 ISP_TAG
    if [[ "${IP_TYPE:-unknown}" != "isp" ]] && [[ -n "${ISP_TAG:-}" ]]; then
        echo "${ISP_TAG}"
    else
        echo "direct"
    fi
}

# 检查当前 IP 类型 (ISP/DataCenter 等)
check_ip_type() {
    log DEBUG "Checking IP Type..."
    local type
    # 从 ipapi.is 获取 IP 类型

    type=$(curl -sSL --max-time 5 --retry 2 "https://api.ipapi.is/" | jq -r '.asn.type // "unknown"')
    echo "${type}"
}

# 获取地理位置信息
get_geo_info() {
    curl -fsSL --max-time 10 --retry 2 https://ip111.cn/ | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>'
}

# 检查 TCP Brutal 模块状态
check_brutal_status() {
    [ -d "/sys/module/brutal" ] && echo "true" || echo "false"
}

# 生成随机字符串/端口/UUID
generateRandomStr() {
    local type=$1 length=${2:-12}
    case $type in
        "port") shuf -i 32000-38000 -n 1 ;;
        "uuid") xray uuid ;;
        "password"|"path")
            local charset='A-Za-z0-9'; [[ "$type" == "path" ]] && charset='a-z0-9'
            LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$length" ;;
    esac
}

# 确保环境变量存在，不存在则生成
ensure_var() {
    local key=$1; shift; local cmd="$@"
    if ! grep -q "^export ${key}=" "${ENV_FILE}"; then
        log INFO "Generating ${key}..."
        local val=$($cmd)
        export "${key}=${val}"
        sed -i "/^export ${key}=/d" "${ENV_FILE}"
        echo "export ${key}='${val}'" >> "${ENV_FILE}"
    fi
}

# 确保密钥对存在
ensure_key_pair() {
    local name=$1 cmd=$2 key1=$3 key2=$4
    if ! grep -q "^export ${key1}=" "${ENV_FILE}" || ! grep -q "^export ${key2}=" "${ENV_FILE}"; then
        log INFO "Generating ${name} keys..."
        local out pair_v1 pair_v2
        out=$($cmd)
        pair_v1=$(echo "$out" | sed -n '1p' | awk -F': ' '{print $2}')
        pair_v2=$(echo "$out" | sed -n '2p' | awk -F': ' '{print $2}')

        export "${key1}=${pair_v1}"
        export "${key2}=${pair_v2}"
        sed -i "/^export ${key1}=/d" "${ENV_FILE}"; echo "export ${key1}='${pair_v1}'" >> "${ENV_FILE}"
        sed -i "/^export ${key2}=/d" "${ENV_FILE}"; echo "export ${key2}='${pair_v2}'" >> "${ENV_FILE}"
    fi
}

# 解密敏感信息环境变量
decryptSecretsEnv() {
    local base_url="https://raw.githubusercontent.com/currycan/key/master"
    local items=( "tmp.bin:/.env/secret" "ptmp.bin:${WORKDIR}/providers" )

    checkRequiredEnv DECODE

    for item in "${items[@]}"; do
        local file="${item#*:}"
        [ -f "$file" ] && continue
        mkdir -p "$(dirname "$file")"
        log INFO "Downloading and decrypting ${file}..."
        curl -fsSLo /tmp/tmp.bin "${base_url}/${item%%:*}" || { log ERROR "Download failed"; exit 1; }
        crypctl decrypt -i /tmp/tmp.bin -o "$file" -k "${DECODE}" || { log ERROR "Decryption failed"; exit 1; }
        rm -f /tmp/tmp.bin
    done
    log INFO "Secrets initialized"
}

# 生成所有必要的环境变量
generateEnv() {
    mkdir -p "$(dirname "${ENV_FILE}")" && touch "${ENV_FILE}"
    set +u; source "${ENV_FILE}"; set -u

    local -a vars=(
        "XUI_LOCAL_PORT|generateRandomStr port"
        "DUFS_PORT|generateRandomStr port"
        "PASSWORD|generateRandomStr password 16"
        "XRAY_UUID|generateRandomStr uuid"
        "SB_UUID|generateRandomStr uuid"
        "XRAY_REALITY_SHORTID|openssl rand -hex 8"
        "XRAY_URL_PATH|generateRandomStr path 32"
        "PORT_HYSTERIA2|generateRandomStr port"
        "PORT_TUIC|generateRandomStr port"
        "PORT_ANYTLS|generateRandomStr port"
        "SUBSCRIBE_TOKEN|generateRandomStr path 32"
        "IP_TYPE|check_ip_type"
        "CHATGPT_OUT|check_chatgpt_access"
        "NETFLIX_OUT|check_netflix_access"
        "DISNEY_OUT|check_disney_access"
        "YOUTUBE_OUT|check_youtube_access"
        "GEMINI_OUT|check_gemini_access"
        "CLAUDE_OUT|check_claude_access"
        "ISP_OUT|get_isp_preferred_strategy"
        "STRATEGY|detect_ip_strategy_api"
        "GEOIP_INFO|get_geo_info"
        "IS_BRUTAL|check_brutal_status"
        "SUB_STORE_FRONTEND_BACKEND_PATH|echo /$(generateRandomStr path 32)"
    )

    for entry in "${vars[@]}"; do
        IFS='|' read -r key cmd <<< "$entry"
        ensure_var "$key" $cmd
    done

    ensure_key_pair "Reality" "xray x25519" "XRAY_REALITY_PRIVATE_KEY" "XRAY_REALITY_PUBLIC_KEY"
    ensure_key_pair "MLKEM768" "xray mlkem768" "XRAY_MLKEM768_SEED" "XRAY_MLKEM768_CLIENT"
    log INFO "Environment Generation Done"
}

# 合并生成 ISP 配置 (服务端 & 客户端)
generateIspConfigs() {
    export SB_SOCKS5_OUTBOUND_CONFIG="" CUSTOM_OUTBOUNDS="" SB_CUSTOM_OUTBOUNDS="" CLASH_ISP_PROXIES=""

    local def_out="" def_sb_out="" oth_out="" oth_sb_out="" clash_proxies="" first_tag=""

    log INFO "Starting generateIspConfigs..."
    local env_vars=$(env | grep "_ISP_IP=" | cut -d= -f1)

    for var in $env_vars; do
        local prefix=${var%_IP} ip="${!var}"
        local port_v="${prefix}_PORT" user_v="${prefix}_USER" pass_v="${prefix}_SECRET"
        local port="${!port_v}" user="${!user_v}" pass="${!pass_v}"

        if [[ -n "$ip" && -n "$port" ]]; then
            log DEBUG "Checking ISP Var: $var | Prefix: $prefix | IP: $ip | PortVar: $port_v | Port: $port"
            log INFO "Proxy: ${prefix} -> $ip:$port"

            # 1. 服务端配置 (逻辑源自 generateIspSocks5Config)
            local tag="proxy-$(echo "${prefix}" | tr '[:upper:]_ ' '[:lower:]-')"
            local x_json="{\"tag\": \"${tag}\", \"protocol\": \"socks\", \"settings\": {\"servers\": [{\"address\": \"$ip\", \"port\": $port, \"users\": [{\"user\": \"$user\", \"pass\": \"$pass\"}]}]}},"
            local s_json="{\"type\": \"socks\", \"tag\": \"${tag}\", \"server\": \"$ip\", \"server_port\": $port, \"username\": \"$user\", \"password\": \"$pass\"},"

            if [[ -z "${first_tag:-}" ]]; then
                first_tag="$tag"
                log INFO "Set first_tag to $first_tag"
            fi

            if [[ -n "${DEFAULT_ISP:-}" && ("$prefix" == "$DEFAULT_ISP" || "$prefix" == "${DEFAULT_ISP}_ISP") ]]; then
                    def_out="${x_json}"; def_sb_out="${s_json}"
                    export ISP_IP="$ip" ISP_PORT="$port" ISP_USER="$user" ISP_SECRET="$pass"
                    export ISP_TAG="$tag"
                else
                    oth_out="${oth_out}${x_json}"; oth_sb_out="${oth_sb_out}${s_json}"
                fi

            # 2. 客户端配置 (逻辑源自 generateClientTemplateConfig)
            local name_prefix="${prefix%_ISP}"
            local c_yaml="  - name: ${name_prefix}-dialer
    type: socks5
    server: ${ip}
    port: ${port}
    username: ${user}
    password: ${pass}
    udp: true
    dialer-proxy: 链式前置"

            if [ -z "$clash_proxies" ]; then
                clash_proxies="${c_yaml}"
            else
                clash_proxies="${clash_proxies}
${c_yaml}"
            fi
        fi
    done

    export CUSTOM_OUTBOUNDS="${def_out}${oth_out}"
    export SB_CUSTOM_OUTBOUNDS="${def_sb_out}${oth_sb_out}"
    export CLASH_ISP_PROXIES="${clash_proxies}"

    if [[ -z "${ISP_TAG:-}" && -n "${first_tag:-}" ]]; then
        export ISP_TAG="$first_tag"
        log INFO "No DEFAULT_ISP matched, using first available ISP ($ISP_TAG) for unlocking."
    fi
    [ -n "${ISP_TAG:-}" ] && log INFO "Unlocking Proxy Tag: ${ISP_TAG}"

    log DEBUG "ISP Configs Generated"
}

# 生成代理提供者配置
generateProxyProvidersConfig() {
    log INFO "Generating Proxy Providers..."
    local provider_config="${WORKDIR}/providers"
    local clash_providers=""

    # 1. 处理文件配置
    if [ -f "$provider_config" ]; then
        local content
        content=$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' -e '/^providers:/d' -e '/^proxy-providers:/d' "$provider_config")
        [ -n "$content" ] && clash_providers="${content}"
        log DEBUG "Loaded file config from $provider_config"
    else
        log WARN "providers.yaml not found in ${WORKDIR}/providers/!"
    fi


    # 2. 处理环境变量配置 (PROVIDERS)
    if [ -n "${PROVIDERS:-}" ]; then
        log DEBUG "Processing PROVIDERS env var..."
        local env_content

        # 使用 awk 解析 "Name|URL|Suffix" 格式
        env_content=$(echo "$PROVIDERS" | awk -F'|' '
            NF>=2 && $1!="" && $2!="" {
                suffix = ""
                if ($3 != "") suffix = " [" $3 "]"
                # Print formatted YAML line
                printf "  %s: {<<: *BaseProvider, url: \"%s\", override: {additional-prefix: \"[%s] \", additional-suffix: \"%s\"}}\n", $1, $2, $1, suffix
            }
        ')

        if [ -n "$env_content" ]; then
            if [ -n "$clash_providers" ]; then
                clash_providers="${clash_providers}
${env_content}"
            else
                clash_providers="${env_content}"
            fi
            log DEBUG "Appended parsed PROVIDERS"
        fi
    fi

    export CLASH_PROXY_PROVIDERS="${clash_providers}"
}

# 基于模板创建配置文件
createConfig() {
    log INFO "Creating configurations..."
    local env_list; env_list=$(env | grep -v '^_' | cut -d= -f1 | sed 's/^/${/;s/$/}/' | xargs)
    export RANDOM_NUM=$(shuf -i 0-9 -n 1)

    apply_tpl() {
        local src="$1" dest="$2" extra_env="${3:-}"
        log DEBUG "Gen $dest"
        mkdir -p "$(dirname "$dest")"
        local temp_out; temp_out=$(mktemp)

        if [ -n "$extra_env" ]; then
            envsubst "$env_list $extra_env" < "$src" > "$temp_out"
        else
            envsubst < "$src" > "$temp_out"
        fi

        if [[ "$dest" == *.json ]]; then
            if jq . "$temp_out" > "$dest" 2>/dev/null; then
                rm -f "$temp_out"; return
            fi
            log WARN "JSON format failed, using raw: $dest"
        fi
        mv "$temp_out" "$dest"
    }

    apply_tpl "/templates/supervisord/supervisord.conf" "/etc/supervisord.conf"
    apply_tpl "/templates/supervisord/daemon.ini"       "/etc/supervisor.d/daemon.ini"
    apply_tpl "/templates/nginx/nginx.conf"             "/etc/nginx/nginx.conf"         "$env_list"
    cp -f /templates/nginx/network_internal.conf        "/etc/nginx/network_internal.conf"
    apply_tpl "/templates/nginx/http.conf"              "/etc/nginx/conf.d/http.conf"   "$env_list \${RANDOM_NUM}"
    apply_tpl "/templates/nginx/tcp.conf"               "/etc/nginx/stream.d/tcp.conf"  "$env_list"
    apply_tpl "/templates/dufs/conf.yml"                "${WORKDIR}/dufs/conf.yml"

    for t in /templates/xray/*.json; do apply_tpl "$t" "${WORKDIR}/xray/$(basename "$t")"; done
    for t in /templates/sing-box/*.json; do apply_tpl "$t" "${WORKDIR}/sing-box/$(basename "$t")"; done
}

# 申请或更新 SSL 证书
issueCertificate() {
    local name="$1" params="$2"
    local first_dom="${params%%:*}"
    local cert="${SSL_PATH}/${name}.crt" key="${SSL_PATH}/${name}.key" ca="${SSL_PATH}/${name}-ca.crt"

    # 检查证书是否存在且未过期 (提前7天)
    if [[ -f "$cert" && -f "$key" && -f "$ca" ]]; then
        if openssl x509 -checkend 604800 -noout -in "$cert" >/dev/null 2>&1; then
            log INFO "Cert [$name] exists and is valid for >7 days."
            return 0
        else
            # 如果 acme.sh 配置丢失,下面的逻辑会重新注册并签发
            log WARN "Cert [$name] is expiring within 7 days. Forcing renewal..."
        fi
    fi

    if ! acme.sh --list | grep -q "${first_dom}"; then
        checkRequiredEnv "ACMESH_SERVER_NAME" "ACMESH_REGISTER_EMAIL" "ALI_KEY" "ALI_SECRET" "CF_TOKEN" "CF_ZONE_ID" "CF_ACCOUNT_ID"
        export Ali_Key="${ALI_KEY}" Ali_Secret="${ALI_SECRET}" CF_Token="${CF_TOKEN}" CF_Zone_ID="${CF_ZONE_ID}" CF_Account_ID="${CF_ACCOUNT_ID}"

        log INFO "Requesting cert for $name..."
        local reg_args=("-m" "${ACMESH_REGISTER_EMAIL}" "--server" "${ACMESH_SERVER_NAME}")

        # Google CA 特殊处理：强制检查 EAB 凭证
        if [[ "${ACMESH_SERVER_NAME}" == "google" ]]; then
            if [[ -z "${ACMESH_EAB_KID:-}" || -z "${ACMESH_EAB_HMAC_KEY:-}" ]]; then
                log ERROR "Google CA requires EAB credentials (ACMESH_EAB_KID & ACMESH_EAB_HMAC_KEY)!"
                return 1
            fi
        fi

        [[ -n "${ACMESH_EAB_KID:-}" && -n "${ACMESH_EAB_HMAC_KEY:-}" ]] && reg_args+=("--eab-kid" "${ACMESH_EAB_KID}" "--eab-hmac-key" "${ACMESH_EAB_HMAC_KEY}")

        acme.sh --register-account "${reg_args[@]}" >/dev/null 2>&1

        local args=("--issue" "--ecc" "--server" "${ACMESH_SERVER_NAME}")
        IFS='|' read -ra ENTRIES <<< "$params"
        for e in "${ENTRIES[@]}"; do
            local d="${e%%:*}" p="${e#*:}"
            args+=("-d" "$d" "--dns" "$p")
            [[ ! "$d" =~ ^[0-9.]+$ ]] && args+=("-d" "*.$d" "--dns" "$p")
        done
        acme.sh "${args[@]}" || { log ERROR "Cert issue failed"; return 1; }
    fi

    log INFO "Installing cert $name..."
    rm -f /etc/nginx/conf.d/* /etc/nginx/stream.d/*
    acme.sh --install-cert --ecc -d "${first_dom}" --key-file "$key" --fullchain-file "$cert" --ca-file "$ca" --reloadcmd "/usr/sbin/nginx"
    /usr/sbin/nginx -s quit 2>/dev/null && rm -f /var/run/nginx/nginx.pid || true
}

if [ "${1#-}" = 'supervisord' ] && [ "$(id -u)" = '0' ]; then
    mkdir -p ${LOGDIR}/{supervisor,xray,sing-box,dufs,nginx,x-ui,s-ui} "${SUI_DB_FOLDER}" "${SUB_STORE_DATA_BASE_PATH}"

    decryptSecretsEnv
    set +u; source "/.env/secret"; source "/.env/xray"; set -u
    # 生成 ISP 配置
    generateIspConfigs
    generateEnv

    while IFS= read -r line; do
        log DEBUG "${line}"
    done < "/.env/xray"

    issueCertificate "sb_xray_bundle" "${DOMAIN}:dns_ali|${CDNDOMAIN}:dns_cf"

    # Nginx DHParam
    dh_file="/etc/nginx/dhparam/dhparam.pem"
    if [ ! -f "$dh_file" ]; then
        mkdir -p "$(dirname "$dh_file")"
        openssl dhparam -dsaparam -out "$dh_file" 4096 && log INFO "DH generated"
    fi

    /scripts/geo_update.sh

    generateProxyProvidersConfig
    createConfig

    log INFO "Init X-UI..."
    x-ui setting -username "${PUBLIC_USER}" -password "${PUBLIC_PASSWORD}" -port "${XUI_LOCAL_PORT}" -webBasePath "${XUI_WEBBASEPATH}" >/dev/null

    log INFO "Init S-UI..."
    sui setting -port "${SUI_PORT}" -subPort "${SUI_SUB_PORT}" -path "/${SUI_WEBBASEPATH}" -subPath "/${SUI_SUB_PATH}" >/dev/null
    sui admin -password "${PUBLIC_PASSWORD}" -username "${PUBLIC_USER}" >/dev/null
    [ -f "${SUI_DB_FOLDER}/s-ui.db" ] && sqlite3 "${SUI_DB_FOLDER}/s-ui.db" "UPDATE settings SET value='https://${DOMAIN}/${SUI_SUB_PATH}/' WHERE key='subURI';"

    # 生成用于订阅端点认证的 .htpasswd 文件
    log INFO "Generating .htpasswd for subscription endpoint..."
    HTPASSWD_FILE="/etc/nginx/.htpasswd"
    if [ -n "${PUBLIC_USER}" ] && [ -n "${PUBLIC_PASSWORD}" ]; then
        # 使用 openssl 生成 bcrypt 密码哈希 (比 MD5 更安全)
        # 注意: nginx 支持 bcrypt, MD5, SHA, 和 crypt 格式
        ENCRYPTED_PASS=$(openssl passwd -apr1 "${PUBLIC_PASSWORD}")
        echo "${PUBLIC_USER}:${ENCRYPTED_PASS}" > "${HTPASSWD_FILE}"
        chmod 644 "${HTPASSWD_FILE}"
        log INFO "HTTP Basic Auth enabled for user: ${PUBLIC_USER}"
    else
        log WARN "PUBLIC_USER or PUBLIC_PASSWORD not set, skipping .htpasswd generation"
    fi


    log INFO "Starting fail2ban..." && fail2ban-client -x start >/dev/null

    # Cron 设置
    cron_file="/var/spool/cron/crontabs/root"
    touch "$cron_file"
    sed -i '/geo_update.sh/d' "$cron_file"
    echo "0 3 * * * /scripts/geo_update.sh >> /var/log/geo_update.log 2>&1" >> "$cron_file"
    chmod 0600 "$cron_file"

    [[ ! -f "/usr/local/bin/show" ]] && ln -sf "/scripts/show-config.sh" "/usr/local/bin/show"
    /usr/local/bin/show

    set -- "$@" -n -c /etc/supervisord.conf
fi

exec "$@"
