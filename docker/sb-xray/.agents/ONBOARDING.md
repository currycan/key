---
name: SB-Xray 项目通用入口
description: 任何 AI 工具进入本项目时的第一读文件，包含项目定位、目录导图、规则和知识库索引
---

# SB-Xray 项目入门

## 项目定位

**SB-Xray** 是一个 Docker 化的企业级全栈网络调度与代理安全网关，基于 **Sing-box + Xray** 双核引擎，单容器集成代理服务、证书管理、面板控制和客户端配置分发。

- 镜像：`currycan/sb-xray`
- 技术栈：Bash、Docker 多阶段构建、Nginx、JSON、YAML、JavaScript

---

## 目录结构速查

```
sb-xray/
├── CLAUDE.md                  # Claude Code 入口
├── GEMINI.md                  # Gemini / Codex / Qwen 入口
├── Dockerfile                 # 四阶段多平台构建 (amd64/arm64)
├── docker-compose.yml         # 部署清单
├── build.sh / release.sh      # 构建与发布自动化
├── scripts/
│   └── entrypoint.sh          # 🔑 核心入口脚本（16段架构，系统启动流水线）
├── templates/                 # 所有配置模板
│   ├── xray/                  # Xray 协议模板 (Reality/XHTTP/VMess-WS)
│   ├── sing-box/              # Sing-box 协议模板 (Hysteria2/TUIC/AnyTLS)
│   ├── nginx/                 # Nginx 反向代理配置
│   ├── client_template/       # 客户端订阅模板 (OneSmartPro/FallBackPro/surge)
│   ├── proxies/               # 节点输出模板 (clash/stash/surge)
│   └── providers/             # Proxy Provider 配置
├── sources/
│   └── hack/rename.js         # 节点重命名流水线（§N 段架构）
├── docs/                      # 技术文档（5篇）
├── .claude/                   # Claude Code 专属功能
│   ├── agents/                # 子代理（planner/doc-updater/refactor-cleaner）
│   ├── commands/              # 斜杠命令（/xray-expert 等 8 个）
│   └── settings.json          # Hooks 配置
└── .agents/                   # 多 AI 共享知识库（本文件所在位置）
    ├── ONBOARDING.md          # 本文件：通用入口
    ├── rules/                 # 所有 AI 必须遵守的规则
    │   ├── workflow.md        # 工作流底线（先方案/文档同步/Bug记录等）
    │   ├── project.md         # 项目约定（语言/ENV/重构规范/敏感词）
    │   └── security.md        # 安全约束（不删/不推/不硬编码密钥）
    └── skills/                # 领域专业知识库
        ├── _shared/
        │   ├── BUGS.md        # ⚠️ 编码前必读，修复 Bug 后必写
        │   └── TERMINAL-SYNC.md
        ├── project-overview/  # 项目架构全景
        ├── xray-expert/       # Xray 协议配置
        ├── sing-box-expert/   # Sing-box 配置
        ├── openclash-expert/  # OpenClash/Mihomo 配置
        ├── template-config/   # YAML/JSON 模板管理
        ├── docker-build-release/ # Docker 构建发布
        ├── script-development/   # Bash/JS 脚本开发规范
        └── documentation/    # 文档维护规范与 Bug 记录格式
```

---

## 工作前必读清单

**所有 AI 在开始任务前，按序加载以下文件：**

| 优先级 | 文件 | 说明 |
|:---|:---|:---|
| 🔴 必读 | `.agents/rules/workflow.md` | 工作流底线（先方案、文档同步、Bug记录） |
| 🔴 必读 | `.agents/rules/project.md` | 项目约定（语言、ENV、重构规范） |
| 🔴 必读 | `.agents/rules/security.md` | 安全约束（不可绕过） |
| 🟡 按需 | `.agents/skills/_shared/BUGS.md` | 编码任务前必读对应分区 |
| 🟡 按需 | `.agents/skills/<领域>/SKILL.md` | 按任务类型选择对应领域知识 |

**领域 → SKILL.md 映射：**

| 任务类型 | 读取文件 |
|:---|:---|
| 了解项目架构 | `skills/project-overview/SKILL.md` |
| Xray 协议配置 | `skills/xray-expert/SKILL.md` |
| Sing-box 配置 | `skills/sing-box-expert/SKILL.md` |
| OpenClash/Mihomo | `skills/openclash-expert/SKILL.md` |
| YAML/JSON 模板 | `skills/template-config/SKILL.md` |
| Docker 构建发布 | `skills/docker-build-release/SKILL.md` |
| Bash/JS 脚本开发 | `skills/script-development/SKILL.md` |
| 文档同步/Bug记录 | `skills/documentation/SKILL.md` |

---

## 核心编码规范速查

- **语言**：所有回复、注释、日志使用简体中文，技术术语保留英文
- **ENV 默认值**：以 `Dockerfile` 中 `ENV` 声明为准
- **entrypoint.sh**：16 段 §N 架构，函数按工具层→业务层→入口层分层声明
- **rename.js**：§N 段架构，Utils 按依赖复杂度排列，Pipeline 私有方法加 `_` 前缀
- **Bug 记录**：修复后写入 `_shared/BUGS.md`，编码前先查阅
