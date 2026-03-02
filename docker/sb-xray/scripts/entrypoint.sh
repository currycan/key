#!/usr/bin/env bash
# ==============================================================================
# 系统入口点脚本 (entrypoint.sh)
#
# 主要功能:
# 1. 变量与安全凭证管理: 初始化环境变量(持久化/内存)，拉取和解密远端安全库。
# 2. 网络设施及流媒体探测: 侦别本机 IP 属性，对主流流媒体及 AI 服务进行可用性探测。
# 3. 动态选路与性能测试: 无条件执行直连和代理测速，确保精准挑选当前网络环境的最优节点。
# 4. 自动编排配置文件: 将获得的最优动态参数无缝映射注入系统内各大应用配置。
# 5. 自动证书闭环管理: 实现 Acme.sh 域名的 SSL/TLS 证书申请、部署、防吊销。
# 6. 面板管控与边界防护: 启动 X-UI / S-UI，注入订阅基本认证，开启 Fail2ban 防护。
# ==============================================================================

set -eou pipefail

# ==============================================================================
# 📌 扇区一：全局环境与通用能力层 (Helper & Global Functions)
# ==============================================================================
# 全局视觉控制常量定义
if [ -t 1 ]; then
    RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; CYAN='\033[1;36m'; NC='\033[0m'
    BOLD='\033[1m'; RESET_BOLD='\033[22m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
    BOLD=''; RESET_BOLD=''
fi

# 核心环境变量持久化文件路径
ENV_FILE="/.env/sb-xray"
SECRET_FILE="/.env/secret"
STATUS_FILE="/.env/status"

# 统一化屏幕输出组件
log() {
    local level=$1; shift
    local color="${NC}"
    case $level in
        INFO)  color="${GREEN}" ;;
        WARN)  color="${YELLOW}" ;;
        ERROR) color="${RED}" ;;
        DEBUG) color="${CYAN}" ;;
    esac
    echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] [${level}] $*${NC}" >&2
}

# 信息汇总展示仪表盘
log_summary_box() {
    local width=65
    local line=$(printf '%.0s=' $(seq 1 $width))

    echo -e "\n${CYAN}${line}"
    echo -e "║${NC}${YELLOW} SYSTEM STRATEGY SUMMARY ${NC}${CYAN}$(printf '%.0s ' $(seq 1 $((width-27))))║"
    echo -e "${line}${NC}"

    local keys=("$@")
    for k in "${keys[@]}"; do
        local val=${!k:-N/A}
        local padding=$((width - 4 - ${#k} - ${#val}))
        [ $padding -lt 0 ] && padding=0
        echo -e "${CYAN}║ ${NC}${GREEN}${k}${NC}: ${val}$(printf '%.0s ' $(seq 1 $padding)) ${CYAN}║${NC}"
    done
    echo -e "${CYAN}${line}${NC}\n"
}

# 进度条函数
show_progress() {
    echo -ne "\r${CYAN}${BOLD}[*] $1 ... ${NC}" >&2
}
end_progress() {
    echo -ne "\r\033[K" >&2
}

# HTTP 探测网络核 (统合取代原本零散的 curl 请求)
http_probe() {
    local url=$1
    local expect_redirect=${2:-false}
    local head_cmd="curl -I -s --max-time 3 --retry 2 -A \"Mozilla/5.0\""
    if [[ "$expect_redirect" == "true" ]]; then
        head_cmd="curl -I -s -L --max-time 3 --retry 2 -A \"Mozilla/5.0\""
    fi
    local res
    res=$(eval "$head_cmd \"$url\"" 2>/dev/null | head -n 1 | awk '{print $2}')
    echo "${res:-Timeout}"
}

# URL 重定向最终路径侦测 (用于 Claude)
http_trace_url() {
    local url=$1
    local res
    res=$(curl -sS -L -I --max-time 5 --retry 2 -w "%{url_effective}" -A "Mozilla/5.0" "$url" 2>/dev/null | tail -1)
    echo "${res}"
}

# 批量处理并产生基于特定范围的高阶字符串或网络服务标识凭据
generateRandomStr() {
    local type=$1 length=${2:-12}
    case $type in
        "port")
            shuf -i 32000-38000 -n 1
            ;;
        "uuid")
            xray uuid
            ;;
        "password"|"path")
            local charset='A-Za-z0-9'
            [[ "$type" == "path" ]] && charset='a-z0-9'
            LC_ALL=C tr -dc "$charset" < /dev/urandom | head -c "$length"
            ;;
    esac
}

# 读取缓存与指令绑定中心（改良版：去除每次重复 grep 写法）
ensure_var() {
    local key=$1; shift;
    local persist=true; if [[ "$1" == "--no-persist" ]]; then persist=false; shift; fi
    local cmd="$*"

    [ ! -f "${ENV_FILE}" ] && mkdir -p "$(dirname "${ENV_FILE}")" && touch "${ENV_FILE}"

    if ! grep -q "^export ${key}=" "${ENV_FILE}"; then
        log DEBUG "系统环境变量欠缺 [${key}]，初始化计算进程: [${cmd}]"
        local val=$($cmd)
        export "${key}=${val}"

        if [[ "$persist" == "true" ]]; then
            sed -i "/^export ${key}=/d" "${ENV_FILE}"
            echo "export ${key}='${val}'" >> "${ENV_FILE}"
            log DEBUG "指纹变量 [${key}] 已成功持久化至配置库，映射值: ${val}"
        else
            log DEBUG "运行变量 [${key}] 初始化完成，载入内存上下文，映射值: ${val}"
        fi
    else
        log DEBUG "存储库中匹配到参数 [${key}]，跳过重复计算阶段。"
    fi
}

# 加密通道密钥构建器
ensure_key_pair() {
    local name=$1 cmd=$2 key1=$3 key2=$4

    [ ! -f "${ENV_FILE}" ] && mkdir -p "$(dirname "${ENV_FILE}")" && touch "${ENV_FILE}"

    if ! grep -q "^export ${key1}=" "${ENV_FILE}" || ! grep -q "^export ${key2}=" "${ENV_FILE}"; then
        log INFO "系统未检索到安全的 ${name} 密钥凭据对，自动启动密码学组件生成..."
        local out pair_v1 pair_v2
        out=$($cmd)

        pair_v1=$(echo "$out" | sed -n '1p' | awk -F': ' '{print $2}')
        pair_v2=$(echo "$out" | sed -n '2p' | awk -F': ' '{print $2}')

        export "${key1}=${pair_v1}"
        export "${key2}=${pair_v2}"

        sed -i "/^export ${key1}=/d" "${ENV_FILE}"; echo "export ${key1}='${pair_v1}'" >> "${ENV_FILE}"
        sed -i "/^export ${key2}=/d" "${ENV_FILE}"; echo "export ${key2}='${pair_v2}'" >> "${ENV_FILE}"

        log INFO "${name} 高级加密对计算通过，存储库覆写完成。"
    else
        log DEBUG "确认命中有效的历史 ${name} Key Pairs 认证存量配置。"
    fi
}

