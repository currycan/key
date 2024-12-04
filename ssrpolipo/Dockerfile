FROM alpine:3.11

LABEL maintainer="andrew <ansandy@foxmail.com>"

RUN set -ex; \
  # Build environment setup
  apk add --update --no-cache --virtual .build-deps \
    git \
    texinfo \
    autoconf \
    automake \
    build-base \
    c-ares-dev \
    libintl \
    libcap \
    libev-dev \
    libsodium-dev \
    linux-headers \
    mbedtls-dev \
    pcre-dev \
    libtool \
    libstdc++ \
    iptables; \
  # Base dependencies setup
  apk add --update --no-cache  \
    curl \
    supervisor \
    tzdata; \
  # Download shadowsocks-libev source code, build and install
  SSR_VER=`curl -s https://github.com/shadowsocks/shadowsocks-libev/tags | grep "/shadowsocks/shadowsocks-libev/releases/tag/" | head -1 | sed -r 's/.*tag\/(.+)\">.*/\1/'`; \
  SSR_URL=https://github.com/shadowsocks/shadowsocks-libev/releases/download/${SSR_VER}/shadowsocks-libev-${SSR_VER:1}.tar.gz; \
  curl -fSL ${SSR_URL} | tar xz --strip-components=0 -C /tmp; \
  cd /tmp/shadowsocks-libev*; \
  curl -fSLO https://raw.githubusercontent.com/shadowsocks/shadowsocks-libev/master/autogen.sh && chmod 770 autogen.sh; \
  ./autogen.sh; \
  ./configure --prefix=/usr --disable-documentation; \
  make install; \
  ls /usr/bin/ss-* | xargs -n1 setcap cap_net_bind_service+ep; \
  # SSR runtime dependencies setup
  apk add --update --no-cache  \
  ca-certificates \
  rng-tools \
  $(scanelf --needed --nobanner /usr/bin/ss-* \
  | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
  | sort -u); \
  # Install polipo
  cd /tmp && git clone https://github.com/jech/polipo.git; \
  cd polipo && make all && make install; \
  # Set timezone
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  # Clean build dependency
  apk del --no-network .build-deps; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

COPY sources /ssrpolipo

WORKDIR /ssrpolipo/config

ENV TZ=Asia/Hong_Kong

CMD ["supervisord", "-c", "/ssrpolipo/config/supervisord.conf"]
