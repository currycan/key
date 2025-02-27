FROM docker.io/alpine:3

# 系统级配置（时区/镜像源）
RUN set -ex; \
  # sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  echo "Asia/Hong_Kong" > /etc/timezone

# 安装基础组件
RUN set -ex; \
  runtime_pkgs="curl bash iproute2 net-tools tzdata bash-completion ca-certificates python3 nginx nginx-mod-stream openssl gettext libc6-compat gcompat vim libqrencode-tools supervisor socat logrotate"; \
  apk add -U --no-cache --virtual .runtime-deps ${runtime_pkgs}; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

# 安装 acme.sh
ENV AUTO_UPGRADE=1
ENV LE_WORKING_DIR=/acme.sh
ENV LE_CONFIG_HOME=/acmecerts
RUN set -ex && wget -O- https://get.acme.sh | sh

# dufs
ARG DUFS_VERSION="0.43.0"
RUN set -ex; \
  curl -fsSL "https://github.com/sigoden/dufs/releases/download/v${DUFS_VERSION}/dufs-v${DUFS_VERSION}-x86_64-unknown-linux-musl.tar.gz" | tar -xzC /tmp/; \
  mv /tmp/dufs /usr/local/bin/; \
  rm -rf /tmp/*

# x-ui
RUN set -ex; \
  apk add -U --no-cache fail2ban; \
  rm -f /etc/fail2ban/jail.d/alpine-ssh.conf; \
  cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local; \
  sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local; \
  sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local; \
  sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf; \
  rm -rf /var/cache/apk/*; \
  rm -rf /tmp/*
COPY --chmod=755 bin/x-ui  /usr/local/bin/x-ui
COPY --chmod=755 bin/xui-xray  /usr/local/bin/bin

# xray
ARG XRAY_VERSION="25.2.21"
RUN set -ex; \
  build_pkgs="unzip"; \
  apk add -U --no-cache --virtual .build-deps ${build_pkgs}; \
  curl -fsSLo /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip"; \
  unzip -q /tmp/xray.zip -d /tmp; \
  mv /tmp/xray /usr/local/bin/; \
  wget -O /usr/local/bin/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat; \
  wget -O /usr/local/bin/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat; \
  apk del --purge .build-deps; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

COPY --chmod=755 bin/crypctl  /usr/local/bin/crypctl
COPY nginx/network_internal.conf /etc/nginx/
COPY 3DCEList /home/wwwroot/3DCEList
COPY configs/nginx.conf /etc/nginx/nginx.conf
COPY configs/supervisord.conf /xray/config/supervisord.conf
COPY configs/logrotate.conf /etc/logrotate.conf
COPY --chmod=755 scripts /scripts
COPY templates/ /templates/
ADD https://raw.githubusercontent.com/currycan/key/master/vimrc /root/.vimrc

# time zone
ENV TZ="Asia/Hong_Kong"

# acme.sh
ENV PATH=/acme.sh/:$PATH
ENV DOMAIN=""
ENV LISTENING_PORT="433"
ENV ACMESH_REGISTER_EMAIL=""
# buypass/zerossl/google/letsencrypt
ENV ACMESH_SERVER_NAME="buypass"
ENV ZEROSSL_EAB_ID=""
ENV ZEROSSL_EAB_KEY=""
ENV GOOGLE_EAB_ID=""
ENV GOOGLE_EAB_KEY=""
ENV ALI_KEY=""
ENV ALI_SECRET=""
ENV CF_KEY=""
ENV CF_EMAIL=""
# ali/cf
ENV DNS_API="ali"
ENV SSL_PATH="/pki"

# xray
ENV DEST_HOST="www.microsoft.com"

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

WORKDIR /xray/

EXPOSE 80 443

VOLUME ["/data", "/acmecerts", "/pki", "/etc/nginx/conf.d", "/etc/nginx/stream.d", "/etc/nginx/dhparam", "/var/log/xray", "/var/log/dufs", "/var/log/nginx", "/var/log/supervisor"]

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
CMD  [ "supervisord" ]