checkRequiredEnv() {
    local missing=()
    for var in "$@"; do
        [ -z "${!var:-}" ] && missing+=("$var")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log ERROR "[致命断言失败] 缺少关键核变参数: ${missing[*]}，请核实 Compose 或环境文件表单！"
        exit 1
    fi
}


# ==============================================================================
# 📌 扇区二：网络环境生成与测速决策 (Phase 1: Environment Variables)
# ==============================================================================

# IPv4 & IPv6 双栈寻址优先级测试
detect_ip_strategy_api() {
    log DEBUG "探究当前宿主 IPv4/IPv6 双栈网络体系状态..."
    local v4="" v6=""
    curl -4 -s --connect-timeout 2 https://api.ip.sb/ip >/dev/null && v4="yes"
    curl -6 -s --connect-timeout 2 https://api.ip.sb/ip >/dev/null && v6="yes"

    if [[ "$v4" == "yes" && "$v6" == "yes" ]]; then
        log DEBUG "结论归纳: 检测到 Dual Stack (IPv4/IPv6) 栈可用。默认路由策略分配: [prefer_ipv4]。"
        echo prefer_ipv4
    elif [[ "$v6" == "yes" ]]; then
        log DEBUG "结论归纳: 本机仅支持 IPv6 出口。默认路由策略分配: [ipv6_only]。"
        echo ipv6_only
    else
        log DEBUG "结论归纳: 本机仅支持 IPv4 出口。默认路由策略分配: [ipv4_only]。"
        echo ipv4_only
    fi
}

# ASN Type 与 IP 大网络数据库查询鉴定服务
check_ip_type() {
    log DEBUG "正在通过平台 ipapi.is 获取主机 IP ASN 属性与公网信誉分类..."
    if [ ! -f /tmp/ipapi.json ]; then
        curl -sSL --max-time 5 --retry 2 "https://api.ipapi.is/" > /tmp/ipapi.json || echo "{}" > /tmp/ipapi.json
    fi
    local type
    type=$(jq -r '.asn.type // "unknown"' /tmp/ipapi.json)
    log DEBUG "网段环境审查结果: 该公网 IP 属性标签标定为 -> [${type}]"
    echo "${type}"
}

# Ip111.cn 地理区域快速标识截取器
get_geo_info() {
    log DEBUG "正在请求 ip111 获取 GeoIP 拓扑节点物理映射标示..."
    curl -fsSL --max-time 10 --retry 2 https://ip111.cn/ 2>/dev/null \
    | grep '这是您访问国内网站所使用的IP' -B 2 | head -n 1 \
    | awk -F' ' '{print $2$3"|"$1}' | tr -d '</p>'
}

# TCP_Brutal 加速模块判定钩子
check_brutal_status() {
    if [ -d "/sys/module/brutal" ]; then
        log DEBUG "内核探测: 底层网络支持环境确认开启 TCP_Brutal 拥塞干预算法。"
        echo "true"
    else
        log DEBUG "内核探测: 未侦测到支持装载的 TCP_Brutal 原生模块。"
        echo "false"
    fi
}

# ==============================================================================
# 代理 fallback 寻址核心 (当 ISP_TAG 已经因为原生直连速度优异被判定为 direct 时，
# 若流媒体/AI服务遭遇区域硬封锁，必须强制拉起第一个可用的 ISP 代理)
# ==============================================================================
get_fallback_proxy() {
    if [[ -n "${ISP_TAG:-}" && "${ISP_TAG}" != "direct" ]]; then
        echo "${ISP_TAG}"
        return
    fi
    local first_var=$(env | grep "_ISP_IP=" | head -n 1 | cut -d= -f1)
    if [[ -n "$first_var" ]]; then
        local prefix=${first_var%_IP}
        echo "proxy-$(echo "$prefix" | sed 's/_ISP//' | tr '[:upper:]_ ' '[:lower:]-')"
    else
        echo "direct"
    fi
}

# Netflix 全球媒体连通诊断
check_netflix_access() {
    log DEBUG "正在模拟并评判 Netflix 高级原生访问策略..."
    if [[ "${IP_TYPE:-unknown}" == "isp" ]]; then
        log INFO "[流分调度] 本机为住宅 IP，Netflix 默认直连。"
        echo "direct"
        return
    fi
    local check_rs=$(http_probe "https://www.netflix.com/title/81249783" "true")
    if [[ "$check_rs" =~ ^(2|3) ]]; then
        log INFO "[流分调度] Netflix 服务区验通无碍，开启底层直连。 (Code: $check_rs)"
        echo "direct"
    else
        log WARN "[流分调度] 侦测到 Netflix 访问阻塞或风控 (Code: $check_rs)，且非住宅网络，切分至 ISP 中继代理结构。"
        get_fallback_proxy
    fi
}

# Disney+ 多级入口鉴权访问拦截检测
check_disney_access() {
    log DEBUG "正在探测 Disney+ 原站 API 接口握手接通率..."
    if [[ "${IP_TYPE:-unknown}" == "isp" ]]; then
        log INFO "[流分调度] 本机为住宅 IP，Disney+ 默认直连。"
        echo "direct"
        return
    fi
    local check_rs=$(http_probe "https://www.disneyplus.com/" "true")
    if [[ "$check_rs" =~ ^(2|3) ]]; then
        log INFO "[流分调度] Disney+ 服务连接响应健康，保留本机直通。 (Code: $check_rs)"
        echo "direct"
    else
        log WARN "[流分调度] Disney+ 节点发生断连或受区域规控 (Code: $check_rs)，且非住宅网络，切分至 ISP 中继链。"
        get_fallback_proxy
    fi
}

# Youtube 原有宽带负载状态
check_youtube_access() {
    log DEBUG "针对 YouTube CDN 发出短时通畅率打分试探..."
    if [[ "${IP_TYPE:-unknown}" == "isp" ]]; then
        log INFO "[流分调度] 本机为住宅 IP，YouTube 默认直连。"
        echo "direct"
        return
    fi
    local check_rs=$(http_probe "https://www.youtube.com/" "true")
    if [[ "$check_rs" =~ ^(2|3) ]]; then
        log INFO "[流分调度] YouTube API 交互连接确认正常。 (Code: $check_rs)"
        echo "direct"
    else
        log WARN "[流分调度] YouTube 请求失效限制 (Code: $check_rs)，且非住宅网络，转移流量至 ISP 节点群池处理。"
        get_fallback_proxy
    fi
}

# Telegram / Twitter (X) 等全球社交媒体连通诊断
check_social_media_access() {
    log DEBUG "评估本机对于全球社交媒体矩阵 (Telegram/Twitter/INS) 的直通可达性..."
    if [[ "${GEOIP_INFO:-}" =~ (中国|China|CN|俄罗斯|Russia|RU|伊朗|Iran|IR) ]]; then
        log WARN "[社交流分] 侦测到物理节点位于强网络审查区域 (${GEOIP_INFO%%|*})，强制社交网络流转借 ISP 脱离。"
        get_fallback_proxy
        return
    elif [[ "${IP_TYPE:-unknown}" != "isp" ]]; then
        log WARN "[社交流分] 侦测到当前节点非纯住宅家庭宽带，社交媒体请求强制交由 ISP 代理池流转。"
        get_fallback_proxy
        return
    else
        log INFO "[社交流分] 本地域且为原生住宅 IP，社交媒体系架构应用直连开放。"
        echo "direct"
    fi
}

