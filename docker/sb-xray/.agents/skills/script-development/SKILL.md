---
name: Shell 脚本开发规范
description: entrypoint.sh 架构说明、编码规范、环境变量缓存系统和调试指南
---

# Shell 脚本开发规范

## 脚本文件概览

| 脚本 | 行数 | 职责 |
|:---|:---|:---|
| `scripts/entrypoint.sh` | 1073 | 核心入口脚本，系统启动流水线 |
| `scripts/check_ip_type.sh` | 564 | IP 质量体检 (ASN/流媒体/风控检测) |
| `scripts/show-config.sh` | 160 | 展示生成的配置与订阅链接 |
| `scripts/geo_update.sh` | ~50 | GeoIP/Geosite 数据库更新 |
| `scripts/stop-supervisor.sh` | ~15 | Supervisord 优雅停止 |

---

## entrypoint.sh 函数索引

### 扇区一：全局能力层 (1-172 行)

| 函数 | 行号 | 用途 |
|:---|:---|:---|
| `log()` | 34-44 | 统一日志输出 (INFO/WARN/ERROR/DEBUG + 颜色 + 时间戳) |
| `log_summary_box()` | 47-63 | 信息汇总仪表盘展示 |
| `show_progress()` / `end_progress()` | 66-71 | 进度条显示/清除 |
| `http_probe()` | 74-84 | HTTP 探测 (HEAD 请求，返回状态码) |
| `http_trace_url()` | 87-92 | URL 重定向终点追踪 |
| `generateRandomStr()` | 95-110 | 随机字符串/端口/UUID/密码生成器 |
| `ensure_var()` | 113-135 | **核心：环境变量缓存系统** |
| `ensure_key_pair()` | 138-161 | 密钥对生成与缓存 |
| `checkRequiredEnv()` | 163-172 | 必填环境变量断言校验 |

### 扇区二：网络探测 (175-557 行)

| 函数 | 用途 |
|:---|:---|
| `detect_ip_strategy_api()` | IPv4/IPv6 双栈检测 |
| `check_ip_type()` | ASN 类型检测 (isp/hosting/business) |
| `get_geo_info()` | GeoIP 地理区域获取 |
| `check_brutal_status()` | TCP_Brutal 内核模块检测 |
| `get_fallback_proxy()` | 代理回退寻址 |
| `check_netflix_access()` | Netflix 解锁检测 |
| `check_disney_access()` | Disney+ 解锁检测 |
| `check_youtube_access()` | YouTube 连通检测 |
| `check_social_media_access()` | 社交媒体 (Telegram/Twitter) 连通检测 |
| `check_tiktok_access()` | TikTok 区域风控检测 |
| `check_chatgpt_access()` | ChatGPT WAF 检测 |
| `check_claude_access()` | Claude 重定向检测 |
| `check_gemini_access()` | Gemini 解锁 (支持手动覆盖) |
| `speed_test()` | 下载测速 (返回 Mbps) |
| `analyze_base_env()` | 基础环境变量初始化入口 |
| `analyze_ai_routing_env()` | AI/流媒体路由变量初始化入口 |

### 扇区三：证书管理 (559-612 行)

| 函数 | 用途 |
|:---|:---|
| `issueCertificate()` | ACME 证书申请/续期/安装 (支持多域名多 DNS 提供商) |

### 扇区四：服务端配置 (615-700 行)

| 函数 | 用途 |
|:---|:---|
| `process_single_isp()` | 构建 ISP 代理出站 JSON (Xray + Sing-box 双格式) |
| `createConfig()` | 全量模板渲染总入口 |
| `apply_tpl()` | 内嵌模板渲染引擎 (envsubst + jq 校验) |

### 扇区五：客户端输出 (703-964 行)

| 函数 | 用途 |
|:---|:---|
| `evaluate_isp_and_build_client_config()` | ISP 代理测速评估 |
| `apply_isp_routing_logic()` | ISP 路由策略决策 (核心选路逻辑) |
| `run_speed_tests_if_needed()` | 测速总调度 (带缓存跳过机制) |
| `build_client_and_server_configs()` | 客户端配置文件生成 |
| `generateProxyProvidersConfig()` | Proxy Provider 配置生成 |

### 主控 (970-1073 行)

