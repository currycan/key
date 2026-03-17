---
description: SB-Xray 项目约定，编写代码、注释和文档时必须遵守
---

# 项目约定

## 语言与风格

- **回复语言**: 所有回复、思考过程、任务清单使用**简体中文**
- **代码注释**: 使用简体中文，技术术语（Reality、Hysteria2、WebSocket 等）保留英文原文
- **脚本日志**: `log INFO/WARN/ERROR` 输出内容使用中文

## 环境变量

- **固定值变量必须且只能在 `Dockerfile ENV` 中定义默认值**，脚本中直接引用 `${VAR}`，禁止 `${VAR:-default}` 硬编码默认值
- 只有随机生成的变量（UUID、端口、密钥等）才在 `entrypoint.sh` 的 `ensure_var` 中计算
- **禁止跨脚本重复定义同一变量的默认值**——`show-config.sh` 等辅助脚本只消费变量，不定义默认值
- `docker-compose.yml` 的 `environment:` 用于用户覆盖，Dockerfile ENV 用于项目默认值
- 新增变量须同步更新 `readme.md` 配置参考表

## 代码重构

- Bash 脚本重构规范（跨平台兼容、函数分层、`§N` 段落、测试驱动）见：
  `.agents/skills/script-development/SKILL.md` § 代码重构规范 — Bash 脚本重构
- JavaScript 脚本重构规范（Utils 依赖顺序、Pipeline `_` 前缀、IIFE 产出缓存）见：
  `.agents/skills/script-development/SKILL.md` § 代码重构规范 — JavaScript 脚本重构

## 敏感词约束

文档中禁止使用：翻墙、科学上网、梯子、VPN（翻墙含义）、GFW、防火长城、墙、机场。
替代用语与完整规范见：`.agents/skills/documentation/SKILL.md` § 敏感词规范

## 终端命令执行

避免终端挂起的同步绕过机制见：`.agents/skills/_shared/TERMINAL-SYNC.md`
