# SB-Xray Enterprise 🚀
> 专业级全栈网络调度与代理安全网关 (v26.2.6)

<div align="center">
  <img src="docs/images/logo.svg" alt="SB-Xray Logo" width="120" height="120" style="border-radius: 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.25);">

  <h3>您的企业级高性能网络安全枢纽</h3>
  <p>打破网络壁垒、聚合多协议、实现无感智能调度的终极云端边缘网关。</p>
  
  <p>
    <a href="https://hub.docker.com/r/currycan/sb-xray">
      <img src="https://img.shields.io/docker/pulls/currycan/sb-xray?style=flat-square&color=00B4D8" alt="Docker Pulls">
    </a>
    <img src="https://img.shields.io/badge/Platform-linux%2Famd64%20%7C%20linux%2Farm64-lightgrey?style=flat-square" alt="Platform">
    <a href="https://github.com/XTLS/Xray-core">
      <img src="https://img.shields.io/badge/Engine-Xray--core--v1.8.x-9D4EDD?style=flat-square" alt="Xray-core">
    </a>
    <a href="https://github.com/SagerNet/sing-box">
      <img src="https://img.shields.io/badge/Engine-Sing--box--v1.8.x-10B981?style=flat-square" alt="Sing-box">
    </a>
    <img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" alt="License">
  </p>

  <p>
    <a href="#-全景架构图-architecture-overview">全景架构</a> • 
    <a href="#-核心企业级特性-enterprise-features">核心特性</a> • 
    <a href="#-官方文档全集-documentation">官方文档</a> • 
    <a href="#-安装与快速接入-quick-start">快速接入</a>
  </p>
</div>

---

**SB-Xray** 是一个基于 Docker 容器化技术构建的**商业级网络流量分发与代理聚合平台**。它摒弃了传统单一代理软件的单薄性，创新性地将 **Nginx 前置流量整形**、**Xray 与 Sing-box 双核引擎**、**后量子安全加密 (MLKEM)** 以及 **自动化资产清洗 (Sub-Store)** 完美融为一体。

通过本系统，您可以零门槛建立起一套涵盖服务器搭建、多级 ISP 智能落地分流、直至移动端/桌面端一键订阅配置下发的全周期网络环境。

## 🗺️ 全景架构图 (Architecture Overview)

为了直观展现系统的数据吞吐能力与安全屏障设计，我们绘制了以下宏观架构图：

```mermaid
graph TD
    classDef client fill:#f96,stroke:#333,stroke-width:2px,color:white;
    classDef gateway fill:#61dafb,stroke:#333,stroke-width:2px,color:black;
    classDef core fill:#b19cd9,stroke:#333,stroke-width:2px,color:white;
    classDef cdn fill:#f1c40f,stroke:#333,stroke-width:2px,color:black;
    classDef dest fill:#2ecc71,stroke:#333,stroke-width:2px,color:white;

    User((客户端设备<br>Clash/v2rayN)):::client
    Cloudflare((外部 CDN 中转网络)):::cdn

    %% 流量入口层
    User -->|"TLS 加密握手 (端口 443)<br>SNI: 伪装大厂域名"| Nginx[Nginx 流控边界防御网关]:::gateway
    User -->|UDP 竞速直连<br>高并发独立端口| Singbox(Sing-box 竞速内核)
    User --> Cloudflare
    Cloudflare -->|"CDN 回源流量 (端口 443)<br>SNI: 真实管理域名"| Nginx

    %% 核心分流层
    Nginx -->|识别为伪装 SNI<br>TCP 原始流透传| XrayReality(Xray - Reality 隐蔽通道)
    Nginx -->|识别为真实 SNI<br>解密并作 HTTP 路由| PanelRouter{Nginx 业务应用分发路由}:::gateway
    
    %% 应用层
    PanelRouter -->|/xhttp, /vmess| XrayCDN(Xray - CDN 备用通道):::core
    PanelRouter -->|/xui, /sui, /sb-xray| Panels[Web 可视化面板与订阅系统]
    
    %% 落地路由层
    XrayReality --> RoutingEngine{智能路由与策略分流引擎}:::core
    XrayCDN --> RoutingEngine
    Singbox --> RoutingEngine:::core
    
    RoutingEngine -->|命中流媒体/AI 规则| ISP[ISP 住宅节点 (SOCKS5 链式代理)]:::dest
    RoutingEngine -->|普通海外流量| Direct[本机直连访问 (Freedom)]:::dest
    
    ISP --> WebOut((全球互联网))
    Direct --> WebOut
```

