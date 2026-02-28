---
name: Docker 构建与发布
description: Docker 多阶段构建流程、版本管理和 Git Release 自动化指南
---

# Docker 构建与发布

## Dockerfile 四阶段构建

`Dockerfile` 使用多阶段构建，支持 `linux/amd64` 和 `linux/arm64` 双平台：

```
阶段 1: sub-store-builder (node:alpine)
  └─ 构建 Sub-Store 前端 + 后端 + http-meta

阶段 2: s-ui-front-builder (node:alpine)
  └─ 构建 S-UI 前端静态资源

阶段 3: builder (golang:alpine)
  └─ 编译 Golang 组件: 3x-UI、S-UI 后端、Sing-box、crypctl
  └─ 下载二进制: Xray、Shoutrrr、Cloudflared、Dufs

阶段 4: 最终镜像 (currycan/nginx:1.29.4)
  └─ 安装运行时依赖 (acme.sh, supervisor, fail2ban, jq 等)
  └─ COPY 所有构建产物 + scripts/ + templates/ + sources/
```

### 版本管理规则

- 各组件版本通过 `ARG` 声明在 Dockerfile 中，有硬编码的默认值
- `build.sh` 在构建时自动从 GitHub API 获取最新版本，通过 `--build-arg` 覆盖默认值
- 如果 API 获取失败，回退到 Dockerfile 中的默认值

### 关键 ARG 列表

| ARG | 组件 | 获取方式 |
|:---|:---|:---|
| `XRAY_VERSION` | Xray | `get_latest_tag` (XTLS/Xray-core) |
| `SING_BOX_VERSION` | Sing-box | `get_latest_stable_tag` (SagerNet/sing-box) |
| `XUI_VERSION` | 3x-UI | `get_latest_stable_tag` (MHSanaei/3x-ui) |
| `SUI_VERSION` | S-UI | `get_latest_release` (alireza0/s-ui) |
| `DUFS_VERSION` | Dufs | `get_latest_stable_tag` (sigoden/dufs) |
| `MIHOMO_VERSION` | Mihomo | `get_latest_release` (MetaCubeX/mihomo) |
| `CLOUDFLARED_VERSION` | Cloudflared | `get_latest_stable_tag` |
| `SHOUTRRR_VERSION` | Shoutrrr | `get_latest_release` |
| `SUB_STORE_BACKEND_VERSION` | Sub-Store 后端 | `get_latest_release` |
| `SUB_STORE_FRONTEND_VERSION` | Sub-Store 前端 | `get_latest_release` |
| `HTTP_META_VERSION` | Http-Meta | `get_latest_release` |

### UPX 压缩

所有 Go 编译产物均使用 `upx --lzma --best` 压缩，大幅减少镜像体积。

---

## build.sh 构建脚本

### 执行方式

```bash
# 自动获取最新版本
./build.sh

# 使用 Dockerfile 中的默认版本 (跳过 API 调用)
./build.sh default
```

### 核心逻辑

1. 检查 `GITHUB_TOKEN` 环境变量，有则在 API 请求中附带认证头
2. 三种版本获取函数：
   - `get_latest_release()` — GitHub Releases API 最新发布
   - `get_latest_tag()` — GitHub Tags API 第一个标签
   - `get_latest_stable_tag()` — 排除 `rc|beta|alpha` 后的最新稳定标签
3. `check_version()` 统一处理：版本有效则去除 `v` 前缀加入 `BUILD_ARGS`，失败则回退到默认值
4. 最终 Docker 镜像 Tag 基于 **Xray 版本号**：`currycan/sb-xray:<xray_version>` + `currycan/sb-xray:latest`
5. 使用 `docker buildx build --platform linux/amd64,linux/arm64 --push` 构建并推送

### 修改版本默认值

如需更新默认版本号，需同步修改两个位置：
1. `Dockerfile` 中对应的 `ARG` 声明
2. `build.sh` 中 `check_version` 调用的第 4 个参数（默认值）

---

## release.sh 发布脚本

### 执行方式

```bash
./release.sh
```

### 核心逻辑

1. 从 GitHub API 获取 Xray 最新版本号
2. 创建与 Xray 版本同步的 Git 标签 (如 `v26.2.6`)
3. 如果安装了 `gh` CLI：自动推送标签 + 创建 GitHub Release
4. 如果没有 `gh`：仅推送标签，提示手动创建 Release

### 版本命名约定

```
Xray 版本: v1.8.8
Docker 镜像 Tag: 1.8.8 (去掉 v 前缀)
Git Release Tag: v1.8.8 (保留 v 前缀)
```

---

## 修改指南

### 添加新组件

1. 在 `Dockerfile` 的对应构建阶段添加编译/下载步骤
2. 在 `Dockerfile` 中添加 `ARG <COMPONENT>_VERSION="<default>"`
3. 在 `build.sh` 中添加版本获取和 `check_version` 调用
4. 如需配置，在 `templates/` 下创建模板目录
5. 在 `entrypoint.sh` 中添加相关初始化逻辑

### 升级组件默认版本

1. 更新 `Dockerfile` 中的 `ARG` 默认值
2. 更新 `build.sh` 中 `check_version` 的第 4 个参数
3. 运行 `./build.sh default` 验证构建
