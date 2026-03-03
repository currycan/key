---
description: 执行文档同步检查，根据代码变更更新 docs/ 目录下的对应文档章节，并检查 Bug 记录是否完整
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

请**并行**读取以下两个文件：

1. `.agents/skills/documentation/SKILL.md` — 文档维护规范与 Bug 记录规范
2. `.agents/skills/_shared/BUGS.md` — 共享 Bug 知识库（检查最新条目是否已同步到文档）

读取完成后：

**文档同步**：按照「代码-文档映射参照表」，检查最近修改的源文件，找出需要更新的文档章节并执行更新。如果用户指定了修改的文件，直接根据映射表定位；否则通过 `git diff --name-only HEAD` 查看变更列表后映射。

**Bug 记录检查**：若此次有修复 Bug，确认经验已按规范追加到 BUGS.md 对应分区，格式包含：Bug ID、涉及文件、函数、触发条件、错误现象、根本原因、修复方案、预防措施、记录时间。

$ARGUMENTS