## 🌟 核心企业级特性 (Enterprise Features)

### 1. 🚀 智能双核引擎驱动 (Dual-Core Engine)
*   **Xray 核心 (隐蔽主干)**: 主理 Reality 协议与 XTLS-Vision 流控，在提供极高防探测能力的同时，确保高频数据通信（如日常网络代理、AI 接口调用）的绝对稳定。
*   **Sing-box 核心 (竞速加速)**: 专注于处理 Hysteria2、TUIC 等基于 UDP 的高并发协议，能够在严重丢包的弱网环境下进行暴力网络竞速，为您提供极致的宽带压榨保障。

### 2. 🛡️ 零信任前置网关 (Zero-Trust Gateway)
*   **Nginx SNI 无缝分流**: 整个系统由 Nginx 统一接管 443 标准端口。它在握手阶段解析 SNI，将 Reality 伪装流量透明下发至 Xray，将 CDN 落地流量路由至 VMess，将管理请求分发至后台面板。即使面临主动探测，也只暴露高纯度的 Web 伪装内容。

### 3. 🔐 金融级抗量子加密 (Quantum-Resistant Security)
*   **MLKEM 密码学加持**: 紧跟网络安全前沿，在 XHTTP 与 VLESS 通道中率先实装了 MLKEM768 后量子密码学协议（符合 NIST FIPS 203 标准），从容应对未来量子计算机的算力破解威胁。
*   **ACME 自动发证中枢**: 内置全自动证书机器人，仅需配置环境变量，即可自动向 ZeroSSL 或 Google CA 申请泛域名证书，并执行 90 天自动化无感续期。

### 4. 🔀 业务级智能路由分发 (Smart Routing & Distribution)
*   **多 ISP 原生链式落地**: 支持无缝挂载多个第三方住宅 IP (ISP Socks5)。内核级路由引擎可根据目标域名（如 Netflix, ChatGPT）自动引流至原生节点，彻底解决数据中心 IP 被阻断的问题。
*   **自动化订阅节点清洗**: 系统内嵌 Sub-Store，在将节点下发给 Clash / Surge 客户端前，自动执行地名标准化、挂载国旗 Emoji、过滤失效节点，提升客户端策略组分流的精准度。

---

## 📚 官方文档全集 (Documentation)

为了给您提供清晰且有理论支撑的操作指引，我们将原来繁杂的文档重新进行了系统化梳理与合并。强烈建议按照以下顺序阅读：

| 模块分类 | 文档链接 | 内容简介与理论支撑 |
| :--- | :--- | :--- |
| 🟢 **架构与原理剖析** | [**👉 01. 系统架构与网络流量链路详解**](./docs/01-architecture-and-traffic.md) | 深度解析 Nginx 前置分流原理、微观 Unix Socket 链路以及 `entrypoint.sh` 的守护进程启动生命周期。 |
| 🔵 **安全加固与协议** | [**👉 02. 后量子加密与 Reality 防探测引擎**](./docs/02-protocols-and-security.md) | 涵盖 MLKEM 理论参考、XTLS-Vision 工作机制、Fallback 路由隐蔽逻辑以及 ACME 证书的自动化申请调优。 |
| 🟡 **调度中枢与客户端** | [**👉 03. 智能路由策略与全平台客户端接入**](./docs/03-routing-and-clients.md) | 详解如何通过 Sub-Store 清洗节点、OpenClash 容忍度优选策略，以及动态 ISP SOCKS5 链式落地的底层实现机制。 |
| 🔴 **系统运维与监控** | [**👉 04. 综合运维、面板管理与故障排查**](./docs/04-ops-and-troubleshooting.md) | 包含多面板入口导航、订阅端点双重安全防扫描机制以及应对 502/404 等常见崩溃的实战排错树 (Troubleshooting Tree)。 |

