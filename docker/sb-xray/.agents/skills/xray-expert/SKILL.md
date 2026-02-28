---
name: Xray 协议配置专家
description: Xray 核心的协议原理、配置语法、传输层选型、Reality/XHTTP/ML-KEM 深度调优和性能优化指南
---

# Xray 协议配置专家

## 协议栈总览

Xray 是 XTLS 团队维护的高性能代理内核，支持多种协议与传输组合：

| 协议层 | 可选项 | 说明 |
|:---|:---|:---|
| **代理协议** | VLESS / VMess / Trojan | VLESS 为推荐首选，零开销无加密层；VMess 兼容性最强 |
| **安全层** | Reality / TLS / None | Reality 为主动探测防御的终极方案；TLS 用于 CDN 兼容场景 |
| **传输层** | Raw(TCP) / WebSocket / XHTTP / gRPC | Raw+Reality 性能最优；WebSocket 穿透 CDN；XHTTP 支持分离模式 |
| **加密增强** | ML-KEM 768 (后量子) | XHTTP 模式下可叠加 ML-KEM 768 抗量子攻击 |

### 本项目使用的协议矩阵

```text
┌──────────────────────────────────────────────────────┐
│ Xray 入站配置 (templates/xray/)                       │
├─────────────────────┬────────────────────────────────┤
│ 01_reality_inbounds │ VLESS + Vision + Reality        │
│                     │ 传输: Raw (Unix Domain Socket)  │
│                     │ 回落: Nginx (/dev/shm/nginx.sock)│
├─────────────────────┼────────────────────────────────┤
│ 02_xhttp_inbounds   │ VLESS + XHTTP + Reality         │
│                     │ 加密: ML-KEM 768 x25519plus     │
│                     │ 模式: auto (支持分离)            │
├─────────────────────┼────────────────────────────────┤
│ 03_vmess_ws_inbounds│ VMess + WebSocket + TLS(CDN)    │
│                     │ 路径: /${XRAY_URL_PATH}-vmessws  │
│                     │ 用途: CDN 回源兜底              │
└─────────────────────┴────────────────────────────────┘
```

---

## Reality 协议深度解析

### 工作原理

Reality 是 XTLS 团队设计的主动防御协议，基于 TLS 1.3 (RFC 8446) 扩展实现：

1. **握手阶段**: 客户端发送的 ClientHello 与正常 TLS 连接完全一致
2. **ServerHello**: 服务端使用真实目标站点 (`DEST_HOST`) 的证书链进行握手
3. **认证分离**: 通过 `shortId` + `privateKey` 在 TLS 握手中嵌入认证信息
4. **结果**: 主动探测器看到的是一个完全合法的 TLS 连接，无法区分

