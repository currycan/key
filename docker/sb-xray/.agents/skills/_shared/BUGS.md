---
name: SB-Xray 共享 Bug 知识库
description: 跨 Skill 的 Bug 修复记录，所有 Agent 工作时必须优先查阅，避免重复踩坑
---

# SB-Xray 共享 Bug 知识库

> **使用规则**：
> - Agent 开始编码前必须查阅与当前任务相关的条目
> - Agent 修复 Bug 后**必须**在此追加新条目（格式见末尾模板）
> - 条目编号递增，禁止修改已有编号
> - 每条记录对应 `CLAUDE.md` 纠错记录的溯源

---

## rename.js / Sub-Store 脚本

### Bug #001 — processPreFormatted 英文地名未转中文

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `sources/hack/rename.js` |
| **函数** | `processPreFormatted` |
| **触发条件** | 预格式化节点（已含旗帜 + `✈`）中含英文地名，如 `Hong Kong`、`Tokyo` |
| **错误现象** | 输出节点名地名仍为英文，未归化为中文（香港、东京） |
| **根本原因** | `flatMap(Utils.cleanPreformatted)` 之后没有调用 `Utils.standardizeRegion()`；`cleanPreformatted` 内部跳过了分隔符规则，但也跳过了地名归化 |
| **修复方案** | `flatMap` 后追加两步 map：`.map(part => Utils.standardizeRegion(part))` + `.map(part => part.replace(/^[-_\||\s]+\|[-_\||\s]+$/g, '').trim())` |
| **预防措施** | 预格式化通道任何后处理步骤都必须保留 `standardizeRegion` 调用 |
| **记录时间** | 2026-03-03 |

---

### Bug #002 — cleanPreformatted 用字符串描述作为功能标志（易碎耦合）

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `sources/hack/rename.js` |
| **函数** | `Utils.cleanPreformatted`、`CleaningRules` |
| **触发条件** | 修改 `CleaningRules` 中分隔符规则的 `desc` 描述文字时 |
| **错误现象** | `rule.desc.includes('分隔符')` 判断失效，分隔符规则被错误执行或跳过 |
| **根本原因** | 用自然语言字符串作为功能控制标志，文字改变则逻辑静默失效 |
| **修复方案** | 在 `CleaningRules` 分隔符规则上添加 `skipInPreformat: true` 布尔字段；`cleanPreformatted` 改为 `if (rule.skipInPreformat) continue` |
| **预防措施** | 功能控制标志用布尔字段，不依赖描述文字；同类规则扩展时先检查是否需要此标志 |
| **记录时间** | 2026-03-03 |

---

### Bug #003 — CountryDB 末尾重复条目导致规则重复注册

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `sources/hack/rename.js` |
| **数据结构** | `CountryDB` 数组 |
| **触发条件** | 脚本加载时执行 `initFlagRules()` |
| **错误现象** | 英国（UK）和韩国（KR）的 flag 规则被重复注册两次 |
| **根本原因** | `CountryDB` 末尾各有一个重复条目（相同 `code`） |
| **修复方案** | 删除末尾的两个重复条目 |
| **预防措施** | 向 `CountryDB` 添加新条目前，先用 `code` 字段检查是否已存在；可考虑在 `initFlagRules` 中加断言：`const codes = CountryDB.map(x => x.code); if (new Set(codes).size !== codes.length) throw new Error('CountryDB 有重复 code')` |
| **记录时间** | 2026-03-03 |

---

### Bug #004 — 协议名移除正则无词边界，误删单词内字母

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `sources/hack/rename.js` |
| **函数** | `processRawNode` 协议名清理段 |
| **触发条件** | 节点名包含 `ss` 协议，且名称中有含 `ss` 的单词（如 `Russia`） |
| **错误现象** | `Russia` → `Ruia`（`ss` 被作为协议名误删） |
| **根本原因** | `new RegExp(protocol, 'ig')` 无词边界限制，`ss` 会匹配到任意位置 |
| **修复方案** | `const escapedProto = protocol.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');` + `new RegExp(\`\\b${escapedProto}\\b\`, 'ig')` |
| **预防措施** | 所有"移除单词"类正则必须加 `\b` 词边界；协议名列表中有 `ss`，必须特别注意 |
| **记录时间** | 2026-03-03 |

---