# TikTok 流媒体特定国家区域风控诊断
check_tiktok_access() {
    log DEBUG "评估 TikTok 对当前物理节点所处区域的国家级风控屏蔽策略..."
    # 众所周知 TikTok 封杀香港与大陆等地机器
    if [[ "${GEOIP_INFO:-}" =~ (香港|Hong|HK|中国|China|CN|俄罗斯|Russia|RU|澳门|Macao|MO) ]]; then
        log WARN "[流分调度] 侦测到节点落入 TikTok 服务商全线防区 (${GEOIP_INFO%%|*})，改派流量送入 ISP 中级。"
        get_fallback_proxy
        return
    elif [[ "${IP_TYPE:-unknown}" != "isp" ]]; then
        log WARN "[流分调度] 侦测到当前节点非纯住宅家庭宽带，TikTok 严格风控请求强制交由 ISP 代理池流转。"
        get_fallback_proxy
        return
    else
        log INFO "[流分调度] 区域评估放行及原生住宅 IP 验证通过，赋予 TikTok 通道直连特权。"
        echo "direct"
    fi
}

# 针对 ChatGPT 新架构验证其可用度，防误入 WAF
check_chatgpt_access() {
    log DEBUG "发送探针对 OpenAI 的 ChatGPT 前置校验 WAF 执行访问阻断判决..."
    if [[ "${GEOIP_INFO:-}" =~ (香港|Hong|HK|中国|China|CN|俄罗斯|Russia|RU|澳门|Macao|MO) ]]; then
        log WARN "[出列机制] 识别到当前物理节点位于 OpenAI 服务禁区 (${GEOIP_INFO%%|*})，强制剥夺直连切入代理模式！"
        get_fallback_proxy
        return
    elif [[ "${IP_TYPE:-unknown}" == "isp" ]]; then echo "direct"; return; fi
    local check_rs=$(http_probe "https://chatgpt.com" "false")
    if [[ "$check_rs" =~ ^(2|3) ]]; then
        log INFO "[出列机制] ChatGPT 支持免验本征 IP 连接请求规范。 (Code: $check_rs)"
        echo "direct"
    else
        log WARN "[出列机制] ChatGPT 遭到拦截或访问失败 (Code: $check_rs)，且非住宅网络，即时强制转由 ISP 通道解控！"
        get_fallback_proxy
    fi
}

# Claude 原站响应跳转机制和 IP 黑名单检验策略
check_claude_access() {
    log DEBUG "验证并捕获 Claude AI 跳转网关在认证入口上的实际响应终点轨迹..."
    if [[ "${GEOIP_INFO:-}" =~ (香港|Hong|HK|中国|China|CN|俄罗斯|Russia|RU|澳门|Macao|MO) ]]; then
        log WARN "[网络风控] 识别到当前物理节点位于 Claude 服务禁区 (${GEOIP_INFO%%|*})，强制剥夺直连切入代理模式！"
        get_fallback_proxy
        return
    elif [[ "${IP_TYPE:-unknown}" == "isp" ]]; then echo "direct"; return; fi
    local final_url=$(http_trace_url "https://claude.ai/login")
    if [[ "$final_url" =~ claude\.ai/(login|chats) || -z "$final_url" ]]; then
        log INFO "[网络风控] Claude API 重定向路线保持正常逻辑，确认容许原生 IP 对话。"
        echo "direct"
    else
        log WARN "[网络风控] Claude API 已偏移阻断或访问失败 (终点: $final_url)，且非住宅网络，全面划为 ISP 收发通道！"
        get_fallback_proxy
    fi
}

# Google Gemini / Nodebooks 解锁优先级仲裁层
check_gemini_access() {
    log DEBUG "结合多维网络属性与参数库，生成对标 Google Gemini 出局选路最佳防封方案策略..."
    if [[ "${GEMINI_DIRECT:-}" == "true" ]]; then
        log INFO "[智算引擎] 判断侦测用户手动置入配置覆盖 [GEMINI_DIRECT=true]，全线解除代理，只准放开本机原生 IP 出口。"
        echo "direct"
        return
    elif [[ "${GEMINI_DIRECT:-}" == "false" ]]; then
        log INFO "[智算引擎] 判断侦测用户硬限制阻断规则 [GEMINI_DIRECT=false]，分流策略已下放强推给 ISP 解锁组件集。"
        get_fallback_proxy
        return
    elif [[ "${GEOIP_INFO:-}" =~ (香港|Hong|HK|中国|China|CN|俄罗斯|Russia|RU|澳门|Macao|MO) ]]; then
        log WARN "[智算引擎] 识别到当前物理节点位于 Google AI 禁区 (${GEOIP_INFO%%|*})，强制剥夺直连切入代理模式！"
        get_fallback_proxy
        return
    elif [[ "${IP_TYPE:-unknown}" == "isp" ]]; then
        log INFO "[智算引擎] 评估基建属性隶属于信任 Residential (家用) 类型区域，判断无须代理阻断过滤网，全面通行许可直连。"
        echo "direct"
        return
    fi
    local check_rs=$(http_probe "https://gemini.google.com/app" "true")
    if [[ "$check_rs" =~ ^(2|3) ]]; then
        log INFO "[智算引擎] Gemini 服务连接响应健康，保留本机直通。 (Code: $check_rs)"
        echo "direct"
    else
        log WARN "[智算引擎] 验证 Gemini 遭遇受限返回 (Code: $check_rs)，且非住宅 IP，涉 AI 请求强送 ISP 主机处理。"
        get_fallback_proxy
    fi
}

# 综合统筹决定最主要的提供商出口选路策略
get_isp_preferred_strategy() {
    log DEBUG "流转至系统主节点级网关路由评估总核决算点..."
    if [[ -n "${ISP_TAG:-}" && "${ISP_TAG:-}" != "direct" ]]; then
        echo "${ISP_TAG}"
        return
    else
        echo "direct"
        return
    fi
}

# 读取并同步远程配置
decryptSecretsEnv() {
    local base_url="https://raw.githubusercontent.com/currycan/key/master"
    local items=( "tmp.bin:${SECRET_FILE}" )

    checkRequiredEnv DECODE
    for item in "${items[@]}"; do
        local file="${item#*:}"
        if [ -f "$file" ]; then
            log DEBUG "本地加密秘钥资源块验证 ($file) 检测正常合规，绕开拉取命令。"
            continue
        fi

        mkdir -p "$(dirname "$file")"
        log INFO "搭建底层保密安全通道下发远端安全核心套件组配置 => [$file]"
        curl -fsSLo /tmp/tmp.bin "${base_url}/${item%%:*}" || { log ERROR "[致命错误] 网络模块遭受严重故障致核心凭证阻断丢失！装填中断，暂停启动流。"; exit 1; }

        crypctl decrypt -i /tmp/tmp.bin -o "$file" -k "${DECODE}" || { log ERROR "[解密终止] 文件解析或密码验证失败，禁止执行无授权的服务进程。终止系统。 "; exit 1; }
        rm -f /tmp/tmp.bin
        log INFO "[$file] 核心参数信息还原入本地工作链上下文。"
    done
    log INFO "各类型加密安全文件证书已解构部署完善。"
}

