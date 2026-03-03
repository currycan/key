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
