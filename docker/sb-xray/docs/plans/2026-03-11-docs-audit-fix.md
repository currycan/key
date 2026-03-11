# 文档过时内容修复 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复 docs/ 下两类过时内容：① `02-protocols-and-security.md` 中 MLKEM 参数格式错误（关键字段 `600s`→`0rtt`、`SEED`→`CLIENT`，共 6 处）；② `05-build-release.md` 中组件默认版本表与 `Dockerfile` 实际值不一致（5 个版本号）。

**Architecture:** 纯文档修改，无代码变更。先修复 Critical 问题（MLKEM），再修复 Outdated 问题（版本号）。每个 Task 独立提交，便于 review 和回滚。

**Tech Stack:** Markdown, `grep`/`sed` 验证，`bash -c` 交叉校验 Dockerfile 与文档

---

## 背景：审计发现问题汇总

| 严重性 | 文档 | 问题 | 代码实际值 |
|:---|:---|:---|:---|
| **Critical** | `02-protocols-and-security.md:258` | URI 示例用 `600s` | `0rtt`（show-config.sh:112） |
| **Critical** | `02-protocols-and-security.md:406` | 配置字符串示例用 `600s` | `0rtt` |
| **Critical** | `02-protocols-and-security.md:414` | 解析表 `600s` = "Ticket 有效期" | `0rtt` = 0-RTT 模式标识符 |
| **Critical** | `02-protocols-and-security.md:415` | 变量名 `XRAY_MLKEM768_SEED` | `XRAY_MLKEM768_CLIENT`（entrypoint.sh:1037） |
| **Critical** | `02-protocols-and-security.md:475` | 表格"MLKEM Seed + 临时密钥" | 变量为 `CLIENT` 非 `SEED` |
| **Critical** | `02-protocols-and-security.md:487` | json 注释 `600s.${SEED}` | `0rtt.${CLIENT}` |
| **Outdated** | `05-build-release.md:204` | Mihomo `1.19.20` | `1.19.0`（Dockerfile:27） |
| **Outdated** | `05-build-release.md:206` | Sub-Store 前端 `2.16.17` | `2.16.13`（Dockerfile:41） |
| **Outdated** | `05-build-release.md:207` | Sub-Store 后端 `2.21.28` | `2.21.21`（Dockerfile:35） |
| **Outdated** | `05-build-release.md:208` | S-UI `1.3.10` | `1.3.9`（Dockerfile:58） |
| **Outdated** | `05-build-release.md:212` | Sing-box `1.12.22` | `1.12.21`（Dockerfile:134） |
| **Outdated** | `05-build-release.md:238` | 示例 `SING_BOX_VERSION=1.12.22` | `1.12.21` |

---

## Task 1：修复 Doc 02 MLKEM 参数格式（Critical）

**Files:**
- Modify: `docs/02-protocols-and-security.md`（行 258、406、414、415、475、487）

### 背景知识

`entrypoint.sh:1037` 的真实命令：
```bash
ensure_key_pair "MLKEM768" "xray mlkem768" "XRAY_MLKEM768_SEED" "XRAY_MLKEM768_CLIENT"
#              ↑ 内部标记   ↑ 生成命令        ↑ 服务端密钥变量      ↑ 客户端配置变量
```

`show-config.sh:112` 中 URI 的真实格式：
```
encryption=mlkem768x25519plus.native.0rtt.${XRAY_MLKEM768_CLIENT}
```

字段解析：
- 第 3 段 `0rtt`：0-RTT 握手模式标识符（非票证有效期）
- 第 4 段 `${XRAY_MLKEM768_CLIENT}`：客户端配置密钥（非服务端 Seed）

**Step 1: 确认当前错误位置**

```bash
grep -n "600s\|MLKEM768_SEED" docs/02-protocols-and-security.md
```

期望输出（至少 6 行）：
```
258:  vless://...encryption=mlkem768x25519plus.native.600s.${XRAY_MLKEM768_SEED}...
406:mlkem768x25519plus.native.600s.${XRAY_MLKEM768_SEED}
414:| `600s` | Ticket 有效期 | 随机下发 300-600 秒的 ticket 以便 0-RTT 复用 |
415:| `${XRAY_MLKEM768_SEED}` | 种子密钥 | 服务端预共享密钥，用于初始化 KEM |
475:| **第 3 层** | MLKEM+X25519 | 客户端 ↔ Xray 核心 | MLKEM Seed + 临时密钥 |
487:"decryption": "mlkem768x25519plus.native.600s.${SEED}"  // 防护 Nginx 中间节点
```

