FROM ghcr.io/mhsanaei/3x-ui:latest AS builder

FROM currycan/acme.sh:1.0.3

LABEL maintainer="andrew <ansandy@foxmail.com>"

RUN set -ex; \
  runtime_pkgs="bash-completion gettext supervisor tzdata vim nginx openrc ca-certificates"; \
  apk add -U --no-cache ${runtime_pkgs}; \
  update-ca-certificates; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

ARG v2ray_version="v5.12.1"
RUN set -ex; \
  build_pkgs="unzip"; \
  apk add -U --no-cache ${build_pkgs}; \
  apk add -U --no-cache libqrencode libqrencode-dev; \
  cd /tmp; \
  wget -nc --no-check-certificate "https://github.com/v2fly/v2ray-core/releases/download/${v2ray_version}/v2ray-linux-64.zip"; \
  unzip -q v2ray-linux-64.zip -d .; \
  mv v2ray /usr/local/bin/; \
  mv geoip.dat /usr/local/bin/; \
  mv geosite.dat /usr/local/bin/; \
  echo "0 3 * * 0 sh /ssl_update.sh" >> /var/spool/cron/crontabs/root; \
  rm -rf /tmp/*; \
  apk del ${build_pkgs}; \
  rm -rf /var/cache/apk/*

# xray
ARG xray_version="1.8.7"
RUN set -ex; \
  build_pkgs="unzip"; \
  apk add -U --no-cache ${build_pkgs}; \
  apk add -U --no-cache libqrencode libqrencode-dev; \
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
ARG xui_version="2.1.3"
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
  mv /tmp/x-ui/bin /usr/local/bin/; \
  rm -rf /var/cache/apk/*; \
  rm -rf /tmp/*
COPY --from=builder  /app/x-ui /usr/local/bin/

COPY config/supervisord.conf /v2ray/config/supervisord.conf
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY 3DCEList /home/wwwroot/3DCEList
COPY templates/ /templates/
COPY script/ /

RUN set -ex; \
  chmod 750 /*.sh; \
  ln -sf /nginx-chkconfig.sh /etc/init.d/nginx; \
  ln -sf /show-config.sh /usr/local/bin/show; \
  rc-update add nginx default

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
ENV XUI_ACCOUNT="admin"
ENV XUI_PASSWORD=""
ENV XUI_PORT="4333"

# Letsencrypt.org 0
# BuyPass.com 1
# ZeroSSL.com 2
# Google Public CA 3
ENV SSLRegisterEmail="ansandy@foxmail.com"
ENV SSL_PROVIDER = 0
ENV GoogleEABId=''
ENV GoogleEABKey=''
ENV CERT_PATH="/pki/v2ray.crt"
ENV KEY_PATH="/pki/v2ray.key"

WORKDIR /v2ray/config

EXPOSE 80 443

VOLUME ["/pki", "/acme.sh", "/var/log/v2ray", "/var/log/xray", "/var/log/nginx"]

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/entrypoint.sh" ]
CMD  [ "supervisord" ]