### Bug #005 — promoteRegion 直接修改输入数组（副作用突变）

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `sources/hack/rename.js` |
| **函数** | `Utils.promoteRegion` |
| **触发条件** | 调用 `promoteRegion(parts)` 后继续使用原 `parts` 变量 |
| **错误现象** | 原数组被 `splice` + `unshift` 原地修改，调用者产生非预期副作用 |
| **根本原因** | 函数直接在入参上调用 `splice`，违反纯函数原则 |
| **修复方案** | 函数开头 `const result = [...parts]`，后续所有操作在 `result` 上进行，`return result` |
| **预防措施** | 数组/对象变换辅助函数默认返回新副本，不修改入参；函数签名注释中标注 "returns new array" |
| **记录时间** | 2026-03-03 |

---

### Bug #006 — FlagRules 手动规则双层捕获括号冗余

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `sources/hack/rename.js` |
| **数据结构** | `FlagRules` 手动规则正则 |
| **触发条件** | 使用正则捕获组结果（`match[1]` 等）时 |
| **错误现象** | `/(( 美[国國]\|...))/i` 外层多一个捕获组，`match[1]` 和 `match[2]` 指向不同层级，部分用法中返回非预期的捕获内容 |
| **根本原因** | 正则手写时多加了一层外括号 |
| **修复方案** | 去掉最外层多余括号：`/(美[国國]\|...)/i` |
| **预防措施** | 正则只保留语义必要的捕获组；添加新 FlagRule 时复制既有格式 `/(关键词1\|关键词2)/i` |
| **记录时间** | 2026-03-03 |

---

### Bug #007 — allRegions 数组在多处函数内重复构建（性能浪费）

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `sources/hack/rename.js` |
| **函数** | `splitAndDedup`、`promoteRegion`、`getPriority`、`extractRegionKey` |
| **触发条件** | 节点处理流水线执行，每个节点调用上述函数时 |
| **错误现象** | 每次调用都执行 `[...Constants.PRIORITY_REGIONS, ...Object.keys(RegionMap)]`，重复构建相同数组 |
| **根本原因** | 派生数据没有在初始化时计算并缓存，而是散落在各函数中重复计算 |
| **修复方案** | 在 `initFlagRules()` 末尾计算 `Constants.ALL_REGIONS`；四处函数统一引用 `Constants.ALL_REGIONS` |
| **预防措施** | 从常量派生的数据在初始化 IIFE 中一次性计算，挂到 `Constants` 上；新增依赖 `RegionMap` 的函数先查 `Constants.ALL_REGIONS` |
| **记录时间** | 2026-03-03 |

---

## entrypoint.sh / Shell 脚本

*（此分区待记录）*

---

## Xray 配置模板

*（此分区待记录）*

---

## Sing-box 配置模板

*（此分区待记录）*

---

## Nginx / Docker 构建

*（此分区待记录）*

---

## 客户端模板 / Clash YAML

### Bug #008 — stash.yaml 中 `nameserver-policy` 值类型错误，Stash 解析失败

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `templates/client_template/stash.yaml` |
| **函数** | DNS 配置块 `nameserver-policy` |
| **触发条件** | Stash 客户端（iOS/macOS）加载订阅，`nameserver-policy` 的值为 YAML 列表（`!!seq`）时 |
| **错误现象** | Stash 抛出 `yaml: unmarshal errors: line N: cannot unmarshal !!seq into string`，配置加载失败 |
| **根本原因** | Stash 基于旧版 Clash 解析器，`nameserver-policy` 值类型硬编码为 `map[string]string`（标量），不接受 `[]string`（列表）。新版 mihomo 已将该字段升级为 `map[string][]string`，两者不兼容 |
| **修复方案** | 将列表格式改为单字符串值：`"geosite:private,cn": "119.29.29.29"`，每个 key 只保留一个 DNS 服务器 |
| **预防措施** | stash.yaml 专属字段凡涉及 nameserver-policy，值一律使用字符串标量，不使用列表；若需多个 DNS 可在 nameserver 字段中配置 |
| **记录时间** | 2026-03-04 |

---

