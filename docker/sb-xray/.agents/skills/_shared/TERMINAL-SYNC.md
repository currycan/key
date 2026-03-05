---
name: 终端同步绕过规范
description: 终端命令执行的同步绕过机制与安全保护，适用于所有 AI Agent
---

# 终端同步绕过与安全保护机制

## 配置变量

| 变量 | 默认值 | 说明 |
|:---|:---|:---|
| `[VAR_TEMP_DIR]` | `.agents/tmp/` | 存储输出文件的相对工作区目录 |
| `[VAR_FAST_TRACK_MS]` | `2500` | 命令发送到后台前的等待时间（毫秒） |
| `[VAR_CLEANUP_DAYS]` | `+1` | 清理终端日志的过期天数界限 |
| `[VAR_TIMEOUT_MINS]` | `2` | 后台命令运行多少分钟后提示用户是否终止 |

---

## 强制执行步骤

**每次对话首次运行命令前**：

```bash
mkdir -p [VAR_TEMP_DIR]
find [VAR_TEMP_DIR] -type f -name "ag_output_*.txt" -mtime [VAR_CLEANUP_DAYS] -delete 2>/dev/null || true
```

**每次调用 `run_command` 时**，在命令前后注入：

```
set -o pipefail; <原始命令> 2>&1 | tee [VAR_TEMP_DIR]ag_output_<id>.txt && echo "===AGENT COMMAND DONE===" >> [VAR_TEMP_DIR]ag_output_<id>.txt
```

- `set -o pipefail`：确保主命令失败时管道返回正确退出码
- `tee`（不加 `-a`）：每条命令覆写文件，控制文件大小
- `WaitMsBeforeAsync` 设置为 `[VAR_FAST_TRACK_MS]`

---

## 完成逻辑

| 情况 | 处理方式 |
|:---|:---|
| `run_command` 在窗口期内完成 | 直接使用输出，**跳过**文件验证 |
| 超时并返回后台 ID | 立即对输出文件调用 `view_file` |
| 文件末尾有 `===AGENT COMMAND DONE===` | 确认完成，立即继续下一步 |
| 前端 UI 显示卡住 | **忽略**，以文件内容为准 |

---

## 长时间运行防范

- 后台命令超过 `[VAR_TIMEOUT_MINS]` 分钟无新输出 → 立即停止等待，用 `notify_user` 询问用户
- 用户指示终止时：使用 `send_command_input` 工具并传入 `Terminate: true` + 对应 `CommandId`
