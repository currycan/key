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
│   ├── entrypoint.sh       # 🔑 核心入口 (1073行, 五大扇区架构)
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
└── docs/                   # 技术文档 (5篇)
```

---

## entrypoint.sh 五大扇区架构

入口脚本是系统核心，按以下扇区组织：

| 扇区 | 行范围 | 职责 |
|:---|:---|:---|
| **扇区一** | 1-172 | 全局环境与通用能力层 (`log`, `ensure_var`, `ensure_key_pair`, `generateRandomStr`, `http_probe`) |
| **扇区二** | 175-557 | 网络环境探测与测速决策 (IP检测、流媒体/AI解锁诊断、速度测试、ISP路由策略) |
| **扇区三** | 559-612 | 安全层与证书发放 (`issueCertificate` - ACME.sh 集成) |
| **扇区四** | 615-700 | 服务端配置生成 (`createConfig` - 模板渲染引擎 `apply_tpl`) |
| **扇区五** | 703-964 | 客户端输出与管控 (ISP测速评估、客户端配置生成、Provider生成) |
| **主控** | 970-1073 | `main_init` 12步启动流水线，最终交给 Supervisord |

---

## 关键环境变量

### 必填变量
| 变量 | 说明 |
|:---|:---|
| `DOMAIN` | 主域名 |
| `CDNDOMAIN` | CDN 域名 (Cloudflare) |
| `DECODE` | 远端密文解密密钥 |

### 重要可选变量
| 变量 | 默认值 | 说明 |
|:---|:---|:---|
| `LISTENING_PORT` | `443` | 主监听端口 |
| `NODE_SUFFIX` | 空 | 节点名称后缀 |
| `DEFAULT_ISP` | 空 | 强制指定 ISP 代理 |
| `GEMINI_DIRECT` | 空 | Gemini 直连控制 (true/false/空=自动) |
| `DEST_HOST` | `speed.cloudflare.com` | TLS SNI 伪装目标 |
| `PROVIDERS` | 空 | 自定义订阅源 (多行格式) |

### 自动生成变量 (持久化到 `/.env/sb-xray`)
`XRAY_UUID`, `SB_UUID`, `PASSWORD`, `SUBSCRIBE_TOKEN`, `XRAY_REALITY_SHORTID`, `XRAY_URL_PATH`, `PORT_HYSTERIA2`, `PORT_TUIC`, `PORT_ANYTLS`, `IP_TYPE`, `STRATEGY`, `GEOIP_INFO`, `IS_BRUTAL`

### 运行时状态变量 (持久化到 `/.env/status`)
`ISP_TAG`, `IS_8K_SMOOTH`, `CHATGPT_OUT`, `NETFLIX_OUT`, `DISNEY_OUT`, `YOUTUBE_OUT`, `GEMINI_OUT`, `CLAUDE_OUT`, `SOCIAL_MEDIA_OUT`, `TIKTOK_OUT`

---

## 编码约定

1. **语言**: 所有注释和日志使用中文
2. **错误处理**: 脚本入口 `set -eou pipefail`，关键路径有 `|| exit 1` 守卫
3. **日志格式**: 使用 `log INFO/WARN/ERROR/DEBUG` 统一输出，带时间戳和颜色
4. **环境变量**: 通过 `ensure_var` 实现 "首次计算，后续缓存" 的持久化策略
5. **模板渲染**: 使用 `envsubst` + `jq` 验证的 `apply_tpl()` 函数
