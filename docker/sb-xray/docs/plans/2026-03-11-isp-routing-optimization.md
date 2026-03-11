# ISP 选路逻辑优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 `apply_isp_routing_logic` 重构为基于条件的显式决策链，并清理本次讨论中涉及的所有残留问题。

**Architecture:** 决策链严格按优先级串联：手动锁定 → 受限地区/非住宅IP判断（need_isp） → 有最优代理则用，无则直连兜底。`_is_restricted_region` 不再控制分支走向，只作日志修饰。

**Tech Stack:** Bash 5+, `set -eou pipefail`, `bc`, `awk`, Sub-Store (rename.js)

---

## 背景与现状

### 本次讨论已完成的修复

| 编号 | 文件 | 内容 | 状态 |
|------|------|------|------|
| Bug #027 | `entrypoint.sh` | 受限地区强制 `ISP_TAG=first_tag`，IS_8K_SMOOTH 参考速度错用 `proxy_max_speed` | ✅ 已修复 |
| rename.js | `sources/hack/rename.js` | `cleanPreformatted` 不拆分 `丨` 导致预格式化节点保留竖线 | ✅ 已修复 |
| 死代码 | `entrypoint.sh` | `run_speed_tests_if_needed` 中 `first_tag` 变量及传参残留 | ✅ 已清理 |

### 待完成：条件化选路逻辑

当前 `apply_isp_routing_logic` 的逻辑仍是「有代理就用」，未体现用户描述的完整决策链：

```
优选最快代理 → 判断受限地区 → 判断是否需流媒体/AI解锁 → 需要则用代理 → 兜底直连
```

目标结构（无中间变量）：

```bash
if   manual_isp_tag                                  → 锁定
elif _is_restricted_region || IP_TYPE != "isp"       → 需要代理
     ├─ FASTEST_PROXY_TAG 非空                        → ISP_TAG=最快代理
     └─ 空                                            → ISP_TAG=direct + ERROR
else                                                  → 住宅IP+非受限，兜底直连
```

---

## Task 1：验证当前 `IS_8K_SMOOTH` 修复正确性

**Files:**
- Read: `scripts/entrypoint.sh:467-560`（`apply_isp_routing_logic`）
- Read: `.agents/skills/_shared/BUGS.md`（Bug #027 记录）

**Step 1: 阅读当前函数，确认 `ref_speed` 来源**

定位函数内 `ref_speed` 赋值段，确认：
- `ISP_TAG != "direct"` 时 → `ref_speed = proxy_max_speed`（FASTEST_PROXY_TAG 的速度）
- `ISP_TAG == "direct"` 时 → `ref_speed = DIRECT_SPEED`

**Step 2: 核实 BUGS.md #027 修复方案描述与代码一致**

确认 Bug #027 记录的修复方案描述准确（受限地区使用 `FASTEST_PROXY_TAG` 而非 `first_tag`）。

**Step 3: 若描述不一致，更新 BUGS.md**

```bash
git add .agents/skills/_shared/BUGS.md
git commit -m "docs: 同步 Bug #027 修复方案描述"
```

---

## Task 2：实现条件化选路逻辑（核心重构）

**Files:**
- Modify: `scripts/entrypoint.sh`（`apply_isp_routing_logic` 函数，约 492-518 行）

**Step 1: 阅读现有 if/elif/else 结构**

```bash
grep -n "elif\|ISP_TAG\|FASTEST_PROXY_TAG\|_is_restricted" scripts/entrypoint.sh | head -40
```

**Step 2: 替换决策分支**

将现有结构替换为：

```bash
    if [[ -n "${manual_isp_tag}" ]]; then
        # 锁定模式：DEFAULT_ISP 非空，强制使用指定出口，跳过所有条件判断
        log INFO "[选路] 手动覆盖 DEFAULT_ISP=${DEFAULT_ISP} → ${manual_isp_tag}"
        export ISP_TAG="$manual_isp_tag"

    elif _is_restricted_region || [[ "${IP_TYPE:-unknown}" != "isp" ]]; then
        # 受限地区 或 非住宅 IP → 需要 ISP 代理解锁
        _is_restricted_region \
            && log WARN "[选路] 受限地区 (${GEOIP_INFO%%|*})，需要 ISP 代理"
        [[ "${IP_TYPE:-unknown}" != "isp" ]] \
            && log INFO "[选路] 非住宅 IP (${IP_TYPE:-unknown})，需 ISP 代理解锁流媒体/AI"
        if [[ -n "${FASTEST_PROXY_TAG:-}" ]]; then
            log INFO "[选路] 使用最优 ISP 代理: ${FASTEST_PROXY_TAG} (${proxy_max_speed:-0} Mbps)"
            export ISP_TAG="${FASTEST_PROXY_TAG}"
        else
            log ERROR "[选路] 需要 ISP 代理但无可用节点！回退直连"
            export ISP_TAG="direct"
        fi

    else
        # 住宅 ISP IP + 非受限地区：兜底直连
        log INFO "[选路] 住宅 ISP IP + 非受限地区，无需代理，直连"
        export ISP_TAG="direct"
    fi
```

