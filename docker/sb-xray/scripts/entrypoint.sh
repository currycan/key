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

checkRequiredEnv() {
    local missing=()
    for var in "$@"; do [ -z "${!var:-}" ] && missing+=("$var"); done
    [ ${#missing[@]} -eq 0 ] || { log ERROR "Missing required env: ${missing[*]}"; exit 1; }
}

# ===== 功能函数 =====

detect_ip_strategy_api() {
    log DEBUG "Getting IP strategy..."
    local v4="" v6=""
    curl -4 -s --connect-timeout 2 https://api.ip.sb/ip >/dev/null && v4="yes"
    curl -6 -s --connect-timeout 2 https://api.ip.sb/ip >/dev/null && v6="yes"
    [[ "$v4" == "yes" && "$v6" == "yes" ]] && echo prefer_ipv4 && return
    [[ "$v6" == "yes" ]] && echo ipv6_only && return
    echo ipv4_only
}

check_chatgpt_access() {
    log DEBUG "Checking ChatGPT..."
    local check_rs
    check_rs=$(curl -sSL --max-time 2 --retry 2 -A "Mozilla/5.0" \
        -H "Authorization: Bearer null" -H "Referer: https://platform.openai.com/" \
        "https://api.openai.com/compliance/cookie_requirements")
    if [[ -z "$check_rs" ]] || grep -qi "unsupported_country" <<< "$check_rs"; then
        log WARN "ChatGPT access requires proxy"
        echo "warp-ep"
    else
        echo "direct"
    fi
}

get_geo_info() {
    curl -fsSL --max-time 10 --retry 2 https://ip111.cn/ | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>'
}

check_brutal_status() {
    if [ -d "/sys/module/brutal" ]; then echo "true"; else echo "false"; fi
}

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

# ===== 环境变量处理 =====

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

decryptSecretsEnv() {
    local sec_file="/.env/secret"
    [ -f "$sec_file" ] && return
    mkdir -p "$(dirname "$sec_file")"
    checkRequiredEnv DECODE
    log INFO "Downloading encrypted secrets..."
    curl -fsSLo /tmp/tmp.bin "https://raw.githubusercontent.com/currycan/key/master/tmp.bin" || { log ERROR "Download failed"; exit 1; }
    crypctl decrypt -i /tmp/tmp.bin -o "$sec_file" -k "${DECODE}" || { log ERROR "Decryption failed"; exit 1; }
    rm -f /tmp/tmp.bin
    log INFO "Secrets decrypted"
}

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
        "CHATGPT_OUT|check_chatgpt_access"
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
    log INFO "Environment ready"
}

generateIspSocks5Config() {
    export SB_SOCKS5_OUTBOUND_CONFIG="" CUSTOM_OUTBOUNDS="" SB_CUSTOM_OUTBOUNDS=""
    [[ "${ENABLE_ISP_PROXY}" != "true" ]] && return

    log INFO "Generating ISP SOCKS5 outbounds..."
    local def_out="" def_sb_out="" oth_out="" oth_sb_out=""

    for var in $(compgen -v | grep "_ISP_IP$"); do
        local prefix=${var%_IP} ip="${!var}"
        local port_v="${prefix}_PORT" user_v="${prefix}_USER" pass_v="${prefix}_SECRET"
        local port="${!port_v}" user="${!user_v}" pass="${!pass_v}"

        if [[ -n "$ip" && -n "$port" ]]; then
            log INFO "Proxy: ${prefix} -> $ip:$port"
            local tag="proxy-$(echo "${prefix}" | tr '[:upper:]_ ' '[:lower:]-')"
            local x_json="{\"tag\": \"${tag}\", \"protocol\": \"socks\", \"settings\": {\"servers\": [{\"address\": \"$ip\", \"port\": $port, \"users\": [{\"user\": \"$user\", \"pass\": \"$pass\"}]}]}},"
            local s_json="{\"type\": \"socks\", \"tag\": \"${tag}\", \"server\": \"$ip\", \"server_port\": $port, \"username\": \"$user\", \"password\": \"$pass\"},"

            if [[ -n "${DEFAULT_ISP:-}" && "$prefix" == "$DEFAULT_ISP" ]]; then
                def_out="${x_json}"; def_sb_out="${s_json}"
            else
                oth_out="${oth_out}${x_json}"; oth_sb_out="${oth_sb_out}${s_json}"
            fi
        fi
    done
    export CUSTOM_OUTBOUNDS="${def_out}${oth_out}"
    export SB_CUSTOM_OUTBOUNDS="${def_sb_out}${oth_sb_out}"
}

createConfig() {
    log INFO "Creating configurations..."
    local env_list; env_list=$(env | grep -v '^_' | cut -d= -f1 | sed 's/^/${/;s/$/}/' | xargs)
    export RANDOM_NUM=$(shuf -i 0-9 -n 1) # used in http.conf

    # Templating helper
    apply_tpl() {
        local src="$1" dest="$2"
        local extra_env="${3:-}" # Optional extra vars
        log DEBUG "Gen $dest"
        mkdir -p "$(dirname "$dest")"

        local temp_out
        temp_out=$(mktemp)

        if [ -n "$extra_env" ]; then
            envsubst "$env_list $extra_env" < "$src" > "$temp_out"
        else
            envsubst < "$src" > "$temp_out"
        fi

        # 如果是 json 文件，尝试格式化
        if [[ "$dest" == *.json ]]; then
            if jq . "$temp_out" > "$dest" 2>/dev/null; then
                log DEBUG "Formatted JSON: $dest"
                rm -f "$temp_out"
                return
            fi
            log WARN "JSON format failed (comments?), using raw: $dest"
        fi

        mv "$temp_out" "$dest"
    }

    apply_tpl "/templates/supervisord/supervisord.conf" "/etc/supervisord.conf"
    apply_tpl "/templates/supervisord/daemon.ini"      "/etc/supervisor.d/daemon.ini"
    apply_tpl "/templates/nginx/nginx.conf"            "/etc/nginx/nginx.conf" "$env_list"
    cp -f /templates/nginx/network_internal.conf       /etc/nginx/network_internal.conf
    apply_tpl "/templates/nginx/http.conf"             "/etc/nginx/conf.d/http.conf" "$env_list \${RANDOM_NUM}"
    apply_tpl "/templates/nginx/tcp.conf"              "/etc/nginx/stream.d/tcp.conf" "$env_list"
    apply_tpl "/templates/dufs/conf.yml"               "${WORKDIR}/dufs/conf.yml"

    for t in /templates/xray/*.json; do apply_tpl "$t" "${WORKDIR}/xray/$(basename "$t")"; done
    for t in /templates/sing-box/*.json; do apply_tpl "$t" "${WORKDIR}/sing-box/$(basename "$t")"; done
}

issueCertificate() {
    local name="$1" params="$2"
    local first_dom="${params%%:*}"
    local cert="${SSL_PATH}/${name}.crt" key="${SSL_PATH}/${name}.key" ca="${SSL_PATH}/${name}-ca.crt"

    [[ -f "$cert" && -f "$key" && -f "$ca" ]] && { log INFO "Cert [$name] exists."; return 0; }

    if ! acme.sh --list | grep -q "${first_dom}"; then
        checkRequiredEnv "ACMESH_SERVER_NAME" "ACMESH_REGISTER_EMAIL" "ALI_KEY" "ALI_SECRET" "CF_TOKEN" "CF_ZONE_ID" "CF_ACCOUNT_ID"
        export Ali_Key="${ALI_KEY}" Ali_Secret="${ALI_SECRET}" CF_Token="${CF_TOKEN}" CF_Zone_ID="${CF_ZONE_ID}" CF_Account_ID="${CF_ACCOUNT_ID}"

        log INFO "Requesting cert for $name..."
        acme.sh --register-account -m "${ACMESH_REGISTER_EMAIL}" --server "${ACMESH_SERVER_NAME}" >/dev/null 2>&1

        local args=("--issue" "--ecc" "--server" "${ACMESH_SERVER_NAME}")
        IFS='|' read -ra ENTRIES <<< "$params"
        for e in "${ENTRIES[@]}"; do
            local d="${e%%:*}" p="${e#*:}"
            args+=("-d" "$d" "--dns" "$p")
            [[ "${ACMESH_SERVER_NAME}" == "letsencrypt" && ! "$d" =~ ^[0-9.]+$ ]] && args+=("-d" "*.$d" "--dns" "$p")
        done
        acme.sh "${args[@]}" || { log ERROR "Cert issue failed"; return 1; }
    fi

    log INFO "Installing cert $name..."
    rm -f /etc/nginx/conf.d/* /etc/nginx/stream.d/*
    acme.sh --install-cert --ecc -d "${first_dom}" --key-file "$key" --fullchain-file "$cert" --ca-file "$ca" --reloadcmd "/usr/sbin/nginx"
    /usr/sbin/nginx -s quit 2>/dev/null && rm -f /var/run/nginx/nginx.pid || true
}

# ===== 主流程 =====

if [ "${1#-}" = 'supervisord' ] && [ "$(id -u)" = '0' ]; then
    mkdir -p ${LOGDIR}/{supervisor,xray,sing-box,dufs,nginx,x-ui,s-ui} "${SUI_DB_FOLDER}" "${SUB_STORE_DATA_BASE_PATH}"

    decryptSecretsEnv
    generateEnv
    source "/.env/secret"
    source "/.env/xray"
    cat "/.env/xray"

    issueCertificate "sb_xray_bundle" "${DOMAIN}:dns_ali|${CDNDOMAIN}:dns_cf"

    # Nginx DHParam
    dh_file="/etc/nginx/dhparam/dhparam.pem"
    if [ ! -f "$dh_file" ]; then
        mkdir -p "$(dirname "$dh_file")"
        openssl dhparam -dsaparam -out "$dh_file" 4096 && log INFO "DH generated"
    fi

    /scripts/geo_update.sh
    generateIspSocks5Config
    createConfig

    log INFO "Init X-UI..."
    x-ui setting -username "${PUBLIC_USER}" -password "${PUBLIC_PASSWORD}" -port "${XUI_LOCAL_PORT}" -webBasePath "${XUI_WEBBASEPATH}" >/dev/null

    log INFO "Init S-UI..."
    sui setting -port "${SUI_PORT}" -subPort "${SUI_SUB_PORT}" -path "/${SUI_WEBBASEPATH}" -subPath "/${SUI_SUB_PATH}" >/dev/null
    sui admin -password "${PUBLIC_PASSWORD}" -username "${PUBLIC_USER}" >/dev/null
    if [ -f "${SUI_DB_FOLDER}/s-ui.db" ]; then
        sqlite3 "${SUI_DB_FOLDER}/s-ui.db" "UPDATE settings SET value='https://${DOMAIN}/${SUI_SUB_PATH}/' WHERE key='subURI';"
    fi

    log INFO "Starting fail2ban..." && fail2ban-client -x start >/dev/null

    # Cron setup
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
