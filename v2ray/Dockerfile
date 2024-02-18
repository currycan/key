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
ENV ALTERID="99"
ENV NETWORK="ws"

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

VOLUME ["/pki", "/acme.sh", "/var/log/v2ray", "/var/log/nginx"]

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/entrypoint.sh" ]
CMD  [ "supervisord" ]
