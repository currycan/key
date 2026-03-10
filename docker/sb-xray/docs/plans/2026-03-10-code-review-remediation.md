# Code Review 整改实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复 code review 识别的 3 个 Important 问题和 3 个 Minor 问题，分两个 commit 提交。

**Architecture:** 按严重级别分两个 commit：Commit 1 修复 Important（日志显示、测试覆盖、函数参数化），Commit 2 修复 Minor（测试隔离、变量初始化、断言方式）。所有修改均遵循 TDD——先确认现有测试，修改后验证测试依然通过。

**Tech Stack:** bash, docker/sb-xray 项目，测试脚本为 `scripts/test_entrypoint.sh`

---

## Commit 1：Important 修复

### Task 1: 修复 `SPEED_TOLERANCE` 日志显示

**Files:**
- Modify: `scripts/entrypoint.sh:459,461`

**背景:** 当前日志硬拼 `1.${SPEED_TOLERANCE}`，若值为 `5` 则显示 `× 1.5` 而非 `× 1.05`。阈值计算（awk）本身正确，仅日志显示有误。

**Step 1: 确认当前行为**

打开 `scripts/entrypoint.sh`，定位第 454–462 行，确认日志字符串为：
```
"... (前最优 ${_prev_max} × 1.${SPEED_TOLERANCE}) ..."
```

**Step 2: 修改日志显示**

将第 459 行和 461 行的 `1.${SPEED_TOLERANCE}` 替换为复用已计算的 `${threshold}` 值：

```bash
# 第 459 行（更新最优分支）改为：
log INFO "[测速] 容差判断: ${speed} Mbps > 阈值 ${threshold} Mbps (前最优 ${_prev_max} × $(awk -v t="${SPEED_TOLERANCE}" 'BEGIN{printf "%.4f", 1 + t/100}')) → 更新最优: ${FASTEST_PROXY_TAG}"

# 第 461 行（保持最优分支）改为：
log INFO "[测速] 容差判断: ${speed} Mbps ≤ 阈值 ${threshold} Mbps (前最优 ${_prev_max} × $(awk -v t="${SPEED_TOLERANCE}" 'BEGIN{printf "%.4f", 1 + t/100}')) → 保持最优: ${FASTEST_PROXY_TAG:-未定}"
```

> 注意：`awk` 子命令在 log 调用中每次都会执行，如果性能敏感可在函数顶部预计算 `local _multiplier; _multiplier=$(awk -v t="${SPEED_TOLERANCE}" 'BEGIN{printf "%.4f", 1 + t/100}')` 然后引用 `${_multiplier}`。**推荐后者。**

最终修改方式：在第 453 行 `local _prev_max=...` 下方插入：
```bash
local _multiplier
_multiplier=$(awk -v t="${SPEED_TOLERANCE}" 'BEGIN{printf "%.4f", 1 + t/100}')
```

然后第 459 行改为：
```bash
log INFO "[测速] 容差判断: ${speed} Mbps > 阈值 ${threshold} Mbps (前最优 ${_prev_max} × ${_multiplier}) → 更新最优: ${FASTEST_PROXY_TAG}"
```

第 461 行改为：
```bash
log INFO "[测速] 容差判断: ${speed} Mbps ≤ 阈值 ${threshold} Mbps (前最优 ${_prev_max} × ${_multiplier}) → 保持最优: ${FASTEST_PROXY_TAG:-未定}"
```

**Step 3: 运行测试确认无回归**

```bash
cd docker/sb-xray
bash scripts/test_entrypoint.sh
```

Expected: 所有测试通过，`FAIL 0`

---

### Task 2: T11 补全 9 个 `*_OUT` 变量断言

**Files:**
- Modify: `scripts/test_entrypoint.sh:372-401`

**背景:** T11 当前只为 `CHATGPT_OUT`、`ISP_OUT`、`NETFLIX_OUT` 写了断言，漏掉 6 个变量。`run_speed_tests_if_needed` 的 `unset` 行覆盖了全部 9 个。

