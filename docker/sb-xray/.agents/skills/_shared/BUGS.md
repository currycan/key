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

### Bug #014 — http_probe 使用 eval 拼接 URL 存在命令注入风险

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `http_probe` |
| **触发条件** | `URL` 参数含特殊 shell 字符（如空格、引号、反引号）时 |
| **错误现象** | `eval "$head_cmd \"$url\""` 会执行 URL 中注入的命令 |
| **根本原因** | 使用 `eval` 拼接带外部输入的字符串，破坏命令边界 |
| **修复方案** | 改用数组参数：`local args=(-I -s ...); curl "${args[@]}" "$url"` |
| **预防措施** | 任何含外部输入的命令绝不使用 `eval`；参数数组 `"${args[@]}"` 是唯一安全做法 |
| **记录时间** | 2026-03-05 |

---

### Bug #015 — ensure_var 从文件检测后未将变量加载到当前 shell

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `ensure_var` |
| **触发条件** | 变量已写入 `ENV_FILE` 但当前 shell 未 export（如容器重启后重新加载） |
| **错误现象** | `grep -q` 检测到文件中存在变量后直接 `return`，变量在当前 shell 中仍为空 |
| **根本原因** | 原逻辑仅作存在性检查，未将文件内容 `source` 或 `export` 到当前进程 |
| **修复方案** | 检测到后用 `grep + sed` 提取值并 `export "${key}=${val}"` |
| **预防措施** | `ensure_var` 三分支（已在 shell / 已在文件→加载 / 都没有→计算）必须每支都显式 export |
| **记录时间** | 2026-03-05 |

---

### Bug #016 — apply_isp_routing_logic L754 死代码条件永不成立

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `apply_isp_routing_logic` |
| **触发条件** | 任何调用路径 |
| **错误现象** | `if [[ "${ISP_TAG}" != "direct" && -z "${ISP_TAG}" && -n "${first_tag}" ]]` 条件永远为 false |
| **根本原因** | `ISP_TAG != "direct"` 与 `-z ISP_TAG` 矛盾：if-else 结构已保证进入该分支时 `ISP_TAG` 已赋值（非空），故 `-z ISP_TAG` 恒 false |
| **修复方案** | 改为防御性兜底：`if [[ -z "${ISP_TAG:-}" && -n "${first_tag:-}" ]]` |
| **预防措施** | 死代码通常出现在多次修改后条件没有跟随逻辑更新。重构前先分析每个条件的不变量 |
| **记录时间** | 2026-03-05 |

---

### Bug #017 — speed_test 通过全局 CurlARG 传递代理参数导致状态污染

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `speed_test` |
| **触发条件** | 先调用代理测速，再调用直连测速时 |
| **错误现象** | 直连测速意外带上代理参数，导致测速结果不准确 |
| **根本原因** | 代理参数通过全局变量 `CurlARG` 传递，函数调用后未清理 |
| **修复方案** | 将代理参数改为函数参数 `speed_test <url> <name> [proxy] [proxy_auth]`，构造局部 `args` 数组 |
| **预防措施** | 函数间通信优先用参数，不用全局变量；必须通信时在函数结束前显式 `unset` |
| **记录时间** | 2026-03-05 |

---

### Bug #018 — sed -i 在 macOS BSD sed 上不加空字符串参数会报错

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `ensure_var`、`ensure_key_pair`、`apply_isp_routing_logic` 等 |
| **触发条件** | 在 macOS 上运行脚本或测试时 |
| **错误现象** | `sed: 1: "...": invalid command code f` |
| **根本原因** | macOS BSD sed 的 `-i` 选项必须跟空字符串 `sed -i ''`，而 GNU sed 不接受这个格式 |
| **修复方案** | 在 §2 封装跨平台函数：`if [[ "$(uname)" == "Darwin" ]]; then _sed_i() { sed -i '' "$@"; }; else _sed_i() { sed -i "$@"; }; fi`，所有 `sed -i` 改用 `_sed_i` |
| **预防措施** | 任何需要原地编辑文件的 sed 调用都必须通过 `_sed_i`，不要直接使用 `sed -i` |
| **记录时间** | 2026-03-05 |

