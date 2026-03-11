# 测速截断均值优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 `speed_test` 函数的均值算法改为截断均值（去最大最小后取中间样本均值），采样次数从 3 改为 5，并在日志中输出标准差和稳定性标注。

**Architecture:** 只修改 `scripts/entrypoint.sh` 的两处：常量 `SPEED_SAMPLES` 和 `speed_test` 函数体。函数签名与返回值格式不变，调用方零改动。核心逻辑用单个 awk 脚本完成排序、截断均值、标准差的一次性计算。

**Tech Stack:** Bash 5+, `awk`（POSIX），`bc`，`set -eou pipefail`

---

## Task 1：更新 `SPEED_SAMPLES` 常量

**Files:**
- Modify: `scripts/entrypoint.sh:50`

**Step 1: 定位常量行，确认当前值**

```bash
grep -n "SPEED_SAMPLES" scripts/entrypoint.sh
```

期望输出包含：`50:SPEED_SAMPLES=3`

**Step 2: 修改常量值**

将第 50 行：
```bash
# 每节点采样次数（取均值，平滑偶发抖动）
SPEED_SAMPLES=3
```

改为：
```bash
# 每节点采样次数（截断均值：去最大最小后取中间样本，平滑突发峰值）
SPEED_SAMPLES=5
```

**Step 3: 语法检查**

```bash
bash -n scripts/entrypoint.sh && echo "syntax OK"
```

期望：`syntax OK`

**Step 4: 提交**

```bash
git add scripts/entrypoint.sh
git commit -m "perf: SPEED_SAMPLES 3→5，为截断均值提供足够样本量"
```

---

## Task 2：重写 `speed_test` 函数体（核心）

**Files:**
- Modify: `scripts/entrypoint.sh:341-374`（`speed_test` 函数）

**Step 1: 阅读现有函数，理解结构**

```bash
sed -n '341,374p' scripts/entrypoint.sh
```

确认：当前用 `total` 累加所有样本后 `total/count` 求均值。

**Step 2: 替换函数体**

将现有 `speed_test()` 函数体（`local total=0 count=0 i` 开始到 `echo "$result"` 结束）替换为以下实现：

