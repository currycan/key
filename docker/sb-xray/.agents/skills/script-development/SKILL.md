---
name: Shell 脚本开发规范
description: entrypoint.sh 与 rename.js 脚本架构、编码规范、已知 Bug 速查和调试指南
---

# Shell 脚本开发规范

> ⚠️ **重要提醒**：修改 Shell 脚本前，请先阅读 `.agents/skills/_shared/BUGS.md` 中 `entrypoint.sh` 分区的所有条目，避免重复踩坑。

## 脚本文件概览

| 脚本 | 职责 |
|:---|:---|
| `scripts/entrypoint.sh` | 核心入口脚本，16段 §N 架构，系统启动流水线 |
| `scripts/check_ip_type.sh` | IP 质量体检 (ASN/流媒体/风控检测) |
| `scripts/show-config.sh` | 展示生成的配置与订阅链接 |
| `scripts/geo_update.sh` | GeoIP/Geosite 数据库更新 |
| `scripts/stop-supervisor.sh` | Supervisord 优雅停止 |

---

## entrypoint.sh 架构概览

16段 §N 分层架构，分层原则与段落含义见 `.agents/skills/project-overview/SKILL.md`。

修改脚本时需了解的关键函数：

| 函数 | 所在段 | 关键点 |
|:---|:---|:---|
| `ensure_var()` | §6 | 环境变量缓存系统核心，见下节详解 |
| `_apply_tpl()` | §5 | 模板渲染引擎（envsubst + jq 校验） |
| `_is_restricted_region()` | §8 | 地区限制判断，影响所有流媒体/AI检测分支 |
| `apply_isp_routing_logic()` | §10 | ISP 路由策略决策，核心选路逻辑 |
| `issueCertificate()` | §12 | ACME 证书申请/续期，acme.sh 集成 |
| `createConfig()` | §13 | 全量模板渲染总入口 |
| `main_init()` | §16 | 12步启动流水线总入口 |

---

## 环境变量缓存系统

### ensure_var() 工作原理

```bash
ensure_var "KEY" "command to generate value"
# 或
ensure_var "KEY" --no-persist "command"
```

**逻辑流程（三分支，见 Bug #015）：**
1. **已在 shell**：变量已 export 到当前进程 → 直接返回，无 I/O
2. **在文件不在 shell**：从 `/.env/sb-xray` 读取并 `export` 到当前 shell → 返回
3. **两者均无**：执行指定命令获取值，`export` 到当前环境，写入持久化文件（`--no-persist` 跳过写文件）

> ⚠️ 不能只检查文件存在性就返回，必须同时 export 到当前 shell（Bug #015 根本原因）。

### 两级持久化文件

| 文件 | 用途 | 清除条件 |
|:---|:---|:---|
| `/.env/sb-xray` | 核心参数 (UUID/端口/密钥等)，长期不变 | 需手动删除 |
| `/.env/status` | 运行时状态 (ISP_TAG/流媒体检测结果)，可能随网络变化 | 删除可触发重新检测 |
| `/.env/secret` | 远端解密的敏感配置 | 拉取后长期缓存 |

---

## 编码规范

### 基本要求

```bash
#!/usr/bin/env bash
set -eou pipefail  # 严格模式：任何错误立即退出
```

### 日志输出规范

```bash
log INFO  "正常流程信息"     # 绿色
log WARN  "需要注意的警告"    # 黄色
log ERROR "严重错误，可能导致退出"  # 红色
log DEBUG "调试信息"          # 青色
```

- 所有日志使用中文
- 日志自动附带时间戳 `[YYYY-MM-DD HH:MM:SS]`
- 日志输出到 stderr (`>&2`)

### 颜色变量

```bash
# 仅在 TTY 环境下启用颜色
RED='\\033[1;31m'; GREEN='\\033[1;32m'; YELLOW='\\033[1;33m'; CYAN='\\033[1;36m'; NC='\\033[0m'
BOLD='\\033[1m'; RESET_BOLD='\\033[22m'
```

### 函数命名

- 使用 `camelCase` 或 `snake_case`（项目中两种风格混用）
- 流媒体检测函数统一命名：`check_<service>_access()`
- 返回值统一为 `"direct"` 或代理标签名

### 流媒体/AI 检测函数模式

所有 `check_*_access()` 函数遵循统一的三层判断：

```bash
check_xxx_access() {
    # 第一层：地域黑名单 (硬封锁地区直接走代理)
    if [[ "${GEOIP_INFO:-}" =~ (香港|中国|...) ]]; then
        get_fallback_proxy; return
    fi
    # 第二层：住宅 IP 优先直连
    if [[ "${IP_TYPE:-}" == "isp" ]]; then
        echo "direct"; return
    fi
    # 第三层：HTTP 探测实际可达性
    local check_rs=$(http_probe "https://xxx")
    if [[ "$check_rs" =~ ^(2|3) ]]; then
        echo "direct"
    else
        get_fallback_proxy
    fi
}
```

---

## 调试指南

### 查看当前环境变量

