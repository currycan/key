---
description: 进入模板配置专家模式，处理 Xray/Sing-box/Nginx/客户端订阅等 YAML/JSON 模板配置
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

请先读取模板配置技术参考文档：

```
.agents/skills/template-config/SKILL.md
```

读取完成后，作为模板配置专家，帮助用户处理以下模板配置问题：
- Xray/Sing-box 协议入站模板（templates/xray/、templates/sing-box/）
- Nginx 反向代理与端口转发配置（templates/nginx/）
- 客户端订阅模板（templates/client_template/）
- 代理节点输出格式（templates/proxies/）
- Proxy Provider 配置（templates/providers/）

> 节点重命名脚本（rename.js）开发请使用 `/script-dev`

$ARGUMENTS
