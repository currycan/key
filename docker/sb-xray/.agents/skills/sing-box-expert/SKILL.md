---
name: Sing-box 协议配置专家
description: Sing-box 核心的 Hysteria2/TUIC/AnyTLS 协议原理、配置语法、QUIC 调优和规则集管理指南
---

# Sing-box 协议配置专家

## Sing-box 与 Xray 的定位差异

| 维度 | Xray | Sing-box |
|:---|:---|:---|
| 语言 | Go | Go |
| 主打协议 | VLESS+Reality, XHTTP | Hysteria2, TUIC, AnyTLS |
| 传输特色 | TLS 伪装 (Reality) | QUIC 加速 (Hysteria2/TUIC) |
| 规则格式 | GeoIP/GeoSite dat 文件 | Rule Set (SRS 二进制) |
| 配置格式 | 多文件 JSON | 单文件 JSON |
| 项目角色 | 主核心 (Reality/XHTTP/VMess) | 辅核心 (Hysteria2/TUIC/AnyTLS) |

---

## 本项目使用的协议矩阵

```text
┌──────────────────────────────────────────────────────┐
│ Sing-box 入站配置 (templates/sing-box/)               │
├──────────────────────┬───────────────────────────────┤
│ 01_hysteria2_inbounds│ Hysteria2 (QUIC)             │
│                      │ 端口: ${PORT_HYSTERIA2}       │
│                      │ 认证: password (SB_UUID)      │
│                      │ TLS: ALPN h3, 证书文件         │
├──────────────────────┼───────────────────────────────┤
│ 02_tuic_inbounds     │ TUIC v5 (QUIC)               │
│                      │ 端口: ${PORT_TUIC}            │
│                      │ 认证: UUID + password          │
│                      │ 拥塞: BBR, zero_rtt 关闭       │
├──────────────────────┼───────────────────────────────┤
│ 03_anytls_inbounds   │ AnyTLS                        │
│                      │ 端口: ${PORT_ANYTLS}          │
│                      │ 认证: password (SB_UUID)       │
│                      │ TLS: 证书文件                  │
└──────────────────────┴───────────────────────────────┘
```

---

## Hysteria2 协议深度解析

### 工作原理

Hysteria2 基于 QUIC (RFC 9000) 协议，核心创新在于自定义拥塞控制：

1. **传输层**: 使用 QUIC 而非 TCP，天然支持多路复用和 0-RTT
2. **拥塞控制**: 可选 Brutal（暴力发送）或 BBR
3. **加密**: TLS 1.3 (ALPN: h3)
4. **认证**: 基于 password 的简单认证

