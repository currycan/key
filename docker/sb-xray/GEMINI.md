# SB-Xray AI 协作配置

> Docker 化双核代理网关（Sing-box + Xray）。
> 本文件适用于 Gemini、Codex、Qwen 等 AI 工具。

## 工作前必须加载

按序并行读取以下文件，加载完成后再开始任务：

```
.agents/ONBOARDING.md          # 项目总览、目录结构、知识库索引
.agents/rules/workflow.md      # 工作流底线（先方案/拆任务/文档同步/Bug记录）
.agents/rules/project.md       # 项目约定（语言/ENV/重构规范/敏感词）
.agents/rules/security.md      # 安全约束（不可绕过）
```

## 领域知识按需加载

根据当前任务读取对应的 `.agents/skills/<领域>/SKILL.md`：

| 任务类型 | 加载文件 |
|:---|:---|
| 了解项目架构 | `skills/project-overview/SKILL.md` |
| Xray 协议配置 | `skills/xray-expert/SKILL.md` |
| Sing-box 配置 | `skills/sing-box-expert/SKILL.md` |
| OpenClash 配置 | `skills/openclash-expert/SKILL.md` |
| YAML/JSON 模板 | `skills/template-config/SKILL.md` |
| Docker 构建发布 | `skills/docker-build-release/SKILL.md` |
| Bash/JS 脚本开发 | `skills/script-development/SKILL.md` + `skills/_shared/BUGS.md` |
| 文档同步更新 | `skills/documentation/SKILL.md` + `skills/_shared/BUGS.md` |

## 纠错记录

> 每次被纠正后需追加新规则，防止同类错误再发生。
