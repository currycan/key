# 🛡️ 订阅端点安全指南

本指南详细说明了 `sb-xray` 项目中针对订阅配置访问端点（`/sb-xray/`）的全面安全防护机制。

---

## 🔒 核心特性

系统采用了多层防御策略，确保订阅信息的绝对安全：

1.  **双重认证系统**：支持 **Token**（推荐）或 **HTTP 基础认证**，灵活且安全。
2.  **防扫描设计**：所有非法请求（文件不存在、认证失败、格式错误）统一返回 `404 Not Found`，彻底隐藏服务端点。
3.  **严格的访问控制**：
    *   **路径验证**：仅允许访问符合 `[a-zA-Z0-9_-]+\.yaml` 格式的文件。
    *   **禁止目录浏览**：防止列出所有订阅文件。
4.  **安全加固**：
    *   **速率限制**：防止暴力破解和 CC 攻击。
    *   **安全响应头**：防止 MIME 嗅探、点击劫持等。
    *   **禁止缓存**：防止敏感配置被中间节点缓存。

---

## 🔑 认证方式

系统默认启用双重认证，优先级逻辑如下：

```mermaid
graph TD
    A[访问请求] --> B{提供 Token?}
    B -- 是 --> C{Token 正确?}
    C -- 是 --> D[✅ 允许访问]
    C -- 否 --> E[要求 HTTP 基础认证]
    B -- 否 --> E
    E -- 凭据正确 --> D
    E -- 凭据错误 --> F[❌ 返回 404]
```

### 方式 1：Token 认证（推荐）

最简单、最友好的认证方式，适合大多数场景。

#### 1. 配置 Token
Token 会在容器首次启动时**自动生成**。

*   **查看当前 Token**：
    ```bash
    docker exec sb-xray cat /sb-xray/.env | grep SUBSCRIBE_TOKEN
    ```

*   **自定义 Token**（可选）：
    在 `docker-compose.yml` 中设置：
    ```yaml
    environment:
      - SUBSCRIBE_TOKEN=your_custom_secure_token_32_chars
    ```

#### 2. 使用方法
在订阅 URL 后添加 `?token=YOUR_TOKEN` 参数：

```
https://your-domain.com/sb-xray/MihomoPro.yaml?token=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
```
> **提示**：这种方式不会弹出认证框，适合所有客户端。

### 方式 2：HTTP 基础认证

基于标准的 HTTP Authentication 协议，作为备用或更高安全性需求的认证方式。

#### 1. 配置凭据
使用与 X-UI / S-UI 相同的用户名和密码（在 `docker-compose.yml` 中设置）：

```yaml
environment:
  - PUBLIC_USER=admin
  - PUBLIC_PASSWORD=your_secure_password
```

#### 2. 使用方法
*   **浏览器**：访问链接时会弹出认证对话框。
*   **客户端/命令行**：
    ```
    https://admin:your_secure_password@your-domain.com/sb-xray/MihomoPro.yaml
    ```

---

## 🛡️ 安全加固细节

### 1. 严格的路径验证
仅允许访问特定的 YAML 文件名。

*   ✅ `https://domain.com/sb-xray/MihomoPro.yaml` (通过)
*   ❌ `https://domain.com/sb-xray/secret.txt` (404 - 扩展名错误)
*   ❌ `https://domain.com/sb-xray/../etc/passwd` (404 - 路径遍历攻击)
*   ❌ `https://domain.com/sb-xray/` (404 - 目录访问)

### 2. 速率限制 (Rate Limiting)
*   **策略**：每个 IP 每分钟限制 **10 次**请求。
*   **突发**：允许 5 次突发请求（Burst）。
*   **效果**：超过限制后直接返回 `404`（而不是 429），让攻击者无法判断是由于限流还是文件不存在。

### 3. 安全响应头
服务器会强制返回以下安全头部：
*   `X-Content-Type-Options: nosniff`
*   `X-Frame-Options: DENY`
*   `Cache-Control: no-store, no-cache...` (禁止缓存)

---

## 📊 监控与日志

所有订阅访问（无论成功与否）都会被记录。

### 查看访问日志
```bash
# 查看成功的订阅访问
docker exec sb-xray tail -f /var/log/nginx/subscribe_access.log
```

### 查看攻击/扫描日志
所有非法路径、认证失败、速率限制拦截都会记录在这里：
```bash
# 实时查看扫描尝试
docker exec sb-xray tail -f /var/log/nginx/subscribe_scan.log
```

### 统计攻击来源
```bash
# 统计前 10 个攻击者 IP
docker exec sb-xray awk '{print $1}' /var/log/nginx/subscribe_scan.log | sort | uniq -c | sort -rn | head -10
```

---

## ⚠️ 常见问题 (FAQ)

**Q: 为什么我访问订阅链接返回 404？**
A: 请检查以下几点：
1. **Token 错误**：URL 中的 Token 与 `.env` 中的不一致。
2. **认证失败**：如果没用 Token，输入的用户名/密码错误。
3. **文件名错误**：文件名大小写敏感，且必须以 `.yaml` 结尾。
4. **触发限流**：请求过于频繁，请稍等一分钟再试。

**Q: 如何更换 Token 或密码？**
A: 修改 `docker-compose.yml` 中的 `SUBSCRIBE_TOKEN` 或 `PUBLIC_PASSWORD`，然后执行 `docker compose restart` 重启容器。

**Q: Token 会过期吗？**
A: 不会，除非您手动更改配置。
