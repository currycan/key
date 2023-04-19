FROM currycan/acme.sh:1.0.2

LABEL maintainer="andrew <ansandy@foxmail.com>"

RUN set -ex; \
  runtime_pkgs="bash-completion gettext supervisor tzdata vim nginx openrc geoip geoip-dev"; \
  apk add -U --no-cache ${runtime_pkgs}; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

ARG v2ray_version="v5.4.1"
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
ENV DOMAIN="baidu.com"
ENV LISTENING_PORT="443"
# ENV V2RAY_PORT="34567"
# ENV VMESS_ID="c87153c0-ff7a-4039-a69f-89aa4a46c9a9"
ENV ALTERID="99"
ENV NETWORK="ws"
# ENV URL_PATH="/2ba84920/"
ENV CERT_PATH="/pki/v2ray.crt"
ENV KEY_PATH="/pki/v2ray.key"

WORKDIR /v2ray/config

EXPOSE 80 443

VOLUME ["/pki", "/acme.sh", "/var/log/v2ray", "/var/log/nginx"]

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/entrypoint.sh" ]
CMD  [ "supervisord" ]
