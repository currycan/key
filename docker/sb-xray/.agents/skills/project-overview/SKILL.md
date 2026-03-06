---
name: SB-Xray 项目全景概览
description: 提供 SB-Xray 项目的架构、核心组件、目录结构和关键环境变量的全面参考
---

# SB-Xray 项目全景概览

## 项目定位

SB-Xray 是一个 **Docker 化的企业级全栈网络调度与代理安全网关**，基于 **Sing-box + Xray** 双核引擎构建。项目以单容器集成的方式提供完整的代理服务、证书管理、面板控制和客户端配置分发能力。

**Docker 镜像**: `currycan/sb-xray`
**技术栈**: Shell (Bash)、Docker (多阶段构建)、Nginx、JSON、YAML
**运行模式**: `network_mode: host`，由 Supervisord 管理所有内部进程

---

## 核心组件清单

| 组件 | 作用 | 配置目录 |
|:---|:---|:---|
| **Xray** | 代理核心引擎 (Reality/XHTTP/VMess-WS) | `templates/xray/` |
| **Sing-box** | 代理核心引擎 (Hysteria2/TUIC/AnyTLS) | `templates/sing-box/` |
| **Nginx** | 反向代理、TLS 终结、路径分发、伪装站 | `templates/nginx/` |
| **Sub-Store** | 订阅管理后端 + 前端 | Dockerfile 中构建 |
| **3x-UI (X-UI)** | Xray 管理面板 | Dockerfile 中构建 |
| **S-UI** | Sing-box 管理面板 | Dockerfile 中构建 |
| **Dufs** | 文件服务器 | `templates/dufs/` |
| **Mihomo** | 客户端 Clash Meta 内核 (用于 Sub-Store http-meta) | Dockerfile 中构建 |
| **ACME.sh** | SSL/TLS 证书自动申请与续期 | `entrypoint.sh` 内逻辑 |
| **Fail2ban** | 入侵防护 | `entrypoint.sh` 内逻辑 |
| **Supervisord** | 进程管理 | `templates/supervisord/` |

---

## 目录结构

```
sb-xray/
├── Dockerfile              # 四阶段多平台构建 (amd64/arm64)
├── docker-compose.yml      # 部署清单
├── build.sh                # 自动化构建脚本 (获取最新版本 + docker buildx)
├── release.sh              # Git Release 自动化 (与 Xray 版本同步)
├── scripts/
│   ├── entrypoint.sh       # 🔑 核心入口 (16段 §N 架构，核心主流程)
│   ├── check_ip_type.sh    # IP 质量体检 (ASN/流媒体解锁/风控检测)
│   ├── show-config.sh      # 展示生成的配置与订阅链接
│   ├── geo_update.sh       # Geosite/GeoIP 数据库定时更新
│   └── stop-supervisor.sh  # Supervisord 优雅停止
├── templates/
│   ├── xray/               # Xray 配置模板 (Reality/XHTTP/VMess-WS + 主配置)
│   ├── sing-box/           # Sing-box 配置模板 (Hysteria2/TUIC/AnyTLS + 主配置)
│   ├── proxies/            # 代理节点输出模板 (all/clash/stash/surge 格式)
│   ├── nginx/              # Nginx 配置模板 (http.conf/tcp.conf/nginx.conf)
│   ├── client_template/    # 客户端订阅模板 (OneSmartPro/FallBackPro/surge)
│   ├── providers/          # Proxy Provider 模板
│   ├── supervisord/        # Supervisord 进程管理模板
│   └── dufs/               # Dufs 文件服务配置模板
├── sources/                # 静态资源 (ACL4SSR规则集/伪装站点/zashboard面板)
│   └── hack/rename.js      # 节点重命名流水线（§N 段架构）
└── docs/                   # 技术文档 (5篇)
```

---

## entrypoint.sh 16段 §N 架构

入口脚本（`scripts/entrypoint.sh`）按功能层次分为 16 段，函数声明严格遵循「被依赖的先声明」原则：

