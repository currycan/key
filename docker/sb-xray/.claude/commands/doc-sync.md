---
description: 执行文档同步检查，根据代码变更更新 docs/ 目录下的对应文档章节
allowed-tools: Read, Grep, Glob, Edit, Write
---

请先读取文档同步规范：

```
.agents/skills/documentation/SKILL.md
```

读取完成后，按照「代码-文档映射参照表」，检查最近修改的源文件，找出需要更新的文档章节并执行更新。

如果用户指定了修改的文件，直接根据映射表定位相关文档；否则通过 `git diff --name-only HEAD` 查看最近变更文件列表后再进行映射。

$ARGUMENTS
