FROM golang:1.25-alpine AS builder

ARG TARGETARCH
ARG TARGETVARIANT

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ENV http_proxy=$HTTP_PROXY
ENV https_proxy=$HTTPS_PROXY
ENV no_proxy=$NO_PROXY

RUN apk --no-cache --update add \
  ca-certificates \
  build-base \
  upx \
  curl \
  git \
  gcc \
  unzip; \
  update-ca-certificates

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"

WORKDIR /app

# ===== 安装 crypctl =====
RUN set -ex; \
  git clone --filter=blob:none --no-checkout https://github.com/currycan/key.git /app/key; \
  cd /app/key && git checkout HEAD -- docker/crypctl; \
  cd docker/crypctl && go build -ldflags="-s -w" -trimpath -o crypctl main.go; \
  upx --lzma --best crypctl; \
  mv crypctl /usr/local/bin/

# ===== 安装 Dufs =====
RUN set -ex; \
    DUFS_VERSION=$(curl -sSf https://github.com/sigoden/dufs/tags \
      | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
      | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
    case "${TARGETARCH}" in \
      amd64)   BINARY_FILE="dufs-v${DUFS_VERSION}-x86_64-unknown-linux-musl.tar.gz";; \
      arm64)   BINARY_FILE="dufs-v${DUFS_VERSION}-arm-unknown-linux-musleabihf.tar.gz";; \
      *)       echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/sigoden/dufs/releases/download/v${DUFS_VERSION}/${BINARY_FILE}" | tar -xzC /tmp/; \
    upx --lzma --best /tmp/dufs; \
    mv /tmp/dufs /usr/local/bin/

# ===== 安装 V2Ray =====
ARG V2RAY_VERSION="5.40.0"
RUN set -ex; \
    if [ -z "$V2RAY_VERSION" ]; then \
        V2RAY_VERSION=$(curl -sSf https://github.com/v2fly/v2ray-core/tags \
            | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
            | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
    fi; \
    case "${TARGETARCH}" in \
      amd64)   BINARY_FILE="v2ray-linux-64.zip";; \
      arm64)   BINARY_FILE="v2ray-linux-arm64-v8a.zip";; \
      *)       echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    mkdir -p /tmp/v2ray; \
    cd /tmp/v2ray; \
    curl -fsSLO "https://github.com/v2fly/v2ray-core/releases/download/v${V2RAY_VERSION}/${BINARY_FILE}"; \
    unzip "${BINARY_FILE}"; \
    upx --lzma --best v2ray; \
    mv v2ray /usr/local/bin/

