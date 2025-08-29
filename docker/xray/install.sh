#!/bin/sh

detect_arch() {
    local machine_arch
    machine_arch=$(uname -m)
    case "$machine_arch" in
        x86_64)
            ARCH="64"
            FNAME="amd64"
            ;;
        i386 | i686)
            ARCH="32"
            FNAME="i386"
            ;;
        aarch64 | arm64)
            ARCH="arm64-v8a"
            FNAME="arm64"
            ;;
        armv7*)
            ARCH="arm32-v7a"
            FNAME="arm32"
            ;;
        armv6*)
            ARCH="arm32-v6"
            FNAME="armv6"
            ;;
        *)
            echo "错误: 不支持的系统架构 '$machine_arch'" >&2
            exit 1
            ;;
    esac
}

get_geo_dat() {
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
    wget -q -O geoip_IR.dat https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat
    wget -q -O geosite_IR.dat https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat
    wget -q -O geoip_RU.dat https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geoip.dat
    wget -q -O geosite_RU.dat https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geosite.dat
}

install_xray() {
    if [ -z "$XRAY_VERSION" ]; then
        XRAY_VERSION=`curl -sSf https://github.com/XTLS/Xray-core/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -o "[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
    fi
    mkdir -p /app/xui/build/bin
    cd /app/xui/build/bin
    wget -q "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${ARCH}.zip"
    unzip "Xray-linux-${ARCH}.zip"
    rm -f "Xray-linux-${ARCH}.zip" geoip.dat geosite.dat
    mv xray "xray-linux-${FNAME}"
    get_geo_dat
}

install_v2ray() {
    if [ -z "$V2RAY_VERSION" ]; then
        V2RAY_VERSION=`curl -sSf https://github.com/v2fly/v2ray-core/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -o "[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
    fi
    mkdir -p /app/v2ray
    cd /app/v2ray
    wget -q "https://github.com/v2fly/v2ray-core/releases/download/v${V2RAY_VERSION}/v2ray-linux-${ARCH}.zip"
    unzip "v2ray-linux-${ARCH}.zip"
}

install_dufs() {
    if [ -z "$DUFS_VERSION" ]; then
        DUFS_VERSION=`curl -sSf https://github.com/sigoden/dufs/tags | grep "releases/tag/" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -o "[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1`
    fi
    if [ x${FNAME} == xamd64 ]; then
        curl -fsSL "https://github.com/sigoden/dufs/releases/download/v${DUFS_VERSION}/dufs-v${DUFS_VERSION}-x86_64-unknown-linux-musl.tar.gz" | tar -xzC /tmp/
    elif [ x${FNAME} == xarm64 ]; then
        curl -fsSL "https://github.com/sigoden/dufs/releases/download/v${DUFS_VERSION}/dufs-v${DUFS_VERSION}-arm-unknown-linux-musleabihf.tar.gz" | tar -xzC /tmp/
    fi
    mv /tmp/dufs /usr/local/bin/
}

if [ -z "$ARCH" ] || [ -z "$FNAME" ]; then
    detect_arch
fi

install_xray
install_v2ray
install_dufs