```bash
# 进入容器
docker exec -it sb-xray bash

# 查看持久化变量
cat /.env/sb-xray

# 查看运行状态变量
cat /.env/status

# 查看生成的配置
/scripts/show-config.sh
# 或快捷命令
show
```

### 重新触发检测

```bash
# 清除状态缓存，重启后将重新检测流媒体/AI解锁和测速
rm -f /.env/status
docker restart sb-xray

# 完全重置所有缓存 (包括 UUID 等，会导致订阅链接变化!)
rm -f /.env/sb-xray /.env/status
docker restart sb-xray
```

### IP 质量体检

```bash
# 在容器内运行完整 IP 体检
/scripts/check_ip_type.sh

# 仅检测 IPv4
/scripts/check_ip_type.sh -4

# 仅检测 IPv6
/scripts/check_ip_type.sh -6
```

### 常见调试方法

1. **模板渲染问题**: 检查 `docker logs sb-xray` 中 `apply_tpl` 的 DEBUG 日志
2. **环境变量未生效**: 确认变量已通过 `export` 或写入持久化文件
3. **证书问题**: 容器内运行 `acme.sh --list` 查看证书状态
4. **JSON 格式错误**: `apply_tpl` 会自动用 `jq` 校验 JSON 文件

---

## JavaScript 脚本代码生成规范（rename.js 类）

> **强制要求**: 编写或修改 `sources/hack/*.js` 前，必须先阅读 `.agents/skills/_shared/BUGS.md` 中 rename.js 分区的所有条目。

### 正则表达式规范

```javascript
// ✅ 正确：移除"单词"类关键词必须加词边界
const escapedProto = protocol.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
name.replace(new RegExp(`\\b${escapedProto}\\b`, 'ig'), '');

// ❌ 错误：无词边界，'ss' 会误删 'Russia' 中的 ss
name.replace(new RegExp(protocol, 'ig'), '');

// ✅ 正确：FlagRules 正则只保留必要捕获组
{ regex: /(美[国國]|United States)/i, emoji: '🇺🇸' }

// ❌ 错误：双层括号引入多余捕获组
{ regex: /((美[国國]|United States))/i, emoji: '🇺🇸' }

// ✅ 正确：锚点无需 g 标志
keyPart.replace(/(\[\s*\d*\s*\]|\d+)$/, '')

// ❌ 错误：$ 锚点加 g 无意义
keyPart.replace(/(\[\s*\d*\s*\]|\d+)$/g, '')
```

### 数组操作规范

```javascript
// ✅ 正确：纯函数，返回新数组，不修改入参
const promoteRegion = (parts) => {
    const result = [...parts];           // 先复制
    const idx = result.findIndex(...);
    if (idx <= 0) return result;
    result.unshift(result.splice(idx, 1)[0]);
    return result;
};

// ❌ 错误：直接修改入参，产生副作用
const promoteRegion = (parts) => {
    const idx = parts.findIndex(...);
    parts.unshift(parts.splice(idx, 1)[0]);  // 突变原数组！
    return parts;
};
```

### 常量与缓存规范

```javascript
// ✅ 正确：派生数据在初始化 IIFE 中一次性计算，缓存到 Constants
(function initFlagRules() {
    // ... 构建 flagMap, SORTED_COUNTRY_KEYS ...
    Constants.ALL_REGIONS = [
        ...Constants.PRIORITY_REGIONS,
        ...Object.keys(RegionMap).filter(k => !Constants.PRIORITY_REGIONS.includes(k))
    ];
})();

// ✅ 正确：函数内直接引用缓存
const getPriority = (name) => {
    return Constants.ALL_REGIONS.findIndex(k => name.includes(k));
};

// ❌ 错误：每次调用都重新构建，性能浪费
const getPriority = (name) => {
    const allRegions = [...Constants.PRIORITY_REGIONS, ...Object.keys(RegionMap)]; // 每次重建！
    return allRegions.findIndex(k => name.includes(k));
};
```

### 功能标志规范

```javascript
// ✅ 正确：用布尔字段作为功能控制标志
const CleaningRules = [
    { desc: "统一分隔符", regex: /[-_|\s丨✈\/]+/g, value: "-", skipInPreformat: true },
];
// 使用时：
if (rule.skipInPreformat) continue;

// ❌ 错误：用描述文字判断，文字改变则逻辑静默失效
if (rule.desc.includes('分隔符')) continue;
```

### 数据去重规范

```javascript
// ✅ 正确：向数据库类数组添加前先检查唯一性
// CountryDB 添加前：
const existingCodes = CountryDB.map(x => x.code);
if (existingCodes.includes(newEntry.code)) {
    throw new Error(`CountryDB 重复 code: ${newEntry.code}`);
}
```

### 预格式化路径规范

```javascript
// ✅ 正确：预格式化快速通道必须保留地名归化
let parts = remainingName.split('✈').flatMap(Utils.cleanPreformatted);
parts = parts
    .map(part => Utils.standardizeRegion(part))    // 英文地名 → 中文
    .map(part => part.replace(/^[-_||\s]+|[-_||\s]+$/g, '').trim())  // 清理残留分隔符
    .filter(part => part !== '');

// ❌ 错误：缺少 standardizeRegion，英文地名未归化
let parts = remainingName.split('✈').flatMap(Utils.cleanPreformatted);
// 直接使用 parts，Hong Kong 不会变成 香港
```