# 挂载 8K 速率评估相关逻辑
CurlARG="-s --connect-timeout 5"
usePROXY=""

speed_test() {
    local url=$1
    local name=$2
    show_progress "正在执行 $name 下载测速"
    local speed=$(curl -s ${CurlARG} -L -o /dev/null -m 5 -w '%{speed_download}' "$url" 2>/dev/null)
    local speed_mbps=$(awk -v s="$speed" 'BEGIN { printf "%.2f", s * 8 / 1024 / 1024 }')
    end_progress
    echo "$speed_mbps"
}

show_report() {
    local speed=$1
    local display_name=${2:-$([[ -n "$usePROXY" ]] && echo "$usePROXY" || echo "直连")}
    local status=""
    local color=""

    speed=$(echo "$speed" | sed 's/[^0-9.]//g')
    if [ "$(echo "$speed > 100" | bc 2>/dev/null)" = "1" ]; then
        status="极速！流畅播放 8K (HDR/60fps)"; color=$GREEN
    elif [ "$(echo "$speed > 60" | bc 2>/dev/null)" = "1" ]; then
        status="流畅播放 8K 视频"; color=$GREEN
    elif [ "$(echo "$speed > 25" | bc 2>/dev/null)" = "1" ]; then
        status="流畅播放 4K 视频，8K 可能卡顿"; color=$YELLOW
    elif [ "$(echo "$speed > 10" | bc 2>/dev/null)" = "1" ]; then
        status="基本满足 1080P/4K，8K 无法播放"; color=$YELLOW
    else
        status="网络较慢，不建议观看高清视频"; color=$RED
    fi
    echo -e "========================================"
    echo -e " 8K 视频播放能力体检报告"
    echo -e "========================================"
    echo -e "代理设置   : ${display_name}"
    echo -e "测速结果   : ${BOLD}${color}${speed} Mbps${NC}"
    echo -e "播放建议   : ${BOLD}${color}${status}${NC}"
    echo -e "----------------------------------------"
    echo -e "评级参考:"
    echo -e "  > 100 Mbps  : 流畅 8K Ultra HD"
    echo -e "  > 60  Mbps  : 推荐 8K"
    echo -e "  > 25  Mbps  : 推荐 4K"
    echo -e "========================================"
}

analyze_base_env() {
    log INFO "==== 系统环境常量池及物理底座基础环境侦测期 ===="

    mkdir -p "$(dirname "${ENV_FILE}")" && touch "${ENV_FILE}"
    source "${ENV_FILE}"

    # 状态盘加载 (解决旧状态落盘污染导致各服务封锁测速异常的问题，结合用户自定义持久化以达到极速复跑)
    mkdir -p "$(dirname "${STATUS_FILE}")" && touch "${STATUS_FILE}"
    source "${STATUS_FILE}"

    local -a p_vars=(
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
        "STRATEGY|detect_ip_strategy_api"
        "GEOIP_INFO|get_geo_info"
        "IS_BRUTAL|check_brutal_status"
        "SUB_STORE_FRONTEND_BACKEND_PATH|echo /$(generateRandomStr path 32)"
        "IP_TYPE|check_ip_type"
    )

    log INFO "阶段 ①/3: 解析运算长效随机特征口令及探测底座宿主机物理 IP 属性..."
    for entry in "${p_vars[@]}"; do
        IFS='|' read -r key cmd <<< "$entry"
        # 物理/系统级基础属性：全面归由持久化系统盘维护（/.envs/xray）
        # 包括 UUID、GEOIP_INFO、IP_TYPE、STRATEGY、IS_BRUTAL 等，以避免每次重启容器造成毫无意义的冗余测漏与接口拖累
        ensure_var "$key" "$cmd"
    done
}

analyze_ai_routing_env() {
    log INFO "==== 流媒体及 AI 引擎测通结算与安全计算期 ===="

    local -a ai_media_vars=(
        "CHATGPT_OUT|check_chatgpt_access"
        "NETFLIX_OUT|check_netflix_access"
        "DISNEY_OUT|check_disney_access"
        "YOUTUBE_OUT|check_youtube_access"
        "GEMINI_OUT|check_gemini_access"
        "CLAUDE_OUT|check_claude_access"
        "SOCIAL_MEDIA_OUT|check_social_media_access"
        "TIKTOK_OUT|check_tiktok_access"
        "ISP_OUT|get_isp_preferred_strategy"
    )

    log INFO "阶段 ②/3: 发射智能探测游标对业务方实施高维度审查..."
    for v in "${ai_media_vars[@]}"; do
        IFS='|' read -r key cmd <<< "$v"
        # 充分利用已外挂的 STATUS 文件优势，如果系统内存已成功载入该环境变量，即刻跳过无需阻断式重新摸底
        if [[ -n "${!key:-}" ]]; then
            log DEBUG ">> 命中系统原生挂载缓存 [${key}=${!key}]。跳过探针重新发起评测任务。"
            continue
        fi
        local val=$(eval "$cmd")
        export "$key"="$val"
        sed -i "/^export ${key}=/d" "${STATUS_FILE}" 2>/dev/null || true
        echo "export ${key}='${val}'" >> "${STATUS_FILE}"
        log DEBUG "运行变量 [$key] 初始化完成，载入内存上下文，映射值: ${val}"
    done

    log INFO "阶段 ③/3: 下达系统密码学认证基础组件并运算所需 DH、Keys 等凭据安全基阵库..."
    ensure_key_pair "Reality" "xray x25519" "XRAY_REALITY_PRIVATE_KEY" "XRAY_REALITY_PUBLIC_KEY"
    ensure_key_pair "MLKEM768" "xray mlkem768" "XRAY_MLKEM768_SEED" "XRAY_MLKEM768_CLIENT"

    log_summary_box "IP_TYPE" "ISP_TAG" "IS_8K_SMOOTH" "ISP_OUT" "CHATGPT_OUT" "NETFLIX_OUT" "DISNEY_OUT" "YOUTUBE_OUT" "GEMINI_OUT" "CLAUDE_OUT" "TIKTOK_OUT" "SOCIAL_MEDIA_OUT"
}

