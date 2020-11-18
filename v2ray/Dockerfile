FROM currycan/acme.sh:1.0.0

LABEL maintainer="andrew <ansandy@foxmail.com>"

RUN set -ex; \
  runtime_pkgs="bash bash-completion gettext supervisor tzdata vim"; \
  apk add -U --no-cache ${build_pkgs} ${runtime_pkgs}; \
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

ARG glibc_version="2.32-r0"
ARG nginx_version="1.19.4"
ARG jemalloc_version="5.2.1"
RUN set -ex; \
  build_pkgs="build-base linux-headers openssl-dev pcre-dev zlib-dev gcc g++ make libffi-dev libtool"; \
  runtime_pkgs="ca-certificates libstdc++ openssl pcre zlib nss socat "; \
  apk add -U --no-cache ${build_pkgs} ${runtime_pkgs}; \
  cd /tmp; \
  wget -q -O /etc/apk/keys/sgerrand.rsa.pub "https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub"; \
  wget -nc --no-check-certificate "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${glibc_version}/glibc-${glibc_version}.apk"; \
  wget -nc --no-check-certificate "http://nginx.org/download/nginx-${nginx_version}.tar.gz"; \
  wget -nc --no-check-certificate "https://github.com/jemalloc/jemalloc/releases/download/${jemalloc_version}/jemalloc-${jemalloc_version}.tar.bz2"; \
  apk add glibc-${glibc_version}.apk; \
  mkdir -p /etc/ld.so.conf.d/; \
  echo "include /etc/ld.so.conf.d/*.conf" > /etc/ld.so.conf; \
  tar -xf jemalloc-${jemalloc_version}.tar.bz2; \
  tar -zxf nginx-${nginx_version}.tar.gz; \
  cd /tmp/jemalloc-${jemalloc_version}; \
  ./configure; \
  THREAD=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l); \
  make -j ${THREAD} && make install; \
  echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf; \
  ldconfig /etc/ld.so.conf.d; \
  cd /tmp/nginx-${nginx_version}; \
  ./configure --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --user=nginx \
  --group=nginx \
  --with-http_ssl_module \
  --with-http_gzip_static_module \
  --with-http_stub_status_module \
  --with-pcre \
  --with-http_realip_module \
  --with-http_flv_module \
  --with-http_mp4_module \
  --with-http_secure_link_module \
  --with-http_v2_module \
  --with-cc-opt='-O3' \
  --with-ld-opt="-ljemalloc"; \
  make -j ${THREAD} && make install; \
  adduser -D nginx; \
  apk del ${build_pkgs}; \
  rm -rf /tmp/*; \
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
  apk add -U --no-cache openrc; \
  rc-update add nginx default; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

ENV TZ="Asia/Hong_Kong"
ENV DOMAIN="baidu.com"
ENV LISTENING_PORT="443"
# ENV V2RAY_PORT="34567"
# ENV VMESS_ID="c87153c0-ff7a-4039-a69f-89aa4a46c9a9"
ENV ALTERID="88"
ENV NETWORK="ws"
# ENV URL_PATH="/2ba84920/"
ENV CERT_PATH="/pki/v2ray.crt"
ENV KEY_PATH="/pki/v2ray.key"

ARG v2ray_version="v4.32.1"
RUN set -ex; \
  build_pkgs="unzip"; \
  apk add -U --no-cache ${build_pkgs}; \
  apk add -U --no-cache libqrencode libqrencode-dev; \
  cd /tmp; \
  wget -nc --no-check-certificate "https://github.com/v2fly/v2ray-core/releases/download/${v2ray_version}/v2ray-linux-64.zip"; \
  unzip -q v2ray-linux-64.zip -d .; \
  mv v2ray /usr/local/bin/; \
  mv v2ctl /usr/local/bin/; \
  mv geoip.dat /usr/local/bin/; \
  mv geosite.dat /usr/local/bin/; \
  echo "0 3 * * 0 sh /ssl_update.sh" >> /var/spool/cron/crontabs/root; \
  rm -rf /tmp/*; \
  apk del ${build_pkgs}; \
  rm -rf /var/cache/apk/*

WORKDIR /v2ray/config

EXPOSE 80 443

VOLUME ["/pki", "/acme.sh", "/var/log/v2ray", "/var/log/nginx"]

STOPSIGNAL SIGTERM

ENTRYPOINT [ "/entrypoint.sh" ]
CMD  [ "supervisord" ]
