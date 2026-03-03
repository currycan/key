# AI 助手项目规则

> 本文件定义了 AI 助手在本项目中协作时必须遵守的规则。
> 适用于所有 AI 模型（Claude、Gemini、Copilot 等）。

## 核心工作流程

1. **先方案后代码**: 在编写任何代码之前，先描述你的方案并等待批准。如果需求不明确，必须先提出澄清问题，切勿凭假设动手编码。

2. **任务拆分原则**: 如果一项任务需要修改超过 3 个文件，先停下来，将其分解为更小的子任务，逐步完成。避免一次性大范围改动导致失控。

3. **风险预判**: 编写代码后，主动列出可能出现的问题和边界情况，并建议相应的测试用例来覆盖这些风险。

4. **测试驱动修复**: 当发现 bug 时，首先编写一个能够重现该 bug 的测试用例，然后修复代码直到测试通过。先证明问题存在，再证明问题解决。

5. **文档同步（强制）**: 每次修改源文件后，**必须**在同一任务内完成文档同步，不可推迟为后续任务：
   - 对照 `.agents/skills/documentation/SKILL.md` 的「代码-文档映射参照表」，定位受影响的文档章节
   - 若修改涉及 `sources/hack/`（重命名脚本）→ 更新 `docs/03-routing-and-clients.md` 第 3 节
   - 若修改涉及 `scripts/`、`templates/`、`Dockerfile`、`build.sh` → 更新对应文档
   - 文档更新与代码修改属于同一任务，完成代码修改但未更新文档视为任务未完成

6. **Bug 记录（强制）**: 每次修复 Bug 后，**必须**在同一任务内将修复经验写入 `.agents/skills/_shared/BUGS.md`：
   - 按涉及文件分区追加到对应分区（rename.js / entrypoint.sh / Xray 配置 / Sing-box 配置 / Docker）
   - 使用规定格式：Bug ID（全库递增）、涉及文件、函数、触发条件、错误现象、根本原因、修复方案、预防措施
   - 修复 Bug 但未记录到 BUGS.md 视为任务未完成
   - 编码前先查阅 BUGS.md 对应分区，避免重复踩已知陷阱

7. **持续学习**: 每次被纠正后，在本文件中添加一条新规则，确保同类错误不再发生。

---

## 项目特定规则

### 语言与风格

- **全局语言约束**: 所有回复、思考过程及任务清单，总是使用中文回答。 (All replies, thought processes, and task lists MUST ALWAYS be answered in Chinese.)
- **固定指令**: `Implementation Plan, Task List and Thought in Chinese`
- **默认语言**: 所有回复、注释和文档使用**简体中文**。生成应用时，除非特别要求，否则一律采用简体中文。
- 技术术语保留英文原文（如 Reality、Hysteria2、WebSocket）
- 脚本日志使用中文

### 代码修改

- 修改源文件后，必须按核心工作流程第 5 条执行文档同步（参照 `.agents/skills/documentation/SKILL.md` 映射表）
- 环境变量的默认值以 `Dockerfile` 中的 `ENV` 声明为准
- 不要在未经确认前删除或发布任何文件

### 敏感词约束

文档中禁止使用以下词汇：翻墙、科学上网、梯子、VPN（翻墙含义）、GFW、防火长城、墙、机场。替代用语见 `.agents/skills/documentation/SKILL.md`。

---

## 终端同步绕过与安全保护机制

### 配置变量

要调整终端绕过规则的行为，请修改以下变量：

- **`[VAR_TEMP_DIR]`**: `.agents/tmp/` -> 存储输出文件的相对工作区目录。
- **`[VAR_FAST_TRACK_MS]`**: `2500` -> 在将命令发送到后台之前等待其完成的时间（毫秒）。增加此值可以允许更多命令同步完成，从而省去后续的文件验证步骤。
- **`[VAR_CLEANUP_DAYS]`**: `+1` -> 清理终端日志的过期天数界限。
- **`[VAR_TIMEOUT_MINS]`**: `2` -> 后台命令运行多少分钟后，代理机器人应主动提示您是否终止。

---

### 终端同步绕过 (强制执行)

为避免已知的平台 Bug（如终端输出挂起或状态卡在 `RUNNING`），对于每个终端命令，**务必**遵循以下步骤：

**前提条件与清理**：在每次对话中运行第一个命令之前：