| 层次 | 段落 | 职责 |
|:---|:---|:---|
| **基础工具层** | §1 颜色与常量 · §2 日志工具 · §3 HTTP工具 · §4 随机值生成 · §5 模板渲染 · §6 环境变量持久化 | 无业务状态依赖的纯工具函数 |
| **网络探测层** | §7 网络环境探测 · §8 选路辅助 · §9 测速 | IP/ASN/GeoIP 检测、流媒体/AI 解锁探测、速度测试 |
| **业务层** | §10 ISP节点处理 · §11 流媒体/AI可达性检测 · §12 证书管理 · §13 配置渲染 · §14 远端密钥解密 | 依赖探测结果的核心业务逻辑 |
| **流程与入口层** | §15 主流程各阶段 · §16 主入口 | `main_init` 启动流水线，最终交给 Supervisord |

---

## 关键环境变量

> 完整参考见 `docs/04-ops-and-troubleshooting.md §2`。

### 优先级（高→低）

`/.env/status` > `/.env/sb-xray` > `/.env/secret` > `docker-compose environment` > `Dockerfile ENV`

### 必填（docker-compose 设置，无默认值）
| 变量 | 说明 |
|:---|:---|
| `DOMAIN` | 主域名 |
| `CDNDOMAIN` | CDN 域名 (Cloudflare) |
| `DECODE` | 远端密钥库解密密钥 |

### 常用可选（docker-compose 覆盖 Dockerfile 默认）
| 变量 | Dockerfile 默认 | 说明 |
|:---|:---|:---|
| `LISTENING_PORT` | `443` | 主监听端口 |
| `DEST_HOST` | `www.microsoft.com` | Reality SNI 伪装目标 |
| `NODE_SUFFIX` | 空 | 节点名称后缀 |
| `DEFAULT_ISP` | `LA_ISP` | 全局兜底 ISP 代理前缀 |
| `GEMINI_DIRECT` | 空 | Gemini 路由 (true/false/空=自动) |
| `PROVIDERS` | 空 | 自定义订阅源 (多行格式) |
| `XUI_WEBBASEPATH` | `xui` | X-UI 面板路径 |
| `SUI_WEBBASEPATH` | `sui` | S-UI 面板路径 |
| `DUFS_PATH_PREFIX` | `/dufs` | 文件服务 URL 前缀 |

### 远端密钥变量（`/.env/secret`，由 `DECODE` 解密，勿放 docker-compose）
`PUBLIC_USER`, `PUBLIC_PASSWORD`, `<PREFIX>_ISP_IP/PORT/USER/SECRET`

### 自动生成变量（`/.env/sb-xray`，首次生成后永久缓存，勿手动设置）
`XRAY_UUID`, `SB_UUID`, `PASSWORD`, `SUBSCRIBE_TOKEN`, `XRAY_REALITY_SHORTID`, `XRAY_REALITY_PRIVATE_KEY`, `XRAY_REALITY_PUBLIC_KEY`, `XRAY_MLKEM768_SEED`, `XRAY_MLKEM768_CLIENT`, `XRAY_URL_PATH`, `PORT_HYSTERIA2`, `PORT_TUIC`, `PORT_ANYTLS`, `XUI_LOCAL_PORT`, `DUFS_PORT`, `SUB_STORE_FRONTEND_BACKEND_PATH`, `STRATEGY`, `GEOIP_INFO`, `IS_BRUTAL`, `IP_TYPE`, `ISP_TAG`, `IS_8K_SMOOTH`

### 自动检测变量（`/.env/status`，删除文件后重启可重新探测）
`CHATGPT_OUT`, `NETFLIX_OUT`, `DISNEY_OUT`, `YOUTUBE_OUT`, `GEMINI_OUT`, `CLAUDE_OUT`, `SOCIAL_MEDIA_OUT`, `TIKTOK_OUT`, `ISP_OUT`

---

## 编码约定

1. **语言**: 所有注释和日志使用中文
2. **错误处理**: 脚本入口 `set -eou pipefail`，关键路径有 `|| exit 1` 守卫
3. **日志格式**: 使用 `log INFO/WARN/ERROR/DEBUG` 统一输出，带时间戳和颜色
4. **环境变量**: 通过 `ensure_var` 实现 "首次计算，后续缓存" 的持久化策略
5. **模板渲染**: 使用 `envsubst` + `jq` 验证的 `apply_tpl()` 函数