### Bug #009 — FallBackPro.yaml `proxy-server-nameserver` 使用 DoH 在 `auto-route: false` 下引发 DNS 引导循环，节点健康检查全部失败

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `templates/client_template/FallBackPro.yaml` |
| **函数** | DNS 配置块 `proxy-server-nameserver`、`nameserver-policy` |
| **触发条件** | ClashMi（macOS）以 `auto-route: false` 运行，DNS 使用 DoH（`https://1.1.1.1/dns-query`）时 |
| **错误现象** | 所有节点健康检查失败，无可用节点 |
| **根本原因** | `auto-route: false` 时 Clash 不修改系统路由表，DoH 请求（TCP 到 `1.1.1.1:443`）进入 Clash 内部路由规则匹配，命中 `MATCH,兜底流量`，被转发给代理组。此时代理组无可用节点（健康检查尚未完成），DoH 失败 → 节点域名解析失败 → 健康检查继续失败 → 死锁。相比之下，`auto-route: true` 时（如 stash.yaml）Clash 会向系统路由表注入 DNS 服务器 IP 的绕过路由，DoH 走物理网卡直连，无此问题 |
| **修复方案** | 删除 `proxy-server-nameserver` 和 `nameserver-policy` 中的 DoH 配置，改用普通 UDP DNS（`119.29.29.29` 等）；`fake-ip-filter` 无此问题可保留 |
| **预防措施** | `auto-route: false` 的客户端模板中，DNS 服务器只使用 UDP 纯 IP 地址，不使用 DoH URL；`auto-route: true` 的模板（stash.yaml）可安全使用 DoH |
| **记录时间** | 2026-03-04 |

---

### Bug #010 — OneSmartPro.yaml `AND,((DST-PORT,443),(NETWORK,UDP)),REJECT` 在 OpenWrt TPROXY 下导致客户端无法上网

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `templates/client_template/OneSmartPro.yaml` |
| **函数** | `rules` 规则块 QUIC 阻断规则 |
| **触发条件** | OpenClash（OpenWrt）以 TPROXY 模式运行，客户端访问 QUIC（UDP/443）网站时 |
| **错误现象** | 路由器上"网络测试"节点健康正常，但 LAN 客户端所有网站均无法打开，表现为连接超时 |
| **根本原因** | 客户端 UDP/443 被 iptables TPROXY 重定向到 mihomo，mihomo 执行 `REJECT` 需要发送 ICMP Port Unreachable 给客户端。但 ICMP 的源 IP 是 fake IP（`198.20.x.x`），该地址不属于路由器本地接口，OpenWrt 防火墙（rp_filter / 出向规则）会拦截这类异常源 IP 的出向包，ICMP 永远无法送达客户端。客户端等待 QUIC 超时（1-3 秒），现代浏览器（Chrome/Safari）每次连接都要经历此过程，用户感知为"无法上网" |
| **修复方案** | 删除 `AND,((DST-PORT,443),(NETWORK,UDP)),REJECT` 规则，让 QUIC 流量正常走代理处理。若需阻断 QUIC，应在 OpenWrt iptables/nftables 层面 DROP，而非在 mihomo 规则层发送 REJECT |
| **预防措施** | 在 TPROXY 透明代理场景下，mihomo 的 `REJECT` 动作对 UDP 流量不可靠（ICMP 回包路由异常）；需要静默丢弃时使用 iptables DROP，需要让浏览器快速回退时同样用 DROP（客户端会因无响应快速切 TCP） |
| **记录时间** | 2026-03-04 |

---

### Bug #011 — OneSmartPro.yaml `hosts: ".dev": 127.0.0.1` 误劫持所有 `.dev` TLD 域名

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `templates/client_template/OneSmartPro.yaml` |
| **函数** | DNS 配置块 `hosts` |
| **触发条件** | 客户端访问任意 `.dev` TLD 域名（如 `web.dev`、`dart.dev`） |
| **错误现象** | `.dev` TLD 域名全部解析到 `127.0.0.1`，连接路由器本地，实际网站不可达 |
| **根本原因** | `hosts` 中 `".dev": 127.0.0.1` 是从 Clash 开发环境模板复制的（开发时用 `.dev` 后缀模拟域名），但 `.dev` 在 2019 年后已成为 Google 注册的真实 TLD；在生产路由器上此条目错误地将所有 `.dev` 真实网站劫持到本地 |
| **修复方案** | 删除 `hosts` 中的 `".dev": 127.0.0.1` 和 `".local": 127.0.0.1` 条目；只保留 `"*.clash.dev"` 和 `"alpha.clash.dev"` 等明确的开发用域名 |
| **预防措施** | `hosts` 段不得使用通配 TLD（`.dev`、`.local`、`.test` 等）作为 Key，除非明确知道该 TLD 不存在真实网站；`.local` 是 mDNS 保留域名也不应映射到 127.0.0.1 |
| **记录时间** | 2026-03-04 |