# ===== 安装 Sing-box =====
ARG SING_BOX_VERSION="1.12.9"
RUN set -ex; \
    if [ -z "$SING_BOX_VERSION" ]; then \
        V2RAY_VERSION=$(curl -sSf https://github.com/SagerNet/sing-box/tags \
            | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
            | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
    fi; \
    curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-linux-${TARGETARCH}.tar.gz" | tar --strip-components=1 -xzC /tmp/; \
    upx --lzma --best /tmp/sing-box; \
    mv /tmp/sing-box /usr/local/bin/

# ===== 安装 cloudflared =====
ARG CLOUDFLARED_VERSION="2025.9.1"
RUN set -ex; \
    if [ -z "$CLOUDFLARED_VERSION" ]; then \
        V2RAY_VERSION=$(curl -sSf https://github.com/cloudflare/cloudflared/tags \
            | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
            | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
    fi; \
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${TARGETARCH}" -o /tmp/cloudflared; \
    chmod +x /tmp/cloudflared; \
    upx --lzma --best /tmp/cloudflared; \
    mv /tmp/cloudflared /usr/local/bin/

# ===== 安装 x-ui =====
ARG XUI_VERSION="2.8.4"
RUN set -ex; \
    if [ -z "$XUI_VERSION" ]; then \
        V2RAY_VERSION=$(curl -sSf https://github.com/MHSanaei/3x-ui/tags \
            | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
            | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
    fi; \
  git clone --recursive --depth 1 --shallow-submodules --branch v${XUI_VERSION} https://github.com/MHSanaei/3x-ui /app/xui; \
  cd /app/xui && go build -ldflags="-s -w" -trimpath -o x-ui main.go; \
  upx --lzma --best x-ui; \
  mv x-ui /usr/local/bin/

# ===== 安装 Xray =====
ARG XRAY_VERSION="25.9.11"
RUN set -ex; \
    if [ -z "$XRAY_VERSION" ]; then \
        XRAY_VERSION=$(curl -sSf https://github.com/XTLS/Xray-core/tags \
            | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
            | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
    fi; \
    case "${TARGETARCH}" in \
      amd64)   BINARY_FILE="Xray-linux-64.zip";; \
      arm64)   BINARY_FILE="Xray-linux-arm64-v8a.zip";; \
      *)       echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    mkdir -p /tmp/xray; \
    cd /tmp/xray; \
    curl -fsSLO "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/${BINARY_FILE}"; \
    unzip "${BINARY_FILE}"; \
    rm -f "${BINARY_FILE}" geoip.dat geosite.dat; \
    upx --lzma --best xray; \
    curl -fsSLO https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat; \
    curl -fsSLO https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat; \
    curl -fsSLo geoip_IR.dat https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat; \
    curl -fsSLo geosite_IR.dat https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat; \
    curl -fsSLo geoip_RU.dat https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geoip.dat; \
    curl -fsSLo geosite_RU.dat https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geosite.dat; \
    mkdir -p /usr/local/bin/bin; \
    mv xray /usr/local/bin/bin/xray-linux-${TARGETARCH}; \
    mv *.dat /usr/local/bin/bin; \
    ln -sf /usr/local/bin/bin/xray* /usr/local/bin/xray; \
    ln -sf /usr/local/bin/bin/*.dat /usr/local/bin/

FROM docker.io/currycan/nginx:1.29.2

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 系统级配置（时区/镜像源）
RUN set -ex; \
  # sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  echo "Asia/Hong_Kong" > /etc/timezone

# 安装基础组件
RUN set -ex; \
  runtime_pkgs="curl bash iproute2 net-tools tzdata bash-completion ca-certificates python3 py3-pip gettext libc6-compat gcompat vim libqrencode-tools socat logrotate nftables jq"; \
  apk add -U --no-cache --virtual .runtime-deps ${runtime_pkgs}; \
  echo -e "[global]\nbreak-system-packages = true" > /etc/pip.conf; \
  pip install --no-cache-dir -U pip supervisor; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

# 安装 acme.sh
ENV AUTO_UPGRADE=1
ENV LE_WORKING_DIR=/acme.sh
ENV LE_CONFIG_HOME=/acmecerts
ENV ACMESH_DEBUG=1
ENV PATH=/acme.sh/:$PATH
RUN set -ex && curl -L https://get.acme.sh | sh

# x-ui dependences
RUN set -ex; \
  apk add -U --no-cache fail2ban; \
  rm -f /etc/fail2ban/jail.d/alpine-ssh.conf; \
  cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local; \
  sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local; \
  sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local; \
  sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf; \
  rm -rf /var/cache/apk/*; \
  rm -rf /tmp/*

COPY --from=builder --chmod=755 /usr/local/bin/ /usr/local/bin/
COPY 3DCEList /home/wwwroot/3DCEList
COPY --chmod=755 scripts /scripts
COPY templates/ /templates/
ADD https://raw.githubusercontent.com/currycan/key/master/vimrc /root/.vimrc

ENV WORKDIR=/sb-xray
ENV LOGDIR=${WORKDIR}/logs

WORKDIR ${WORKDIR}

# time zone
ENV TZ="Asia/Hong_Kong"

# xray
ENV DEST_HOST="www.microsoft.com"
ENV DOMAIN=""
ENV CDNDOMAIN=""
ENV LISTENING_PORT="433"

# v2ray
ENV ALTERID="0"
ENV NETWORK="ws"

# acme.sh
ENV ACMESH_REGISTER_EMAIL=""
# buypass/zerossl/letsencrypt
ENV ACMESH_SERVER_NAME="letsencrypt"
# certs path
ENV SSL_PATH=/pki

# x-ui
ENV XUI_LOG_LEVEL="info"
ENV XUI_DEBUG="false"
ENV XUI_LOG_FOLDER=${LOGDIR}/x-ui
ENV XUI_WEBBASEPATH="x-ui"
ENV XUI_ACCOUNT="admin"
ENV XUI_PORT="8888"

# dufs
ENV DUFS_SERVE_PATH="/data"
ENV DUFS_PORT="8889"
ENV DUFS_BIND="0.0.0.0"
ENV DUFS_PATH_PREFIX="/dufs"
ENV DUFS_ALLOW_ALL="false"
ENV DUFS_ALLOW_UPLOAD="true"
ENV DUFS_ALLOW_DELETE="true"
ENV DUFS_ALLOW_SEARCH="true"
ENV DUFS_ALLOW_SYMLINK="true"
ENV DUFS_ALLOW_ARCHIVE="true"
ENV DUFS_ENABLE_CORS="true"
ENV DUFS_RENDER_INDEX="true"
ENV DUFS_RENDER_TRY_INDEX="true"
ENV DUFS_RENDER_SPA="true"
ENV DUFS_LOG_FORMAT=""
ENV DUFS_COMPRESS="low"

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD supervisorctl status xray | grep -q 'RUNNING' || exit 1

EXPOSE 80 443

VOLUME ${DUFS_SERVE_PATH} ${WORKDIR} ${LOGDIR} /etc/nginx/conf.d /etc/nginx/stream.d /etc/nginx/dhparam

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
CMD  [ "supervisord" ]
