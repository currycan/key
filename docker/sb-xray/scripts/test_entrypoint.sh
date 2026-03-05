#!/usr/bin/env bash
# ==============================================================================
# test_entrypoint.sh — entrypoint.sh 单元测试套件（红绿测试）
#
# 用法: bash scripts/test_entrypoint.sh
# 说明: 通过 source 加载被测脚本，逐组验证核心函数行为。
#       重构前运行 → 验证 bug 存在（红）
#       重构后运行 → 全部通过（绿）
# ==============================================================================

set -uo pipefail

PASS=0; FAIL=0
_TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$_TEST_TMPDIR"' EXIT

# ==============================================================================
# 断言工具
# ==============================================================================
assert_eq() {
    local desc=$1 expected=$2 actual=$3
    if [[ "$actual" == "$expected" ]]; then
        echo "  ✓ ${desc}"; (( PASS++ )) || true
    else
        echo "  ✗ ${desc}"
        echo "    期望: '${expected}'"
        echo "    实际: '${actual}'"
        (( FAIL++ )) || true
    fi
}

assert_match() {
    local desc=$1 pattern=$2 actual=$3
    if [[ "$actual" =~ $pattern ]]; then
        echo "  ✓ ${desc}"; (( PASS++ )) || true
    else
        echo "  ✗ ${desc}"
        echo "    期望匹配: '${pattern}'"
        echo "    实际:     '${actual}'"
        (( FAIL++ )) || true
    fi
}

assert_not_empty() {
    local desc=$1 actual=$2
    if [[ -n "$actual" ]]; then
        echo "  ✓ ${desc}"; (( PASS++ )) || true
    else
        echo "  ✗ ${desc} (结果为空)"; (( FAIL++ )) || true
    fi
}

# ==============================================================================
# Mock 外部命令（防止真实网络调用与系统依赖）
# ==============================================================================
curl()    { :; }                                                   # 默认空实现，各测试组按需覆盖
xray()    {
    case "${1:-}" in
        uuid)     echo "mock-uuid-$(date +%s)" ;;
        x25519)   printf "Private key: mock-priv-key\nPublic key: mock-pub-key\n" ;;
        mlkem768) printf "Seed: mock-seed\nClient: mock-client\n" ;;
    esac
}
openssl() { echo "mock-openssl-output"; }
jq()      { cat; }

# ==============================================================================
# 加载被测脚本（source 模式：BASH_SOURCE 保护跳过 exec）
# ==============================================================================
ENV_FILE="${_TEST_TMPDIR}/sb-xray.env"
SECRET_FILE="${_TEST_TMPDIR}/secret"
STATUS_FILE="${_TEST_TMPDIR}/status.env"
touch "$ENV_FILE" "$STATUS_FILE"

# shellcheck source=scripts/entrypoint.sh
source "$(dirname "$0")/entrypoint.sh"

# ==============================================================================
# T1  http_probe — 无 eval，参数数组方式调用
# ==============================================================================
echo ""
echo "▶ [T1] http_probe"

curl() { echo "HTTP/2 200"; }
assert_eq "T1-1: 返回 HTTP 200" "200" "$(http_probe "https://example.com")"

curl() { echo "HTTP/1.1 404 Not Found"; }
assert_eq "T1-2: 返回 HTTP 404" "404" "$(http_probe "https://example.com")"

curl() { :; }
assert_eq "T1-3: 超时返回 Timeout" "Timeout" "$(http_probe "https://example.com")"

curl() { echo "HTTP/1.1 200 OK"; }
assert_eq "T1-4: follow_redirect=true 返回 200" "200" "$(http_probe "https://example.com" "true")"

# ==============================================================================
# T2  ensure_var — 三种分支（含修复验证）
# ==============================================================================
echo ""
echo "▶ [T2] ensure_var"

# T2-1: 变量未在 env 也不在文件 → 执行命令并写入文件
unset TEST_VAR_A
> "$ENV_FILE"
ensure_var TEST_VAR_A echo "hello"
assert_eq     "T2-1: 命令执行后变量已 export"     "hello" "${TEST_VAR_A:-}"
assert_match  "T2-1: 变量已写入 ENV_FILE"          "TEST_VAR_A" "$(cat "$ENV_FILE")"

# T2-2: 变量已在文件中但未在当前 shell → 应从文件加载（核心 bug 修复验证）
#        原代码仅 grep 检查文件，不重新 export，导致变量仍为空
unset TEST_VAR_B
echo "export TEST_VAR_B='from_file'" >> "$ENV_FILE"
ensure_var TEST_VAR_B echo "should_not_run"
assert_eq "T2-2: 从文件加载（不重复执行命令）" "from_file" "${TEST_VAR_B:-}"

# T2-3: 变量已在当前 shell → 直接跳过
export TEST_VAR_C="already_set"
ensure_var TEST_VAR_C echo "should_not_override"
assert_eq "T2-3: 已在 env 中则跳过" "already_set" "${TEST_VAR_C:-}"

