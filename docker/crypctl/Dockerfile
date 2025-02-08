# 构建阶段
FROM golang:1.23-alpine AS builder

# 安全配置
RUN apk add --no-cache \
  ca-certificates \
  upx

WORKDIR /app

# 下载依赖
COPY . /app

# 构建参数
ARG CGO_ENABLED=0
ARG GOOS=linux
ARG GOARCH=amd64

# 编译并压缩
RUN go build -ldflags="-s -w" -o /crypctl && \
  upx --best -q /crypctl

# 运行时阶段
FROM alpine:3


WORKDIR /app

# 复制可执行文件
COPY --from=builder /crypctl /usr/local/bin/crypctl

# 入口点
ENTRYPOINT ["crypctl"]