---

### Bug #019 — tr | head -c 管道在 pipefail 模式下触发 SIGPIPE 误退出

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `generateRandomStr` |
| **触发条件** | `set -eo pipefail` 下调用 `generateRandomStr password/path`，或在子 shell 中通过 `$()` 调用 |
| **错误现象** | 脚本以退出码 141（SIGPIPE）退出，后续代码不执行 |
| **根本原因** | `head -c N` 读完所需字节后退出，`tr` 写入关闭的管道得到 SIGPIPE；`pipefail` 将管道退出码设为 141；`set -e` 导致脚本立即退出 |
| **修复方案** | 末尾加 `|| true`：`LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom \| head -c "$length" \|\| true` |
| **预防措施** | 任何 `producer | head` 类管道在 `pipefail` 脚本中都必须用 `|| true` 抑制 SIGPIPE；同理适用于 `| grep -m1` 等提前退出的消费者 |
| **记录时间** | 2026-03-05 |

---

## Xray 配置模板

### Bug #032 — policy-priority 关键词大小写不符，AnyTLS 实际得 0 分

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `templates/client_template/OneSmartPro.yaml`、`scripts/show-config.sh` |
| **函数** | `policy-priority` 权重配置、`generate_links` 节点命名 |
| **触发条件** | Mihomo Smart 模式加载含 AnyTLS/TUIC 节点的策略组时 |
| **错误现象** | AnyTLS 节点实际得 0 分（anytls:1 不匹配节点名 "AnyTLS"）；TUIC 得 6 分高于 AnyTLS，优先级与实际稳定性（高峰期 TUIC UDP QoS 严重）相反；vless/hysteria2/tuic/vmess 小写关键词全部不匹配实际大写节点名，均为死权重 |
| **根本原因** | Mihomo policy-priority 为**区分大小写**的字符串包含匹配；节点名使用大写首字母（`AnyTLS`/`TUIC`/`Hysteria2`/`Vmess`），但 policy-priority 中部分关键词为小写（`anytls`/`tuic`/`hysteria2`/`vmess`）；纯 Reality 节点名（`Reality ✈`）与 XHTTP+Reality 节点名同为 `Reality:20`，无法区分协议优先级 |
| **修复方案** | ① `show-config.sh`：纯 Reality 节点改名 `XTLS-Reality ✈` 加入 XTLS 标记；② policy-priority 更新为 `高速:10;Reality:20;XTLS:8;Xhttp:5;Hysteria2:8;AnyTLS:5;TUIC:3;Vmess:2;super:30;good:10`；最终得分：XTLS-Reality(28) > Xhttp+Reality(25) > Hysteria2(8) > AnyTLS(5) > TUIC(3) > Vmess(2) |
| **预防措施** | policy-priority 关键词必须与节点名实际大小写完全一致；新增协议时先确认节点名格式再写关键词；建议在注释中标注"节点名示例"供核对 |
| **记录时间** | 2026-03-13 |

---

## Sing-box 配置模板

### Bug #030 — sing-box rule_set 不支持 path 字段，导致 FATAL 启动失败

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `templates/sing-box/sb.json` |
| **函数** | `route.rule_set[]` 远程规则集配置 |
| **触发条件** | 在 remote 类型 rule_set 配置中添加 `path` 字段时 |
| **错误现象** | `FATAL[0000] decode config at .../sb.json: route.rule_set[0].path: json: unknown field "path"` |
| **根本原因** | sing-box 的 remote rule_set 不支持 `path` 字段；规则集持久化通过 `experimental.cache_file`（BBolt cache.db）自动处理，无需手动指定磁盘路径 |
| **修复方案** | 删除所有 remote rule_set 条目中的 `path` 字段；规则集缓存已由 `cache_file.path: "${WORKDIR}/sing-box/cache.db"` 统一处理 |
| **预防措施** | sing-box remote rule_set 只支持 `tag`、`type`、`format`、`url`、`download_detour`、`update_interval` 字段；凡涉及 rule_set 持久化需求，查阅 `experimental.cache_file` 而非 rule_set 本身 |
| **记录时间** | 2026-03-13 |