**Step 3: 同步更新函数头注释的"选路原则"**

```bash
# 选路原则：
#   1. 优选最快 ISP 代理（FASTEST_PROXY_TAG，由测速阶段确定）
#   2. 受限地区 OR 非住宅 IP → 需要代理（解锁 geo / 流媒体 / AI）
#   3. 需要代理 + 有可用节点 → ISP_TAG = FASTEST_PROXY_TAG
#   4. 需要代理 + 无可用节点 → 回退直连（ERROR）
#   5. 条件均不满足（住宅 IP + 非受限）→ 直连兜底
```

**Step 4: 同步更新 `log INFO "[选路] 原则:..."` 打印行**

```bash
log INFO "[选路] 原则: 受限地区/非住宅IP→需代理解锁; 住宅IP+非受限→直连兜底"
```

**Step 5: 提交**

```bash
git add scripts/entrypoint.sh
git commit -m "refactor: apply_isp_routing_logic 条件化选路，显式评估受限地区与IP类型"
```

---

## Task 3：记录 Bug #027 最终修复方案到 BUGS.md

**Files:**
- Modify: `.agents/skills/_shared/BUGS.md`

**Step 1: 定位 Bug #027 条目**

```bash
grep -n "Bug #027" .agents/skills/_shared/BUGS.md
```

**Step 2: 确认修复方案字段准确描述最终代码**

修复方案应描述：
- 受限地区分支改为 `elif _is_restricted_region || [[ IP_TYPE != "isp" ]]`
- `_is_restricted_region` 降级为日志修饰，不控制分支走向
- 移除 `first_tag` 变量及传参

**Step 3: 若需要，更新修复方案描述**

**Step 4: 提交**

```bash
git add .agents/skills/_shared/BUGS.md
git commit -m "docs: 更新 Bug #027 最终修复方案描述"
```

---

## Task 4：验证 rename.js `丨` 修复

**Files:**
- Read: `sources/hack/rename.js:519-527`（`cleanPreformatted`）
- Read: `sources/hack/rename.js:624-646`（`_processPreFormatted`）

**Step 1: 确认两处改动均已落地**

```bash
grep -n "丨" sources/hack/rename.js
```

期望输出：
```
526:        return cleaned.split(/[\/丨]/).map(s => s.trim()).filter(s => s !== '');
632:            .map(part => part.replace(/^[-_|丨\s]+|[-_|丨\s]+$/g, '').trim())
```

**Step 2: 构造测试用例，手动验证（Node.js REPL）**

```js
// 模拟输入：预格式化节点含 丨
const name = "🇭🇰 ss ✈ 香港丨流媒体 ✈ 高速 01"
// 期望输出：丨 被拆分，不出现在节点名中
// 🇭🇰 ss ✈ 香港 ✈ 流媒体 ✈ 高速 01
```

**Step 3: 提交（若有遗漏改动）**

```bash
git add sources/hack/rename.js
git commit -m "fix: cleanPreformatted 拆分 丨 分隔符，预格式化节点不保留竖线"
```

---

## Task 5：整体回归验证

**Step 1: 检查 entrypoint.sh 语法**

```bash
bash -n scripts/entrypoint.sh && echo "syntax OK"
```

期望：`syntax OK`，无报错。

**Step 2: 检查 rename.js 语法**

```bash
node --check sources/hack/rename.js && echo "syntax OK"
```

期望：`syntax OK`，无报错。

**Step 3: 检查死代码残留**

```bash
grep -n "first_tag" scripts/entrypoint.sh
```

期望：无输出（已清理）。

**Step 4: 检查 BUGS.md 编号连续**

```bash
grep "^### Bug #" .agents/skills/_shared/BUGS.md | awk -F'#' '{print $2+0}' | sort -n
```

期望：编号连续，无跳号。

**Step 5: 最终提交**

```bash
git add -A
git commit -m "chore: ISP选路优化整体回归验证通过"
```

---

## 验收标准

- [ ] `bash -n scripts/entrypoint.sh` 无报错
- [ ] `node --check sources/hack/rename.js` 无报错
- [ ] `grep "first_tag" scripts/entrypoint.sh` 无输出
- [ ] 受限地区（香港/中国大陆）场景：日志输出 `WARN 受限地区`，`ISP_TAG=FASTEST_PROXY_TAG`
- [ ] 非住宅IP（hosting）场景：日志输出 `非住宅 IP`，`IS_TAG=FASTEST_PROXY_TAG`
- [ ] 住宅IP + 非受限地区场景：日志输出 `无需代理，直连`，`ISP_TAG=direct`
- [ ] IS_8K_SMOOTH 参考速度与 ISP_TAG 对应节点一致
- [ ] 预格式化节点含 `丨` 的输出名称中不含 `丨`
- [ ] BUGS.md #027 描述与最终代码一致
