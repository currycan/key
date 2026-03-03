---
name: OpenClash 智能调度专家
description: OpenClash (Mihomo 内核) 的 Smart/Fallback 策略组、Policy-Priority 多维权重评分、Filter 正则筛选、覆写脚本和 Sub-Store 集成指南
---

# OpenClash 智能调度专家

## 架构概览

OpenClash 是运行在 OpenWrt 上的代理客户端管理框架，核心引擎为 **Mihomo** (Clash Meta)：

```text
OpenWrt 路由器
  └─ OpenClash (LuCI 插件)
       └─ Mihomo 内核 (Clash Meta)
            ├─ 订阅配置 (YAML)
            ├─ Proxy Provider (远程节点源)
            ├─ Rule Set (远程规则集)
            └─ 策略组 (Smart/Fallback/LoadBalance/Select)
```

### 本项目与 OpenClash 的关系

| 组件 | 角色 |
|:---|:---|
| SB-Xray 服务端 | 提供代理节点 (Reality/XHTTP/Hysteria2/TUIC/AnyTLS) |
| `templates/client_template/` | 生成 OpenClash 可用的 Mihomo YAML 配置 |
| `templates/proxies/` | 生成各格式订阅源（节点列表） |
| `templates/providers/` | 生成 Proxy Provider 配置 |
| `sources/openclash/` | OpenClash UCI 配置样板 |
| `sources/hack/` | OpenClash 覆写脚本 (AnyTLS 兼容性等) |

---

## 策略组类型详解

### Smart (智选)

Mihomo 独有的智能策略组类型，结合 `policy-priority` 权重评分机制：

```yaml
{type: smart, interval: 180, tolerance: 300, lazy: true, url: "https://www.gstatic.com/generate_204", uselightgbm: true, collectdata: true}
```

| 参数 | 作用 |
|:---|:---|
| `interval` | 健康检查间隔（秒） |
| `tolerance` | 延迟容忍度（毫秒），在此范围内按权重排序而非延迟 |
| `lazy` | `true`: 仅在有流量时才进行健康检查 |
| `uselightgbm` | 使用 LightGBM 机器学习模型辅助决策 |
| `collectdata` | 收集训练数据，持续优化选路 |

**核心机制**: 在 `tolerance` 容忍度范围内，节点不单纯按延迟排序，而是按 `policy-priority` 权重累加得分排序。这使得"协议质量 + IP 质量 + 地区偏好"可以综合影响选路。

### Fallback (故障转移)

按优先级顺序依次尝试，第一个可用的节点为主节点：

```yaml
{type: fallback, interval: 180, tolerance: 300, lazy: true, url: "https://www.gstatic.com/generate_204"}
```

适用于需要稳定性优先的场景。

### Load Balance (负载均衡)

```yaml
{type: load-balance, interval: 180, tolerance: 300, lazy: true, url: "https://www.gstatic.com/generate_204"}
```

在可用节点间分散流量，适合带宽需求大的场景。

### URL Test (自动测速)

在 FallBackPro 模板中使用，自动选择延迟最低的节点：

```yaml
{type: url-test, interval: 60, tolerance: 50, lazy: true, url: "https://www.gstatic.com/generate_204"}
```

---

## Policy-Priority 多维权重评分

### 评分原理

`policy-priority` 是 Mihomo Smart 模式的核心机制。它定义了一组 "关键词:权重" 对，Mihomo 会扫描节点名中的关键词，**累加匹配到的所有权重**，最终按总分排序。

### 基础权重配置

本项目所有策略共享的基础权重：

```text
高速:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;TUIC:6;tuic:6;Vmess:3;vmess:3;anytls:1;super:30;good:10
```

解读：

| 权重维度 | 关键词 → 得分 | 设计意图 |
|:---|:---|:---|
| **IP 质量** | `super`:30, `good`:10 | 住宅 IP 直出 8K > ISP 代理出 8K |
| **协议性能** | `Reality`:20, `vless`:10 | Reality 最优 > VLESS > Hysteria2 > TUIC > VMess > AnyTLS |
| **特殊标签** | `高速`:10 | 标记为高速的节点额外加分 |

### 场景化权重叠加

