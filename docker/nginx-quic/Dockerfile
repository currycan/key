FROM alpine:3 AS builder

WORKDIR /src

# 1. 基础构建依赖
RUN set -ex; \
  apk upgrade --no-cache -a; \
  apk add --no-cache --virtual .build-deps \
    ca-certificates clang lld cmake ninja make git bash \
    libatomic_ops-dev zlib-dev pcre-dev pcre2-dev linux-headers \
    libxml2-dev libxslt-dev curl curl-dev lmdb-dev libfuzzy2-dev \
    zstd-dev geoip-dev libmaxminddb-dev openssl-dev

# 2. Nginx 源码
# https://github.com/nginx/nginx
ARG NGINX_VERSION=release-1.29.4
ARG DTR_VER=1.29.2
# https://github.com/nginx-modules/ngx_http_tls_dyn_size
# https://github.com/openresty/openresty
ARG RCP_VER=1.27.1
RUN set -ex; \
  git clone --recursive --depth 1 --shallow-submodules https://github.com/nginx/nginx -b "${NGINX_VERSION}" /src/nginx; \
  cd /src/nginx; \
  curl -fsSL https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/refs/heads/master/nginx__dynamic_tls_records_${DTR_VER}%2B.patch -o /src/nginx/1.patch; \
  curl -fsSL https://raw.githubusercontent.com/openresty/openresty/refs/heads/master/patches/nginx/${RCP_VER}/nginx-${RCP_VER}-resolver_conf_parsing.patch -o /src/nginx/2.patch; \
  curl -fsSL https://patch-diff.githubusercontent.com/raw/nginx/nginx/pull/689.patch -o /src/nginx/3.patch; \
  sed -i "s|nginx/|NPMplus/|g" /src/nginx/src/core/nginx.h; \
  sed -i "s|Server: nginx|Server: NPMplus|g" /src/nginx/src/http/ngx_http_header_filter_module.c; \
  sed -i "/<hr><center>/d" /src/nginx/src/http/ngx_http_special_response.c; \
  git apply /src/nginx/1.patch /src/nginx/2.patch /src/nginx/3.patch

# 3. 模块源码
# ngx_brotli https://github.com/google/ngx_brotli
ARG BROTLI_VERSION=master
RUN git clone --recursive --depth 1 --shallow-submodules -b ${BROTLI_VERSION} https://github.com/google/ngx_brotli /src/ngx_brotli

ARG FANCYINDEX_VERSION=v0.5.2
RUN git clone --recursive --depth 1 --shallow-submodules -b ${FANCYINDEX_VERSION} https://github.com/aperezdc/ngx-fancyindex /src/ngx-fancyindex

ARG HEADERS_MORE_VERSION=v0.39
RUN git clone --recursive --depth 1 --shallow-submodules -b ${HEADERS_MORE_VERSION} https://github.com/openresty/headers-more-nginx-module /src/headers-more-nginx-module

ARG DEVEL_KIT_VERSION=v0.3.4
RUN git clone --recursive --depth 1 --shallow-submodules -b ${DEVEL_KIT_VERSION} https://github.com/vision5/ngx_devel_kit /src/ngx_devel_kit

ARG ZSTD_VERSION=0.1.1
RUN git clone --recursive --depth 1 --shallow-submodules -b ${ZSTD_VERSION} https://github.com/tokers/zstd-nginx-module.git /src/ngx_http_zstd_module

ARG GEOIP2_VERSION=3.4
RUN git clone --recursive --depth 1 --shallow-submodules -b ${GEOIP2_VERSION} https://github.com/leev/ngx_http_geoip2_module /src/ngx_http_geoip2_module

ARG NTLM_VERSION=v1.19.3
RUN git clone --recursive --depth 1 --shallow-submodules -b ${NTLM_VERSION} https://github.com/gabihodoroaga/nginx-ntlm-module /src/nginx-ntlm-module

ARG VTS_VERSION=v0.2.5
RUN git clone --recursive --depth 1 --shallow-submodules -b ${VTS_VERSION} https://github.com/vozlt/nginx-module-vts /src/nginx-module-vts

# 4. 编译器参数与构建
ARG FLAGS
ARG CC=clang
ARG CFLAGS="$FLAGS -m64 -O2 -pipe -flto=thin -funroll-loops -ffunction-sections -fdata-sections -fstrict-flex-arrays=3 -fstack-clash-protection -fstack-protector-strong -ftrivial-auto-var-init=zero -fno-delete-null-pointer-checks -fno-strict-overflow -fno-strict-aliasing -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS -D_LIBCPP_ENABLE_THREAD_SAFETY_ANNOTATIONS=1 -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST -Wformat=2 -Werror=format-security"
ARG CXX=clang++
ARG CXXFLAGS="$FLAGS -m64 -O2 -pipe -flto=thin -funroll-loops -ffunction-sections -fdata-sections -fstrict-flex-arrays=3 -fstack-clash-protection -fstack-protector-strong -ftrivial-auto-var-init=zero -fno-delete-null-pointer-checks -fno-strict-overflow -fno-strict-aliasing -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS -D_LIBCPP_ENABLE_THREAD_SAFETY_ANNOTATIONS=1 -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST -Wformat=2 -Werror=format-security"
ARG LDFLAGS="-fuse-ld=lld -m64 -Wl,-s -Wl,-O1 -Wl,--gc-sections -Wl,-z,nodlopen -Wl,-z,noexecstack -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -Wl,--no-copy-dt-needed-entries -Wl,--sort-common -Wl,-z,pack-relative-relocs"

