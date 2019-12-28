FROM alpine:3.11

LABEL maintainer="andrew <ansandy@foxmail.com>"

ARG TZ=Asia/Hong_Kong

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -S -g 1000 ssrkcp && adduser -S -G ssrkcp -u 999 ssrkcp

RUN set -ex; \
  # Build environment setup
  apk add --update --no-cache --virtual .build-deps \
    git \
    dpkg \
    gnupg \
    ca-certificates \
    autoconf \
    automake \
    build-base \
    c-ares-dev \
    libcap \
    libev-dev \
    libsodium-dev \
    linux-headers \
    mbedtls-dev \
    pcre-dev; \
  # Base dependencies setup
  apk add --update --no-cache  \
    curl \
    tzdata \
    libtool \
    libstdc++ \
    iptables \
    su-exec>=0.2 \
    tini; \
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
  # Install kcptun-plugins
  cd /tmp && git clone https://github.com/w1ndy/kcptun-plugins.git; \
  cd kcptun-plugins/ && make install; \
  # Install docker-entrypoint.sh
  curl -SLo /usr/local/bin/entrypoint.sh https://raw.githubusercontent.com/currycan/key/master/ssrkcp/entrypoint.sh; \
  chmod 770 /usr/local/bin/entrypoint.sh; \
  # Set timezone
  ln -sf /usr/share/zoneinfo/$TZ /etc/localtime; \
  # Clean all cache and temp files
  apk del --no-network .build-deps; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

# Set shadowsocks-libev run time env
ENV server_addr=0.0.0.0 \
  server_port=2019 \
  password=p@ssw0rd12^3a \
  method=chacha20-ietf-poly1305 \
  timeout=300 \
  dns_addrs=8.8.8.8,8.8.4.4 \
  args=''

# Set kcptun run time env
ENV config='' \
  crypt=aes-128 \
  mode=fast3 \
  mtu=1200 \
  sndwnd=1024 \
  rcvwnd=4096 \
  datashard=1 \
  parityshard=1 \
  dscp=46 \
  nocomp=true \
  params=''

ENV key=p@ssw0rd456 raw=YES

# Set udp2raw run time env
ENV raw_config='' \
  raw_mode=faketcp \
  raw_cipher=aes128cbc \
  raw_auth=md5 \
  raw_params=''

ENV enable_kcptun="true"

EXPOSE 2019 2020

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

CMD ss-server -s ${server_addr} \
  -p ${server_port} \
  -k ${password:-$(hostname)} \
  -m ${method} \
  -t ${timeout} \
  -d ${dns_addrs} \
  -u \
  --fast-open \
  --mtu ${mtu} \
  --no-delay \
  ${args}