不同使用场景在基础权重上叠加**地区偏好**：

| 策略名 | 场景 | 地区偏好 (高→低) |
|:---|:---|:---|
| `PolicyDefault` | 通用上网 | 无地区偏好 |
| `PolicyISP` | 社交/电商 | 🇺🇸:20 > 🇰🇷:10 > 🇯🇵:6 > 🇸🇬:4 > 🇹🇼:2 |
| `PolicyMedia` | 流媒体 | 🇺🇸:15 > 🇰🇷:8 > 🇯🇵:6 > 🇸🇬:4 > 🇹🇼:2 |
| `PolicyAI` | AI 服务 | 🇺🇸:20 > 🇯🇵:10 > 🇰🇷:8 > 🇸🇬:4 > 🇹🇼:2 |
| `PolicyDialer` | 链式代理 | 🇭🇰:20 > 🇹🇼:15 > 🇨🇳:15 > 🇰🇷:10 |

### 评分示例

节点名: `🇺🇸 洛杉矶 ✈高速 ✈super ✈isp VLESS Reality`

```text
super    → +30
Reality  → +20
高速     → +10
vless    → +10  (VLESS 匹配 vless)
🇺🇸      → +20  (PolicyISP 场景)
─────────────
总分     = 90
```

---

## Filter 正则筛选语法

### 筛选器作用

`filter` 控制策略组**可见哪些节点**，与 `policy-priority` 配合使用。

### 本项目定义的筛选器

| 筛选器 | 用途 | 正则特点 |
|:---|:---|:---|
| `FilterALL` | 全部有效节点 | 排除垃圾词（群、邀请、官网、流量等） |
| `FilterUS/HK/TW/SG/JP/KR` | 按地区筛选 | 正向匹配国旗 + 城市名 |
| `FilterOT` | 其他地区 | 排除所有已知地区 |
| `FilterISP` | 家宽节点 | 匹配 `住宅/isp/ISP/AllOne` |
| `FilterMedia` | 流媒体节点 | 匹配 `流媒体/AllOne` |
| `FilterFAST` | 高速节点 | 匹配 `高速` |
| `FilterAI` | AI 节点 | 匹配 `AI/AllOne` |
| `FilterDialer` | 链式前置 | 匹配 🇭🇰/🇹🇼/🇨🇳 但排除 `-dialer` |

### 正则编写规范

```yaml
# 正向匹配 (include): ^(?=.*(?i)(关键词1|关键词2))(?!.*(排除词)).*$
# 反向匹配 (exclude): ^(?!.*(排除词1|排除词2)).*$
```

- `(?i)`: 不区分大小写
- `(?=.*)`: 正向前瞻（节点名必须包含）
- `(?!.*)`: 负向前瞻（节点名不能包含）
- 所有筛选器都排除 `5x` 以过滤倍率节点

---

## 客户端模板结构

### OneSmartPro.yaml (Smart 模式)

```text
锚点配置 (YAML Anchors)
  ├─ 代理提供者模板 (&BaseProvider)
  ├─ 策略组类型模板 (&BaseSmart, &MediaSmart, &StableSmart)
  ├─ Filter 筛选器 (&FilterALL, &FilterUS, ...)
  ├─ Policy-Priority 权重 (&PolicyDefault, &PolicyISP, ...)
  └─ 策略组选择模板 (&OneSmart, &SelectAI, ...)
代理提供者 (proxy-providers)
  └─ ${CLASH_PROXY_PROVIDERS}  ← 由服务端 envsubst 渲染
代理节点 (proxies)
  └─ ${CLASH_ISP_PROXIES}      ← ISP 链式代理节点
策略组 (proxy-groups)
  ├─ 智选组: 家宽/媒体/高速/AI/LD-智选
  ├─ 服务组: Netflix/YouTube/TikTok/人工智能...
  └─ 地区组: 香港/台湾/日本/韩国/美国/狮城...
规则 (rules)
  └─ RULE-SET 引用远程规则集
规则提供者 (rule-providers)
  └─ ACL4SSR + 自定义规则集
```

### FallBackPro.yaml (Fallback 模式)

