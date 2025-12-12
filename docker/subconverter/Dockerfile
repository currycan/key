FROM alpine:3 AS builder

ARG THREADS="4"

# Validate and install build dependencies
RUN set -ex; \
    apk add --no-cache --virtual .build-deps \
    bash git nodejs npm gcc g++ build-base linux-headers \
    cmake make autoconf automake libtool python3 \
    mbedtls-dev mbedtls-static \
    curl-dev curl-static \
    openssl-dev \
    zlib-dev zlib-static \
    rapidjson-dev \
    pcre2-dev pcre2-static \
    yaml-cpp-dev \
    libpsl-dev libpsl-static \
    c-ares-dev \
    nghttp2-dev nghttp2-static

# Build quickjspp
WORKDIR /build/quickjspp
RUN set -ex; \
    git clone https://github.com/ftk/quickjspp --depth=1 .; \
    git submodule update --init; \
    cmake -DCMAKE_BUILD_TYPE=Release .; \
    make quickjs -j $THREADS; \
    install -d /usr/lib/quickjs/; \
    install -m644 quickjs/libquickjs.a /usr/lib/quickjs/; \
    install -d /usr/include/quickjs/; \
    install -m644 quickjs/quickjs.h quickjs/quickjs-libc.h /usr/include/quickjs/; \
    install -m644 quickjspp.hpp /usr/include

# Build libcron
WORKDIR /build/libcron
RUN set -ex; \
    git clone https://github.com/PerMalmberg/libcron --depth=1 .; \
    git submodule update --init; \
    cmake -DCMAKE_BUILD_TYPE=Release .; \
    make libcron -j $THREADS; \
    install -m644 libcron/out/Release/liblibcron.a /usr/lib/; \
    install -d /usr/include/libcron/; \
    install -m644 libcron/include/libcron/* /usr/include/libcron/; \
    install -d /usr/include/date/; \
    install -m644 libcron/externals/date/include/date/* /usr/include/date/

# Build toml11
WORKDIR /build/toml11
RUN set -ex; \
    git clone https://github.com/ToruNiina/toml11 --depth=1 .; \
    cmake -DCMAKE_CXX_STANDARD=11 .; \
    make install -j $THREADS

# Build subconverter
WORKDIR /usr/src/subconverter
COPY . .

# Generate version info and build
RUN set -ex; \
    if [ -d ".git" ]; then \
        VERSION=$(git describe --tags --always 2>/dev/null || echo "unknown"); \
        COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "abcd"); \
        DATE=$(date +%y.%m%d.%H%M); \
        sed -i 's/\(v[0-9]\.[0-9]\.[0-9]\)/\1-'"$DATE-$COMMIT"'/' src/version.h; \
    fi; \
    cmake -DCMAKE_BUILD_TYPE=Release .; \
    make -j $THREADS; \
    mv subconverter /usr/bin/subconverter; \
    # Prepare base resources
    python3 -m venv venv; \
    . venv/bin/activate; \
    pip install gitpython; \
    python3 scripts/update_rules.py -c scripts/rules_config.conf; \
    mv base /base

# Final Stage
FROM alpine:3

# Install runtime dependencies (same as test.Dockerfile + extras if needed)
RUN set -ex; \
  apk add --no-cache \
    pcre2 \
    libcurl \
    yaml-cpp \
    libevent \
    tzdata \
    ca-certificates

# Copy artifacts
COPY --from=builder /usr/bin/subconverter /usr/bin/subconverter
COPY --from=builder /base /base

# Set Timezone (Default to Asia/Shanghai as per original, or make it configurable)
# ENV TZ=Asia/Shanghai
ENV TZ="Asia/Hong_Kong"

WORKDIR /base

EXPOSE 25500

CMD ["subconverter"]