# T2-4: --no-persist 不写文件
unset TEST_VAR_D
> "$ENV_FILE"
ensure_var TEST_VAR_D --no-persist echo "mem_only"
assert_eq    "T2-4: --no-persist 变量已 export"   "mem_only" "${TEST_VAR_D:-}"
assert_eq    "T2-4: --no-persist 不写入文件"        "" "$(grep 'TEST_VAR_D' "$ENV_FILE" || true)"

# ==============================================================================
# T3  generateRandomStr
# ==============================================================================
echo ""
echo "▶ [T3] generateRandomStr"

assert_match "T3-1: port 在 32000-38000" "^3[2-7][0-9]{3}$|^38000$" "$(generateRandomStr port)"

xray() { echo "mock-uuid-1234"; }
assert_match "T3-2: uuid 非空" "." "$(generateRandomStr uuid)"

pw=$(generateRandomStr password 16)
assert_eq    "T3-3: password 长度 16"              "16" "${#pw}"
assert_match "T3-4: password 含字母数字"            "^[A-Za-z0-9]+$" "$pw"

pt=$(generateRandomStr path 32)
assert_eq    "T3-5: path 长度 32"                  "32" "${#pt}"
assert_match "T3-6: path 仅含小写字母和数字"        "^[a-z0-9]+$" "$pt"

# ==============================================================================
# T4  apply_isp_routing_logic — 各选路分支
# ==============================================================================
echo ""
echo "▶ [T4] apply_isp_routing_logic"

_reset_routing() {
    unset ISP_TAG IS_8K_SMOOTH FASTEST_PROXY_TAG proxy_max_speed DIRECT_SPEED \
          DEFAULT_ISP GEOIP_INFO IP_TYPE first_tag 2>/dev/null || true
    > "$ENV_FILE"
}

# T4-1: DEFAULT_ISP 手动覆盖
_reset_routing
export DEFAULT_ISP="MYISP_ISP" DIRECT_SPEED=30 proxy_max_speed=0
first_tag="proxy-fallback"
apply_isp_routing_logic
assert_eq "T4-1: DEFAULT_ISP 强制覆盖" "proxy-myisp" "${ISP_TAG:-}"

# T4-2: 受限地区 + first_tag 存在 → 使用 first_tag
_reset_routing
export GEOIP_INFO="中国|1.2.3.4" IP_TYPE="hosting" DIRECT_SPEED=50 proxy_max_speed=0
first_tag="proxy-first"
apply_isp_routing_logic
assert_eq "T4-2: 受限地区使用 first_tag" "proxy-first" "${ISP_TAG:-}"

# T4-3: 非住宅 IP + 有最优代理 → 使用最优代理
_reset_routing
export GEOIP_INFO="US|1.2.3.4" IP_TYPE="hosting" FASTEST_PROXY_TAG="proxy-best" \
       proxy_max_speed=80 DIRECT_SPEED=30
first_tag=""
apply_isp_routing_logic
assert_eq "T4-3: 非住宅 IP 使用最优代理" "proxy-best" "${ISP_TAG:-}"

# T4-4: 住宅 IP + 直连够快 → direct
_reset_routing
export GEOIP_INFO="SG|1.2.3.4" IP_TYPE="isp" DIRECT_SPEED=80 proxy_max_speed=0
first_tag=""
apply_isp_routing_logic
assert_eq "T4-4: 住宅 IP 直连" "direct" "${ISP_TAG:-}"

# T4-5: 代理快于直连 → 使用代理
_reset_routing
export GEOIP_INFO="SG|1.2.3.4" IP_TYPE="isp" FASTEST_PROXY_TAG="proxy-fast" \
       proxy_max_speed=100 DIRECT_SPEED=30
first_tag=""
apply_isp_routing_logic
assert_eq "T4-5: 代理更快时使用代理" "proxy-fast" "${ISP_TAG:-}"

# T4-6: 原 L754 死代码修复验证
#        原条件: `ISP_TAG != "direct" && -z ISP_TAG && first_tag` — 但 if-else 已保证 ISP_TAG 非空
#        修复后: `if [[ -z ISP_TAG && -n first_tag ]]` 永远不应在 else 之后命中
#        此处直接调用 apply_isp_routing_logic 并检查 ISP_TAG 被正确设为 "direct"（无 first_tag 情况）
_reset_routing
export GEOIP_INFO="SG|1.2.3.4" IP_TYPE="isp" DIRECT_SPEED=50 proxy_max_speed=0
first_tag=""
apply_isp_routing_logic
assert_eq "T4-6: 无代理无 first_tag → direct" "direct" "${ISP_TAG:-}"

# ==============================================================================
# T5  IS_8K_SMOOTH 计算
# ==============================================================================
echo ""
echo "▶ [T5] IS_8K_SMOOTH"