```bash
speed_test() {
    local url=$1 name=$2 proxy=${3:-} proxy_auth=${4:-}
    local args=(-s --connect-timeout 5 -L -o /dev/null -m 5 -w '%{speed_download}')
    [[ -n "$proxy" ]]      && args+=(-x "$proxy")
    [[ -n "$proxy_auth" ]] && args+=(--proxy-user "$proxy_auth")
    log INFO "[测速] 开始: ${name}${proxy:+ | 代理: ${proxy}} | 测速源: ${url} | 采样: ${SPEED_SAMPLES}次"

    local samples=() i
    for (( i=1; i<=SPEED_SAMPLES; i++ )); do
        local raw; raw=$(curl "${args[@]}" "$url" 2>/dev/null || echo "0")
        local kbps mbps
        kbps=$(awk -v s="$raw" 'BEGIN { printf "%.0f", s / 1024 }')
        mbps=$(awk -v s="$raw" 'BEGIN { printf "%.2f", s * 8 / 1024 / 1024 }')
        log INFO "[测速] ${name} | 第 ${i}/${SPEED_SAMPLES} 轮: ${kbps} KB/s → ${mbps} Mbps"
        # 有效样本阈值: > 1024 bytes/sec (1 KB/s)；低于此值视为连接失败
        if (( $(echo "$raw > 1024" | bc 2>/dev/null || echo 0) )); then
            samples+=("$raw")
        fi
    done

    local count=${#samples[@]}
    local result="0.00"

    if [[ "$count" -eq 0 ]]; then
        log WARN "[测速] ${name}: 全部 ${SPEED_SAMPLES} 次采样失败，返回 0"
        echo "$result"
        return
    fi

    # 截断均值 + 标准差：全部在一个 awk 脚本中完成
    # 输入：每行一个原始 bytes/sec 值
    # 输出：3 个空格分隔的值 → 截断均值(Mbps)  标准差(Mbps)  稳定性标注
    local stats
    stats=$(printf '%s\n' "${samples[@]}" | awk -v n="$count" '
    { vals[NR] = $1 }
    END {
        # 冒泡排序（样本量≤5，够用）
        for (i = 1; i <= n; i++)
            for (j = i+1; j <= n; j++)
                if (vals[j] < vals[i]) { t=vals[i]; vals[i]=vals[j]; vals[j]=t }

        # 截断范围：≥3 个样本时去掉最小(1)和最大(n)
        s = (n >= 3) ? 2 : 1
        e = (n >= 3) ? n-1 : n

        # 截断均值（bytes/s → Mbps）
        tsum = 0; tn = 0
        for (i = s; i <= e; i++) { tsum += vals[i]; tn++ }
        tmean = tsum * 8 / tn / 1024 / 1024

        # 全样本均值（用于标准差基准）
        fsum = 0
        for (i = 1; i <= n; i++) fsum += vals[i] * 8 / 1024 / 1024
        fmean = fsum / n

        # 总体标准差
        sum2 = 0
        for (i = 1; i <= n; i++) sum2 += (vals[i] * 8 / 1024 / 1024 - fmean)^2
        sd = sqrt(sum2 / n)

        # 变异系数 → 稳定性标注
        cv = (tmean > 0) ? sd / tmean : 0
        if      (cv < 0.2) lbl = "[稳定]"
        else if (cv < 0.5) lbl = "[轻微波动]"
        else               lbl = "[波动较大]"

        printf "%.2f %.2f %s\n", tmean, sd, lbl
    }')

    result=$(echo "$stats" | awk '{print $1}')
    local stddev lbl
    stddev=$(echo "$stats" | awk '{print $2}')
    lbl=$(echo "$stats" | awk '{print $3}')

    log INFO "[测速] ${name}: ${count}/${SPEED_SAMPLES} 有效样本，截断均值 ${result} Mbps，标准差 ${stddev} Mbps ${lbl}"
    echo "$result"
}
```

**Step 3: 语法检查**

```bash
bash -n scripts/entrypoint.sh && echo "syntax OK"
```

期望：`syntax OK`，无任何报错。

**Step 4: 手动功能验证**

创建临时验证脚本确认 awk 逻辑正确：

```bash
# 模拟 5 个样本（bytes/sec）：对应 365.49, 44.05, 55.66, 51.20, 6.80 Mbps
printf '%s\n' 46783000 5638400 7124480 6553600 871424 | awk -v n=5 '
{ vals[NR] = $1 }
END {
    for (i = 1; i <= n; i++)
        for (j = i+1; j <= n; j++)
            if (vals[j] < vals[i]) { t=vals[i]; vals[i]=vals[j]; vals[j]=t }
    s=2; e=n-1
    tsum=0; tn=0
    for (i = s; i <= e; i++) { tsum += vals[i]; tn++ }
    tmean = tsum * 8 / tn / 1024 / 1024
    fsum=0
    for (i = 1; i <= n; i++) fsum += vals[i] * 8 / 1024 / 1024
    fmean = fsum / n
    sum2=0
    for (i = 1; i <= n; i++) sum2 += (vals[i] * 8 / 1024 / 1024 - fmean)^2
    sd = sqrt(sum2 / n)
    cv = (tmean > 0) ? sd / tmean : 0
    if (cv < 0.2) lbl="[稳定]"
    else if (cv < 0.5) lbl="[轻微波动]"
    else lbl="[波动较大]"
    printf "截断均值: %.2f Mbps\n标准差:   %.2f Mbps\n稳定性:   %s\n", tmean, sd, lbl
}'
```

期望输出（近似值）：
```
截断均值: 50.30 Mbps
标准差:   127.xx Mbps
稳定性:   [波动较大]
```