结构与 OneSmartPro 类似，但策略组类型从 `smart` 改为 `fallback` + `url-test`，适合追求稳定的场景。

---

## Proxy Provider 订阅机制

客户端通过 `proxy-providers` 获取远程节点列表：

```yaml
proxy-providers:
  provider_name:
    <<: *BaseProvider
    url: "https://example.com/subscribe?token=xxx"
    path: ./proxy_providers/provider_name.yaml
```

- 服务端 `templates/providers/providers.yaml` 模板控制 Provider 定义
- `${CLASH_PROXY_PROVIDERS}` 由 `envsubst` 渲染后注入客户端模板
- 使用 YAML 锚点 `*BaseProvider` 复用公共配置（interval、health-check 等）

---

## 覆写脚本 (Overwrite)

OpenClash 支持在配置加载后执行自定义覆写脚本：

### AnyTLS 兼容性覆写

路径: `sources/hack/anytls_overwrite.sh`

功能: 自动为所有 AnyTLS 节点添加 `skip-cert-verify: true`

```text
触发时机: OpenClash 加载配置后
工作方式: Ruby 脚本解析 YAML → 找到 type=anytls 的节点 → 修改属性 → 写回
```

### 节点重命名

路径: `sources/hack/rename.js`

功能: 深度格式化节点名称（清理无效字符、标准化分隔符），确保 Smart 模式的正则权重匹配正确。

---

## Sub-Store 节点清洗集成

本项目内置 Sub-Store 订阅管理：

1. **接收**: Sub-Store 从上游获取原始订阅
2. **清洗**: 通过 `rename.js` 等脚本规范化节点名称
3. **输出**: 清洗后的节点通过 Proxy Provider 供 OpenClash 调用
4. **关键**: 节点名的规范化直接影响 `filter` 筛选和 `policy-priority` 评分的准确性

---

## 调试与排障

### 查看当前策略组状态

```bash
# OpenClash 面板
http://<路由器IP>/cgi-bin/luci/admin/services/openclash

# API 查询活跃节点
curl http://127.0.0.1:9090/proxies | jq '.proxies["默认代理"]'
```

### 追踪权重计算

```bash
# 查看 Policy-Priority 计分日志
grep "policy-priority" /tmp/openclash.log
```

### 常见问题

| 问题 | 原因 | 解决 |
|:---|:---|:---|
| AnyTLS 节点无法连接 | 缺少 `skip-cert-verify` | 部署 `anytls_overwrite.sh` 覆写脚本 |
| 权重评分不准 | 节点名格式不统一 | 通过 Sub-Store `rename.js` 规范化 |
| Provider 节点为空 | 订阅链接过期或 token 错误 | 检查 `SUBSCRIBE_TOKEN` 和订阅 URL |
| 规则集加载失败 | GitHub 连接超时 | 使用 CDN 代理规则源 (如 `gh-proxy.com`) |
| Smart 不切换节点 | `tolerance` 过高 | 适当降低容忍度 (如 300ms → 150ms) |

> **rename.js 相关**：节点名格式异常时，优先查 `.agents/skills/_shared/BUGS.md` rename.js 分区（Bug #001-#007），避免重复踩坑。
> **Bug 记录**：修复 OpenClash / 覆写脚本 Bug 后，追加到 `.agents/skills/_shared/BUGS.md` 对应分区。

---

## 参考文献

| 领域 | 资源 |
|:---|:---|
| Mihomo (Clash Meta) | [wiki.metacubex.one](https://wiki.metacubex.one/) |
| OpenClash 项目 | [github.com/vernesong/OpenClash](https://github.com/vernesong/OpenClash) |
| ACL4SSR 规则集 | [github.com/ACL4SSR/ACL4SSR](https://github.com/ACL4SSR/ACL4SSR) |
| Sub-Store | [github.com/sub-store-org/Sub-Store](https://github.com/sub-store-org/Sub-Store) |
| Custom OpenClash Rules | [github.com/Aethersailor/Custom_OpenClash_Rules](https://github.com/Aethersailor/Custom_OpenClash_Rules) |
| OpenClash Overwrite | [github.com/Giveupmoon/OpenClash_Overwrite](https://github.com/Giveupmoon/OpenClash_Overwrite) |
