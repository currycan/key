# Hysteria2/TUIC 端口跳跃与 UDP 443 伪装设计

## 目标

降低 ISP 高峰期（北京时间 21:00+）对 Hysteria2 和 TUIC UDP 流量的识别与限速概率。通过将监听端口改为知名端口（伪装 QUIC）并启用端口跳跃（port hopping），使 UDP 流量特征接近正常 HTTP/3 行为，增加 ISP 封锁成本。

## 架构

```
客户端 ──UDP──► 宿主机 20000-37999 或 443
                    │
              iptables DNAT (自定义 chain: SB_XRAY_HOP)
                    │
                    ▼
          sing-box 监听 UDP 443 (Hysteria2)

客户端 ──UDP──► 宿主机 38000-48000 或 8443
                    │
              iptables DNAT
                    │
                    ▼
          sing-box 监听 UDP 8443 (TUIC)
```

## 端口分布

```
UDP 443            ← Hysteria2 实际监听（伪装 QUIC）
UDP 8443           ← TUIC 实际监听（HTTPS 备用端口）
20000-37999        ← HY2_HOP_RANGE（18000 个端口，DNAT → 443）
38000-48000        ← TUIC_HOP_RANGE（10001 个端口，DNAT → 8443）
60000-65000        ← AnyTLS / XUI / DUFS 随机端口
```

## 新增环境变量

| 变量 | 默认值 | 说明 |
|:---|:---|:---|
| `HY2_HOP_RANGE` | `20000-37999` | Hysteria2 端口跳跃范围，空值=禁用 |
| `TUIC_HOP_RANGE` | `38000-48000` | TUIC 端口跳跃范围，空值=禁用 |

## 移除环境变量

| 变量 | 原用途 | 替代 |
|:---|:---|:---|
| `PORT_HYSTERIA2` | hy2 随机高位端口 | 固定 443 |
| `PORT_TUIC` | TUIC 随机高位端口 | 固定 8443 |

## 变更文件清单

| 文件 | 改动 |
|:---|:---|
| `scripts/entrypoint.sh` | ① 新增 `HY2_HOP_RANGE`/`TUIC_HOP_RANGE` 环境变量处理 ② iptables 规则注入（自定义 chain） ③ `generateRandomStr port` 范围改为 60000-65000 ④ 移除 `PORT_HYSTERIA2`/`PORT_TUIC` 生成 ⑤ 旧变量迁移清理 |
| `templates/sing-box/01_hysteria2_inbounds.json` | `listen_port` 改为 `443` |
| `templates/sing-box/02_tuic_inbounds.json` | `listen_port` 改为 `8443` |
| `scripts/show-config.sh` | hy2 URI 端口→443 + `mport=`；TUIC URI 端口→8443 + `mport=` |
| `templates/proxies/all` | hy2 port→443 + `ports:` 字段；TUIC port→8443 + `ports:` |
| `templates/proxies/clash` | 同上 |
| `templates/client_template/OneSmartPro.yaml` | hy2/TUIC 节点 port + ports 更新 |
| `templates/client_template/FallBackPro.yaml` | 同上 |
| `templates/client_template/stash.yaml` | 同上（如有 hy2/TUIC 节点） |
| `docker-compose.yml` | 取消 `cap_add: NET_ADMIN` 注释 |
| `docs/02-protocols-and-security.md` | §1.2 Hysteria2 + §1.3 TUIC 补充端口跳跃说明 |

## iptables 规则设计

使用自定义 chain 管理规则，避免重启时堆积：

```bash
# 创建或清空自定义 chain
iptables -t nat -N SB_XRAY_HOP 2>/dev/null || iptables -t nat -F SB_XRAY_HOP
# 挂载到 PREROUTING（幂等）
iptables -t nat -C PREROUTING -j SB_XRAY_HOP 2>/dev/null || \
    iptables -t nat -A PREROUTING -j SB_XRAY_HOP

# Hysteria2 端口跳跃（仅 HY2_HOP_RANGE 非空时）
iptables -t nat -A SB_XRAY_HOP -p udp --dport 20000:37999 -j DNAT --to-destination :443

# TUIC 端口跳跃（仅 TUIC_HOP_RANGE 非空时）
iptables -t nat -A SB_XRAY_HOP -p udp --dport 38000:48000 -j DNAT --to-destination :8443
```

**nftables 兼容**：检测 `iptables` 是否可用，不可用时使用 `nft` 等效命令。

**清理时机**：entrypoint.sh 启动阶段，sing-box 启动前。

## 客户端 URI 格式

### Hysteria2

```
hysteria2://${SB_UUID}@${DOMAIN}:443/?sni=${DOMAIN}&alpn=h3&mport=443,20000-37999#...
```

### TUIC

```
tuic://${SB_UUID}:${SB_UUID}@${DOMAIN}:8443?alpn=h3&congestion_control=bbr&mport=8443,38000-48000#...
```

`mport=` 格式：`基础端口,跳跃范围起-跳跃范围止`。HOP_RANGE 为空时省略 `mport=`，退化为普通单端口。

### Clash 代理模板

```yaml
# Hysteria2
  port: 443
  ports: 443,20000-37999

# TUIC
  port: 8443
  ports: 8443,38000-48000
```

## 向后兼容

### 现有部署迁移

- `PORT_HYSTERIA2`/`PORT_TUIC` 已缓存在 `ENV_FILE` 中
- entrypoint.sh 检测到旧变量时从 `ENV_FILE` 中删除并忽略
- 日志输出 `[迁移] PORT_HYSTERIA2/PORT_TUIC 已废弃，hy2→443, TUIC→8443`

### 随机端口

- 已缓存的 AnyTLS/XUI/DUFS 端口（32000-38000 旧范围）保持不变
- 仅新部署或重新生成时使用 60000-65000

### 禁用端口跳跃

- `HY2_HOP_RANGE=""` → 不注入 hy2 iptables 规则，不生成 `mport=`
- `TUIC_HOP_RANGE=""` → 同理
- 退化为普通单端口模式（443 / 8443），仍享受知名端口伪装效果

## 不改动

- TUIC 协议参数（congestion_control、zero_rtt 等）
- AnyTLS 配置
- Nginx / Xray 所有配置
- 客户端策略组结构（OneSmartPro smart / FallBackPro fallback）