---

### Bug #031 — AnyTLS padding_scheme "default" 非法格式，导致 FATAL 启动失败

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `templates/sing-box/03_anytls_inbounds.json` |
| **函数** | AnyTLS inbound `padding_scheme` 配置 |
| **触发条件** | 将 `padding_scheme` 设为字符串 `"default"` 或 `["default"]` 时 |
| **错误现象** | `FATAL[0000] create service: initialize inbound[2]: incorrect padding scheme format` |
| **根本原因** | `padding_scheme` 要求特定格式的规则对象数组，不接受字符串 "default"；空数组 `[]` 为合法值（表示禁用填充） |
| **修复方案** | 回退为 `"padding_scheme": []`（空数组，禁用填充） |
| **预防措施** | AnyTLS `padding_scheme` 不支持字符串枚举值；修改此字段前查阅 sing-box 官方文档确认格式；空数组是最安全的兜底值 |
| **记录时间** | 2026-03-13 |

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

### Bug #020 — createConfig() 使用 shuf 在非 GNU 环境报错

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `createConfig` |
| **触发条件** | 在 macOS 或 Alpine busybox（无 GNU coreutils）上运行 |
| **错误现象** | `shuf: command not found`，RANDOM_NUM 未赋值，配置渲染可能失败 |
| **根本原因** | `shuf` 是 GNU coreutils 专属命令，macOS / busybox 不提供 |
| **修复方案** | `RANDOM_NUM=$(( RANDOM % 10 ))`，使用 bash 内置 `RANDOM` 变量（0-32767），取模 10 得 0-9 |
| **预防措施** | 编写 bash 脚本不依赖 `shuf`；随机整数范围用 `$(( RANDOM % N + base ))` |
| **记录时间** | 2026-03-05 |

---

### Bug #021 — analyze_ai_routing_env() 使用 eval 调用函数名

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `analyze_ai_routing_env` |
| **触发条件** | 任何调用路径 |
| **错误现象** | 当 `cmd` 变量值含 shell 元字符时，`eval "$cmd"` 会执行意外命令 |
| **根本原因** | 对单纯函数名调用使用了 `eval`，存在二次解析风险；且与同文件 `ensure_var` 中 `val=$($cmd)` 的写法不一致 |
| **修复方案** | 改为 `val=$($cmd)` 直接调用，无需 `eval` |
| **预防措施** | 函数名变量直接用 `$($cmd)` 调用；`eval` 仅用于必须进行字符串到命令转换的场景，且需严格校验输入来源 |
| **记录时间** | 2026-03-05 |

---

### Bug #022 — 工具函数 _apply_tpl 归入业务节导致声明顺序混乱

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `_apply_tpl`（工具）→ 原位于 `createConfig` 业务节 |
| **触发条件** | 代码审查 / 结构检查 |
| **错误现象** | 工具函数夹杂在业务函数节中，违反「工具先声明」规则，阅读和维护困难 |
| **根本原因** | 未按「工具层 → 探测层 → 业务层 → 流程层」的分层原则组织函数 |
| **修复方案** | 新建 §5「模板渲染工具」节，将 `_apply_tpl` 移至工具区；选路辅助（`_is_restricted_region`、`get_fallback_proxy`、`get_isp_preferred_strategy`）新建 §8「选路辅助」节独立存放 |
| **预防措施** | 每次新增函数时，先判断属于哪一层，再放入对应节；工具函数以 `_` 前缀命名辅助识别 |
| **记录时间** | 2026-03-05 |

---

