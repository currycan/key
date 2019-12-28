FROM alpine:3.11

LABEL maintainer="andrew <ansandy@foxmail.com>"

ARG TZ=Asia/Hong_Kong
RUN set -ex; \
  # Build environment setup
  apk add --update --no-cache --virtual .build-deps \
  curl \
  git \
  autoconf \
  automake \
  build-base \
  c-ares-dev \
  libcap \
  libev-dev \
  libtool \
  libsodium-dev \
  linux-headers \
  mbedtls-dev \
  pcre-dev; \
  # Get shadowsocks-libev & download source code
  SSR_VER=`curl -s https://github.com/shadowsocks/shadowsocks-libev/tags | grep "/shadowsocks/shadowsocks-libev/releases/tag/" | head -1 | sed -r 's/.*tag\/(.+)\">.*/\1/'`; \
  SSR_URL=https://github.com/shadowsocks/shadowsocks-libev/releases/download/${SSR_VER}/shadowsocks-libev-${SSR_VER:1}.tar.gz; \
  curl -fSL ${SSR_URL} | tar xz --strip-components=0 -C /tmp; \
  # Build & install
  cd /tmp/shadowsocks-libev*; \
  curl -fSLO https://raw.githubusercontent.com/shadowsocks/shadowsocks-libev/master/autogen.sh && chmod 770 autogen.sh; \
  ./autogen.sh; \
  ./configure --prefix=/usr --disable-documentation; \
  make install; \
  ls /usr/bin/ss-* | xargs -n1 setcap cap_net_bind_service+ep; \
  # Runtime dependencies setup
  apk add --update --no-cache  \
  tzdata \
  libstdc++ \
  iptables \
  ca-certificates \
  rng-tools \
  $(scanelf --needed --nobanner /usr/bin/ss-* \
  | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
  | sort -u); \
  cd /tmp && git clone https://github.com/w1ndy/kcptun-plugins.git; \
  cd kcptun-plugins/ && make install; \
  curl -SLo /usr/local/bin/start https://raw.githubusercontent.com/currycan/key/master/entrypoint.sh; \
  chmod 770 /usr/local/bin/start; \
  apk del .build-deps; \
  apk add --update --no-cache libtool curl; \
  ln -sf /usr/share/zoneinfo/$TZ /etc/localtime; \
  rm -rf /tmp/*; \
  rm -rf /var/cache/apk/*

# ARG user=ssrkcp
# ARG group=ssrkcp

# RUN addgroup -S ssrkcp && adduser -S -G ssrkcp ssrkcp
# USER ssrkcp

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

ENV enable_kcptun=false

EXPOSE 2019

CMD [ "start" ]


# key=p@ssw0rd456;raw=YES;crypt=aes-128;mode=fast3;mtu=1200;sndwnd=512;rcvwnd=4096;datashard=1;parityshard=1;dscp=46;nocomp=true;autoexpire=1800