---

## ⚡ 安装与快速接入 (Quick Start)

**1. 前置准备工作**
确保您的宿主机已安装 Docker 环境，并放行了 TCP `80`、`443` 以及高位 UDP 端口（如果需要 Hysteria2 竞速）。准备好您的**主域名**与**CDN防护域名**，并将其 DNS 的 A 记录指向该服务器 IP。

**2. 编写部署清单 (docker-compose.yml)**
```yaml
services:
  sb-xray:
    image: currycan/sb-xray:latest
    container_name: sb-xray
    network_mode: host
    restart: always
    environment:
      # 必填核心配置
      - DOMAIN=example.com            # 您的私有主域名
      - CDNDOMAIN=cdn.example.com     # 您的 CDN 保护域名
      - DEST_HOST=www.microsoft.com   # Reality 极度伪装目标站点
      # 证书自动化配置
      - ACMESH_SERVER_NAME=zerossl    # CA 机构颁发者 (推荐 ZeroSSL)
      - ACMESH_REGISTER_EMAIL=admin@example.com
    volumes:
      - ./pki:/pki
      - ./acmecerts:/acmecerts
      - ./.envs:/.env
      - ./sb-xray:/sb-xray
      - ./data:/data
```

**3. 一键启动引擎**
```bash
docker compose up -d
```
启动成功后，执行 `docker logs -f sb-xray`。系统将会输出生成的强密码账户、节点 UUID、订阅专属防泄漏 Token 及您的私密入口链接。

---

## 🛠️ 开发与跨平台构建 (Development)

<details>
<summary>点击查看自动整合构建与 Docker Buildx 交叉编译指令</summary>

### 自动整合构建（推荐）
```bash
./build.sh
```

### 手动精细化构建 (Docker Buildx)
```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg SHOUTRRR_VERSION="0.8.0" \
  --build-arg MIHOMO_VERSION="1.19.0" \
  --build-arg HTTP_META_VERSION="1.0.6" \
  --build-arg SUB_STORE_FRONTEND_VERSION="2.16.13" \
  --build-arg SUB_STORE_BACKEND_VERSION="2.21.21" \
  --build-arg SUI_VERSION="1.3.9" \
  --build-arg DUFS_VERSION="0.45.0" \
  --build-arg CLOUDFLARED_VERSION="2026.2.0" \
  --build-arg XUI_VERSION="2.8.9" \
  --build-arg SING_BOX_VERSION="1.12.21" \
  --build-arg XRAY_VERSION="26.2.6" \
  --tag currycan/sb-xray:26.2.6 \
  --tag currycan/sb-xray:latest \
  --push .
```
</details>

---

## 🤝 鸣谢与理论文献 (Acknowledgements & References)

本系统的基石建立在无数伟大的开源项目之上，同时核心架构的实现参考了前沿的通信文献：

*   **[XTLS 核心团队](https://github.com/XTLS/Xray-core)** - 感谢其带来的 Xray-core、XTLS-Vision 及后量子安全隧道机制。
    * *架构参考*: [XTLS/Xray-core#4118 (Reality 端口共存模型)](https://github.com/XTLS/Xray-core/discussions/4118)
    * *通信参考*: [XHTTP 标准探讨](https://github.com/XTLS/Xray-core/discussions/4113)
*   **[SagerNet 团队](https://github.com/SagerNet/sing-box)** - 打造了轻量、高效、通用性极强的 Sing-box 泛用代理内核。
*   **[Sub-Store 维护者](https://github.com/sub-store-org/Sub-Store)** - 赋予了节点资产清洗、聚合的强大灵魂。
*   **加密算法基准**: [NIST FIPS 203 (Module-Lattice-Based Key-Encapsulation Mechanism Standard)](https://csrc.nist.gov/pubs/fips/203/final) - MLKEM 后量子加密的实现理论基石。

## 📄 许可协议 (License)
本项目及其所有相关脚本受 [MIT License](LICENSE) 保护。您可自由用于商业化部署或二次开发分发，但需保留原作者版权声明。
