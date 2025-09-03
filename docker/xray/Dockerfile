FROM golang:1.25-alpine AS builder

WORKDIR /app

RUN apk --no-cache --update add \
  build-base \
  curl \
  git \
  gcc \
  wget \
  unzip

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"

ARG XUI_VERSION=v2.6.6
ARG XRAY_VERSION="25.8.3"
ARG V2RAY_VERSION="5.38.0"

COPY --chmod=755 install.sh /usr/local/bin/
RUN set -ex; \
  git clone --recursive --depth 1 --shallow-submodules --branch ${XUI_VERSION} https://github.com/MHSanaei/3x-ui /app/xui; \
  cd /app/xui && go build -ldflags "-w -s" -o build/x-ui main.go; \
  git clone --filter=blob:none --no-checkout https://github.com/currycan/key.git /app/key; \
  cd /app/key && git checkout HEAD -- docker/crypctl; \
  cd /app/key/docker/crypctl; \
  go build -ldflags "-w -s" -o crypctl main.go; \
  install.sh

FROM docker.io/currycan/nginx:1.29.1

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 系统级配置（时区/镜像源）
RUN set -ex; \
  # sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  echo "Asia/Hong_Kong" > /etc/timezone

# 安装基础组件
RUN set -ex; \
  runtime_pkgs="curl bash iproute2 net-tools tzdata bash-completion ca-certificates python3 py3-pip gettext libc6-compat gcompat vim libqrencode-tools socat logrotate"; \
  apk add -U --no-cache --virtual .runtime-deps ${runtime_pkgs}; \
  echo -e "[global]\nbreak-system-packages = true" > /etc/pip.conf; \
  pip install --no-cache-dir -U pip supervisor; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

# 安装 acme.sh
ENV AUTO_UPGRADE=1
ENV LE_WORKING_DIR=/acme.sh
ENV LE_CONFIG_HOME=/acmecerts
RUN set -ex && wget -O- https://get.acme.sh | sh

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

COPY --from=builder --chmod=755 /app/xui/build/ /usr/local/bin/
COPY --from=builder --chmod=755 /app/key/docker/crypctl/crypctl /usr/local/bin/
COPY --from=builder --chmod=755 /app/v2ray/v2ray /usr/local/bin/
COPY --from=builder --chmod=755 /usr/local/bin/dufs /usr/local/bin/
COPY nginx/ /etc/nginx/
COPY 3DCEList /home/wwwroot/3DCEList
COPY --chmod=755 scripts /scripts
COPY templates/ /templates/
ADD https://raw.githubusercontent.com/currycan/key/master/vimrc /root/.vimrc

# xray
RUN set -ex; \
  ln -sf /usr/local/bin/bin/xray* /usr/local/bin/xray; \
  cp -a /usr/local/bin/bin/*.dat /usr/local/bin/

# time zone
ENV TZ="Asia/Hong_Kong"

# xray
ENV DEST_HOST="www.microsoft.com"
ENV PATH=/acme.sh/:$PATH
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
# ali/cf
# for cf
ENV CF_TOKEN=""
ENV CF_ZONE_ID=""
ENV CF_ACCOUNT_ID=""
# for ali
ENV ALI_KEY=""
ENV ALI_SECRET=""
# certs path
ENV SSL_PATH="/pki"

# x-ui
ENV XUI_LOG_LEVEL="info"
ENV XUI_DEBUG="false"
ENV XUI_LOG_FOLDER="/var/log/x-ui"
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

# WORKDIR /xray/

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD supervisorctl -c /etc/supervisord/all.conf status xray | grep -q 'RUNNING' || exit 1

EXPOSE 80 443

VOLUME ["/data", "/pki", "/acmecerts", "/etc/supervisord", "/etc/xray/conf", "/etc/v2ray", "/etc/dufs", "/etc/x-ui/","/etc/nginx/conf.d", "/etc/nginx/stream.d", "/etc/nginx/dhparam", "/var/log/xray", "/var/log/v2ray","/var/log/x-ui", "/var/log/dufs", "/var/log/nginx", "/var/log/supervisor"]

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
CMD  [ "supervisord" ]
