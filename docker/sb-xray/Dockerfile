# ===== sub-store =====
# https://github.com/sub-store-org/Sub-Store
ARG SUB_STORE_BACKEND_VERSION="2.21.21"
FROM xream/sub-store:${SUB_STORE_BACKEND_VERSION}-http-meta AS substore

FROM node:alpine AS sub-store-front-builder

RUN apk add --no-cache git

WORKDIR /app/sub-store-frontend

ENV SUB_STORE_WEBBASEPATH="sub-store"

ARG SUB_STORE_FRONTEND_VERSION="2.16.13"
COPY --from=substore /opt/app /sub-store
RUN set -ex; \
  if [ -z "$SUB_STORE_FRONTEND_VERSION" ]; then \
    SUI_VERSION=$(curl -sSf https://api.github.com/repos/sub-store-org/Sub-Store-Front-End/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/'); \
  fi; \
  git clone --depth 1 --branch ${SUB_STORE_FRONTEND_VERSION} https://github.com/sub-store-org/Sub-Store-Front-End /app/sub-store-frontend; \
  npm install -g pnpm; \
  pnpm install --frozen-lockfile; \
  VITE_PUBLIC_PATH="/${SUB_STORE_WEBBASEPATH}/" pnpm run build; \
  rm -rf /sub-store/frontend; \
  mv /app/sub-store-frontend/dist /sub-store/frontend

# ===== s-ui frontend builder =====
FROM node:alpine AS s-ui-front-builder

RUN apk add --no-cache git

ARG SUI_VERSION="1.3.9"
RUN set -ex; \
  if [ -z "$SUI_VERSION" ]; then \
    SUI_VERSION=$(curl -sSf https://api.github.com/repos/alireza0/s-ui/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/'); \
  fi; \
  git clone --depth 1 --branch v${SUI_VERSION} https://github.com/alireza0/s-ui /app/s-ui; \
  git clone --depth 1 --branch main https://github.com/alireza0/s-ui-frontend /app/s-ui-frontend; \
  cd /app/s-ui-frontend && npm install && npm run build; \
  mv /app/s-ui-frontend/dist /app/s-ui/web/html

FROM golang:1-alpine AS builder

ARG TARGETARCH
ARG TARGETVARIANT

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
ARG DUFS_VERSION="0.45.0"
RUN set -ex; \
  if [ -z "$DUFS_VERSION" ]; then \
    DUFS_VERSION=$(curl -sSf https://github.com/sigoden/dufs/tags \
      | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
      | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
  fi; \
  case "${TARGETARCH}" in \
    amd64)   BINARY_FILE="dufs-v${DUFS_VERSION}-x86_64-unknown-linux-musl.tar.gz";; \
    arm64)   BINARY_FILE="dufs-v${DUFS_VERSION}-arm-unknown-linux-musleabihf.tar.gz";; \
    *)       echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
  esac; \
  curl -fsSL "https://github.com/sigoden/dufs/releases/download/v${DUFS_VERSION}/${BINARY_FILE}" | tar -xzC /tmp/; \
  upx --lzma --best /tmp/dufs; \
  mv /tmp/dufs /usr/local/bin/