---

## 代码重构规范

### Bash 脚本重构（entrypoint.sh 类）

1. **先呈方案，再动手**: 列出所有拟修复的问题点，获得用户批准后再开始编写代码
2. **红绿测试驱动**:
   - 重构前：先写测试套件（`scripts/test_*.sh`），确认测试能暴露已知 bug（红灯）
   - 重构后：运行测试，全部通过才算完成（绿灯），任何失败必须修复
3. **可测性设计**: 脚本必须支持 `source` 模式执行，用 `BASH_SOURCE` 保护入口，且路径变量（`ENV_FILE` 等）需允许外部覆盖（`${ENV_FILE:-/default/path}`）
4. **跨平台兼容**: 所有 `sed -i` 改用封装函数 `_sed_i()`，管道末端 `tr | head -c` 须加 `|| true` 防 SIGPIPE，避免使用 Linux 专属命令（如 `shuf`，改用 `$(( RANDOM % N + base ))`）
5. **函数声明顺序**（按分层原则，被依赖的先声明）:

   | 层次 | 内容 |
   |:---|:---|
   | 工具层 | 纯函数：日志、HTTP、随机生成、模板渲染、持久化 |
   | 探测层 | 网络环境探测、选路辅助（`_is_restricted_region` 等） |
   | 速度层 | 测速函数 |
   | ISP 层 | ISP 节点构建、测速、选路决策 |
   | 业务层 | 流媒体/AI 可达性检测、证书管理、配置渲染、密钥解密 |
   | 流程层 | 主流程各阶段函数（严格按运行时调用顺序声明） |
   | 入口层 | `main_init` + exec 保护 |

6. **结构清晰**: 大脚本用 `§N 段落名` 注释分段（建议 14-16 段），`main_init` 内步骤注释须标注对应的 `daemon.ini` priority 值
7. **Bug 记录**: 重构时消灭的 bug 必须同步写入 BUGS.md

### JavaScript 脚本重构（rename.js 类）

1. **段落标记统一**: 使用 `// ── §N 段落名 ──` 风格分段，全文保持一致
2. **Utils 方法声明顺序**（按依赖复杂度递增）:
   - 第一层：纯函数（无任何项目数据依赖，如 `getNum`、`extractFlag`、`shortProtocol`）
   - 第二层：依赖 `CleaningRules` 等静态配置的函数（如 `cleanName`、`cleanPreformatted`）
   - 第三层：依赖 `RegionMap` 的函数（如 `standardizeRegion`）
   - 第四层：依赖 IIFE 初始化产出（如 `flagRules`）的函数（如 `splitAndDedup`、`getPriority`、`detectFlag`）
   - IIFE 初始化函数（如 `initFlagRules()`）紧随被初始化数据（如 `RegionMap`）之后声明，注释标注「产出」变量
3. **Pipeline/业务对象内部顺序**:
   - 私有辅助方法一律加 `_` 前缀，整体前置（在所有阶段入口之前）
   - 阶段入口方法严格按运行时执行顺序排列（如 `filter → format → sort → renumber`）
   - 每个阶段入口添加 `// 依赖: _xxx, _yyy` 注释
4. **算子入口 `operator()`**: 在注释中标注完整执行链，便于快速理解数据流向

---

## 代码提交前自检清单

> 完成 JavaScript 脚本修改后，逐项确认：

- [ ] 所有"移除单词"类正则都添加了 `\b` 词边界
- [ ] 数组变换辅助函数返回新数组，未修改入参
- [ ] 新增 `CleaningRules` 条目检查是否需要 `skipInPreformat` 标志
- [ ] 功能控制标志使用布尔字段，不依赖描述文字
- [ ] 向 `CountryDB` / `RegionMap` 等查找表添加条目前检查重复
- [ ] 新增引用 `RegionMap` 的代码优先使用 `Constants.ALL_REGIONS`
- [ ] 预格式化分支包含 `standardizeRegion()` 调用
- [ ] 修复 Bug 后在 `.agents/skills/_shared/BUGS.md` 追加记录

---

## 已知问题速查（rename.js）

快速导航到 `.agents/skills/_shared/BUGS.md` 的对应条目：

| Bug ID | 一句话描述 | 关键词 |
|:---|:---|:---|
| #001 | 预格式化通道英文地名未转中文 | `processPreFormatted`, `standardizeRegion` |
| #002 | 功能标志用字符串描述，修改描述则逻辑失效 | `cleanPreformatted`, `skipInPreformat` |
| #003 | CountryDB 末尾重复条目 | `CountryDB`, `UK`, `KR` |
| #004 | 协议名正则无词边界，误删单词内字母 | `processRawNode`, `\b`, `Russia` |
| #005 | promoteRegion 直接修改入参数组 | `promoteRegion`, 副作用 |
| #006 | FlagRules 正则双层括号 | `FlagRules`, 捕获组 |
| #007 | allRegions 在多处函数内重复构建 | `Constants.ALL_REGIONS`, 缓存 |
