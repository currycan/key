FROM docker.io/library/alpine:3 AS builder

# Requirements
RUN set -ex; \
  apk upgrade --no-cache -a; \
  apk add --no-cache --virtual .build-deps \
    # 基础证书和构建工具
    ca-certificates \
    build-base \
    cmake \
    ninja \
    git \
    # 自动化工具链
    libtool \
    autoconf \
    automake \
    bash \
    # 库依赖
    libatomic_ops-dev \
    zlib-dev \
    pcre2-dev \
    linux-headers \
    yajl-dev \
    libxml2-dev \
    libxslt-dev \
    curl-dev \
    lmdb-dev \
    libfuzzy2-dev \
    zstd-dev \
    # 地理和数据库相关
    geoip-dev \
    libmaxminddb-dev \
    # 测试和基准工具
    gtest-dev \
    benchmark-dev \
    # 协议相关
    protobuf-dev;

WORKDIR /src
COPY attachment.patch /src/attachment.patch

# ModSecurity
# https://github.com/owasp-modsecurity/ModSecurity
ARG MODSEC_VER=v3.0.14
RUN set -ex; \
  git clone --recurse-submodules https://github.com/owasp-modsecurity/ModSecurity --branch "$MODSEC_VER" /src/ModSecurity; \
  cd /src/ModSecurity; \
  sed -i "s|SecRuleEngine .*|SecRuleEngine On|g" /src/ModSecurity/modsecurity.conf-recommended; \
  sed -i "s|^SecAudit|#SecAudit|g" /src/ModSecurity/modsecurity.conf-recommended; \
  sed -i "s|unicode.mapping|/etc/nginx/conf/conf.d/include/unicode.mapping|g" /src/ModSecurity/modsecurity.conf-recommended; \
  /src/ModSecurity/build.sh; \
  /src/ModSecurity/configure --with-pcre2 --with-lmdb; \
  make -j "$(nproc)" install

