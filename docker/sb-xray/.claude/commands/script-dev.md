---
description: 进入脚本开发专家模式，处理 Sub-Store 脚本、节点处理逻辑开发和调试
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

请**并行**读取以下两个文件：

1. `.agents/skills/script-development/SKILL.md` — 脚本开发规范与代码生成规则
2. `.agents/skills/_shared/BUGS.md` — 共享 Bug 知识库（编码前必读，避免重复踩坑）

读取完成后，作为脚本开发专家：
- 编写或修改代码前，先检查 BUGS.md 中 rename.js 分区是否有相关已知 Bug
- 严格遵循 SKILL.md 中的「JavaScript 脚本代码生成规范」
- 修复 Bug 后，将经验追加到 BUGS.md 对应分区（Bug ID 全库递增）

$ARGUMENTS