**Step 1: 查看 T11 测试构造段**

定位 `test_entrypoint.sh` 第 372–401 行，确认当前 `STATUS_FILE` 初始内容只写了 3 行（CHATGPT_OUT、ISP_OUT、NETFLIX_OUT）。

**Step 2: 扩充 T11 初始 STATUS_FILE**

将第 377–381 行的 heredoc 改为写入全部 9 个变量：

```bash
cat > "$STATUS_FILE" <<'EOF'
export CHATGPT_OUT='proxy-stale'
export ISP_OUT='proxy-stale'
export NETFLIX_OUT='proxy-stale'
export DISNEY_OUT='proxy-stale'
export YOUTUBE_OUT='proxy-stale'
export GEMINI_OUT='proxy-stale'
export CLAUDE_OUT='proxy-stale'
export SOCIAL_MEDIA_OUT='proxy-stale'
export TIKTOK_OUT='proxy-stale'
EOF
```

**Step 3: 扩充内存变量导出**

在第 374 行 `export CHATGPT_OUT="proxy-stale" ISP_OUT="proxy-stale" NETFLIX_OUT="proxy-stale"` 改为：

```bash
export CHATGPT_OUT="proxy-stale" ISP_OUT="proxy-stale" NETFLIX_OUT="proxy-stale" \
       DISNEY_OUT="proxy-stale" YOUTUBE_OUT="proxy-stale" GEMINI_OUT="proxy-stale" \
       CLAUDE_OUT="proxy-stale" SOCIAL_MEDIA_OUT="proxy-stale" TIKTOK_OUT="proxy-stale"
```

**Step 4: 扩充内存断言（第 395–397 行之后追加）**

在 `assert_eq "T11-3: 旧 NETFLIX_OUT 缓存已清除" ...` 之后追加：

```bash
assert_eq "T11-3b: 旧 DISNEY_OUT 缓存已清除"       "" "${DISNEY_OUT:-}"
assert_eq "T11-3c: 旧 YOUTUBE_OUT 缓存已清除"      "" "${YOUTUBE_OUT:-}"
assert_eq "T11-3d: 旧 GEMINI_OUT 缓存已清除"       "" "${GEMINI_OUT:-}"
assert_eq "T11-3e: 旧 CLAUDE_OUT 缓存已清除"       "" "${CLAUDE_OUT:-}"
assert_eq "T11-3f: 旧 SOCIAL_MEDIA_OUT 缓存已清除" "" "${SOCIAL_MEDIA_OUT:-}"
assert_eq "T11-3g: 旧 TIKTOK_OUT 缓存已清除"       "" "${TIKTOK_OUT:-}"
```

**Step 5: 扩充 STATUS_FILE 断言（第 400–401 行之后追加）**

```bash
assert_eq "T11-5b: STATUS_FILE 无残留 DISNEY_OUT"       "" "$(grep '^export DISNEY_OUT=' "$STATUS_FILE" || true)"
assert_eq "T11-5c: STATUS_FILE 无残留 YOUTUBE_OUT"      "" "$(grep '^export YOUTUBE_OUT=' "$STATUS_FILE" || true)"
assert_eq "T11-5d: STATUS_FILE 无残留 GEMINI_OUT"       "" "$(grep '^export GEMINI_OUT=' "$STATUS_FILE" || true)"
assert_eq "T11-5e: STATUS_FILE 无残留 CLAUDE_OUT"       "" "$(grep '^export CLAUDE_OUT=' "$STATUS_FILE" || true)"
assert_eq "T11-5f: STATUS_FILE 无残留 SOCIAL_MEDIA_OUT" "" "$(grep '^export SOCIAL_MEDIA_OUT=' "$STATUS_FILE" || true)"
assert_eq "T11-5g: STATUS_FILE 无残留 TIKTOK_OUT"       "" "$(grep '^export TIKTOK_OUT=' "$STATUS_FILE" || true)"
```

**Step 6: 运行测试**