# ===== 安装 cloudflared =====
ARG CLOUDFLARED_VERSION="2026.2.0"
RUN set -ex; \
  if [ -z "$CLOUDFLARED_VERSION" ]; then \
    CLOUDFLARED_VERSION=$(curl -sSf https://github.com/cloudflare/cloudflared/tags \
      | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
      | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
  fi; \
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${TARGETARCH}" -o /tmp/cloudflared; \
  chmod +x /tmp/cloudflared; \
  upx --lzma --best /tmp/cloudflared; \
  mv /tmp/cloudflared /usr/local/bin/

# ===== 安装 x-ui =====
ARG XUI_VERSION="2.8.9"
RUN set -ex; \
  if [ -z "$XUI_VERSION" ]; then \
    XUI_VERSION=$(curl -sSf https://github.com/MHSanaei/3x-ui/tags \
      | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
      | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
  fi; \
  git clone --recursive --depth 1 --shallow-submodules --branch v${XUI_VERSION} https://github.com/MHSanaei/3x-ui /app/xui; \
  cd /app/xui && go build -ldflags="-s -w" -trimpath -o x-ui main.go; \
  upx --lzma --best x-ui; \
  mv x-ui /usr/local/bin/

# ===== 安装 s-ui backend =====
COPY --from=s-ui-front-builder /app/s-ui /app/s-ui
RUN set -ex; \
  cd /app/s-ui; \
  go build -ldflags="-s -w" -trimpath -tags "with_quic,with_grpc,with_utls,with_acme,with_gvisor" -o sui main.go; \
  upx --lzma --best sui; \
  mv sui /usr/local/bin/

# ===== 安装 Sing-box =====
ARG SING_BOX_VERSION="1.12.21"
RUN set -ex; \
  if [ -z "$SING_BOX_VERSION" ]; then \
    SING_BOX_VERSION=$(curl -sSf https://github.com/SagerNet/sing-box/tags \
      | grep "releases/tag/" | grep -Ev "rc|alpha|beta" \
      | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" | head -n 1); \
  fi; \
  curl -fsSL "https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-linux-${TARGETARCH}.tar.gz" | tar --strip-components=1 -xzC /tmp/; \
  upx --lzma --best /tmp/sing-box; \
  mv /tmp/sing-box /usr/local/bin/

# ===== 安装 Xray =====
ARG XRAY_VERSION="26.2.6"
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
  mkdir -p /usr/local/bin/bin; \
  mv xray /usr/local/bin/bin/xray-linux-${TARGETARCH}; \
  ln -sf /usr/local/bin/bin/xray* /usr/local/bin/xray;

FROM docker.io/currycan/nginx:1.29.4

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 系统级配置（时区/镜像源）
RUN set -ex; \
  # sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  echo "Asia/Hong_Kong" > /etc/timezone

# 安装基础组件
RUN set -ex; \
  runtime_pkgs="curl bash iproute2 net-tools tzdata bash-completion ca-certificates python3 py3-pip gettext libc6-compat gcompat vim libqrencode-tools socat logrotate nftables jq sqlite nodejs"; \
  apk add -U --no-cache --virtual .runtime-deps ${runtime_pkgs}; \
  echo -e "[global]\nbreak-system-packages = true" > /etc/pip.conf; \
  pip install --no-cache-dir -U pip supervisor; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

# 安装 acme.sh
ENV AUTO_UPGRADE=1
ENV LE_WORKING_DIR=/acme.sh
ENV LE_CONFIG_HOME=/acmecerts
ENV ACMESH_DEBUG=2
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

ENV WORKDIR=/sb-xray
ENV LOGDIR=/var/log/
ENV SUPERVISOR_LOG_MAX_BYTES="20MB"

WORKDIR ${WORKDIR}

COPY --from=builder --chmod=755 /usr/local/bin/ /usr/local/bin/
COPY --from=sub-store-front-builder /sub-store /sub-store
# ADD web.tgz /home/wwwroot/
# RUN chown -R nginx:nginx /home/wwwroot
COPY --chmod=755 scripts /scripts
COPY templates/ /templates/
COPY sources /sources
ADD https://raw.githubusercontent.com/currycan/key/master/vimrc /root/.vimrc

# time zone
ENV TZ="Asia/Singapore"

# xray
ENV DEST_HOST="www.microsoft.com"
ENV DOMAIN=""
ENV CDNDOMAIN=""
ENV LISTENING_PORT="433"

# acme.sh
ENV ACMESH_REGISTER_EMAIL=""
# zerossl/google
ENV ACMESH_SERVER_NAME="zerossl"
# certs path
ENV SSL_PATH=/pki

# 节点特性后缀
ENV NODE_SUFFIX=""

# ISP proxy
ENV ENABLE_ISP_PROXY="false"
ENV DEFAULT_ISP="LA_ISP"

# 新增provider
ENV PROVIDERS=""

# x-ui
ENV XUI_LOG_LEVEL="info"
ENV XUI_DEBUG="false"
ENV XUI_LOG_FOLDER="/x-ui/db"
ENV XUI_WEBBASEPATH="xui"
ENV XUI_ACCOUNT="admin"
ENV XUI_PORT="8888"

# s-ui
ENV SUI_LOG_LEVEL="info"
ENV SUI_DEBUG="false"
ENV SUI_PORT="3095"
ENV SUI_SUB_PORT="3096"
ENV SUI_DB_FOLDER="/s-ui/db"
ENV SUI_WEBBASEPATH="sui"
ENV SUI_SUB_PATH="sub"

# sub-store
ENV SUB_STORE_META_FOLDER="/sub-store/http-meta/"
ENV SUB_STORE_DOCKER=true
ENV SUB_STORE_FRONTEND_PATH="/sub-store/frontend/"
ENV SUB_STORE_DATA_BASE_PATH="/sub-store/data"
ENV SUB_STORE_BACKEND_API_PORT="3000"
ENV SUB_STORE_BACKEND_API_HOST="127.0.0.1"
ENV SUB_STORE_FRONTEND_PORT="3001"
ENV SUB_STORE_FRONTEND_HOST="127.0.0.1"
ENV SUB_STORE_WEBBASEPATH="sub-store"
ENV SUB_STORE_FRONTEND_BACKEND_PATH="/2cXaAxRGfddmGz2yx1wA"
ENV SUB_STORE_BACKEND_SYNC_CRON="55 23 * * *"

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

HEALTHCHECK --interval=30s --timeout=30s --start-period=15s --retries=3 \
  CMD supervisorctl status xray | grep -q 'RUNNING' || exit 1

EXPOSE 80 443

VOLUME ${DUFS_SERVE_PATH} ${WORKDIR} ${SUB_STORE_DATA_BASE_PATH} ${LOGDIR} /etc/nginx/conf.d /etc/nginx/stream.d /etc/nginx/dhparam

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
CMD  [ "supervisord" ]