### Bug #023 — ISP_TAG 持久化到 ENV_FILE，删除 STATUS_FILE 无法触发重新测速

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `apply_isp_routing_logic` |
| **触发条件** | 用户删除 `/.env/status` 并重启容器，期望重新测速选路 |
| **错误现象** | `[阶段 2] ISP_TAG 已缓存 (proxy-xxx)，跳过测速` — 测速完全跳过 |
| **根本原因** | `apply_isp_routing_logic` 将 `ISP_TAG` 和 `IS_8K_SMOOTH` 持久化到 `ENV_FILE`（`/.env/sb-xray`），而非 `STATUS_FILE`（`/.env/status`）；`run_speed_tests_if_needed` 在 step 3 source ENV_FILE 后即检测到 ISP_TAG 非空而提前返回 |
| **修复方案** | 将持久化目标从 `ENV_FILE` 改为 `STATUS_FILE`：`_sed_i '/^export IS_8K_SMOOTH=/d; /^export ISP_TAG=/d' "${STATUS_FILE}"` |
| **预防措施** | 区分两类持久化变量：稳定配置（UUID/端口/密钥）→ ENV_FILE；网络运行时状态（ISP_TAG/IS_8K_SMOOTH/流媒体检测结果）→ STATUS_FILE |
| **记录时间** | 2026-03-06 |

---

### Bug #024 — show_progress / end_progress 的 `\r` 在非 TTY Docker 日志中遮蔽后续 log 行

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `speed_test`（调用 `show_progress` / `end_progress`） |
| **触发条件** | 在非 TTY 环境下查看 Docker logs（`docker logs sb-xray`）时 |
| **错误现象** | 测速循环的每轮采样结果（`[测速] 样本 N/M: XX KB/s → XX Mbps`）在日志中完全不可见，用户无法确认多采样是否正常执行 |
| **根本原因** | `show_progress` 用 `echo -ne "\r..."` 输出无换行符的行首覆写，`end_progress` 用 `\r\033[K` 清行；在非 TTY 的 Docker JSON log driver 中，`\r` 不触发行覆写，而是与下一段内容合并为同一行缓冲区，导致紧随其后的 `log INFO` 样本行被视觉遮蔽或挤占 |
| **修复方案** | 在 `speed_test` 的采样循环中移除 `show_progress` 和 `end_progress` 调用，改为直接在 curl 完成后用 `log INFO "[测速] ${name} \| 第 ${i}/${SPEED_SAMPLES} 轮: ${kbps} KB/s → ${mbps} Mbps"` 输出持久化日志行 |
| **预防措施** | `show_progress` / `end_progress` 仅适合交互式 TTY 终端的短暂进度提示；在需要持久化记录的循环体内（测速、批量处理等）只使用 `log` 函数，不混用进度覆写 |
| **记录时间** | 2026-03-06 |

### Bug #025 — ISP_TAG 重新评估后 *_OUT 服务路由缓存未联动清除

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `run_speed_tests_if_needed` / `analyze_ai_routing_env` |
| **触发条件** | 容器重启后 STATUS_FILE 中 ISP_TAG 被清除（或不存在），触发重新测速；但 `*_OUT`（CHATGPT_OUT、ISP_OUT、NETFLIX_OUT 等）在 STATUS_FILE 中仍保留上次的旧值 |
| **错误现象** | 测速选出新的最快 ISP（如 `proxy-la-isp`），但 CHATGPT_OUT/ISP_OUT/NETFLIX_OUT 等仍指向上次的旧代理（如 `proxy-us-isp`），导致流媒体/AI 路由未使用最快 ISP |
| **根本原因** | `analyze_ai_routing_env()` 通过 `[[ -n "${!key:-}" ]]` 检查缓存——旧 `*_OUT` 值在启动时从 STATUS_FILE source 进 shell，非空则跳过重新评估，即使 ISP_TAG 已更新为新代理 |
| **修复方案** | 在 `run_speed_tests_if_needed()` 中 ISP_TAG 缓存未命中时，立即通过 `_sed_i` 从 STATUS_FILE 删除所有 `*_OUT` 行并 `unset` shell 变量，确保后续 `analyze_ai_routing_env()` 基于新 ISP_TAG 重新评估 |
| **附带修复** | `env \| grep "_ISP_IP="` 管道在无匹配时 grep 返回 1，`set -eou pipefail` 导致脚本退出；已在三处添加 `\|\| true` |
| **预防措施** | 涉及缓存依赖链的变量（ISP_TAG → *_OUT），上游变更时必须联动清除下游缓存 |
| **记录时间** | 2026-03-06 |