```bash
bash scripts/test_entrypoint.sh
```

Expected: 所有新断言通过，`FAIL 0`

---

### Task 3: `first_tag` 改为显式参数

**Files:**
- Modify: `scripts/entrypoint.sh:471,497,517,956`
- Modify: `scripts/test_entrypoint.sh:162-163,169-170`

**背景:** `apply_isp_routing_logic` 通过 bash 动态作用域隐式读取 `first_tag`。若单独调用则静默降级。改为显式参数 `$1`。

**Step 1: 修改函数签名和内部引用**

在 `scripts/entrypoint.sh` 第 471 行（`apply_isp_routing_logic() {`），函数体内将所有 `${first_tag:-}` 替换为 `${1:-}`（位置参数）：

- 第 466–467 行的注释改为：
  ```bash
  # 参数:
  #   $1 - first_tag: 第一个检测到的 ISP 节点 tag，用于受限地区兜底（可为空）
  ```

- 第 497 行：`if [[ -n "${first_tag:-}" ]];` → `if [[ -n "${1:-}" ]];`
- 第 498 行：`log WARN "... ${first_tag}"` → `log WARN "... ${1}"`
- 第 499 行：`export ISP_TAG="${first_tag}"` → `export ISP_TAG="${1}"`
- 第 517 行：`if [[ -z "${ISP_TAG:-}" && -n "${first_tag:-}" ]];` → `if [[ -z "${ISP_TAG:-}" && -n "${1:-}" ]];`
- 第 518 行：`export ISP_TAG="$first_tag"` → `export ISP_TAG="${1}"`
- 第 519 行：`log WARN "... ${ISP_TAG}"` — 不变（已用 ISP_TAG）

**Step 2: 修改调用方传参**

`scripts/entrypoint.sh` 第 956 行：
```bash
# 原：
apply_isp_routing_logic
# 改为：
apply_isp_routing_logic "$first_tag"
```

**Step 3: 更新 T4-1 和 T4-2 测试**

`scripts/test_entrypoint.sh`：

T4-1（第 161–164 行）— `first_tag` 变量不再影响函数，改为通过参数传递：
```bash
_reset_routing
export DEFAULT_ISP="MYISP_ISP" DIRECT_SPEED=30 proxy_max_speed=0
apply_isp_routing_logic "proxy-fallback"   # 原: first_tag="proxy-fallback"; apply_isp_routing_logic
assert_eq "T4-1: DEFAULT_ISP 强制覆盖" "proxy-myisp" "${ISP_TAG:-}"
```

T4-2（第 167–171 行）：
```bash
_reset_routing
export GEOIP_INFO="中国|1.2.3.4" IP_TYPE="hosting" DIRECT_SPEED=50 proxy_max_speed=0
apply_isp_routing_logic "proxy-first"      # 原: first_tag="proxy-first"; apply_isp_routing_logic
assert_eq "T4-2: 受限地区使用 first_tag" "proxy-first" "${ISP_TAG:-}"
```

检查其他 T4 用例（T4-3 等），确认它们调用时是否也用了全局 `first_tag`，若无则无需修改。

**Step 4: 运行测试**

```bash
bash scripts/test_entrypoint.sh
```

Expected: T4 全部通过，`FAIL 0`

**Step 5: 提交 Commit 1**

```bash
git add scripts/entrypoint.sh scripts/test_entrypoint.sh
git commit -m "fix: 修复 Important 级代码审查问题（日志显示、测试覆盖、参数传递）"
```

---

## Commit 2：Minor 修复

### Task 4: `_reset_routing` 清空 `STATUS_FILE`

**Files:**
- Modify: `scripts/test_entrypoint.sh:153-157`

**Step 1: 找到 `_reset_routing` 函数**

定位第 153–157 行：
```bash
_reset_routing() {
    unset ISP_TAG IS_8K_SMOOTH FASTEST_PROXY_TAG proxy_max_speed DIRECT_SPEED \
          DEFAULT_ISP GEOIP_INFO IP_TYPE first_tag 2>/dev/null || true
    > "$ENV_FILE"
}
```