# Nginx
# https://github.com/nginx/nginx
ARG NGINX_VERSION=release-1.27.4
ARG DTR_VER=1.27.4
ARG RCP_VER=1.27.1
RUN set -ex; \
  git clone https://github.com/nginx/nginx --branch "$NGINX_VERSION" /src/nginx; \
  cd /src/nginx; \
  wget -q https://raw.githubusercontent.com/nginx-modules/ngx_http_tls_dyn_size/master/nginx__dynamic_tls_records_"$DTR_VER"%2B.patch -O /src/nginx/1.patch; \
  wget -q https://raw.githubusercontent.com/openresty/openresty/master/patches/nginx-"$RCP_VER"-resolver_conf_parsing.patch -O /src/nginx/2.patch; \
  sed -i "s|nginx/|NPMplus/|g" /src/nginx/src/core/nginx.h; \
  sed -i "s|Server: nginx|Server: NPMplus|g" /src/nginx/src/http/ngx_http_header_filter_module.c; \
  sed -i "/<hr><center>/d" /src/nginx/src/http/ngx_http_special_response.c; \
  git diff; \
  git apply /src/nginx/1.patch; \
  git apply /src/nginx/2.patch; \
  rm -v /src/nginx/*.patch

# all nginx modules
# ngx_brotli https://github.com/google/ngx_brotli
# ARG BROTLI_VERSION=v1.0.0rc
ARG BROTLI_VERSION=master
RUN set -ex; \
  echo "Cloning ngx_brotli $BROTLI_VERSION ..."; \
  git clone --recursive --depth 1 --shallow-submodules --single-branch -b ${BROTLI_VERSION} https://github.com/google/ngx_brotli /src/ngx_brotli;

ARG FANCYINDEX_VERSION=v0.5.2
RUN set -ex; \
  echo "Cloning ngx-fancyindex $FANCYINDEX_VERSION ..."; \
  git clone --recursive --depth 1 --single-branch -b ${FANCYINDEX_VERSION} https://github.com/aperezdc/ngx-fancyindex /src/ngx-fancyindex;

ARG HEADERS_MORE_VERSION=v0.38
RUN set -ex; \
  echo "Cloning headers-more-nginx-module ${HEADERS_MORE_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${HEADERS_MORE_VERSION} https://github.com/openresty/headers-more-nginx-module /src/headers-more-nginx-module

ARG NJS_VERSION=0.8.9
RUN set -ex; \
  echo "Cloning and configuring njs ${NJS_VERSION} ..."; \
  git clone --recursive --depth 1 --single-branch -b ${NJS_VERSION} https://github.com/nginx/njs /src/njs;

ARG DEVEL_KIT_VERSION=v0.3.4
RUN set -ex; \
  echo "Cloning and configuring ngx_devel_kit ${DEVEL_KIT_VERSION} ..."; \
  git clone --recursive --depth 1 --single-branch -b ${DEVEL_KIT_VERSION} https://github.com/vision5/ngx_devel_kit /src/ngx_devel_kit;

# https://github.com/tokers/zstd-nginx-module/releases
ARG ZSTD_VERSION=0.1.1
RUN set -ex; \
  echo "Cloning zstd-nginx-module ..."; \
  git clone --recursive --depth 1 --shallow-submodules --branch ${ZSTD_VERSION} https://github.com/tokers/zstd-nginx-module.git /src/ngx_http_zstd_module

# https://github.com/leev/ngx_http_geoip2_module/releases
ARG GEOIP2_VERSION=3.4
RUN set -ex; \
  echo "Cloning ngx_http_geoip2_module ${GEOIP2_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${GEOIP2_VERSION} https://github.com/leev/ngx_http_geoip2_module /src/ngx_http_geoip2_module

ARG NTLM_VERSION=v1.19.3
RUN set -ex; \
  echo "Cloning nginx-ntlm-module ${NTLM_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${NTLM_VERSION} https://github.com/gabihodoroaga/nginx-ntlm-module /src/nginx-ntlm-module

ARG VTS_VERSION=v0.2.4
RUN set -ex; \
  echo "Cloning nginx-module-vts ${VTS_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${VTS_VERSION} https://github.com/vozlt/nginx-module-vts /src/nginx-module-vts

# patch ModSecurity-nginx
ARG MODSECNGX_VERSION=v1.0.3
RUN set -ex; \
  echo "Cloning ModSecurity-nginx ${MODSECNGX_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${MODSECNGX_VERSION} https://github.com/SpiderLabs/ModSecurity-nginx /src/ModSecurity-nginx; \
  cd /src/ModSecurity-nginx; \
  wget -q https://patch-diff.githubusercontent.com/raw/owasp-modsecurity/ModSecurity-nginx/pull/320.patch -O /src/ModSecurity-nginx/1.patch; \
  git apply /src/ModSecurity-nginx/1.patch; \
  rm -v /src/ModSecurity-nginx/*.patch

# RUN set -ex; \
#   echo "Cloning and configuring quickjs ..."; \
#   git clone --recursive --depth 1 https://github.com/bellard/quickjs /src/quickjs; \
#   cd /src/quickjs; \
#   make -j$(nproc) libquickjs.a; \
#   echo "quickjs $(cat VERSION)"

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
  --add-module=/src/ModSecurity-nginx \
  --add-module=/src/headers-more-nginx-module \
  --add-module=/src/ngx_http_zstd_module \
  --add-dynamic-module=/src/ngx-fancyindex \
  --add-dynamic-module=/src/ngx_http_geoip2_module \
  --add-dynamic-module=/src/njs/nginx \
  --add-dynamic-module=/src/nginx-ntlm-module \
  --add-dynamic-module=/src/nginx-module-vts \
  "

ARG CC_OPT=""
ARG LD_OPT=""

RUN set -ex; \
  echo "Building nginx ..."; \
  mkdir -p /var/run/nginx/ /var/cache/nginx; \
  cd /src/nginx; \
  ./auto/configure $CONFIG --with-cc-opt="${CC_OPT}" --with-ld-opt="${LD_OPT}"; \
  # make -j "$(nproc)" install && make install && make clean && strip /usr/sbin/nginx
  make -j "$(nproc)" install; \
  ln -s /etc/nginx/sbin/nginx /usr/sbin/nginx

# openappsec attachment
ARG ATTACHMENT_VERSION=main
RUN set -ex; \
  echo "Cloning attachment ${ATTACHMENT_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${ATTACHMENT_VERSION} https://github.com/openappsec/attachment /src/attachment; \
  echo "Building attachment ..."; \
  cd /src/attachment; \
  git apply /src/attachment.patch; \
  rm -v /src/attachment.patch; \
  cmake /src/attachment -G Ninja; \
  ninja; \
  mv -v /src/attachment/attachments/nginx/ngx_module/libngx_module.so /etc/nginx/modules/libngx_module.so

# liboqs
ARG LIBOQS_VERSION=0.12.0
RUN set -ex; \
  echo "Cloning liboqs ${LIBOQS_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${LIBOQS_VERSION} https://github.com/open-quantum-safe/liboqs /src/liboqs; \
  echo "Building liboqs ..."; \
  cd /src/liboqs; \
  cmake -G Ninja; \
  ninja install

# oqs-provider
ARG OQSPROVIDER_VERSION=0.8.0
RUN set -ex; \
  echo "Cloning oqs-provider ${OQSPROVIDER_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${OQSPROVIDER_VERSION} https://github.com/open-quantum-safe/oqs-provider /src/oqs-provider; \
  echo "Building oqs-provider ..."; \
  cd /src/oqs-provider; \
  cmake -DOQS_KEM_ENCODERS=ON -G Ninja; \
  ninja

# OpenTelemetry lib
ARG OPENTELEMETRY_VERSION=v1.19.0
RUN set -ex; \
  echo "Cloning opentelemetry-cpp ${OPENTELEMETRY_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${OPENTELEMETRY_VERSION} https://github.com/open-telemetry/opentelemetry-cpp /src/opentelemetry-cpp; \
  echo "Building opentelemetry-cpp ..."; \
  cd /src/opentelemetry-cpp; \
  cmake -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DWITH_OTLP_HTTP=ON -G Ninja; \
  ninja install

# OpenTelemetry module
# ARG OPENTELEMETRY_MODULE_VERSION=v1.1.0
ARG OPENTELEMETRY_MODULE_VERSION=main
RUN set -ex; \
  echo "Cloning opentelemetry-cpp-contrib ${OPENTELEMETRY_MODULE_VERSION} ..."; \
  git clone --recursive --depth 1 --branch ${OPENTELEMETRY_MODULE_VERSION} https://github.com/open-telemetry/opentelemetry-cpp-contrib /src/opentelemetry-cpp-contrib; \
  echo "Building opentelemetry-cpp-contrib ..."; \
  cd /src/opentelemetry-cpp-contrib/instrumentation/nginx; \
  cmake -G Ninja; \
  ninja; \
  mv -v /src/opentelemetry-cpp-contrib/instrumentation/nginx/otel_ngx_module.so /etc/nginx/modules/otel_ngx_module.so

# strip files
RUN set -ex; \
  strip -s /etc/nginx/sbin/nginx; \
  find /etc/nginx/modules -name "*.so" -exec strip -s {} \;; \
  strip -s /src/oqs-provider/lib/oqsprovider.so; \
  strip -s /src/ModSecurity/src/.libs/libmodsecurity.so.3; \
  strip -s /src/opentelemetry-cpp/libopentelemetry_proto.so; \
  strip -s /src/attachment/core/shmem_ipc/libosrc_shmem_ipc.so; \
  strip -s /src/attachment/core/compression/libosrc_compression_utils.so; \
  strip -s /src/attachment/attachments/nginx/nginx_attachment_util/libosrc_nginx_attachment_util.so

FROM alpine:3

RUN set -ex; \
  apk upgrade --no-cache -a && \
  apk add --no-cache \
  # 基础运行时库
  libstdc++ zlib pcre2 \
  # 安全与证书
  ca-certificates openssl \
  # 时区管理
  tzdata \
  # 进程管理
  tini \
  # 网络与协议
  libcurl libprotobuf \
  # XML/XSLT处理
  libxml2 libxslt yajl \
  # 数据库与存储
  lmdb \
  # 地理定位
  geoip libmaxminddb-libs \
  # 数据处理
  libfuzzy2; \
  sed -i "s|default = default_sect|default = default_sect\noqsprovider = oqsprovider_sect|g" /etc/ssl/openssl.cnf; \
  sed -i "s|\[default_sect\]|\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n|g" /etc/ssl/openssl.cnf

ARG NGINX_USER_UID=100
ARG NGINX_GROUP_GID=101
# add user
RUN set -ex; \
  addgroup --gid $NGINX_GROUP_GID -S nginx; \
  adduser --uid $NGINX_USER_UID -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /usr/sbin/nginx                                          /usr/sbin/nginx
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /etc/nginx                                                    /etc/nginx
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /var/log/nginx/                                               /var/log/nginx/
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /var/run/nginx/                                               /var/run/nginx/

COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /src/oqs-provider/lib/oqsprovider.so                          /usr/lib/ossl-modules/oqsprovider.so
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /src/ModSecurity/src/.libs/libmodsecurity.so.3                /usr/local/lib/libmodsecurity.so.3
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /src/ModSecurity/unicode.mapping                              /etc/nginx/conf/conf.d/include/unicode.mapping
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /src/ModSecurity/modsecurity.conf-recommended                 /etc/nginx/conf/conf.d/include/modsecurity.conf.example
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /src/opentelemetry-cpp/libopentelemetry_proto.so              /usr/local/lib/libopentelemetry_proto.so
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /src/attachment/core/shmem_ipc/libosrc_shmem_ipc.so           /usr/local/lib/libosrc_shmem_ipc.so
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /src/attachment/core/compression/libosrc_compression_utils.so /usr/local/lib/libosrc_compression_utils.so
COPY --from=builder --chown=${NGINX_USER_UID}:${NGINX_GROUP_GID} /src/attachment/attachments/nginx/nginx_attachment_util/libosrc_nginx_attachment_util.so /usr/local/lib/libosrc_nginx_attachment_util.so

WORKDIR /etc/nginx

EXPOSE 80/tcp 81/tcp 443/tcp 443/udp

STOPSIGNAL SIGQUIT

# USER nginx

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