# T5-1: 住宅 IP + 直连 >60 → true
_reset_routing
export IP_TYPE="isp" DIRECT_SPEED=80 proxy_max_speed=0
first_tag=""
apply_isp_routing_logic
assert_eq "T5-1: 住宅 IP 直连 >60 → smooth=true" "true" "${IS_8K_SMOOTH:-}"

# T5-2: 机房 IP + 代理 >60 → true
_reset_routing
export GEOIP_INFO="SG|1.2.3.4" IP_TYPE="hosting" FASTEST_PROXY_TAG="proxy-x" \
       proxy_max_speed=100 DIRECT_SPEED=20
first_tag=""
apply_isp_routing_logic
assert_eq "T5-2: 机房 IP 代理 >60 → smooth=true" "true" "${IS_8K_SMOOTH:-}"

# T5-3: 直连 <60 且无代理 → false
_reset_routing
export IP_TYPE="isp" DIRECT_SPEED=30 proxy_max_speed=0
first_tag=""
apply_isp_routing_logic
assert_eq "T5-3: 直连 <60 → smooth=false" "false" "${IS_8K_SMOOTH:-}"

# ==============================================================================
# T6  speed_test — 无全局 CurlARG 污染
# ==============================================================================
echo ""
echo "▶ [T6] speed_test"

# Mock curl 返回模拟字节速率（bytes/sec），3145728 ≈ 25 Mbps
curl() { echo "3145728"; }

result=$(speed_test "https://example.com/__down" "TestDirect")
assert_not_empty "T6-1: 直连测速返回非空" "$result"
assert_match     "T6-2: 直连测速返回数值"  "^[0-9]+\.[0-9]+$" "$result"

# 代理测速：验证代理参数被正确传递，不改变全局状态
result_proxy=$(speed_test "https://example.com/__down" "TestProxy" "socks5h://1.2.3.4:1080" "user:pass")
assert_not_empty "T6-3: 代理测速返回非空" "$result_proxy"
assert_match     "T6-4: 代理测速返回数值" "^[0-9]+\.[0-9]+$" "$result_proxy"

# 验证两次调用结果相同（无全局 CurlARG 污染）
result2=$(speed_test "https://example.com/__down" "TestDirect2")
assert_eq "T6-5: 代理测速后直连结果不变（无全局污染）" "$result" "$result2"

# ==============================================================================
# T7  ensure_key_pair
# ==============================================================================
echo ""
echo "▶ [T7] ensure_key_pair"

unset TEST_KEY1 TEST_KEY2
> "$ENV_FILE"
xray() { printf "Private key: mock-priv-key\nPublic key: mock-pub-key\n"; }

ensure_key_pair "TestAlgo" "xray x25519" "TEST_KEY1" "TEST_KEY2"
assert_eq "T7-1: KEY1 已 export"    "mock-priv-key" "${TEST_KEY1:-}"
assert_eq "T7-2: KEY2 已 export"    "mock-pub-key"  "${TEST_KEY2:-}"
assert_match "T7-3: KEY1 写入文件"  "TEST_KEY1"     "$(cat "$ENV_FILE")"

# 再次调用不应重新生成：从文件加载
unset TEST_KEY1 TEST_KEY2
_xray_call_count=0
xray() { (( _xray_call_count++ )) || true; printf "Private key: NEW-priv\nPublic key: NEW-pub\n"; }
ensure_key_pair "TestAlgo" "xray x25519" "TEST_KEY1" "TEST_KEY2"
assert_eq "T7-4: 已存在时从文件加载" "mock-priv-key" "${TEST_KEY1:-}"
assert_eq "T7-5: 已存在时不调用生成命令" "0" "${_xray_call_count}"

# ==============================================================================
# T8  _is_restricted_region
# ==============================================================================
echo ""
echo "▶ [T8] _is_restricted_region"

export GEOIP_INFO="中国|1.2.3.4"
_is_restricted_region && assert_eq "T8-1: 中国 → 受限" "0" "0" || assert_eq "T8-1: 中国 → 受限" "受限" "未受限"

export GEOIP_INFO="US|1.2.3.4"
_is_restricted_region && assert_eq "T8-2: 美国 → 未受限" "未受限" "受限" || assert_eq "T8-2: 美国 → 未受限" "0" "0"

export GEOIP_INFO="香港|1.2.3.4"
_is_restricted_region && assert_eq "T8-3: 香港 → 受限" "0" "0" || assert_eq "T8-3: 香港 → 受限" "受限" "未受限"

# ==============================================================================
# 汇总
# ==============================================================================
echo ""
echo "════════════════════════════════════════"
echo "  测试结果:  ✓ ${PASS} 通过   ✗ ${FAIL} 失败"
echo "════════════════════════════════════════"
echo ""
(( FAIL == 0 ))
