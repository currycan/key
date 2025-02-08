# crypctl - 文件加解密工具

[![Docker Image](https://img.shields.io/badge/docker%20image-available-brightgreen)](https://hub.docker.com/r/yourname/crypctl)

基于Golang开发的文件加密/解密命令行工具,支持AES-256-GCM加密算法,提供容器化部署方案。

## 功能特性

- **军用级加密**:采用AES-256-GCM认证加密算法
- **安全密钥派生**:使用SHA-256哈希算法生成256位密钥
- **完整数据认证**:自动生成并验证GCM认证标签
- **容器化支持**:提供开箱即用的Docker镜像
- **跨平台运行**:支持Windows/Linux/macOS及容器环境

## 初始化步骤（使用Go Modules）

1.创建项目目录并初始化：

```bash
mkdir crypctl && cd crypctl
go mod init crypctl
```

2.安装依赖：

```bash
go get github.com/spf13/cobra@latest
```

3.初始化cobra项目结构：

```bash
go install github.com/spf13/cobra-cli@latest
cobra-cli init
```

4.添加子命令：

```bash
# mkdir cmd
cobra-cli add encrypt
cobra-cli add decrypt
cobra-cli add completion
```

## 安装方式

### docker 安装

```bash
# 原生方式
go build -o crypctl
sudo mv crypctl /usr/local/bin/

# Docker方式
docker build -t currycan/crypctl:1.0.0 .
```

## 使用指南

### 加密文件

```bash
# 原生方式
crypctl encrypt -i input.txt -o encrypted.bin -k "your-strong-key"

# Docker方式
docker run -v $(pwd):/app currycan/crypctl:1.0.0 encrypt \
  -i /app/input.txt \
  -o /app/encrypted.bin \
  -k "your-strong-key"
```

### 解密文件

```bash
# 原生方式
crypctl decrypt -i encrypted.bin -o decrypted.txt -k "your-strong-key"

# Docker方式
docker run -v $(pwd):/app currycan/crypctl:1.0.0 decrypt \
  -i /app/encrypted.bin \
  -o /app/decrypted.txt \
  -k "your-strong-key"
```
