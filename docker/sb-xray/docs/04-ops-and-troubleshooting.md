# 04. 运维管理与故障排查手册

> 覆盖系统管理面板导航、订阅端点安全防护、证书运维、GeoIP 数据更新与常见故障排查。

---

## 目录

1. [系统控制面板导航](#1-系统控制面板导航)
2. [订阅端点安全体系](#2-订阅端点安全体系)
3. [证书管理运维](#3-证书管理运维)
4. [GeoIP/GeoSite 数据更新](#4-geoipgeosite-数据更新)
5. [故障排查实战手册](#5-故障排查实战手册)

---

## 1. 系统控制面板导航

SB-Xray 集成了多个可视化管理面板，全部通过 CDN 域名的子路径访问。

### 1.1 控制面板一览

| 面板 | 入口路径 | 功能 | 默认凭据来源 |
|:---|:---|:---|:---|
| **X-UI (3x-ui)** | `https://${CDNDOMAIN}/${XUI_WEBBASEPATH}` | Xray 协议与用户管理 | 环境变量 `XUI_ACCOUNT` |
| **S-UI** | `https://${CDNDOMAIN}/${SUI_WEBBASEPATH}` | Sing-box 入站与出站监控 | 环境变量 |
| **Sub-Store** | `https://${CDNDOMAIN}/sub-store` | 订阅源管理与节点清洗 | 无需认证 |
| **Dufs** | `https://${CDNDOMAIN}/${DUFS_PATH_PREFIX}` | 文件上传/下载网盘 | HTTP Basic 认证 |
| **Yacd/Zashboard** | `https://${CDNDOMAIN}:9090/ui` | 实时流量与策略组监控 | Secret: `yyds666` |

> **安全提醒**：所有面板路径均通过 Nginx 的 `location` 指令保护，建议首次登录后立即修改默认 WebBasePath。

### 1.2 环境变量配置示例

```yaml
environment:
  # X-UI
  - XUI_WEBBASEPATH=3xadmin      # 自定义面板路径
  - XUI_ACCOUNT=admin             # 默认用户名
  - XUI_PORT=8888                 # 内部端口

  # S-UI
  - SUI_WEBBASEPATH=sui           # 自定义面板路径
  - SUI_PORT=3095                 # 内部端口

  # Dufs 文件服务
  - DUFS_PATH_PREFIX=/myfiles     # 文件网盘的 URL 前缀
  - DUFS_SERVE_PATH=/data         # 文件存储路径
```

---

## 2. 订阅端点安全体系

订阅配置文件（`/sb-xray/`）包含所有代理连接信息，安全性至关重要。系统对此端点设计了多层防御策略。

### 2.1 安全体系总览

```mermaid
graph TD
    A["访问请求"] --> B{"携带 Token?"}
    B -- "是" --> C{"Token 正确?"}
    C -- "是" --> D["允许访问"]
    C -- "否" --> E["要求 HTTP 基础认证"]
    B -- "否" --> E
    E -- "凭据正确" --> D
    E -- "凭据错误" --> F["返回 404"]

    style D fill:#55efc4,stroke:#00b894,stroke-width:2px
    style F fill:#ff7675,stroke:#d63031,stroke-width:2px
```

### 2.2 认证方式一：Token 认证（推荐）

Token 在容器首次启动时**自动生成**。

**查看当前 Token**：

```bash
docker exec sb-xray grep SUBSCRIBE_TOKEN /.env/sb-xray
```

**使用方法**：在订阅 URL 后添加 `?token=YOUR_TOKEN` 参数：

```
https://your-domain.com/sb-xray/MihomoPro.yaml?token=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
```

**自定义 Token**（可选）：

```yaml
environment:
  - SUBSCRIBE_TOKEN=your_custom_secure_token_32_chars
```

### 2.3 认证方式二：HTTP 基础认证（备用）

使用与 X-UI / S-UI 相同的用户名和密码：

```yaml
environment:
  - PUBLIC_USER=admin
  - PUBLIC_PASSWORD=your_secure_password
```

**使用方法**：

* 浏览器：访问链接时会弹出认证对话框
* 客户端：`https://admin:password@your-domain.com/sb-xray/MihomoPro.yaml`

### 2.4 安全加固措施

| 措施 | 实现方式 | 效果 |
|:---|:---|:---|
| **防扫描设计** | 所有非法请求统一返回 `404` | 攻击者无法判断端点是否存在 |
| **严格路径验证** | 仅允许字母数字+`.yaml`后缀 | 阻止目录遍历攻击 (`../etc/passwd`) |
| **禁止目录浏览** | Nginx `autoindex off` | 防止列出全部订阅文件 |
| **速率限制** | 每 IP 每分钟 10 次 | 超限也返回 `404`（防暴力破解） |
| **安全响应头** | `X-Content-Type-Options: nosniff` | 防 MIME 嗅探、点击劫持 |
| **禁止缓存** | `Cache-Control: no-store` | 防敏感配置被中间节点缓存 |

### 2.5 监控与日志

```bash
# 查看成功的订阅访问
docker exec sb-xray tail -f /var/log/nginx/subscribe_access.log

# 实时查看扫描尝试
docker exec sb-xray tail -f /var/log/nginx/subscribe_scan.log

# 统计前 10 个攻击者 IP
docker exec sb-xray awk '{print $1}' /var/log/nginx/subscribe_scan.log | sort | uniq -c | sort -rn | head -10
```

---

## 3. 证书管理运维

### 3.1 日常运维命令

```bash
# 查看证书状态
docker exec sb-xray openssl x509 -in /pki/fullchain.pem -text -noout | grep -E "Not (Before|After)"

# 强制重新签发（删除旧证书后重启）
rm -rf ./pki/* ./acmecerts/*
docker compose restart

# 手动续期
docker exec sb-xray /acme.sh/acme.sh --renew -d ${DOMAIN} -d ${CDNDOMAIN} --force
```

### 3.2 多域名证书策略

系统默认申请**泛域名 + 主域名**双SAN证书：

```
SAN[0]: *.example.com     (泛域名，覆盖所有子域名)
SAN[1]: example.com       (主域名)
```

### 3.3 DH 参数安全加固

首次启动时，系统自动生成 2048-bit DH 密钥参数：

```bash
# 存储路径：挂载卷 ./nginx/dhparam/dhparam.pem
# 耗时约 30 秒至 2 分钟（取决于 CPU）
# 生成后缓存，后续重启直接复用
```

---

## 4. GeoIP/GeoSite 数据更新

`scripts/geo_update.sh` 负责更新 Xray 和 Sing-box 使用的地理信息数据库。

### 4.1 自动更新

系统通过 Supervisor 定时任务自动执行更新。

### 4.2 手动更新

```bash
# 手动触发更新
docker exec sb-xray /scripts/geo_update.sh

# 查看当前 GeoIP 数据版本
docker exec sb-xray ls -la /usr/local/bin/bin/
```

### 4.3 数据源

| 文件 | 用途 | 来源 |
|:---|:---|:---|
| `geoip.dat` | IP 地理归属库 (Xray) | Loyalsoldier/v2ray-rules-dat |
| `geosite.dat` | 域名分类库 (Xray) | Loyalsoldier/v2ray-rules-dat |
| `geoip.db` | IP 地理归属库 (Sing-box) | SagerNet/sing-geoip |
| `geosite.db` | 域名分类库 (Sing-box) | SagerNet/sing-geosite |

---

## 5. 故障排查实战手册

### 5.1 快速诊断流程

```mermaid
flowchart TD
    Start(("连接出问题")) --> Q1{"能 ping 通服务器 IP 吗?"}
    Q1 -- "不能" --> A1["检查服务器防火墙和网络"]
    Q1 -- "能" --> Q2{"浏览器打开域名能出页面吗?"}
    Q2 -- "出 SSL 报错 / 无响应" --> A2["检查 Nginx 和证书配置"]
    Q2 -- "出伪装页面 / 404" --> Q3{"Proxy 客户端连接超时?"}
    Q3 -- "Vision 超时" --> A3["检查 UUID、Reality 参数"]
    Q3 -- "VMess/XHTTP 超时" --> A4["检查 Path、CDN域名匹配"]
    Q3 -- "Hysteria2 超时" --> A5["检查 UDP 端口、防火墙"]
```

### 5.2 常见故障排查表

#### ❌ 故障一：客户端连接 502 Bad Gateway

**现象**：浏览器或客户端返回 502 错误

**排查步骤**：

```bash
# 1. 检查 Xray 核心是否存活
docker exec sb-xray supervisorctl status xray

# 2. 查看 Xray 错误日志
docker exec sb-xray tail -50 /var/log/xray/access.log

# 3. 检查 Nginx 连接 UDS 是否正常
docker exec sb-xray ls -la /dev/shm/*.sock

# 4. 检查 Nginx 错误日志
docker exec sb-xray tail -50 /var/log/nginx/error.log
```

**常见原因**：
| 原因 | 解决方案 |
|:---|:---|
| Xray 配置 JSON 语法错误导致崩溃 | 检查日志中的 JSON parse error |
| UDS Socket 文件不存在 | 重启容器：`docker compose restart` |
| 内存不足导致 OOM | 检查 `dmesg` |

#### ❌ 故障二：订阅文件返回 404

**排查顺序**：

1. **Token 错误**：检查 URL 中的 Token 与 `.env` 中的是否一致
2. **认证失败**：未携带 Token 时，输入的用户名/密码可能错误
3. **文件名大小写**：文件名大小写敏感
4. **触发限流**：请求过于频繁，等待一分钟

#### ❌ 故障三：证书申请失败

**排查步骤**：

```bash
# 检查 DNS 解析
nslookup ${DOMAIN}

# 检查 443 端口是否开放
nc -zv ${SERVER_IP} 443

# 检查 acme.sh 日志
docker exec sb-xray cat /var/log/acme.sh.log
```

**常见原因**：
| 原因 | 解决方案 |
|:---|:---|
| DNS A 记录未指向服务器 | 修正 DNS 记录并等待传播 |
| Cloudflare 小黄云未关闭 | DNS-only 模式下申请后再开启 |
| CA 频率限制 | 切换 CA 或等待后重试 |
| EAB 凭据过期 (Google CA) | 重新生成 EAB 凭据 |

#### ❌ 故障四：Hysteria2/TUIC 连接失败

**排查步骤**：

```bash
# 检查 Sing-box 状态
docker exec sb-xray supervisorctl status sing-box

# 检查 UDP 端口是否监听
docker exec sb-xray ss -ulnp | grep ${PORT_HYSTERIA2}

# 外部测试 UDP 连通性
nc -zuv ${SERVER_IP} ${PORT_HYSTERIA2}
```

**常见原因**：
| 原因 | 解决方案 |
|:---|:---|
| 服务器防火墙未放行 UDP | `ufw allow ${PORT}/udp` 或安全组放行 |
| ISP 封锁 UDP | 切换其他协议 |
| 客户端 UUID 错误 | 注意 Sing-box 使用 `SB_UUID` 而非 `XRAY_UUID` |

### 5.3 日志检查速查表

| 日志位置 | 用途 |
|:---|:---|
| `/var/log/xray/access.log` | Xray 访问日志 |
| `/var/log/xray/error.log` | Xray 错误日志 |
| `/var/log/sing-box/sing-box.log` | Sing-box 日志 |
| `/var/log/nginx/error.log` | Nginx 错误日志 |
| `/var/log/nginx/access.log` | Nginx 访问日志 |
| `/var/log/nginx/subscribe_access.log` | 订阅成功访问 |
| `/var/log/nginx/subscribe_scan.log` | 扫描/攻击记录 |
| `/var/log/supervisord.log` | Supervisor 主日志 |
| `/var/log/acme.sh.log` | 证书申请/续期日志 |

### 5.4 快速运维命令汇总

```bash
# 容器状态
docker compose ps
docker exec sb-xray supervisorctl status

# 重启所有服务
docker compose restart

# 仅重启某个核心
docker exec sb-xray supervisorctl restart xray
docker exec sb-xray supervisorctl restart sing-box
docker exec sb-xray supervisorctl restart nginx

# 查看实时配置
docker exec sb-xray /scripts/show-config.sh

# 进入容器终端
docker exec -it sb-xray bash
```
