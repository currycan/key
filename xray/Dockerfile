FROM enwaiax/x-ui:latest AS builder

FROM currycan/acme.sh:1.0.3

LABEL maintainer="andrew <ansandy@foxmail.com>"

RUN set -ex; \
  runtime_pkgs="bash-completion gettext supervisor tzdata vim ca-certificates"; \
  apk add -U --no-cache ${runtime_pkgs}; \
  update-ca-certificates; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  rm -rf /tmp/*; \
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
# ARG xui_version="0.3.2"
# RUN set -ex; \
#   cd /tmp; \
#   wget -nc --no-check-certificate "https://github.com/vaxilu/x-ui/releases/download/${xui_version}/x-ui-linux-amd64.tar.gz"; \
#   tar zxf x-ui-linux-amd64.tar.gz; \
#   mv /tmp/x-ui/x-ui /usr/local/bin/; \
#   rm -rf /tmp/*
COPY --from=builder  /usr/local/bin/x-ui /usr/local/bin/

COPY config/supervisord.conf /xray/config/supervisord.conf
COPY templates/ /templates/
COPY script/ /

RUN set -ex; \
  chmod 750 /*.sh; \
  ln -sf /show-config.sh /usr/local/bin/show;

ENV TZ="Asia/Hong_Kong"
ENV DOMAIN="abc.com"

# xray
ENV XRAY_NETWORK="tcp"
ENV SECURITY="reality"
ENV FLOW="xtls-rprx-vision"
ENV XVER=0
ENV DEST_HOST="www.microsoft.com"
ENV DEST_PORT="443"

WORKDIR /xray/config

VOLUME ["/var/log/xray"]

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/entrypoint.sh" ]
CMD  [ "supervisord" ]