### Bug #026 — speed_test 有效样本阈值为 0，极小速度被误计为有效采样

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `speed_test` |
| **触发条件** | ISP SOCKS5 节点无法正常下载，curl 返回极低速度（< 1 KB/s）时 |
| **错误现象** | 日志显示 `3/3 有效样本，均值 0.00 Mbps`，实际应为"全部采样失败"；误导运维判断 |
| **根本原因** | 有效样本判定条件为 `$raw > 0`，curl 连接失败时仍返回极小的非零浮点数，被误计为有效样本 |
| **修复方案** | 阈值从 `> 0` 改为 `> 1024`（bytes/sec，即 1 KB/s）；低于此值视为连接失败，不计入有效样本 |
| **预防措施** | 网络测速类函数的有效样本阈值不得使用 `> 0`；以 1 KB/s 作为"连接成功"的最低判定基准 |
| **记录时间** | 2026-03-07 |

---

### Bug #027 — 受限地区强制 ISP_TAG=first_tag，IS_8K_SMOOTH 参考速度错用 proxy_max_speed

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `apply_isp_routing_logic` |
| **触发条件** | 服务器 GeoIP 处于受限地区（香港/中国大陆/俄罗斯/澳门），且存在多个 ISP 节点，其中测速最快的不是遍历顺序第一个 |
| **错误现象** | `ISP_TAG=proxy-us-isp`（第一个节点，62 Mbps），但 `IS_8K_SMOOTH=true`（参考速度 121 Mbps，属于 LA_ISP）；show-config.sh 错误生成 `✈ good` 标签 |
| **根本原因** | 受限地区分支 `ISP_TAG="${1}"` 使用 `first_tag`（首个遍历节点），而 `ref_speed=proxy_max_speed` 存储的是 `FASTEST_PROXY_TAG` 的速度；两者节点不一致时 IS_8K_SMOOTH 基准错误 |
| **修复方案** | 重构为条件化决策链：`elif _is_restricted_region \|\| IP_TYPE != "isp"` 表示需要代理，非空 `FASTEST_PROXY_TAG` 则使用，空则回退直连（ERROR）；住宅 IP + 非受限地区走 `else` 直连兜底；`_is_restricted_region` 降级为日志修饰，不再控制分支走向；移除 `first_tag` 变量及传参 |
| **预防措施** | 受限地区选路和正常选路应使用同一套"最快节点"逻辑；`ref_speed` 来源必须与实际 `ISP_TAG` 对应的节点绑定，不能共享全局最大值变量；IP 类型（住宅/机房）应作为选路条件之一，与地区受限同级评估 |
| **记录时间** | 2026-03-11 |

---

### Bug #029 — speed_test bc 科学计数法导致 set -e 脚本崩溃

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `speed_test`、`show_report`、`apply_isp_routing_logic`（~line 505）、IS_8K_SMOOTH 判定（~line 577） |
| **触发条件** | curl 返回科学计数法格式速度（如 `1.5e+06`）；或 speed 值为 `0.00` 时进入 `(( $(bc) ))` 判断 |
| **错误现象** | `bc` 无法处理科学计数法，返回错误；`echo 0` fallback 使 `(( 0 ))` 以退出码 1 结束；`set -e` 触发脚本立即退出，后续代码全部不执行 |
| **根本原因** | `(( $(echo "$x > $thresh" \| bc 2>/dev/null \|\| echo 0) ))` 模式在 `set -eou pipefail` 下不安全：bc 失败时 `|| echo 0` 仅保护 bc 子命令，但 `(( 0 ))` 本身退出码为 1，仍触发 `set -e` |
| **修复方案** | 全文替换为 `awk -v s="$x" -v t="$thresh" 'BEGIN { exit (s + 0 > t + 0 ? 0 : 1) }'`；awk `+0` 运算自动处理科学计数法；exit 0/1 语义明确，不受 `set -e` 影响 |
| **预防措施** | `set -eou pipefail` 脚本中禁止使用 `(( $(cmd) ))` 模式作数值比较；数值比较统一用 awk；bc 适用于高精度计算但不适合布尔判断 |
| **记录时间** | 2026-03-11 |

---

