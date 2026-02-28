---
name: 模板与配置管理
description: 模板目录结构、变量替换机制、各核心组件的配置模板说明和客户端模板管理
---

# 模板与配置管理

## 模板引擎机制

项目使用 `envsubst` 作为模板渲染引擎，配合 `apply_tpl()` 函数（位于 `scripts/entrypoint.sh` 第 666-685 行）实现自动化配置生成。

### apply_tpl() 工作流程

```
1. 读取模板源文件
2. 收集当前所有环境变量名列表 (env | grep -v '^_' | ...)
3. 使用 envsubst 替换所有 ${VAR} 占位符
4. 如果目标是 .json 文件，自动执行 jq 格式校验
5. 校验通过则写入目标路径，失败则日志告警并强制覆盖
```

### 变量占位符语法

- 使用 `${VARIABLE_NAME}` 格式（标准 Shell 环境变量风格）
- `envsubst` 只替换已在环境中 `export` 的变量
- 未定义的变量会被替换为空字符串
- 特殊变量 `${RANDOM_NUM}` 在 `createConfig()` 中动态生成

---

## 模板目录结构

### templates/xray/ — Xray 核心配置

| 文件 | 用途 | 关键变量 |
|:---|:---|:---|
| `xr.json` | Xray 主配置文件 (路由/日志/DNS/出站) | `${CUSTOM_OUTBOUNDS}`, `${NETFLIX_OUT}`, `${CHATGPT_OUT}` 等路由标签 |
| `01_reality_inbounds.json` | Reality (VLESS+Vision) 入站 | `${XRAY_REALITY_PRIVATE_KEY}`, `${XRAY_REALITY_SHORTID}`, `${DEST_HOST}`, `${XRAY_UUID}` |
| `02_xhttp_inbounds.json` | XHTTP 入站 | `${XRAY_URL_PATH}`, `${XRAY_UUID}`, `${XRAY_MLKEM768_SEED}` |
| `03_vmess_ws_inbounds.json` | VMess + WebSocket 入站 | `${XRAY_URL_PATH}`, `${XRAY_UUID}` |

### templates/sing-box/ — Sing-box 核心配置

| 文件 | 用途 | 关键变量 |
|:---|:---|:---|
| `sb.json` | Sing-box 主配置文件 (路由/DNS/出站) | `${SB_CUSTOM_OUTBOUNDS}`, 各路由标签 |
| `01_hysteria2_inbounds.json` | Hysteria2 入站 | `${PORT_HYSTERIA2}`, `${PASSWORD}`, `${SSL_PATH}` |
| `02_tuic_inbounds.json` | TUIC 入站 | `${PORT_TUIC}`, `${SB_UUID}`, `${PASSWORD}`, `${SSL_PATH}` |
| `03_anytls_inbounds.json` | AnyTLS 入站 | `${PORT_ANYTLS}`, `${PASSWORD}`, `${SSL_PATH}` |

### templates/nginx/ — Nginx 配置

| 文件 | 用途 |
|:---|:---|
| `nginx.conf` | Nginx 主配置文件 |
| `http.conf` | HTTP 虚拟主机配置 (反向代理、路径分发、伪装站) |
| `tcp.conf` | TCP Stream 配置 (Hysteria2/TUIC 端口转发) |
| `network_internal.conf` | 内网地址段定义 (直接复制，不渲染) |

### templates/proxies/ — 代理节点输出

| 文件 | 用途 |
|:---|:---|
| `all` | 包含所有协议节点的完整输出模板 |
| `clash` | Clash/Mihomo 格式的节点模板 |
| `stash` | Stash 格式的节点模板 |
| `surge` | Surge 格式的节点模板 |

### templates/client_template/ — 客户端订阅模板

| 文件 | 策略模式 | 说明 |
|:---|:---|:---|
| `OneSmartPro.yaml` | Mihomo Smart 模式 | 智能策略组，自动测速选取最优节点 |
| `FallBackPro.yaml` | Mihomo Fallback 模式 | 回退策略组，按优先级依次尝试 |
| `surge.conf` | Surge 配置 | 完整的 Surge 客户端配置 |
| `0-readme.md` | 说明文档 | 模板使用说明 |

### templates/providers/ — 订阅源 Provider

| 文件 | 用途 |
|:---|:---|
| `providers.yaml` | Proxy Provider 配置模板，使用 YAML 锚点 `*BaseProvider` |

### templates/supervisord/ — 进程管理

| 文件 | 用途 |
|:---|:---|
| `supervisord.conf` | Supervisord 主配置 |
| `daemon.ini` | 各进程（xray/sing-box/nginx/x-ui/s-ui/dufs 等）的管理配置 |

### templates/dufs/ — 文件服务

| 文件 | 用途 |
|:---|:---|
| `conf.yml` | Dufs 配置文件 |

---

## 模板渲染调用链

`createConfig()` 函数（`entrypoint.sh` 第 661-700 行）按以下顺序渲染所有模板：

```
1. supervisord.conf → /etc/supervisord.conf
2. daemon.ini → /etc/supervisor.d/daemon.ini
3. nginx.conf → /etc/nginx/nginx.conf
4. network_internal.conf → 直接复制 (不渲染)
5. http.conf → /etc/nginx/conf.d/http.conf
6. tcp.conf → /etc/nginx/stream.d/tcp.conf
7. dufs/conf.yml → ${WORKDIR}/dufs/conf.yml
8. providers.yaml → ${WORKDIR}/providers
9. xray/*.json → ${WORKDIR}/xray/ (循环渲染)
10. sing-box/*.json → ${WORKDIR}/sing-box/ (循环渲染)
```

---

## 修改指南

### 添加新的代理协议

1. 在 `templates/xray/` 或 `templates/sing-box/` 下新建 `NN_<protocol>_inbounds.json` 模板
2. 使用 `${VAR}` 引用需要的环境变量
3. 在 `entrypoint.sh` 的 `analyze_base_env()` 中通过 `ensure_var` 注册新端口等变量
4. 模板会被 `createConfig()` 中的 `for` 循环自动发现和渲染
5. 更新 `templates/proxies/` 中的节点输出模板
6. 更新 `templates/nginx/tcp.conf` 添加端口转发（如需）

### 修改客户端模板

1. 编辑 `templates/client_template/` 下的对应文件
2. 变量使用 `{变量名}` 格式（由 `build_client_and_server_configs` 函数中的 `sed` 替换）
3. 注意客户端模板的变量格式与服务端模板不同，服务端使用 `${VAR}`，客户端使用花括号 `{VAR}`

### 新增环境变量到模板

1. 确保变量在 `entrypoint.sh` 中通过 `ensure_var` 或 `export` 到环境
2. 在模板文件中使用 `${VAR_NAME}` 引用
3. `apply_tpl` 会自动识别所有已导出的环境变量