ARG CONFIG="\
  --build=nginx \
  --with-debug \
  --user=nginx \
  --group=nginx \
  --prefix=/etc/nginx \
  --sbin-path=/etc/nginx/sbin/nginx \
  --modules-path=/etc/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx/nginx.pid \
  --lock-path=/var/run/nginx/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --with-compat \
  --with-threads \
  --with-file-aio \
  --with-libatomic \
  --with-pcre \
  --with-pcre-jit \
  --with-select_module \
  --with-poll_module \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-stream_geoip_module \
  --with-stream_realip_module \
  --with-http_v2_module \
  --with-http_v3_module \
  --with-http_ssl_module \
  --with-http_geoip_module \
  --with-http_realip_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_sub_module \
  --with-http_addition_module \
  --with-http_stub_status_module \
  --with-http_auth_request_module \
  --add-module=/src/ngx_brotli \
  --add-module=/src/ngx_devel_kit \
  --add-module=/src/headers-more-nginx-module \
  --add-module=/src/ngx_http_zstd_module \
  --add-dynamic-module=/src/ngx-fancyindex \
  --add-dynamic-module=/src/ngx_http_geoip2_module \
  --add-dynamic-module=/src/nginx-ntlm-module \
  --add-dynamic-module=/src/nginx-module-vts \
  "

RUN set -ex; \
  echo "Building nginx ..."; \
  mkdir -p /var/run/nginx/ /var/cache/nginx; \
  cd /src/nginx; \
  ./auto/configure $CONFIG --with-cc-opt="${CFLAGS}" --with-ld-opt="${LDFLAGS}"; \
  make -j "$(nproc)" install; \
  ln -s /etc/nginx/sbin/nginx /usr/sbin/nginx; \
  \
  # 5. 清理和准备运行时文件
  make install; \
  mkdir /etc/nginx/conf.d/; \
  mkdir /etc/nginx/stream.d/; \
  mkdir -p /etc/nginx/ssl; \
  # Strip 二进制文件减少体积
  strip /usr/sbin/nginx*; \
  find /etc/nginx/modules -name "*.so" -exec strip -s {} \;; \
  # 获取 dhparam
  curl -fsSL https://ssl-config.mozilla.org/ffdhe2048.txt -o /etc/nginx/ssl/dhparam.pem; \
  \
  # 6. 计算运行时依赖
  apk add --no-cache --virtual .gettext gettext; \
  scanelf --needed --nobanner /usr/sbin/nginx /etc/nginx/modules/*.so /usr/bin/envsubst \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u \
      | xargs -r apk info --installed \
      | sort -u > /tmp/runDeps.txt

# Final Stage
FROM docker.io/library/alpine:3

COPY --from=builder /tmp/runDeps.txt /tmp/runDeps.txt

ARG NGINX_USER_UID=200
ARG NGINX_GROUP_GID=201

RUN set -ex; \
  apk upgrade --no-cache -a; \
  # 安装基础运行时库 + 计算出的 Nginx 依赖
  apk add --no-cache --virtual .base-rundeps \
    bash \
    libstdc++ zlib pcre pcre2 \
    ca-certificates openssl \
    tzdata tini \
    libcurl \
    libxml2 libxslt \
    geoip libmaxminddb-libs; \
  apk add --no-cache --virtual .nginx-rundeps $(cat /tmp/runDeps.txt); \
  rm -f /tmp/runDeps.txt; \
  # 配置 OpenSSL
  sed -i "s|default = default_sect|default = default_sect\n|g" /etc/ssl/openssl.cnf; \
  sed -i "s|\[default_sect\]|\[default_sect\]\nactivate = 1\n|g" /etc/ssl/openssl.cnf; \
  # 创建用户和目录
  addgroup --gid $NGINX_GROUP_GID -S nginx; \
  adduser --uid $NGINX_USER_UID -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx; \
  mkdir -p /var/log/nginx /var/run/nginx /var/cache/nginx; \
  chown -R ${NGINX_USER_UID}:${NGINX_GROUP_GID} /var/log/nginx /var/run/nginx /var/cache/nginx

# 复制文件
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /etc/nginx /etc/nginx
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /var/log/nginx/ /var/log/nginx/
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /var/run/nginx/ /var/run/nginx/
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /usr/bin/envsubst /usr/bin/envsubst
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /etc/nginx/ssl /etc/nginx/ssl

WORKDIR /etc/nginx

EXPOSE 80/tcp 81/tcp 443/tcp 443/udp

STOPSIGNAL SIGQUIT

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