**Step 2: 修改 §1.6.1 URI 示例（第 258 行）**

将：
```
  vless://${XRAY_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=mlkem768x25519plus.native.600s.${XRAY_MLKEM768_SEED}&security=reality&sni=${DEST_HOST}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=/${XRAY_URL_PATH}-xhttp&mode=auto#🇺🇸 Xhttp+Reality直连 ✈ ${NODE_NAME}${NODE_SUFFIX}
```
改为：
```
  vless://${XRAY_UUID}@${DOMAIN}:${LISTENING_PORT}?encryption=mlkem768x25519plus.native.0rtt.${XRAY_MLKEM768_CLIENT}&security=reality&sni=${DEST_HOST}&fp=chrome&pbk=${XRAY_REALITY_PUBLIC_KEY}&sid=${XRAY_REALITY_SHORTID}&type=xhttp&path=/${XRAY_URL_PATH}-xhttp&mode=auto#🇺🇸 Xhttp+Reality直连 ✈ ${NODE_NAME}${NODE_SUFFIX}
```

**Step 3: 修改 §2.4 配置字符串示例（第 406 行）**

将：
```
mlkem768x25519plus.native.600s.${XRAY_MLKEM768_SEED}
```
改为：
```
mlkem768x25519plus.native.0rtt.${XRAY_MLKEM768_CLIENT}
```

**Step 4: 修改 §2.4 解析表（第 414-415 行）**

将：
```markdown
| `600s` | Ticket 有效期 | 随机下发 300-600 秒的 ticket 以便 0-RTT 复用 |
| `${XRAY_MLKEM768_SEED}` | 种子密钥 | 服务端预共享密钥，用于初始化 KEM |
```
改为：
```markdown
| `0rtt` | 握手模式 | 启用 0-RTT 快速握手，复用 ticket 免去完整 1-RTT 协商 |
| `${XRAY_MLKEM768_CLIENT}` | 客户端密钥 | 客户端配置密钥（`xray mlkem768` 命令的 CLIENT 输出），与服务端 SEED 配对 |
```

**Step 5: 修改 §2.7 多层加密表（第 475 行）**

将：
```markdown
| **第 3 层** | MLKEM+X25519 | 客户端 ↔ Xray 核心 | MLKEM Seed + 临时密钥 |
```
改为：
```markdown
| **第 3 层** | MLKEM+X25519 | 客户端 ↔ Xray 核心 | MLKEM Client 密钥 + 临时密钥 |
```

**Step 6: 修改 §2.8 配置策略代码注释（第 487 行）**

将：
```json
"decryption": "mlkem768x25519plus.native.600s.${SEED}"  // 防护 Nginx 中间节点
```
改为：
```json
"decryption": "mlkem768x25519plus.native.0rtt.${XRAY_MLKEM768_CLIENT}"  // 防护 Nginx 中间节点
```

**Step 7: 验证所有 `600s` 和 `MLKEM768_SEED` 已清除**

```bash
grep -n "600s\|MLKEM768_SEED" docs/02-protocols-and-security.md
```

期望：**无输出**（所有旧格式已替换）

**Step 8: 验证新格式已写入**

```bash
grep -n "0rtt\|MLKEM768_CLIENT" docs/02-protocols-and-security.md
```

期望：至少 6 行匹配

**Step 9: 提交**

```bash
git add docs/02-protocols-and-security.md
git commit -m "docs: 修正 MLKEM 参数格式 600s→0rtt，SEED→CLIENT（共 6 处）"
```

---

## Task 2：修复 Doc 05 组件默认版本表（Outdated）

**Files:**
- Modify: `docs/05-build-release.md`（行 204、206、207、208、212、238）

### 版本对照（以 Dockerfile 为准）