**Step 2: 追加 STATUS_FILE 清空**

```bash
_reset_routing() {
    unset ISP_TAG IS_8K_SMOOTH FASTEST_PROXY_TAG proxy_max_speed DIRECT_SPEED \
          DEFAULT_ISP GEOIP_INFO IP_TYPE first_tag 2>/dev/null || true
    > "$ENV_FILE"
    > "$STATUS_FILE"
}
```

**Step 3: 运行测试**

```bash
bash scripts/test_entrypoint.sh
```

Expected: `FAIL 0`（此改动不应破坏任何已有测试）

---

### Task 5: `XRAY_VERSION_FINAL` 显式初始化

**Files:**
- Modify: `build.sh`（第 113 行附近的变量声明区）

**Step 1: 找到变量声明区**

定位 `build.sh` 第 112–117 行（`USE_DEFAULT_VERSIONS` 声明处）。

**Step 2: 在声明区追加初始化**

在 `USE_DEFAULT_VERSIONS=false` 下方插入：
```bash
XRAY_VERSION_FINAL=""
```

**Step 3: 验证无语法错误**

```bash
bash -n docker/sb-xray/build.sh
```

Expected: 无输出（无语法错误）

---

### Task 6: T9-4 改为断言返回值

**Files:**
- Modify: `scripts/test_entrypoint.sh:332-335`

**背景:** 当前用 `grep -q "采样失败"` 硬匹配中文字符串，日志措辞变化则失效。改为断言返回值为 `"0.00"`，同时保留 stderr 非空检查。

**Step 1: 找到 T9-4 段**

定位第 328–335 行：
```bash
curl() { echo "100"; }
_t9d_log=$(speed_test "https://example.com/__down" "T9-TinySpeed" 2>&1 >/dev/null)
echo "$_t9d_log" | grep -q "采样失败" && _t9d_hit="yes" || _t9d_hit="no"
assert_eq "T9-4: 极小速度（100 B/s）→ 日志应显示采样失败" "yes" "$_t9d_hit"
```

**Step 2: 改为返回值断言**

```bash
curl() { echo "100"; }
result9d=$(speed_test "https://example.com/__down" "T9-TinySpeed" 2>/dev/null)
assert_eq "T9-4: 极小速度（100 B/s）→ 应返回 0.00" "0.00" "$result9d"
# 同时验证诊断日志存在（不依赖具体措辞）
_t9d_log=$(speed_test "https://example.com/__down" "T9-TinySpeed-log" 2>&1 >/dev/null)
[[ -n "$_t9d_log" ]] && _t9d_has_log="yes" || _t9d_has_log="no"
assert_eq "T9-4b: 极小速度 → 有诊断日志输出" "yes" "$_t9d_has_log"
```

**Step 3: 运行测试**

```bash
bash scripts/test_entrypoint.sh
```

Expected: `FAIL 0`

**Step 4: 提交 Commit 2**

```bash
git add scripts/entrypoint.sh scripts/test_entrypoint.sh build.sh
git commit -m "fix: 修复 Minor 级代码审查问题（测试隔离、变量初始化、断言方式）"
```

---

## 验收清单

- [ ] `SPEED_TOLERANCE=5` 时日志显示 `× 1.0500`（非 `× 1.5`）
- [ ] T11 断言覆盖全部 9 个 `*_OUT` 变量（内存 + STATUS_FILE）
- [ ] `apply_isp_routing_logic` 接受显式 `$1` 参数，无隐式 `first_tag` 依赖
- [ ] `_reset_routing` 后 `STATUS_FILE` 为空
- [ ] `build.sh` 顶部 `XRAY_VERSION_FINAL=""` 初始化存在
- [ ] T9-4 通过返回值断言（`0.00`），不依赖日志措辞
- [ ] `bash scripts/test_entrypoint.sh` 全部通过，`FAIL 0`
- [ ] 共 2 个 commit，符合设计文档约定
