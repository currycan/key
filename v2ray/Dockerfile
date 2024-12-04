FROM currycan/acme.sh:1.0.4

LABEL maintainer="andrew <ansandy@foxmail.com>"

# # glibc
ARG glibc_version=2.35-r1
RUN set -ex; \
  apk add --update --no-cache libstdc++; \
  wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub; \
  for pkg in glibc-${glibc_version} glibc-bin-${glibc_version} glibc-i18n-${glibc_version}; \
  do \
  curl -sSL https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${glibc_version}/${pkg}.apk -o /tmp/${pkg}.apk; \
  done; \
  apk add /tmp/*.apk; \
  ( /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 C.UTF-8 || true ); \
  echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh; \
  /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib; \
  /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8; \
  apk del --no-network glibc-i18n; \
  rm -rf /tmp/* /var/cache/apk/*

RUN set -ex; \
  runtime_pkgs="bash-completion gettext supervisor tzdata vim nginx openrc ca-certificates libqrencode libqrencode-dev"; \
  apk add -U --no-cache ${runtime_pkgs}; \
  update-ca-certificates; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

ARG v2ray_version="v5.22.0"
RUN set -ex; \
  build_pkgs="unzip"; \
  apk add -U --no-cache ${build_pkgs}; \
  cd /tmp; \
  wget -nc --no-check-certificate "https://github.com/v2fly/v2ray-core/releases/download/${v2ray_version}/v2ray-linux-64.zip"; \
  unzip -q v2ray-linux-64.zip -d .; \
  mv v2ray /usr/local/bin/; \
  mv geoip.dat /usr/local/bin/; \
  mv geosite.dat /usr/local/bin/; \
  rm -rf /tmp/*; \
  apk del ${build_pkgs}; \
  rm -rf /var/cache/apk/*

# xray
ARG xray_version="24.11.30"
RUN set -ex; \
  build_pkgs="unzip"; \
  apk add -U --no-cache ${build_pkgs}; \
  cd /tmp; \
  wget -nc --no-check-certificate "https://github.com/XTLS/Xray-core/releases/download/v${xray_version}/Xray-linux-64.zip"; \
  unzip -q Xray-linux-64.zip -d .; \
  mv /tmp/xray /usr/local/bin/; \
  wget -O /usr/local/bin/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat; \
  wget -O /usr/local/bin/geoip.dat https://github.com/v2fly/geoip/releases/latest/download/geoip.dat; \
  rm -rf /tmp/*; \
  apk del ${build_pkgs}; \
  rm -rf /var/cache/apk/*

# x-ui
ARG xui_version="2.4.8"
RUN set -ex; \
  apk add -U --no-cache fail2ban; \
  rm -f /etc/fail2ban/jail.d/alpine-ssh.conf; \
  cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local; \
  sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local; \
  sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local; \
  sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf; \
  cd /tmp; \
  wget -nc --no-check-certificate "https://github.com/MHSanaei/3x-ui/releases/download/v${xui_version}/x-ui-linux-amd64.tar.gz"; \
  tar zxf x-ui-linux-amd64.tar.gz; \
  rm -f /tmp/x-ui/bin/{LICENSE,README.md}; \
  cp -a /tmp/x-ui/bin/*_*.dat /usr/local/bin/; \
  cp -a /tmp/x-ui/x-ui /usr/local/bin/; \
  mv /tmp/x-ui/bin /usr/local/bin/; \
  rm -rf /var/cache/apk/*; \
  rm -rf /tmp/*

# dufs
ARG dufs_version="0.43.0"
RUN set -ex; \
  cd /tmp; \
  wget -nc --no-check-certificate "https://github.com/sigoden/dufs/releases/download/v${dufs_version}/dufs-v${dufs_version}-x86_64-unknown-linux-musl.tar.gz"; \
  tar zxf dufs-v${dufs_version}-x86_64-unknown-linux-musl.tar.gz; \
  mv /tmp/dufs /usr/local/bin/; \
  rm -rf /var/cache/apk/*; \
  rm -rf /tmp/*

RUN apk add -U --no-cache gcompat || echo 0 && rm -rf /tmp/* /var/cache/apk/*

# COPY config/supervisord.conf /v2ray/config/supervisord.conf
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY 3DCEList /home/wwwroot/3DCEList
COPY templates/ /templates/
COPY script/ /

# normal script
RUN set -ex; \
  chmod 750 /*.sh; \
  chmod 750 /*.py; \
  ln -sf /nginx-chkconfig.sh /etc/init.d/nginx; \
  ln -sf /show-config.sh /usr/local/bin/show; \
  rc-update add nginx default

# crontab for certification
RUN set -ex;\
  echo "0 3 * * 0 sh /ssl_update.sh" >> /var/spool/cron/crontabs/root;

ENV TZ="Asia/Hong_Kong"
ENV DOMAIN="abc.com"
ENV LISTENING_PORT="443"

# v2ray
ENV ALTERID="0"
ENV NETWORK="ws"

# xray
ENV XRAY_NETWORK="tcp"
ENV SECURITY="reality"
ENV FLOW="xtls-rprx-vision"
ENV XVER=0
ENV DEST_HOST="www.microsoft.com"
ENV DEST_PORT="443"

# x-ui
ENV XUI_LOG_LEVEL="info"
ENV XUI_DEBUG="false"
ENV XUI_LOG_FOLDER="/var/log/x-ui"
ENV XUI_WEBBASEPATH="x-ui"
ENV XUI_ACCOUNT="admin"
ENV XUI_PORT="4333"

# dufs
ENV DUFS_SERVE_PATH="/data"
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

# Letsencrypt.org 0
# BuyPass.com 1
# ZeroSSL.com 2
# Google Public CA 3
ENV SSLRegisterEmail="ansandy@foxmail.com"
ENV SSL_PROVIDER = 0
ENV GoogleEABId=''
ENV GoogleEABKey=''
ENV SSL_PATH="/pki"

WORKDIR /v2ray/config

EXPOSE 80 443

VOLUME ["/pki", "/acme.sh", "/var/log/v2ray", "/var/log/xray", "/var/log/dufs", "/var/log/nginx", "/var/log/supervisor"]

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/entrypoint.sh" ]
CMD  [ "supervisord" ]