### Bug #033 — get_geo_info 管道 grep | head -n 1 在 pipefail 下触发 SIGPIPE 导致容器退出

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `get_geo_info`、`http_probe` |
| **触发条件** | `set -eou pipefail` 下，`grep` 输出多行结果经 `head -n 1` 截取时 |
| **错误现象** | 容器启动时日志显示 `[DEBUG] [GEOIP_INFO] 计算中: get_geo_info` 后静默退出，无错误日志 |
| **根本原因** | `grep -B 2` 输出 3 行，`head -n 1` 读完第一行后关闭管道，`grep` 写剩余行时收到 SIGPIPE（退出码 141）；`pipefail` 将管道退出码设为 141，`set -e` 触发脚本退出。宿主机测试正常是因为未启用 `pipefail` |
| **修复方案** | `head -n 1` → `sed -n '1p'`（sed 读完全部输入再输出第一行，不触发 SIGPIPE）；同步修复 `http_probe` 中相同模式 |
| **预防措施** | `set -o pipefail` 下禁止使用 `head -n` 截取多行管道输出；改用 `sed -n 'Np'`；仅 `tr | head -c` 等单行场景可用 `|| true` 兜底。已写入 SKILL.md 第 5 条规则 |
| **记录时间** | 2026-03-17 |

---

### Bug #034 — ensure_var 命令失败时 set -e 静默退出，无错误日志

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/entrypoint.sh` |
| **函数** | `ensure_var` |
| **触发条件** | `ensure_var` 分支 3 中 `val=$($cmd)` 执行失败（任何网络探测函数返回非零） |
| **错误现象** | 容器退出但日志中无任何 ERROR 信息，仅有最后一条 `[DEBUG] [变量名] 计算中: xxx`，排查困难 |
| **根本原因** | `local val; val=$($cmd)` 失败时，`set -e` 立即终止脚本，跳过后续所有代码（包括日志输出） |
| **修复方案** | 改为 `if ! val=$($cmd); then log ERROR "[${key}] 计算失败: ${cmd}"; return 1; fi`，确保退出前打印错误日志 |
| **预防措施** | `set -e` 模式下任何可能失败的关键操作必须用 `if !` 或 trap 捕获，先打印 `log ERROR` 再退出。已写入 SKILL.md 错误退出规范 |
| **记录时间** | 2026-03-17 |

---

### Bug #028 — hysteria2 URI 缺少 sni= 参数，xray-core 原生 hy2 TLS 握手失败

| 字段 | 内容 |
|:---|:---|
| **涉及文件** | `scripts/show-config.sh`、`templates/sing-box/01_hysteria2_inbounds.json`、`templates/proxies/all`、`templates/proxies/clash` |
| **函数** | `generate_links`（URI 生成）；sing-box hysteria2 inbound TLS 配置 |
| **触发条件** | v2rayN 7.18+（xray-core v26.1.23+）使用原生 hy2 实现时，导入 hysteria2 URI |
| **错误现象** | hysteria2 节点连接失败；v2rayN 旧版（外置 hy2 二进制）正常，升级后全部无法使用 |
| **根本原因** | URI 格式 `/?alpn=h3` 无 `sni=` 参数；外置 hy2 二进制从连接地址隐式推断 SNI，但 xray-core 原生实现需要 URI 中显式提供 `sni=` 才能正确填充 TLS `serverName`；sing-box 入站 `server_name: ""` 为空，增加不确定性。另：`show-config.sh` 中两行 `sed '/# 需把 tls 里的 inSecure 设置为 true/d'` 为无效死代码（该注释早已不存在于订阅内容中） |
| **修复方案** | ① URI 改为 `/?sni=${DOMAIN}&alpn=h3`；② sing-box 入站 `server_name` 改为 `"${DOMAIN}"`；③ Clash/all 模板 hysteria2 代理添加 `sni: ${DOMAIN}`；④ 删除两行 `sed` 死代码 |
| **预防措施** | 所有代理协议 URI 必须显式包含 `sni=` 参数，不依赖客户端隐式推断；`allowInsecure` 已在 xray-core v26.2.x 废弃，CA 签名证书无需跳过验证；外置二进制升级为原生核心实现时需重新审查所有参数的显式性 |
| **记录时间** | 2026-03-11 |

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
