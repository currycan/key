FROM alpine:3.11

LABEL maintainer="andrew <ansandy@foxmail.com>"

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -S -g 1000 ssrkcp && adduser -S -G ssrkcp -u 999 ssrkcp

# Install tini su-exec and gosu
RUN set -ex; \
  apk add --update --no-cache tini su-exec; \
  apk add --update --no-cache --virtual .gosu-deps \
    curl \
    dpkg \
    gnupg \
    ca-certificates; \
  # Install gosu
  dpkgArch=`dpkg --print-architecture | awk -F- '{ print $NF }'`; \
  GOSU_VERSION=`curl -s https://github.com/tianon/gosu/tags | grep "/tianon/gosu/releases/tag/" | head -1 | sed -r 's/.*tag\/(.+)\">.*/\1/'`; \
  curl -fSLo /usr/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
  curl -fSLo /usr/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
  export GNUPGHOME=`mktemp -d`; \
  gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
  gpg --batch --verify /usr/bin/gosu.asc /usr/bin/gosu; \
  command -v gpgconf && gpgconf --kill all || :; \
  rm -rf "$GNUPGHOME" /usr/bin/gosu.asc; \
  chmod +x /usr/bin/gosu; \
  gosu nobody true; \
  apk del --no-network .gosu-deps; \
  rm -rf /var/cache/apk/*

RUN set -ex; \
  # Build environment setup
  apk add --update --no-cache --virtual .build-deps \
    git \
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
    gettext \
    iproute2 \
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
  # Install obfs plgin
  cd /tmp && git clone https://github.com/shadowsocks/simple-obfs.git; \
  (cd simple-obfs; \
  git submodule update --init --recursive; \
  ./autogen.sh && ./configure --disable-documentation; \
  make && make install); \
  # Install v2ray-plugin
  V2RAY_VER=`curl -s https://github.com/shadowsocks/v2ray-plugin/tags | grep "/shadowsocks/v2ray-plugin/releases/tag/" | head -1 | sed -r 's/.*tag\/(.+)\">.*/\1/'`; \
  V2RAY_URL=https://github.com/shadowsocks/v2ray-plugin/releases/download/${V2RAY_VER}/v2ray-plugin-linux-amd64-${V2RAY_VER}.tar.gz; \
  curl -fSL ${V2RAY_URL} | tar xz -C /tmp; \
  mv /tmp/v2ray-plugin_linux_amd64 /usr/bin/v2ray-plugin; \
  # Install kcptun server
  KCP_VER=`curl -s "https://github.com/xtaci/kcptun/tags" | grep "/xtaci/kcptun/releases/tag/" | head -1 | sed -r 's/.*tag\/(.+)\">.*/\1/'`; \
  KCP_URL=https://github.com/xtaci/kcptun/releases/download/${KCP_VER}/kcptun-linux-amd64-${KCP_VER:1}.tar.gz; \
  curl -fSL ${KCP_URL} | tar xz -C /tmp; \
  mv /tmp/server_* /usr/bin/kcptun-server; \
  # Set timezone
  ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime; \
  apk del --no-network .build-deps; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

WORKDIR /ssrkcp/config

# Install docker-entrypoint.sh
COPY sources /ssrkcp
RUN chmod 770 /ssrkcp/entrypoint.sh; \
  chmod 770 /ssrkcp/ss_plugin.sh; \
  chmod 770 /ssrkcp/utils/view_config.sh; \
  ln -sf /ssrkcp/entrypoint.sh /usr/local/bin/entrypoint.sh; \
  ln -sf /ssrkcp/ss_plugin.sh /usr/local/bin/show

ENV TZ=Asia/Hong_Kong
ENV PLUGIN_CLIENT_NAME=kcptun
# Set shadowsocks-libev run time env
ENV SS_PORT=2019 \
  SS_PASSWD=p@ssw0rd12^3a \
  SS_METHOD=xchacha20-ietf-poly1305

# Set kcptun run time env
# sndwnd*mtu*8/1024/1024=1024*1024*8/1024/1024
ENV KCP_PORT=2020 \
    KCP_PASSWD=p@ssw0rd456 \
    KCP_CRYPT=aes-128 \
    KCP_MODE=fast2 \
    KCP_MTU=1460 \
    KCP_SNDWND=4096 \
    KCP_RCVWND=1024 \
    KCP_DATASHARD=10 \
    KCP_PARITYSHARD=3 \
    KCP_DSCP=46 \
    KCP_SMUXVER=1 \
    KCP_NOCOMP=true \
    KCP_PPROF=false \
    KCP_TCP=true

ENTRYPOINT [ "entrypoint.sh" ]

CMD  [ "supervisord" ]
