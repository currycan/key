#!/bin/bash
set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 辅助函数: 获取 GitHub API Token 头 (如果有 GITHUB_TOKEN 环境变量)
get_auth_header() {
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "-H \"Authorization: token $GITHUB_TOKEN\""
    else
        echo ""
    fi
}

# 辅助函数: 执行 CURL 请求 (处理错误并返回空字符串)
fetch_url() {
    local url=$1
    local token_header=""
    if [ -n "$GITHUB_TOKEN" ]; then
        token_header="-H 'Authorization: token $GITHUB_TOKEN'"
    fi

    # 打印 URL 到 stderr 用于调试
    echo -e "${BLUE}[GET] ${url}${NC}" >&2

    # 执行请求，出错时返回空，不中止脚本 (|| echo "")
    # 使用 eval 处理带空格的 header 参数
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -sSf -H "Authorization: token $GITHUB_TOKEN" "$url" 2>/dev/null || echo ""
    else
        curl -sSf "$url" 2>/dev/null || echo ""
    fi
}

# 辅助函数: 获取最新 Release Tag
get_latest_release() {
    local repo=$1
    local url="https://api.github.com/repos/$repo/releases/latest"
    local response=$(fetch_url "$url")

    if [ -n "$response" ]; then
        echo "$response" | jq -r '.tag_name'
    else
        echo ""
    fi
}

# 辅助函数: 获取最新 Tag
get_latest_tag() {
    local repo=$1
    local url="https://api.github.com/repos/$repo/tags"
    local response=$(fetch_url "$url")

    if [ -n "$response" ]; then
        echo "$response" | jq -r '.[0].name'
    else
        echo ""
    fi
}

# 辅助函数: 获取最新 Stable Tag
get_latest_stable_tag() {
    local repo=$1
    local url="https://api.github.com/repos/$repo/tags?per_page=100"
    local response=$(fetch_url "$url")

    if [ -n "$response" ]; then
        echo "$response" | jq -r '[.[] | select(.name | test("rc|beta|alpha") | not)] | .[0].name'
    else
        echo ""
    fi
}

echo -e "${BLUE}开始获取最新版本信息...${NC}"

# 获取各组件版本
SHOUTRRR_TAG=$(get_latest_release "containrrr/shoutrrr")
MIHOMO_TAG=$(get_latest_release "MetaCubeX/mihomo")
HTTP_META_VERSION=$(get_latest_release "xream/http-meta")
SUB_STORE_FRONTEND_VERSION=$(get_latest_release "sub-store-org/Sub-Store-Front-End")
SUB_STORE_BACKEND_VERSION=$(get_latest_release "sub-store-org/Sub-Store")
SUI_TAG=$(get_latest_release "alireza0/s-ui")
DUFS_TAG=$(get_latest_stable_tag "sigoden/dufs")
CLOUDFLARED_VERSION=$(get_latest_stable_tag "cloudflare/cloudflared")
XUI_TAG=$(get_latest_stable_tag "MHSanaei/3x-ui")
SING_BOX_TAG=$(get_latest_stable_tag "SagerNet/sing-box")
XRAY_TAG=$(get_latest_tag "XTLS/Xray-core")

# 处理版本号并构建 Docker 参数
BUILD_ARGS=""

# 检查版本函数
# 参数:
# $1 = 组件显示名称
# $2 =获取到的版本号 (可能带 v 前缀)
# $3 = Docker build-arg 变量名
check_version() {
    local name=$1
    local version=$2
    local arg_name=$3

    if [ -z "$version" ] || [ "$version" == "null" ]; then
        printf "%-25s ${RED}获取失败! 停止构建${NC}\n" "${name}:"
        exit 1
    else
        # 去除 'v' 前缀
        clean_version=${version#v}
        printf "%-25s ${GREEN}%s${NC}\n" "${name}:" "${clean_version}"
        BUILD_ARGS="${BUILD_ARGS} --build-arg ${arg_name}=${clean_version}"

        # 特殊处理: Xray 版本用于镜像 Tag
        if [ "$name" == "Xray" ]; then
            XRAY_VERSION_FINAL=$clean_version
        fi
    fi
}

check_version "Shoutrrr" "$SHOUTRRR_TAG" "SHOUTRRR_VERSION"
check_version "Mihomo" "$MIHOMO_TAG" "MIHOMO_VERSION"
check_version "Http-Meta" "$HTTP_META_VERSION" "HTTP_META_VERSION"
check_version "Sub-Store Front" "$SUB_STORE_FRONTEND_VERSION" "SUB_STORE_FRONTEND_VERSION"
check_version "Sub-Store Back" "$SUB_STORE_BACKEND_VERSION" "SUB_STORE_BACKEND_VERSION"
check_version "s-ui" "$SUI_TAG" "SUI_VERSION"
check_version "Dufs" "$DUFS_TAG" "DUFS_VERSION"
check_version "Cloudflared" "$CLOUDFLARED_VERSION" "CLOUDFLARED_VERSION"
check_version "3x-ui" "$XUI_TAG" "XUI_VERSION"
check_version "Sing-box" "$SING_BOX_TAG" "SING_BOX_VERSION"
check_version "Xray" "$XRAY_TAG" "XRAY_VERSION"

# 确定镜像 Tag (如果 Xray 获取失败，则回退到 'manual')
if [ -z "$XRAY_VERSION_FINAL" ]; then
    echo -e "${YELLOW}警告: 无法获取 Xray 版本用于 Tag。将使用 'manual' 作为 Tag。${NC}"
    TAG_VERSION="manual"
else
    TAG_VERSION=$XRAY_VERSION_FINAL
fi

echo -e "${BLUE}开始构建 Docker 镜像...${NC}"
echo -e "Tags: currycan/sb-xray:${TAG_VERSION}, currycan/sb-xray:latest"

# 构建命令
# shellcheck disable=SC2086
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  $BUILD_ARGS \
  --tag currycan/sb-xray:${TAG_VERSION} \
  --tag currycan/sb-xray:latest \
  --push .