> **参考**: [Hysteria2 官方文档](https://v2.hysteria.network/), [RFC 9000 (QUIC)](https://www.rfc-editor.org/rfc/rfc9000)

### 关键配置项

```json
{
    "type": "hysteria2",
    "listen_port": 50001,
    "users": [{ "password": "${SB_UUID}" }],
    "ignore_client_bandwidth": false,
    "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "min_version": "1.3",
        "max_version": "1.3",
        "certificate_path": "${SSL_PATH}/sb_xray_bundle.crt",
        "key_path": "${SSL_PATH}/sb_xray_bundle.key"
    }
}
```

| 参数 | 作用 | 建议 |
|:---|:---|:---|
| `ignore_client_bandwidth` | `false`: 尊重客户端带宽声明；`true`: 服务端强制限速 | 设为 `false` 让客户端自行调节 |
| `alpn` | TLS 应用层协议协商 | 必须为 `["h3"]` 以启用 QUIC |
| `min_version` / `max_version` | TLS 版本限制 | 均设 `"1.3"` 以获最佳安全性 |

### Brutal vs BBR 拥塞控制

| 模式 | 特点 | 适用场景 |
|:---|:---|:---|
| **Brutal** | 忽略丢包反馈，按设定带宽强制发送 | 高丢包/高延迟网络（需内核模块支持） |
| **BBR** | 基于带宽和延迟的自适应算法 | 通用场景，无需额外内核支持 |

> 本项目通过 `check_brutal_status()` 检测内核是否加载 `tcp_brutal` 模块，结果存入 `IS_BRUTAL` 变量。

---

## TUIC 协议深度解析

### 工作原理

TUIC v5 同样基于 QUIC，但设计侧重于：

1. **UUID 认证**: 比密码更规范的认证方式
2. **拥塞控制可选**: 支持 `bbr` / `cubic` / `new_reno`
3. **零 RTT**: `zero_rtt_handshake` 可加速初始连接（但有重放攻击风险）

> **参考**: [TUIC 项目](https://github.com/EAimTY/tuic)

### 关键配置项

```json
{
    "type": "tuic",
    "listen_port": 50002,
    "users": [{ "uuid": "${SB_UUID}", "password": "${SB_UUID}" }],
    "congestion_control": "bbr",
    "zero_rtt_handshake": false,
    "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "...",
        "key_path": "..."
    }
}
```

| 参数 | 作用 |
|:---|:---|
| `congestion_control` | 拥塞控制算法，推荐 `bbr` |
| `zero_rtt_handshake` | 0-RTT 握手，`false` 更安全 |
| `uuid` + `password` | 双因素认证（TUIC v5 特有） |

---

## AnyTLS 协议深度解析

### 工作原理

AnyTLS 是 Sing-box 的创新协议，核心特点：

1. **TLS 指纹伪装**: 连接看起来完全像普通 HTTPS 流量
2. **填充方案**: `padding_scheme` 可定义数据包填充规则，进一步对抗流量分析
3. **简洁认证**: 基于 password 的轻量认证

> **参考**: [Sing-box AnyTLS 文档](https://sing-box.sagernet.org/configuration/inbound/anytls/)

### 关键配置项

```json
{
    "type": "anytls",
    "listen_port": 50003,
    "users": [{ "password": "${SB_UUID}" }],
    "padding_scheme": [],
    "tls": {
        "enabled": true,
        "certificate_path": "...",
        "key_path": "..."
    }
}
```

| 参数 | 作用 |
|:---|:---|
| `padding_scheme` | 数据填充方案，空数组表示不填充 |
| 无 `alpn` | AnyTLS 不需要指定 ALPN |

### OpenClash 兼容性

AnyTLS 节点在 OpenClash (Mihomo) 中需要 `skip-cert-verify: true`。本项目提供覆写脚本 `sources/hack/anytls_overwrite.sh` 自动处理此兼容性。

---

## Sing-box 路由与规则集

### Rule Set 格式 (vs Xray GeoIP)

Sing-box 使用远程 Rule Set 替代传统 dat 文件：

```json
{
    "rule_set": [
        {
            "tag": "geosite-openai",
            "type": "remote",
            "format": "binary",
            "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-openai.srs"
        }
    ]
}
```

| 特性 | Xray (dat) | Sing-box (Rule Set) |
|:---|:---|:---|
| 格式 | 单一大文件 | 按规则分文件 |
| 更新 | 需下载整个 dat | 独立更新各规则集 |
| 引用 | `geosite:openai` | `rule_set: ["geosite-openai"]` |
| 来源 | Loyalsoldier | SagerNet |

### 路由规则语法差异

```json
// Xray 风格
{ "type": "field", "domain": ["geosite:openai"], "outboundTag": "proxy" }

// Sing-box 风格
{ "rule_set": ["geosite-openai"], "outbound": "proxy" }
```

### DNS 策略

```json
{
    "dns": {
        "servers": [{ "address": "1.1.1.1" }, { "address": "8.8.8.8" }],
        "strategy": "${STRATEGY}"
    }
}
```

`STRATEGY` 取值:
- `prefer_ipv4`: 优先 IPv4 解析
- `prefer_ipv6`: 优先 IPv6 解析
- `ipv4_only` / `ipv6_only`: 仅使用指定协议

---

## TLS 证书管理

Hysteria2、TUIC、AnyTLS 三个协议共享同一套 TLS 证书：

```text
证书路径: ${SSL_PATH}/sb_xray_bundle.crt
密钥路径: ${SSL_PATH}/sb_xray_bundle.key
```

- 由 `entrypoint.sh` 的 `issueCertificate()` 函数通过 ACME.sh 自动申请
- 支持 ZeroSSL 和 Google CA
- 自动续期，无需人工干预

> **参考**: [ACME.sh 文档](https://github.com/acmesh-official/acme.sh)

---

## 性能调优

### NTP 时间同步

```json
{
    "ntp": {
        "enabled": true,
        "server": "time.apple.com",
        "server_port": 123,
        "interval": "60m"
    }
}
```

QUIC 协议对时间精度敏感，NTP 确保服务端时钟准确。

### 缓存机制

```json
{
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "${WORKDIR}/sing-box/cache.db"
        }
    }
}
```

缓存 DNS 解析结果和规则集，加速后续请求处理。

---

## 常见配置错误

| 问题 | 原因 | 解决 |
|:---|:---|:---|
| Hysteria2 连接失败 | 端口被防火墙 / NAT 阻断 (UDP) | 确保 UDP 端口开放 |
| TUIC 认证失败 | UUID 格式错误或未同步 | 核对容器内 `/.env/sb-xray` 中的 `SB_UUID` |
| AnyTLS 证书错误 | 证书未签发或路径不正确 | 检查 `${SSL_PATH}` 下的证书文件 |
| Rule Set 加载失败 | 网络无法访问 GitHub Raw | 容器内需配置代理或使用镜像源 |
| QUIC 性能差 | Brutal 内核模块未加载 | 检查 `IS_BRUTAL` 变量，加载 `tcp_brutal` 模块 |

---

## 参考文献

| 领域 | 资源 |
|:---|:---|
| Sing-box 官方文档 | [sing-box.sagernet.org](https://sing-box.sagernet.org/) |
| Hysteria2 文档 | [v2.hysteria.network](https://v2.hysteria.network/) |
| TUIC 项目 | [github.com/EAimTY/tuic](https://github.com/EAimTY/tuic) |
| QUIC 协议 | [RFC 9000](https://www.rfc-editor.org/rfc/rfc9000) |
| TLS 1.3 | [RFC 8446](https://www.rfc-editor.org/rfc/rfc8446) |
| Rule Set 规则源 | [SagerNet/sing-geosite](https://github.com/SagerNet/sing-geosite) |
| ACME.sh | [github.com/acmesh-official/acme.sh](https://github.com/acmesh-official/acme.sh) |