验证点：
- 截断均值 ≈ 50 Mbps（不含 365.49 和 6.80 这两个极端值）
- 标准差 > 100 Mbps（因为 365 Mbps 的离群值拉大了方差）
- 标注为 `[波动较大]`（cv > 0.5）

**Step 5: 验证边界情况（count=1 和 count=2）**

```bash
# count=1：直接返回该值
printf '%s\n' 5000000 | awk -v n=1 '
{ vals[NR]=$1 }
END {
    s=(n>=3)?2:1; e=(n>=3)?n-1:n
    tsum=0; tn=0
    for(i=s;i<=e;i++){tsum+=vals[i];tn++}
    printf "%.2f\n", tsum*8/tn/1024/1024
}'
# 期望：38.15（5000000 bytes/s → Mbps）

# count=2：两者均值
printf '%s\n' 5000000 7000000 | awk -v n=2 '
{ vals[NR]=$1 }
END {
    for(i=1;i<=n;i++) for(j=i+1;j<=n;j++) if(vals[j]<vals[i]){t=vals[i];vals[i]=vals[j];vals[j]=t}
    s=(n>=3)?2:1; e=(n>=3)?n-1:n
    tsum=0; tn=0
    for(i=s;i<=e;i++){tsum+=vals[i];tn++}
    printf "%.2f\n", tsum*8/tn/1024/1024
}'
# 期望：45.78（两者均值）
```

**Step 6: 同步更新函数头注释**

将函数头注释：
```bash
# 下载测速，返回速度均值（Mbps，保留两位小数）
# 用法: speed_test <url> <name> [socks5h://ip:port] [user:pass]
# 采样: 执行 SPEED_SAMPLES 次，取非零样本均值；全部失败则返回 0
```

改为：
```bash
# 下载测速，返回截断均值（Mbps，保留两位小数）
# 用法: speed_test <url> <name> [socks5h://ip:port] [user:pass]
# 采样: 执行 SPEED_SAMPLES 次；有效样本≥3时去最大最小取中间均值（截断均值）；
#       全部失败返回 0；日志输出标准差与稳定性标注（[稳定]/[轻微波动]/[波动较大]）
```

**Step 7: 提交**

```bash
git add scripts/entrypoint.sh
git commit -m "perf: speed_test 改用截断均值，增加标准差与稳定性日志"
```

---

## Task 3：整体回归验证

**Step 1: 语法检查**

```bash
bash -n scripts/entrypoint.sh && echo "syntax OK"
```

期望：`syntax OK`

**Step 2: 确认 SPEED_SAMPLES 已为 5**

```bash
grep "SPEED_SAMPLES" scripts/entrypoint.sh
```

期望：`SPEED_SAMPLES=5`

**Step 3: 确认旧的 `total=0 count=0` 算法已移除**

```bash
grep "total=0" scripts/entrypoint.sh
```

期望：无输出（旧算法已清除）

**Step 4: 确认新函数包含截断均值关键词**

```bash
grep "截断均值\|samples\|trimmed\|冒泡" scripts/entrypoint.sh
```

期望：至少 3 行匹配

**Step 5: 最终提交（如有遗漏改动）**

```bash
git add -A
git commit -m "chore: 截断均值回归验证通过"
```

---

## 验收标准

- [ ] `bash -n scripts/entrypoint.sh` 无报错
- [ ] `SPEED_SAMPLES=5`
- [ ] 5 个样本 [365, 44, 55, 51, 7] Mbps → 截断均值 ≈ 50 Mbps（非 155 Mbps）
- [ ] 日志格式：`截断均值 XX Mbps，标准差 XX Mbps [稳定/轻微波动/波动较大]`
- [ ] count=1 / count=2 边界情况不崩溃，返回合理值
- [ ] count=0 仍返回 `0.00` 并输出 WARN 日志
- [ ] `IS_8K_SMOOTH` 和容差比较逻辑调用方无需修改（函数签名不变）