---

### Bug #012 — `fake-ip-filter` 引用运行时 rule-set 导致 DNS 模块启动阻塞，OpenClash 客户端全部无法上网

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `templates/client_template/FallBackPro.yaml`、`templates/client_template/OneSmartPro.yaml` |
| **函数** | DNS 配置块 `fake-ip-filter` |
| **触发条件** | OpenClash（OpenWrt）启动 mihomo，`fake-ip-filter` 中包含 `"rule-set:fakeipfilter_domain"` 且该规则集需从网络下载时 |
| **错误现象** | OpenClash 网络测试正常（代理节点可达），但所有 LAN 客户端 DNS 解析失败，完全无法上网；客户端手动设置外部 DNS（如 `114.114.114.114`）后恢复正常 |
| **根本原因** | mihomo 初始化 DNS 模块时，必须先加载 `fake-ip-filter` 引用的所有规则集，才能启动 DNS 服务器（端口 7874）。`rule-set:fakeipfilter_domain` 是 HTTP 类型规则集，需在 mihomo 启动时从网络下载（`raw.githubusercontent.com`），但此时 OpenClash 的代理尚未建立、国内直连 GitHub 成功率低，下载失败或超时导致 DNS 模块一直无法完成初始化，客户端发往路由器 IP 的 DNS 查询永远无响应 |
| **修复方案** | 从 `fake-ip-filter` 中删除 `"rule-set:fakeipfilter_domain"` 引用，同时从 `rule-providers` 中删除该规则集定义；`fake-ip-filter` 仅保留内置数据源：`+.lan`、`+.local`、`"geosite:cn"`（mihomo 内置 geosite.dat，随时可用，不阻塞启动） |
| **预防措施** | `fake-ip-filter` 中**禁止**引用 HTTP 类型（需下载）的 rule-set；只使用 `geosite:xxx`（内置）和 `+.domain` 字面量；如需补充 fakeip 过滤，等 mihomo 启动完成后由路由规则下载，不放在 fake-ip-filter 中 |
| **记录时间** | 2026-03-04 |

---

## OpenClash 系统配置 (op-amd / op-arm)

### Bug #013 — OpenClash Smart 模式开启"ASN 优先"导致 DNS 泄露

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `sources/openclash/op-amd`、`sources/openclash/op-arm` |
| **函数** | UCI 配置块 `smart_prefer_asn` 选项 |
| **触发条件** | OpenClash 开启 Smart 模式（`smart_enable '1'`）且 `smart_prefer_asn '1'` 时 |
| **错误现象** | DNS 泄露：本应走代理解析的域名被直接发往本地/ISP DNS，隐私保护失效 |
| **根本原因** | Smart 模式"ASN 优先"会优先按 ASN 路由流量，此逻辑会绕过 fake-ip DNS 拦截，导致部分 DNS 查询直接发往上游而非 mihomo 内部 DNS 处理 |
| **修复方案** | 将 `option smart_prefer_asn` 设为 `'0'`，禁用 ASN 优先；两个架构配置文件均需修改（op-amd 第 408 行、op-arm 第 409 行） |
| **预防措施** | OpenClash Smart 模式配置中，`smart_prefer_asn` 必须保持 `'0'`；升级 OpenClash 或重置配置后需检查该值是否被重置为 `'1'` |
| **记录时间** | 2026-03-05 |

---

## 新增 Bug 记录模板

> 修复 Bug 后，复制以下模板追加到对应分区末尾：

```markdown
### Bug #NNN — [一句话描述]

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `path/to/file` |
| **函数** | `functionName` |
| **触发条件** | 什么情况下会触发 |
| **错误现象** | 外部观察到的错误表现 |
| **根本原因** | 为什么会出现这个问题 |
| **修复方案** | 具体怎么改的（可附代码片段） |
| **预防措施** | 今后编写类似代码时的注意事项 |
| **记录时间** | YYYY-MM-DD |
```
