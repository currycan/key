# Code Review 整改设计

**日期**: 2026-03-10
**来源**: Code Review（e32ac43 → HEAD）
**范围**: `scripts/entrypoint.sh`、`scripts/test_entrypoint.sh`、`build.sh`

---

## 背景

对 `e32ac43` 提交的 code review 识别出 3 个 Important 问题和 3 个 Minor 问题，全部需修复。按严重级别分两个 commit 提交，与 review 分级直接对应。

---

## Commit 1：Important 修复

### 1.1 `SPEED_TOLERANCE` 日志显示修复

**文件**: `scripts/entrypoint.sh:459`
**问题**: 日志使用 `1.${SPEED_TOLERANCE}` 字符串拼接，`SPEED_TOLERANCE=5` 时显示 `× 1.5` 而非 `× 1.05`，实际计算正确但日志误导调试。
**修复**: 通过 `awk` 计算实际乘数后再输出，与阈值计算复用同一逻辑。

### 1.2 T11 补全 9 个 `*_OUT` 变量断言

**文件**: `scripts/test_entrypoint.sh:395-401`
**问题**: 仅断言 `CHATGPT_OUT`、`ISP_OUT`、`NETFLIX_OUT` 三个变量被清空，漏掉 `DISNEY_OUT`、`YOUTUBE_OUT`、`GEMINI_OUT`、`CLAUDE_OUT`、`SOCIAL_MEDIA_OUT`、`TIKTOK_OUT`。
**修复**: 补全全部 9 个变量的内存断言和 `STATUS_FILE` 断言。

### 1.3 `first_tag` 改为显式参数传递

**文件**: `scripts/entrypoint.sh:467、925`
**问题**: `first_tag` 为 `local` 变量，通过 bash 动态作用域隐式传入 `apply_isp_routing_logic`，单独调用时静默降级。
**修复**:
- `apply_isp_routing_logic` 增加位置参数 `$1`
- 调用方改为 `apply_isp_routing_logic "$first_tag"`
- 删除"隐式依赖"注释，改为标准参数文档
- T4-2 测试同步改为通过函数调用传参

---

## Commit 2：Minor 修复

### 2.1 `_reset_routing` 清空 `STATUS_FILE`

**文件**: `scripts/test_entrypoint.sh:153-157`
**问题**: `_reset_routing` 清空 `ENV_FILE` 但未清空 `STATUS_FILE`，测试隔离不完整。
**修复**: 末尾追加 `> "$STATUS_FILE"`。

### 2.2 `XRAY_VERSION_FINAL` 显式初始化

**文件**: `build.sh:226`
**问题**: 变量无初始化声明，未来调用顺序变化时可能产生空 tag 静默错误。
**修复**: 顶部变量声明区追加 `XRAY_VERSION_FINAL=""`。

### 2.3 T9-4 改为断言返回值

**文件**: `scripts/test_entrypoint.sh:332-335`
**问题**: 硬编码中文字符串做 grep 匹配，措辞变化即失效。
**修复**: 断言 `speed_test` 返回值为 `"0.00"`；保留 stderr 非空检查（不硬编码文字）以验证诊断日志存在。

---

## 提交策略

```
Commit 1: fix: 修复 Important 级代码审查问题（日志显示、测试覆盖、参数传递）
Commit 2: fix: 修复 Minor 级代码审查问题（测试隔离、变量初始化、断言方式）
```

---

## 验收标准

- [ ] `SPEED_TOLERANCE` 任意值日志显示与实际计算一致
- [ ] T11 断言覆盖全部 9 个 `*_OUT` 变量（内存 + 文件）
- [ ] `apply_isp_routing_logic` 可独立调用，无动态作用域依赖
- [ ] `_reset_routing` 后 `STATUS_FILE` 为空
- [ ] `build.sh` 顶部 `XRAY_VERSION_FINAL` 有初始化
- [ ] T9-4 通过返回值断言，不依赖日志措辞
- [ ] 所有现有测试通过