> **参考**: [XTLS/Xray-core REALITY Wiki](https://github.com/XTLS/Xray-core/wiki/REALITY)

### 关键配置项

```json
{
    "realitySettings": {
        "show": false,
        "target": "${DEST_HOST}:443",
        "serverNames": ["${DEST_HOST}"],
        "privateKey": "${XRAY_REALITY_PRIVATE_KEY}",
        "shortIds": ["${XRAY_REALITY_SHORTID}"]
    }
}
```

| 参数 | 作用 | 要求 |
|:---|:---|:---|
| `target` | TLS 握手的伪装目标 | 必须是真实存在且支持 TLS 1.3 + H2 的站点 |
| `serverNames` | 允许的 SNI 列表 | 必须与 target 域名匹配 |
| `privateKey` | X25519 密钥对的私钥 | 通过 `xray x25519` 生成，务必保密 |
| `shortIds` | 客户端认证标识 | 最长 16 位十六进制字符串 |

### DEST_HOST 选择原则

1. 必须支持 TLS 1.3 和 H2
2. 与服务器 IP 在同一运营商 / 相近地理位置为佳
3. 站点需长期稳定可用
4. 推荐: `www.microsoft.com`, `www.apple.com`, `speed.cloudflare.com`

### Vision 流控

`flow: "xtls-rprx-vision"` 启用 Vision 流控，特点：
- 读取 TLS 内层数据时不二次加密，减少 CPU 开销
- 仅适用于 Raw (TCP) 传输，不兼容 WebSocket / gRPC
- 配合 Reality 使用时性能最优

> **参考**: VLESS + Vision + Reality 组合是 Xray 官方推荐的最佳实践

---

## XHTTP 传输详解

### 工作原理

XHTTP 是 Xray v24.12+ 引入的下一代传输协议：

- **上行**: 使用 HTTP POST 请求发送数据
- **下行**: 可选 SSE (Server-Sent Events) 或独立连接
- **分离模式**: 上行和下行可走不同网络路径

> **参考**: [XTLS/Xray-core XHTTP 文档](https://github.com/XTLS/Xray-core/discussions/4113)

### 模式选择

| mode | 上行 | 下行 | 适用场景 |
|:---|:---|:---|:---|
| `auto` | POST | 自动协商 | 默认推荐，自动选择最优方式 |
| `packet-up` | POST | SSE | 低延迟场景 |
| `stream-up` | POST Stream | 同连接 | 握手开销最小 |

### 分离模式配置

本项目支持多种上下行分离组合：

```text
模式 1: 上行 XHTTP+Reality 直连 + 下行 XHTTP+Reality 直连 (默认)
模式 2: 上行 XHTTP+TLS+CDN    + 下行 XHTTP+Reality
模式 3: 上行 XHTTP+Reality    + 下行 XHTTP+TLS+CDN
模式 4: 上行 XHTTP+TLS+CDN    + 下行 XHTTP+TLS+CDN (全CDN)
```

分离模式通过 `extra.downloadSettings` 字段配置下行通道的独立传输参数。

---

## ML-KEM 后量子加密

### 原理

ML-KEM (Module-Lattice-based Key Encapsulation Mechanism) 是 NIST 标准化的后量子密钥封装算法：

- **标准**: FIPS 203 (ML-KEM)
- **安全级别**: ML-KEM-768 提供 AES-192 等价安全性
- **用途**: 与 X25519 混合使用，即使量子计算机破解了 X25519，ML-KEM 仍提供保护

> **参考**: [NIST FIPS 203](https://csrc.nist.gov/pubs/fips/203/final), [RFC 7748 (X25519)](https://www.rfc-editor.org/rfc/rfc7748)

### 配置语法

```json
{
    "decryption": "mlkem768x25519plus.native.600s.${XRAY_MLKEM768_SEED}"
}
```

格式解析: `mlkem768x25519plus` `.` `native` `.` `600s` `.` `seed`

| 片段 | 含义 |
|:---|:---|
| `mlkem768x25519plus` | 算法：ML-KEM-768 + X25519 混合 |
| `native` | 使用原生加密库 |
| `600s` | 密钥轮换周期 600 秒 |
| `seed` | 双方共享的种子值 |

客户端连接串中使用 `encryption=mlkem768x25519plus.native.0rtt.${CLIENT_SEED}` 启用 0-RTT 模式。

---

## 路由规则配置

### Xray 路由结构

```json
{
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            { "type": "field", "domain": ["geosite:openai"], "outboundTag": "${CHATGPT_OUT}" },
            { "type": "field", "domain": ["geosite:netflix"], "outboundTag": "${NETFLIX_OUT}" }
        ]
    }
}
```

### domainStrategy 选项

| 策略 | 行为 |
|:---|:---|
| `AsIs` | 仅域名匹配，不做 DNS 解析 |
| `IPIfNonMatch` | 域名未匹配时解析 IP 再匹配（推荐） |
| `IPOnDemand` | 所有域名都解析 IP 匹配 |

### GeoIP / GeoSite 规则集

- `geoip.dat` / `geosite.dat`: Loyalsoldier 维护的规则集
- 路径: `/usr/local/bin/bin/`
- 更新: 由 `scripts/geo_update.sh` 定时更新
- 格式: Xray 使用 V2Ray dat 格式 (`geoip:cn`, `geosite:openai`)

> **参考**: [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat)

---

## 性能调优

### Unix Domain Socket (UDS)

本项目所有 Xray 入站使用 UDS 而非 TCP 端口：

```json
{ "listen": "/dev/shm/udsreality.sock,0666" }
```

优势：省去 TCP 握手开销，延迟更低；`/dev/shm/` 为内存文件系统，I/O 零延迟。

### TCP 优化参数

```json
{
    "sockopt": {
        "tcpFastOpen": true,
        "tcpcongestion": "bbr",
        "tcpMptcp": true,
        "tcpNoDelay": true
    }
}
```

| 参数 | 作用 | 要求 |
|:---|:---|:---|
| `tcpFastOpen` | TFO，减少握手 RTT | 内核 >= 3.7 |
| `tcpcongestion: bbr` | 使用 BBR 拥塞控制 | 内核 >= 4.9 |
| `tcpMptcp` | 多路径 TCP | 内核 >= 5.6 |
| `tcpNoDelay` | 禁用 Nagle 算法 | 降低延迟 |

### Sniffing 嗅探

```json
{
    "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
    }
}
```

`routeOnly: true` 表示仅用嗅探结果做路由决策，不覆盖目标地址，避免 SNI 与实际目标不一致的问题。

---

## 常见配置错误

| 问题 | 原因 | 解决 |
|:---|:---|:---|
| Reality 握手失败 | `serverNames` 与 `target` 不匹配 | 确保两者域名一致 |
| Vision 不生效 | WebSocket/gRPC 传输下使用 Vision | Vision 仅支持 Raw(TCP) |
| XHTTP 连接超时 | Nginx 未正确转发 XHTTP 路径 | 检查 `http.conf` 中的 location 配置 |
| ML-KEM 握手失败 | 客户端 seed 与服务端不匹配 | 核对 `XRAY_MLKEM768_SEED` vs `XRAY_MLKEM768_CLIENT` |
| UUID 认证失败 | 客户端 UUID 错误 | 检查 `XRAY_UUID`，通过 `show-config.sh` 获取正确链接 |

---

## 参考文献

| 领域 | 资源 |
|:---|:---|
| Xray 官方文档 | [xtls.github.io](https://xtls.github.io/) |
| REALITY 原理 | [Xray REALITY Wiki](https://github.com/XTLS/Xray-core/wiki/REALITY) |
| XHTTP 协议 | [Xray XHTTP Discussion](https://github.com/XTLS/Xray-core/discussions/4113) |
| TLS 1.3 | [RFC 8446](https://www.rfc-editor.org/rfc/rfc8446) |
| X25519 | [RFC 7748](https://www.rfc-editor.org/rfc/rfc7748) |
| ML-KEM | [NIST FIPS 203](https://csrc.nist.gov/pubs/fips/203/final) |
| VLESS 协议 | [VLESS Protocol](https://xtls.github.io/development/protocols/vless.html) |
| GeoIP/GeoSite 规则 | [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) |