| 函数 | 用途 |
|:---|:---|
| `main_init()` | 12步启动流水线总入口 |

---

## 环境变量缓存系统

### ensure_var() 工作原理

```bash
ensure_var "KEY" "command to generate value"
# 或
ensure_var "KEY" --no-persist "command"
```

**逻辑流程：**
1. 检查持久化文件 `/.env/sb-xray` 中是否存在 `export KEY=...`
2. **命中缓存**：跳过计算，直接使用缓存值
3. **未命中缓存**：
   - 执行指定命令获取值
   - `export` 到当前环境
   - 如果不是 `--no-persist`，写入持久化文件

### 两级持久化文件

| 文件 | 用途 | 清除条件 |
|:---|:---|:---|
| `/.env/sb-xray` | 核心参数 (UUID/端口/密钥等)，长期不变 | 需手动删除 |
| `/.env/status` | 运行时状态 (ISP_TAG/流媒体检测结果)，可能随网络变化 | 删除可触发重新检测 |
| `/.env/secret` | 远端解密的敏感配置 | 拉取后长期缓存 |

---

## 编码规范

### 基本要求

```bash
#!/usr/bin/env bash
set -eou pipefail  # 严格模式：任何错误立即退出
```

### 日志输出规范

```bash
log INFO  "正常流程信息"     # 绿色
log WARN  "需要注意的警告"    # 黄色
log ERROR "严重错误，可能导致退出"  # 红色
log DEBUG "调试信息"          # 青色
```

- 所有日志使用中文
- 日志自动附带时间戳 `[YYYY-MM-DD HH:MM:SS]`
- 日志输出到 stderr (`>&2`)

### 颜色变量

```bash
# 仅在 TTY 环境下启用颜色
RED='\\033[1;31m'; GREEN='\\033[1;32m'; YELLOW='\\033[1;33m'; CYAN='\\033[1;36m'; NC='\\033[0m'
BOLD='\\033[1m'; RESET_BOLD='\\033[22m'
```

### 函数命名

- 使用 `camelCase` 或 `snake_case`（项目中两种风格混用）
- 流媒体检测函数统一命名：`check_<service>_access()`
- 返回值统一为 `"direct"` 或代理标签名

### 流媒体/AI 检测函数模式

所有 `check_*_access()` 函数遵循统一的三层判断：

```bash
check_xxx_access() {
    # 第一层：地域黑名单 (硬封锁地区直接走代理)
    if [[ "${GEOIP_INFO:-}" =~ (香港|中国|...) ]]; then
        get_fallback_proxy; return
    fi
    # 第二层：住宅 IP 优先直连
    if [[ "${IP_TYPE:-}" == "isp" ]]; then
        echo "direct"; return
    fi
    # 第三层：HTTP 探测实际可达性
    local check_rs=$(http_probe "https://xxx")
    if [[ "$check_rs" =~ ^(2|3) ]]; then
        echo "direct"
    else
        get_fallback_proxy
    fi
}
```

---

## 调试指南

### 查看当前环境变量

```bash
# 进入容器
docker exec -it sb-xray bash

# 查看持久化变量
cat /.env/sb-xray

# 查看运行状态变量
cat /.env/status

# 查看生成的配置
/scripts/show-config.sh
# 或快捷命令
show
```

### 重新触发检测

```bash
# 清除状态缓存，重启后将重新检测流媒体/AI解锁和测速
rm -f /.env/status
docker restart sb-xray

# 完全重置所有缓存 (包括 UUID 等，会导致订阅链接变化!)
rm -f /.env/sb-xray /.env/status
docker restart sb-xray
```

### IP 质量体检

```bash
# 在容器内运行完整 IP 体检
/scripts/check_ip_type.sh

# 仅检测 IPv4
/scripts/check_ip_type.sh -4

# 仅检测 IPv6
/scripts/check_ip_type.sh -6
```

### 常见调试方法

1. **模板渲染问题**: 检查 `docker logs sb-xray` 中 `apply_tpl` 的 DEBUG 日志
2. **环境变量未生效**: 确认变量已通过 `export` 或写入持久化文件
3. **证书问题**: 容器内运行 `acme.sh --list` 查看证书状态
4. **JSON 格式错误**: `apply_tpl` 会自动用 `jq` 校验 JSON 文件