# ==============================================================================
# 📌 扇区三：安全层及证书发放 (Phase 2: Certificate Issuance)
# ==============================================================================
issueCertificate() {
    local name="$1" params="$2"
    local first_dom="${params%%:*}"
    local cert="${SSL_PATH}/${name}.crt" key="${SSL_PATH}/${name}.key" ca="${SSL_PATH}/${name}-ca.crt"

    if [[ -f "$cert" && -f "$key" && -f "$ca" ]]; then
        if openssl x509 -checkend 604800 -noout -in "$cert" >/dev/null 2>&1; then
            log INFO "系统合规性查询: 数字签发证书 [$name] 仍富含冗余生命周期(>7Days)，免除重新轮换消耗策略。"
            return 0
        else
            log WARN "系统合规性预警: 发现凭证 [$name] 快将到达废弃销毁阈期，挂载安全接口启动应急在线续签重装预案！"
        fi
    fi

    if ! acme.sh --list | grep -q "${first_dom}"; then
        log INFO "为满足新生网域，正在连接权威外网 CA 端获取其网络签发公钥认证资料集流..."
        checkRequiredEnv "ACMESH_SERVER_NAME" "ACMESH_REGISTER_EMAIL" "ALI_KEY" "ALI_SECRET" "CF_TOKEN" "CF_ZONE_ID" "CF_ACCOUNT_ID"

        export Ali_Key="${ALI_KEY}" Ali_Secret="${ALI_SECRET}" CF_Token="${CF_TOKEN}" CF_Zone_ID="${CF_ZONE_ID}" CF_Account_ID="${CF_ACCOUNT_ID}"
        log INFO "请求验证申请云端下发的 TLS 数字加密准入颁公章中: [$name]..."

        local reg_args=("-m" "${ACMESH_REGISTER_EMAIL}" "--server" "${ACMESH_SERVER_NAME}")

        if [[ "${ACMESH_SERVER_NAME}" == "google" ]]; then
            if [[ -z "${ACMESH_EAB_KID:-}" || -z "${ACMESH_EAB_HMAC_KEY:-}" ]]; then
                log ERROR "校验中止: 如果选择机构下设为 Google CA，则要求用户部署时提供商用 EAB 参数 (ACMESH_EAB_KID 等密钥值)！"
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

        acme.sh "${args[@]}" || { log ERROR "Acme 请求生成失败。受不可抗力服务器可能拒收服务操作申请。"; return 1; }
    fi

    log INFO "凭证更新获取成功完成验证重安装挂接绑定。准备通过重构唤发重新挂接核心服务应用进程..."
    rm -f /etc/nginx/conf.d/* /etc/nginx/stream.d/*
    acme.sh --install-cert --ecc -d "${first_dom}" --key-file "$key" --fullchain-file "$cert" --ca-file "$ca" --reloadcmd "/usr/sbin/nginx"

    /usr/sbin/nginx -s quit 2>/dev/null && rm -f /var/run/nginx/nginx.pid || true
}


# ==============================================================================
# 📌 扇区四：服务端控制面及配置生成 (Phase 3: Server Configurations)
# ==============================================================================

# 构建仅有优胜者节点底层引擎出站 JSON（改写为使用 cat <<EOF，避免反斜杠地狱）
process_single_isp() {
    local prefix=$1 ip=$2 port=$3 user=$4 pass=$5 tag=$6
    log DEBUG "应用级 JSON 装载机正在按标获取中转提供商底座核心参数并渲染 => 对应系统标识 [Tag: ${tag}]"

    # 构建 Xray Format
    export CUSTOM_OUTBOUNDS=$(cat <<EOF
{
  "tag": "${tag}",
  "protocol": "socks",
  "settings": {
    "servers": [
      {
        "address": "${ip}",
        "port": ${port},
        "users": [
          {
            "user": "${user}",
            "pass": "${pass}"
          }
        ]
      }
    ]
  }
},
EOF
)

    # 构建 Sing-Box Format
    export SB_CUSTOM_OUTBOUNDS=$(cat <<EOF
{
  "type": "socks",
  "tag": "${tag}",
  "server": "${ip}",
  "server_port": ${port},
  "username": "${user}",
  "password": "${pass}"
},
EOF
)
}

createConfig() {
    log INFO "==== 流转系统控制权，执行架构引擎模块动态编译及实体文件的最终部署渲染 ===="
    local env_list; env_list=$(env | grep -v '^_' | cut -d= -f1 | sed 's/^/${/;s/$/}/' | xargs)
    export RANDOM_NUM=$(shuf -i 0-9 -n 1)

    apply_tpl() {
        local src="$1" dest="$2" extra_env="${3:-}"
        log DEBUG "模板替换引擎: 解析渲染配置模板 [$src]  ===> 实体组件落地 => [$dest]"
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
            log ERROR "[格式解析损毁] JSON 转化时遭到异常变量注射破损。系统实行强回退覆盖: $dest"
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
    apply_tpl "/templates/providers/providers.yaml"     "${WORKDIR}/providers"

    for t in /templates/xray/*.json; do apply_tpl "$t" "${WORKDIR}/xray/$(basename "$t")"; done
    for t in /templates/sing-box/*.json; do apply_tpl "$t" "${WORKDIR}/sing-box/$(basename "$t")"; done

    log INFO "内部逻辑服务器控制面组件网关系统参数结构体输出均配置合成构建完毕。"
}


# ==============================================================================
# 📌 扇区五：客户端输出与管控呈现 (Phase 4: Client Configurations)
# ==============================================================================

# 代理选路调度与基线验证体系 (合并于源脚本逻辑)
evaluate_isp_and_build_client_config() {
    local prefix=$1 ip=$2 port=$3 user=$4 pass=$5 tag=$6
    log INFO "启动针对 [${prefix}] 中继环境通过真实 Socks5 测试物理传输压力与突发流承压..."
    local old_curl_arg=${CurlARG:-}
    CurlARG="$old_curl_arg -x socks5h://${ip}:${port} --proxy-user ${user}:${pass}"
    local speed_val=$(speed_test "https://speed.cloudflare.com/__down?bytes=25000000" "${prefix}")
    log INFO "节点性能测回统计汇报完成，极限测试收值录为 -> ${speed_val} Mbps"
    show_report "$speed_val" "${prefix}" >&2
    CurlARG=$old_curl_arg

    if [ "$(echo "$speed_val > ${proxy_max_speed:-0}" | bc 2>/dev/null)" = "1" ]; then
        export proxy_max_speed=$speed_val
        export FASTEST_PROXY_TAG="$tag"
        log INFO "[排行调度] 当前网络链路中拔得承压测速头筹锚点为: ${FASTEST_PROXY_TAG} (${proxy_max_speed} Mbps)"
    fi
}

apply_isp_routing_logic() {
    log INFO "正在开启网络优先分发层决策链结算逻辑..."
    local manual_isp_tag=""
    if [[ -n "${DEFAULT_ISP:-}" ]]; then
        manual_isp_tag="proxy-$(echo "${DEFAULT_ISP%_ISP}" | tr '[:upper:]_ ' '[:lower:]-')"
    fi

    if [[ -n "${manual_isp_tag:-}" ]]; then
        log INFO "[核心决断定准] 根据全局系统静态强制化覆写 [DEFAULT_ISP=${DEFAULT_ISP}] 强制指向中极代理: $manual_isp_tag。"
        export ISP_TAG="$manual_isp_tag"
    elif [[ "${GEOIP_INFO:-}" =~ (香港|Hong|HK|中国|China|CN|俄罗斯|Russia|RU|澳门|Macao|MO) ]]; then
        if [[ -n "${first_tag:-}" ]]; then
            log WARN "[核心决断定准] 识别到当前物理节点位于特殊业务风控强受限区 (${GEOIP_INFO%%|*})，强制剥全链路夺直连权切入中继代理: ${first_tag}。"
            export ISP_TAG="${first_tag}"
        else
            log ERROR "[核心决断定准] 位于风控强受限区 (${GEOIP_INFO%%|*}) 但未配置任何后备 ISP 跳板提供商！"
            export ISP_TAG="direct"
        fi
    elif [[ "${IP_TYPE:-unknown}" != "isp" ]] && [[ -n "${FASTEST_PROXY_TAG:-}" ]]; then
        log INFO "[核心决断定准] 非家庭宽带环境 (${IP_TYPE})，强制选用测速最优代理接管 ISP_TAG: ${FASTEST_PROXY_TAG}"
        export ISP_TAG="${FASTEST_PROXY_TAG}"
    elif [[ -n "${FASTEST_PROXY_TAG:-}" && ("$(echo "${proxy_max_speed:-0} > ${DIRECT_SPEED:-0}" | bc 2>/dev/null)" == "1" || "$(echo "${DIRECT_SPEED:-0} < 60" | bc 2>/dev/null)" == "1") ]]; then
        log INFO "[核心决断定准] 获取吞吐带宽比较数据，全速代理接管链路: ${FASTEST_PROXY_TAG} | 最高性能估值: ${proxy_max_speed} Mbps"
        export ISP_TAG="${FASTEST_PROXY_TAG}"
    else
        log INFO "[核心决断定准] 系统原装直传优先。"
        export ISP_TAG="direct"
    fi

    if [[ "${ISP_TAG:-}" != "direct" && -z "${ISP_TAG:-}" && -n "${first_tag:-}" ]]; then
        export ISP_TAG="$first_tag"
        log WARN "[熔断机制容错] 缺失全部对比或者正常结算数值！为了自保启动应急容转到第一个存活的节点 ($ISP_TAG) 接管！"
    fi

    # 计算 8K 流畅度 (IS_8K_SMOOTH)
    if [[ "${IP_TYPE:-unknown}" == "isp" ]]; then
        # 住宅 IP 强制以 直连能力 作为 8K 流畅评估标准
        if [ "$(echo "${DIRECT_SPEED:-0} > 60" | bc 2>/dev/null)" = "1" ]; then export IS_8K_SMOOTH="true"; else export IS_8K_SMOOTH="false"; fi
    else
        # 机房 IP 则取决于它实际使用的出口
        if [[ "${ISP_TAG:-}" == "direct" ]]; then
            if [ "$(echo "${DIRECT_SPEED:-0} > 60" | bc 2>/dev/null)" = "1" ]; then export IS_8K_SMOOTH="true"; else export IS_8K_SMOOTH="false"; fi
        else
            if [ "$(echo "${proxy_max_speed:-0} > 60" | bc 2>/dev/null)" = "1" ]; then export IS_8K_SMOOTH="true"; else export IS_8K_SMOOTH="false"; fi
        fi
    fi

    # 强制斩断遗留项以保持单体写入，状态变量全部沉淀于持久化系统盘
    sed -i '/^export IS_8K_SMOOTH=/d' "${ENV_FILE}" 2>/dev/null || true
    sed -i '/^export ISP_TAG=/d' "${ENV_FILE}" 2>/dev/null || true

    echo "export IS_8K_SMOOTH='${IS_8K_SMOOTH:-false}'" >> "${ENV_FILE}"
    echo "export ISP_TAG='${ISP_TAG:-}'" >> "${ENV_FILE}"

    if [ -n "${ISP_TAG:-}" ]; then
        log INFO "路由分接定级部署敲定。突破阻拦核心配置指派标签名 -> 系统统一切换为：${GREEN}${ISP_TAG:-}${NC}"
    fi
}

# 装配主干测速持久化存储引擎
run_speed_tests_if_needed() {
    log INFO "==== 发起系统多节点探测雷达与全局通信带宽物理极限探测轮巡体系 ===="

    if [[ -n "${ISP_TAG:-}" ]]; then
        log INFO ">> 命中持久化状态变量！当前环境预存 ISP_TAG=[${ISP_TAG}]。跳过耗时测速。 <<"
        return
    fi
    log INFO ">> 环境状态表不齐或触发首次测速。系统进入深度极限带宽轮询环节... <<"

    unset ISP_TAG TOP_ISP_TAG proxy_max_speed FASTEST_PROXY_TAG IS_8K_SMOOTH DIRECT_SPEED
    export proxy_max_speed=0
    local first_tag=""

    local env_vars=$(env | grep "_ISP_IP=" | cut -d= -f1)

    export DIRECT_SPEED=0
    log INFO "首先以本机无任何中继的 Direct 态下利用测试集群获取满核原直传大流拉取测录值评估！"
    DIRECT_SPEED=$(speed_test "https://speed.cloudflare.com/__down?bytes=25000000" "Direct")
    log INFO "基础测试环境指标落档记录已获取标定：成绩认定值为 ${DIRECT_SPEED} Mbps"
    show_report "${DIRECT_SPEED}" "Direct" >&2

    # 第一轮测速
    for var in $env_vars; do
        local prefix=${var%_IP} ip="${!var}"
        local port_v="${prefix}_PORT" user_v="${prefix}_USER" pass_v="${prefix}_SECRET"
        local port="${!port_v}" user="${!user_v}" pass="${!pass_v}"

        if [[ -n "$ip" && -n "$port" ]]; then
            local tag="proxy-$(echo "${prefix}" | tr '[:upper:]_ ' '[:lower:]-')"
            if [[ -z "${first_tag:-}" ]]; then
                first_tag="$tag"
                log DEBUG "挂载后备缓存防呆项首发节点项: $first_tag"
            fi
            evaluate_isp_and_build_client_config "$prefix" "$ip" "$port" "$user" "$pass" "$tag"
        fi
    done

    apply_isp_routing_logic
    log INFO "网络综合带宽物理试探评估及参数测回结果落地处理结束。"
}

# 挂载提取并进行最终系统架构及对端用户侧客户端映射生成配置
build_client_and_server_configs() {
    log INFO "==== 根据内存决断引擎参数矩阵装配渲染客户端呈现与服务端出站 JSON ===="

    export SB_SOCKS5_OUTBOUND_CONFIG="" CUSTOM_OUTBOUNDS="" SB_CUSTOM_OUTBOUNDS="" CLASH_ISP_PROXIES=""
    export clash_proxies="" surge_proxies=""

    local env_vars=$(env | grep "_ISP_IP=" | cut -d= -f1)

    # 生成客户端 Clash YAML 对等规则集配置片段
    for var in $env_vars; do
        local prefix=${var%_IP} ip="${!var}"
        local port_v="${prefix}_PORT" user_v="${prefix}_USER" pass_v="${prefix}_SECRET"
        local port="${!port_v}" user="${!user_v}" pass="${!pass_v}"

        if [[ -n "$ip" && -n "$port" ]]; then
            local name_prefix="${prefix%_ISP}"
            local c_yaml="  - name: ${name_prefix}-dialer
    type: socks5
    server: ${ip}
    port: ${port}
    username: ${user}
    password: ${pass}
    udp: true
    dialer-proxy: 链式前置"

            local surge_ini="${name_prefix}-dialer = socks5, ${ip}, ${port}, username=${user}, password=${pass}, udp-relay=true"

            if [ -z "$clash_proxies" ]; then
                clash_proxies="${c_yaml}"
                surge_proxies="${surge_ini}"
            else
                clash_proxies="${clash_proxies}
${c_yaml}"
                surge_proxies="${surge_proxies}
${surge_ini}"
            fi
        fi
    done
    export CLASH_ISP_PROXIES="${clash_proxies}"
    export SURGE_ISP_PROXIES="${surge_proxies}"

    # 安装特定指纹选定的冠军级服务端 JSON 通配逻辑块
    export CUSTOM_OUTBOUNDS="" SB_CUSTOM_OUTBOUNDS=""
    if [[ -n "${ISP_TAG:-}" && "${ISP_TAG:-}" != "direct" ]]; then
        for var in $env_vars; do
            local prefix=${var%_IP}
            local tag="proxy-$(echo "${prefix}" | tr '[:upper:]_ ' '[:lower:]-')"
            if [[ "$tag" == "${ISP_TAG:-}" ]]; then
                local ip="${!var}"
                local port_v="${prefix}_PORT" user_v="${prefix}_USER" pass_v="${prefix}_SECRET"
                local port="${!port_v}" user="${!user_v}" pass="${!pass_v}"

                export ISP_IP="$ip" ISP_PORT="$port" ISP_USER="$user" ISP_SECRET="$pass"
                log INFO "系统萃取被认可获授的主力出海源 [${ISP_TAG}] 数据集配置结构化编入核心工作网底层。"
                process_single_isp "$prefix" "$ip" "$port" "$user" "$pass" "$tag"
                break
            fi
        done
    fi
    log INFO "网络决策中枢以及对端服务端/客户端策略化输出组件渲染阶段宣告终结。"
}


# 提供商网络环境组建
generateProxyProvidersConfig() {
    log INFO "准备装接组建提供对外的 Providers 供接库集成规则数据化配置组集映射..."
    local provider_config="${WORKDIR}/providers"
    local clash_providers=""

    if [ -f "$provider_config" ]; then
        log DEBUG "分离解读本地物理存在 providers 定义映射挂载。开始分解并提纯规则。"
        local content
        content=$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' -e '/^providers:/d' -e '/^proxy-providers:/d' "$provider_config")
        [ -n "$content" ] && clash_providers="${content}"
    else
        log WARN "监测反馈：并未于所指向工作栈下 ${WORKDIR}/providers 捕获外部的源提供拓展应用组，该流程中断略过。"
    fi

    if [ -n "${PROVIDERS:-}" ]; then
        log DEBUG "介入执行来自外挂参量 (PROVIDERS) 配置拆包的二次分拣封装作业..."
        local env_content
        env_content=$(echo "$PROVIDERS" | awk -F'|' '
            NF>=2 && $1!="" && $2!="" {
                suffix = ""
                if ($3 != "") suffix = " [" $3 "]"
                printf "  %s: {<<: *BaseProvider, url: \"%s\", override: {additional-prefix: \"[%s] \", additional-suffix: \"%s\"}}\n", $1, $2, $1, suffix
            }
        ')
        if [ -n "$env_content" ]; then
            if [ -n "$clash_providers" ]; then
                clash_providers="${clash_providers}\n${env_content}"
            else
                clash_providers="${env_content}"
            fi
            log INFO "附加外送拓展环境所提供源代理库项目数据群列处理完并纳入生产队列！"
        fi
    fi

    export CLASH_PROXY_PROVIDERS="${clash_providers}"

    # Surge 采用 Policy-Path 结构，如:
    # 机场名称 = smart, policy-path=https://.../raw/AllOne-Surge, update-interval=86400, no-alert=0, hidden=1, include-all-proxies=0
    # 依据整理后的 clash_providers 统一列表，过滤提取链接并将其组装成 .ini 格式
    local surge_providers=""
    if [ -n "${clash_providers}" ]; then
        surge_providers=$(echo "$clash_providers" | awk -F":" '
            $0 ~ /url:/ {
                name = $1
                gsub(/^[ \t]+|[ \t]+$/, "", name)

                # 用户要求配置 surge 只需要 AllOne 机场
                if (name != "AllOne") {
                    next
                }

                match($0, /url:[ \t]*"[^"]+"/)
                if (RSTART > 0) {
                    url_part = substr($0, RSTART, RLENGTH)
                    match(url_part, /"[^"]+"/)
                    url = substr(url_part, RSTART + 1, RLENGTH - 2)
                    sub(/-Common$/, "-Surge", url)
                    sub(/-common$/, "-Surge", url)
                    printf "%s = smart, policy-path=%s, update-interval=86400, no-alert=0, hidden=1, include-all-proxies=0\n", name, url
                }
            }
        ')
    fi
    export SURGE_PROXY_PROVIDERS="${surge_providers}"

    local surge_names=""
    if [ -n "${surge_providers}" ]; then
        surge_names=$(echo "$surge_providers" | awk -F'=' '{print $1}' | awk '{$1=$1};1' | paste -sd "," -)
        if [ -n "$surge_names" ]; then
            surge_names=", ${surge_names}"
        fi
    fi
    export SURGE_PROVIDER_NAMES="${surge_names}"

    # Stash 模板使用 use: [provider1, provider2] 引用节点，需提取所有 provider 名称
    local stash_names=""
    if [ -n "${clash_providers}" ]; then
        stash_names=$(echo "${clash_providers}" | awk -F':' 'NF>=2 && $1 !~ /^[[:space:]]*#/ {name=$1; gsub(/^[ \t]+|[ \t]+$/, "", name); if (name != "") print name}' | paste -sd ", " -)
    fi
    export STASH_PROVIDER_NAMES="${stash_names}"
}


# ==============================================================================
# 大主干系统运行中枢引擎处理区 (Main Controller Initialization)
# ==============================================================================
main_init() {
    log INFO "────────────────────────────────────────────────────────────────"
    log INFO "  ▶ SB-Xray 控制体系初始化微核子程序 (Startup Pipeline) 部署接入 ◀ "
    log INFO "────────────────────────────────────────────────────────────────"

    log INFO "[步骤 1] 分区生成并注册关键挂接环境的物理支撑映射组件组和依赖存储底座架构库..."
    mkdir -p ${LOGDIR}/{supervisor,xray,sing-box,dufs,nginx,x-ui,s-ui} "${SUI_DB_FOLDER}" "${SUB_STORE_DATA_BASE_PATH}"

    log INFO "[步骤 2] 调用密文环境对云保密网节点系统组认证通道获取、脱壳解析挂接动作处理..."
    decryptSecretsEnv
    source "${SECRET_FILE}"

    log INFO "[步骤 3] 检测读取在持久盘驻存留存下来的服务状态集并向环境上下文实施还原作业缓存..."
    if [ -f "${ENV_FILE}" ]; then
        log DEBUG "侦测到持久化状态文件 ${ENV_FILE}，准备读取环境参数。"
        source "${ENV_FILE}"
    fi

    log INFO "[步骤 3.5] 部署常量参数池与物理本机属性(IP_TYPE等)的提前探针识别..."
    analyze_base_env

    log INFO "[步骤 4] 开展大模型多级提供商云代理的链路穿透测速以及持久化防堵测速写入作业..."
    run_speed_tests_if_needed

    log INFO "[步骤 5] 执行上层 AI 解锁判定探测，与参数体系全局依赖网络闭环..."
    analyze_ai_routing_env

    log INFO "[步骤 5.5] 对接提取渲染处理供上层及用户侧面板使用的客户端 YAML / JSON 实体文件数据组..."
    build_client_and_server_configs

    log DEBUG "---- 本地核心被分配或检测记录后当前有效环境变量集摘要总览视图 ----"
    while IFS= read -r line; do
        log DEBUG "├─ ■ [变量注入] => ${line}"
    done < "${ENV_FILE}"
    log DEBUG "------------------------------------------------------------------"

    log INFO "[步骤 6] 调校安全加密签批组件请求建立和派发公钥网络证书及全体系域名授权保障控制服务..."
    issueCertificate "sb_xray_bundle" "${DOMAIN}:dns_ali|${CDNDOMAIN}:dns_cf"

    log INFO "[步骤 7] 处理执行密文级别算法，强制运算符合严苛安全基准保障加密协议强度的底层 DH 套件基配..."
    local dh_file="/etc/nginx/dhparam/dhparam.pem"
    if [ ! -f "$dh_file" ]; then
        mkdir -p "$(dirname "$dh_file")"
        openssl dhparam -dsaparam -out "$dh_file" 4096 && log INFO "高级严格准入门槛的系统 DH Parameters 参数生成计算闭环完毕挂装。"
    else
        log DEBUG "探测发现已保存合规要求范围生命期内的套件库避免强制损毁开销！"
    fi

    log INFO "[步骤 8] 取交核对路由分网组件底栈关键网络分流判别的全局访问路由系统控制系统（Geosite/IP库）！"
    /scripts/geo_update.sh

    log INFO "[步骤 9] 取交控制面板与路由网规则渲染对发于外界分发节点的 YAML 与组配 JSON 源包映射执行装填！"
    createConfig
    generateProxyProvidersConfig

    log INFO "[步骤 10] 初始化拉取业务核心交互微界面(如 X-UI / S-UI)管理组及生成挂装认证准入验证组件配置工作！"
    log INFO "  > 系统微服编排调度：载入 X-UI 工具节点初始化状态装机指令上下文执行分配..."
    x-ui setting -username "${PUBLIC_USER}" -password "${PUBLIC_PASSWORD}" -port "${XUI_LOCAL_PORT}" -webBasePath "${XUI_WEBBASEPATH}" >/dev/null

    log INFO "  > 系统微服编排调度：生成装载维护 S-UI 的 SQLite 环境模型并部署业务接口安全口径..."
    sui setting -port "${SUI_PORT}" -subPort "${SUI_SUB_PORT}" -path "/${SUI_WEBBASEPATH}" -subPath "/${SUI_SUB_PATH}" >/dev/null
    sui admin -password "${PUBLIC_PASSWORD}" -username "${PUBLIC_USER}" >/dev/null
    [ -f "${SUI_DB_FOLDER}/s-ui.db" ] && sqlite3 "${SUI_DB_FOLDER}/s-ui.db" "UPDATE settings SET value='https://${DOMAIN}/${SUI_SUB_PATH}/' WHERE key='subURI';"

    log INFO "[步骤 11] 构建组配最外边界防护及请求导流管理基础核心模块(Nginx & Fail2ban)入侵审查和限制规则环境！"
    local HTPASSWD_FILE="/etc/nginx/.htpasswd"
    if [ -n "${PUBLIC_USER:-}" ] && [ -n "${PUBLIC_PASSWORD:-}" ]; then
        local ENCRYPTED_PASS
        ENCRYPTED_PASS=$(openssl passwd -apr1 "${PUBLIC_PASSWORD}")
        echo "${PUBLIC_USER}:${ENCRYPTED_PASS}" > "${HTPASSWD_FILE}"
        chmod 644 "${HTPASSWD_FILE}"
        log INFO "已应用外部服务门禁组件启用生成基于 HTTP Basic Auth 基本反爆拦截的授权门系统管控。(系统主理人: ${PUBLIC_USER})"
    else
        log WARN "安全降级通知: 环境获取由于没获取对应最高授权者基本准入信息密码，主动拆除放弃组件验证门限组建立动作保持空门直出裸环境建立！"
    fi

    log INFO "指令派生：申请向平台核心控制申请挂起侦探防渗包管理控制工具调入 Fail2ban 规则框架环境体系的常驻防护层..."
    fail2ban-client -x start >/dev/null || log WARN "内核交互失联拦截: 调拨命令 Fail2ban 处理包反馈启动系统失误缺失回应。监控策略将无效丢失环境监管体系支撑构建。"

    log INFO "[步骤 12] 后台支撑应用装配常规自动检测防瘫或数据更迭系统业务到调度管控核心 Cron 定点清单维护模块！"
    local cron_file="/var/spool/cron/crontabs/root"
    touch "$cron_file"
    sed -i '/geo_update.sh/d' "$cron_file"
    echo "0 3 * * * /scripts/geo_update.sh >> /var/log/geo_update.log 2>&1" >> "$cron_file"
    chmod 0600 "$cron_file"
    log INFO "例时日常安全与路由数据生态保障环境挂机维护系统编入中心保存建立！"

    [[ ! -f "/usr/local/bin/show" ]] && ln -sf "/scripts/show-config.sh" "/usr/local/bin/show"

    log INFO "全节点业务核心构件环境构建终点到达。交付系统核心运行托管权限前的最后汇总数据呈现结果播报板： "
    /usr/local/bin/show

    log INFO "────────────────────────────────────────────────────────────────"
    log INFO "  ✅ 系统业务链模块组件均已核准。移交管理特权给中心引擎 Supervisord 进行平台看管工作起动...    "
    log INFO "────────────────────────────────────────────────────────────────"
}

if [ "${1#-}" = 'supervisord' ] && [ "$(id -u)" = '0' ]; then
    main_init
    set -- "$@" -n -c /etc/supervisord.conf
fi

exec "$@"
