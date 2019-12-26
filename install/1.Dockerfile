FROM alpine:3.11

LABEL maintainer="andrew <ansandy@foxmail.com>"

ENV TZ=Asia/Hong_Kong
RUN set -ex; apk add --update --no-cache curl ca-certificates tzdata python libsodium supervisor && update-ca-certificates; \
  mkdir -p /ssr/kcptun; \
  cd /ssr; \
  SSR_VER=`curl -s https://github.com/shadowsocksrr/shadowsocksr/tags | grep "/shadowsocksrr/shadowsocksr/releases/tag/" | head -1 | sed -r 's/.*tag\/(.+)\">.*/\1/'`; \
  SSR_URL=https://github.com/shadowsocksrr/shadowsocksr/archive/${SSR_VER}.tar.gz; \
  curl -fSL ${SSR_URL} | tar xz; \
  mv shadowsocksr-*/shadowsocks shadowsocks; \
  rm -rf shadowsocksr-* *.zip; \
  cd /ssr/kcptun; \
  KCP_VER=`curl -s "https://github.com/xtaci/kcptun/tags" | grep "/xtaci/kcptun/releases/tag/" | head -1 | sed -r 's/.*tag\/(.+)\">.*/\1/'`; \
  KCP_URL=https://github.com/xtaci/kcptun/releases/download/${KCP_VER}/kcptun-linux-amd64-${KCP_VER:1}.tar.gz; \
  curl -fSL ${KCP_URL} | tar xz; \
  rm client_*; \
  mv server_* server; \
  curl -SLo /usr/local/bin/start https://raw.githubusercontent.com/currycan/key/master/entrypoint.sh; \
  chmod 770 /usr/local/bin/start; \
  apk del curl; \
  ln -sf /usr/share/zoneinfo/$TZ /etc/localtime; \
  rm -rf /var/cache/apk/*

ENV SSR=ssr://origin:chacha20-ietf:tls1.2_ticket_auth:p@ssw0rd123 \
    SSR_REDIRECT='["www.alibabagroup.com","www.alibabacloud.com","www.alibaba.co.jp"]' \
    SSR_OBFS_PARAM=alibabagroup.com \
    SSR_PROTOCOL_PARAM=''

ENV KCP_KEY=p@ssw0rd123 \
    KCP_CRYPT=aes-128 \
    KCP_MODE=fast3 \
    KCP_MTU=1400 \
    KCP_SNDWND=1024 \
    KCP_RCVWND=4096

WORKDIR /ssr

EXPOSE 2019/tcp 2019/udp 2020/udp

CMD ["start"]