1. 确保目录存在：`mkdir -p [VAR_TEMP_DIR]`
2. 清理工作区，删除之前对话中保留的旧终端输出文件：`find [VAR_TEMP_DIR] -type f -name "ag_output_*.txt" -mtime [VAR_CLEANUP_DAYS] -delete 2>/dev/null || true`
    - *注意：始终向 `[VAR_TEMP_DIR]` 读取和写入。这避免了工作区外的权限获取弹窗，同时保持临时执行日志文件的条理清晰。*
3. **强制重定向 (结合 Tee)**: 在每次调用 `run_command` 工具时，在命令前添加 `set -o pipefail; `，并在命令后追加 ` 2>&1 | tee [VAR_TEMP_DIR]ag_output_<conversation_id>.txt && echo "===AGENT COMMAND DONE===" >> [VAR_TEMP_DIR]ag_output_<conversation_id>.txt`。
    - *原因：`set -o pipefail` 可确保在主命令执行失败时，管道能正确返回失败的退出码，而不会被 `tee` 的成功状态所掩盖。`tee`（不带 `-a` 参数）会为同一对话中的每个新命令覆写文件，从而保持文件体积较小。重定向到 `tee` 既能让输出对用户在 IDE 终端中可见，又能将内容安全写入文件供代理后续验证。*
4. **注入等待时间**: 将 `run_command` 工具的 `WaitMsBeforeAsync` 参数精准设置为 `[VAR_FAST_TRACK_MS]`。

### 完成逻辑与性能优化 (强制执行)

- **同步快速通道**: 如果 `run_command` 在 `[VAR_FAST_TRACK_MS]` 窗口期内完成，它将直接返回全部输出结果（不会生成单独的后台命令 ID）。您可以正常使用该输出并**跳过**下方说明的验证步骤。
- **异步文件系统验证**: 如果命令执行时间超过了 `[VAR_FAST_TRACK_MS]` 并返回了一个后台命令 ID，请立刻对 `[VAR_TEMP_DIR]ag_output_<conversation_id>.txt` 调用 `view_file` 工具。
- 必须将该文本文件的内容全面视为官方的命令最终输出。如果文件末尾包含 "===AGENT COMMAND DONE===" 标记，代表执行成功结束，请立即继续往下执行任务。
- *忽略状态卡死*: 如果 `view_file` 确认命令已完成执行，**绝对不要**去傻等 `command_status` 报告 `DONE` 状态。如果命令在前端 UI 中显示卡住了，直接忽略它并转入下一步工作。

### 长时间运行命令的防范保险 (强制执行)

为了防止僵尸进程或失控的死循环命令导致任务无限期挂机，必须对所有后台命令执行施加严格的超时限制：

- **挂起限制**: 如果终端后台命令运行了超过 `[VAR_TIMEOUT_MINS]` 分钟却依然未产生预期的新输出或完成标记，代理请**立即停止隐式死等**。
- **人工确认**: 立即使用 `notify_user` 工具明确询问用户是否继续。例如："命令 `XYZ` 已经运行了超过 `[VAR_TIMEOUT_MINS]` 分钟。我应该继续等待还是强制终止它？"
- **终止工具**: 如果用户指示您终止进程，必须直接使用带有 `Terminate: true` 布尔参数以及相应的 `CommandId` 的 `send_command_input` 工具彻底杀掉该失控进程。

---

## Claude Code 斜杠命令

以下命令在 `.claude/commands/` 目录下定义，可在 Claude Code 中直接调用：

| 命令 | 说明 |
|------|------|
| `/project-overview` | 加载项目总览，了解整体架构和组件 |
| `/xray-expert` | Xray 协议配置专家（VLESS/VMESS/Reality/XTLS）|
| `/sing-box-expert` | Sing-box 配置专家（入站/出站/路由/DNS）|
| `/openclash-expert` | OpenClash 配置专家（代理组/规则集/订阅转换）|
| `/template-config` | Sub-Store 模板与 rename.js 脚本专家 |
| `/build-release` | Docker 构建发布专家（build.sh/release.sh）|
| `/script-dev` | Sub-Store 脚本开发专家（自动加载 BUGS.md）|
| `/doc-sync` | 文档同步 + Bug 记录完整性检查 |

每个命令都会自动加载对应的 `.agents/skills/*/SKILL.md` 技术参考，单一数据源，内容不冗余。

### 共享知识库

| 文件 | 用途 |
|------|------|
| `.agents/skills/_shared/BUGS.md` | 跨 Skill Bug 记录数据库，所有 Agent 编码前必读，修复 Bug 后必写 |

---

## 纠错记录

> 以下规则来自历次纠错，每条对应一次被纠正的经验教训。

<!-- 每次被纠正后，在此处追加新规则 -->