| 组件 | 文档旧值 | Dockerfile 实际值 | ARG 变量名 |
|:---|:---|:---|:---|
| Mihomo | 1.19.20 | **1.19.0** | `MIHOMO_VERSION`（行 27） |
| Sub-Store 前端 | 2.16.17 | **2.16.13** | `SUB_STORE_FRONTEND_VERSION`（行 41） |
| Sub-Store 后端 | 2.21.28 | **2.21.21** | `SUB_STORE_BACKEND_VERSION`（行 35） |
| S-UI | 1.3.10 | **1.3.9** | `SUI_VERSION`（行 58） |
| Sing-box | 1.12.22 | **1.12.21** | `SING_BOX_VERSION`（行 134） |

注：Dufs（0.45.0）、Cloudflared（2026.2.0）、3x-ui（2.8.10）已正确，**不改动**。

**Step 1: 确认 Dockerfile 实际版本**

```bash
grep -E "ARG (MIHOMO|SUB_STORE_BACKEND|SUB_STORE_FRONTEND|SUI|SING_BOX)_VERSION" Dockerfile
```

期望输出：
```
ARG MIHOMO_VERSION="1.19.0"
ARG SUB_STORE_BACKEND_VERSION="2.21.21"
ARG SUB_STORE_FRONTEND_VERSION="2.16.13"
ARG SUI_VERSION="1.3.9"
ARG SING_BOX_VERSION="1.12.21"
```

**Step 2: 修改版本表（行 204-212）**

将版本表中的 5 行：
```markdown
| Mihomo | 1.19.20 | `MIHOMO_VERSION` |
...
| Sub-Store 前端 | 2.16.17 | `SUB_STORE_FRONTEND_VERSION` |
| Sub-Store 后端 | 2.21.28 | `SUB_STORE_BACKEND_VERSION` |
| S-UI | 1.3.10 | `SUI_VERSION` |
...
| Sing-box | 1.12.22 | `SING_BOX_VERSION` |
```
改为：
```markdown
| Mihomo | 1.19.0 | `MIHOMO_VERSION` |
...
| Sub-Store 前端 | 2.16.13 | `SUB_STORE_FRONTEND_VERSION` |
| Sub-Store 后端 | 2.21.21 | `SUB_STORE_BACKEND_VERSION` |
| S-UI | 1.3.9 | `SUI_VERSION` |
...
| Sing-box | 1.12.21 | `SING_BOX_VERSION` |
```

**Step 3: 修改命令行示例（行 238）**

将：
```bash
  --build-arg SING_BOX_VERSION=1.12.22 \
```
改为：
```bash
  --build-arg SING_BOX_VERSION=1.12.21 \
```

**Step 4: 验证旧版本号已清除**

```bash
grep -n "1\.19\.20\|2\.16\.17\|2\.21\.28\|1\.3\.10\|1\.12\.22" docs/05-build-release.md
```

期望：**无输出**

**Step 5: 交叉验证文档与 Dockerfile 一致**

```bash
# 逐一确认 5 个版本号一致
for pair in "MIHOMO_VERSION:1.19.0" "SUB_STORE_BACKEND_VERSION:2.21.21" "SUB_STORE_FRONTEND_VERSION:2.16.13" "SUI_VERSION:1.3.9" "SING_BOX_VERSION:1.12.21"; do
    key="${pair%%:*}"; val="${pair##*:}"
    docker_val=$(grep "ARG $key=" Dockerfile | grep -o '"[^"]*"' | tr -d '"')
    doc_val=$(grep "$val" docs/05-build-release.md | head -1)
    echo "$key: Dockerfile=$docker_val | doc_match=$([ -n "$doc_val" ] && echo YES || echo NO)"
done
```

期望：5 个 `doc_match=YES`

**Step 6: 提交**

```bash
git add docs/05-build-release.md
git commit -m "docs: 同步组件默认版本至 Dockerfile 实际值（5 个版本号）"
```

---

## 验收标准

- [ ] `grep "600s\|MLKEM768_SEED" docs/02-protocols-and-security.md` → 无输出
- [ ] `grep "0rtt\|MLKEM768_CLIENT" docs/02-protocols-and-security.md` → ≥ 6 行
- [ ] `grep "1\.19\.20\|2\.16\.17\|2\.21\.28\|1\.3\.10\|1\.12\.22" docs/05-build-release.md` → 无输出
- [ ] Doc 05 版本表中 5 个版本号与 `Dockerfile` ARG 行完全一致
- [ ] Doc 02 §2.4 解析表的 `0rtt` 行描述语义正确（握手模式，非 Ticket 有效期）
