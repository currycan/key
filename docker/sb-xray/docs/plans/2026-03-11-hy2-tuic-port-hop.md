# Hysteria2/TUIC 端口跳跃与 UDP 443 伪装 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move Hysteria2 to UDP 443 and TUIC to UDP 8443, add iptables-based port hopping (DNAT), and update all client configs/URIs to support `mport=` / `ports:` fields.

**Architecture:** Container runs with `NET_ADMIN` capability. On startup, entrypoint.sh creates a custom iptables chain `SB_XRAY_HOP` that DNATs hop ranges to the actual listening ports. Clients connect on any port in the hop range; DNAT redirects to sing-box.

**Tech Stack:** Bash (entrypoint.sh), iptables/nftables, sing-box JSON templates, Clash YAML templates

**Design doc:** `docs/plans/2026-03-11-hy2-tuic-port-hop-design.md`

---

### Task 1: Update sing-box inbound templates (fixed ports)

**Files:**
- Modify: `templates/sing-box/01_hysteria2_inbounds.json:7`
- Modify: `templates/sing-box/02_tuic_inbounds.json:7`

**Step 1: Change Hysteria2 listen_port**

In `templates/sing-box/01_hysteria2_inbounds.json`, replace:
```
"listen_port": ${PORT_HYSTERIA2},
```
with:
```
"listen_port": 443,
```

**Step 2: Change TUIC listen_port**

In `templates/sing-box/02_tuic_inbounds.json`, replace:
```
"listen_port": ${PORT_TUIC},
```
with:
```
"listen_port": 8443,
```

**Step 3: Commit**

```bash
git add templates/sing-box/01_hysteria2_inbounds.json templates/sing-box/02_tuic_inbounds.json
git commit -m "feat: fix hy2/TUIC listen ports to 443/8443 for UDP masquerade"
```

---

### Task 2: Update random port range in generateRandomStr

**Files:**
- Modify: `scripts/entrypoint.sh:133`

**Step 1: Change port range from 32000-38000 to 60000-65000**

In `scripts/entrypoint.sh`, replace:
```bash
        port)     echo $(( RANDOM % 6001 + 32000 )) ;;
```
with:
```bash
        port)     echo $(( RANDOM % 5001 + 60000 )) ;;
```

This changes the range from `32000-38000` to `60000-65000`, avoiding overlap with hop ranges `20000-48000`.

**Step 2: Commit**

```bash
git add scripts/entrypoint.sh
git commit -m "feat: move random port range to 60000-65000 (avoid hop range overlap)"
```

---

### Task 3: Update analyze_base_env — remove old vars, add hop range vars

**Files:**
- Modify: `scripts/entrypoint.sh:920-949`

**Step 1: Remove PORT_HYSTERIA2 and PORT_TUIC from vars array**

In `scripts/entrypoint.sh`, in the `analyze_base_env` function, remove these two lines from the `vars` array:
```bash
        "PORT_HYSTERIA2|generateRandomStr port"
        "PORT_TUIC|generateRandomStr port"
```

**Step 2: Add HY2_HOP_RANGE and TUIC_HOP_RANGE defaults after analyze_base_env**

After the `analyze_base_env` function closing `}`, add a new function:

```bash
# 初始化端口跳跃环境变量（带默认值，空值=禁用）
init_port_hop_env() {
    : "${HY2_HOP_RANGE:=20000-37999}"
    : "${TUIC_HOP_RANGE:=38000-48000}"
    export HY2_HOP_RANGE TUIC_HOP_RANGE
    log INFO "端口跳跃配置: HY2_HOP_RANGE=${HY2_HOP_RANGE:-禁用}, TUIC_HOP_RANGE=${TUIC_HOP_RANGE:-禁用}"
}
```

**Step 3: Commit**

```bash
git add scripts/entrypoint.sh
git commit -m "feat: remove PORT_HYSTERIA2/PORT_TUIC, add hop range env vars"
```

---

### Task 4: Add iptables port hopping injection function

**Files:**
- Modify: `scripts/entrypoint.sh` (add new function near §4 or after init_port_hop_env)

**Step 1: Add setup_port_hopping function**

Add the following function after `init_port_hop_env`:

```bash
# 设置端口跳跃 iptables/nftables DNAT 规则
# 使用自定义 chain SB_XRAY_HOP 管理规则，重启时清空避免堆积
setup_port_hopping() {
    # 检测 iptables 是否可用
    if command -v iptables &>/dev/null && iptables -t nat -L -n &>/dev/null 2>&1; then
        log INFO "使用 iptables 配置端口跳跃..."
        # 创建或清空自定义 chain
        iptables -t nat -N SB_XRAY_HOP 2>/dev/null || iptables -t nat -F SB_XRAY_HOP
        # 挂载到 PREROUTING（幂等）
        iptables -t nat -C PREROUTING -j SB_XRAY_HOP 2>/dev/null || \
            iptables -t nat -A PREROUTING -j SB_XRAY_HOP

        if [[ -n "${HY2_HOP_RANGE}" ]]; then
            local hy2_start="${HY2_HOP_RANGE%-*}"
            local hy2_end="${HY2_HOP_RANGE#*-}"
            iptables -t nat -A SB_XRAY_HOP -p udp --dport "${hy2_start}:${hy2_end}" -j DNAT --to-destination :443
            log INFO "Hysteria2 端口跳跃: UDP ${hy2_start}-${hy2_end} → 443"
        fi

        if [[ -n "${TUIC_HOP_RANGE}" ]]; then
            local tuic_start="${TUIC_HOP_RANGE%-*}"
            local tuic_end="${TUIC_HOP_RANGE#*-}"
            iptables -t nat -A SB_XRAY_HOP -p udp --dport "${tuic_start}:${tuic_end}" -j DNAT --to-destination :8443
            log INFO "TUIC 端口跳跃: UDP ${tuic_start}-${tuic_end} → 8443"
        fi
    elif command -v nft &>/dev/null; then
        log INFO "使用 nftables 配置端口跳跃..."
        # 删除旧表（如存在）后重建
        nft delete table inet sb_xray_hop 2>/dev/null || true
        nft add table inet sb_xray_hop
        nft add chain inet sb_xray_hop prerouting '{ type nat hook prerouting priority dstnat; policy accept; }'

        if [[ -n "${HY2_HOP_RANGE}" ]]; then
            local hy2_start="${HY2_HOP_RANGE%-*}"
            local hy2_end="${HY2_HOP_RANGE#*-}"
            nft add rule inet sb_xray_hop prerouting udp dport "${hy2_start}-${hy2_end}" dnat to :443
            log INFO "Hysteria2 端口跳跃 (nft): UDP ${hy2_start}-${hy2_end} → 443"
        fi

        if [[ -n "${TUIC_HOP_RANGE}" ]]; then
            local tuic_start="${TUIC_HOP_RANGE%-*}"
            local tuic_end="${TUIC_HOP_RANGE#*-}"
            nft add rule inet sb_xray_hop prerouting udp dport "${tuic_start}-${tuic_end}" dnat to :8443
            log INFO "TUIC 端口跳跃 (nft): UDP ${tuic_start}-${tuic_end} → 8443"
        fi
    else
        log WARN "iptables 和 nftables 均不可用，跳过端口跳跃配置"
        log WARN "Hysteria2 仅监听 UDP 443，TUIC 仅监听 UDP 8443（无端口跳跃）"
    fi
}
```

**Step 2: Commit**

```bash
git add scripts/entrypoint.sh
git commit -m "feat: add setup_port_hopping() with iptables/nftables DNAT"
```

---

### Task 5: Add migration logic for old PORT_HYSTERIA2/PORT_TUIC

**Files:**
- Modify: `scripts/entrypoint.sh` (add migration in analyze_base_env or init_port_hop_env)

**Step 1: Add migration code at the start of init_port_hop_env**

Insert at the beginning of `init_port_hop_env`:

```bash
    # 迁移: 清理已废弃的 PORT_HYSTERIA2 / PORT_TUIC
    local env_file="${ENV_FILE}"
    if [[ -f "$env_file" ]]; then
        if grep -qE '^(PORT_HYSTERIA2|PORT_TUIC)=' "$env_file" 2>/dev/null; then
            log INFO "[迁移] PORT_HYSTERIA2/PORT_TUIC 已废弃，hy2→443, TUIC→8443"
            sed_inplace '/^PORT_HYSTERIA2=/d' "$env_file"
            sed_inplace '/^PORT_TUIC=/d' "$env_file"
        fi
    fi
```

**Step 2: Commit**

```bash
git add scripts/entrypoint.sh
git commit -m "feat: migrate deprecated PORT_HYSTERIA2/PORT_TUIC from env file"
```

---

### Task 6: Wire init_port_hop_env and setup_port_hopping into main flow

**Files:**
- Modify: `scripts/entrypoint.sh` (main execution flow, find where analyze_base_env is called)

**Step 1: Find the main flow call site**

Search for where `analyze_base_env` is called in the main execution flow. Add `init_port_hop_env` right after it. Add `setup_port_hopping` before sing-box starts.

Run: `grep -n 'analyze_base_env\|start_singbox\|sing-box run\|setup_port_hopping\|init_port_hop' scripts/entrypoint.sh`

**Step 2: Insert init_port_hop_env call after analyze_base_env call**

After the line that calls `analyze_base_env`, add:
```bash
    init_port_hop_env
```

**Step 3: Insert setup_port_hopping call before sing-box starts**

Before the line that starts sing-box (or in the startup sequence), add:
```bash
    setup_port_hopping
```

**Step 4: Commit**

```bash
git add scripts/entrypoint.sh
git commit -m "feat: wire port hop init and iptables setup into main flow"
```

---

### Task 7: Update show-config.sh URIs

**Files:**
- Modify: `scripts/show-config.sh:105-106`

**Step 1: Update Hysteria2 URI**

In `scripts/show-config.sh`, replace the Hysteria2 link line:
```bash
    local link_hysteria2="hysteria2://${SB_UUID}@${DOMAIN}:${PORT_HYSTERIA2}/?sni=${DOMAIN}&${h2_alpn}#${FLAG_PREFIX}Hysteria2 ✈ ${region_name}${NODE_SUFFIX}"
```
with:
```bash
    local hy2_mport_param=""
    [[ -n "${HY2_HOP_RANGE}" ]] && hy2_mport_param="&mport=443,${HY2_HOP_RANGE%-*}-${HY2_HOP_RANGE#*-}"
    local link_hysteria2="hysteria2://${SB_UUID}@${DOMAIN}:443/?sni=${DOMAIN}&${h2_alpn}${hy2_mport_param}#${FLAG_PREFIX}Hysteria2 ✈ ${region_name}${NODE_SUFFIX}"
```

**Step 2: Update TUIC URI**

Replace the TUIC link line:
```bash
    local link_tuic="tuic://${SB_UUID}:${SB_UUID}@${DOMAIN}:${PORT_TUIC}?${h2_alpn}&congestion_control=bbr#${FLAG_PREFIX}TUIC ✈ ${region_name}${NODE_SUFFIX}"
```
with:
```bash
    local tuic_mport_param=""
    [[ -n "${TUIC_HOP_RANGE}" ]] && tuic_mport_param="&mport=8443,${TUIC_HOP_RANGE%-*}-${TUIC_HOP_RANGE#*-}"
    local link_tuic="tuic://${SB_UUID}:${SB_UUID}@${DOMAIN}:8443?${h2_alpn}&congestion_control=bbr${tuic_mport_param}#${FLAG_PREFIX}TUIC ✈ ${region_name}${NODE_SUFFIX}"
```

**Step 3: Commit**

```bash
git add scripts/show-config.sh
git commit -m "feat: update hy2/TUIC URIs with fixed ports and mport= param"
```

---

### Task 8: Update proxy templates (all, clash, stash, surge)

**Files:**
- Modify: `templates/proxies/all:5,17`
- Modify: `templates/proxies/clash:5,17`
- Modify: `templates/proxies/stash:5,16`
- Modify: `templates/proxies/surge:2,4`

**Step 1: Update `templates/proxies/all`**

For Hysteria2 (line 5), replace:
```yaml
    port: ${PORT_HYSTERIA2}
```
with:
```yaml
    port: 443
    ports: 443,${HY2_HOP_PORTS}
```

For TUIC (line 17), replace:
```yaml
    port: ${PORT_TUIC}
```
with:
```yaml
    port: 8443
    ports: 8443,${TUIC_HOP_PORTS}
```

**Step 2: Update `templates/proxies/clash`** — same changes as `all`

**Step 3: Update `templates/proxies/stash`** — same changes (line 5, line 16)

**Step 4: Update `templates/proxies/surge`**

Replace `${PORT_HYSTERIA2}` → `443` and `${PORT_TUIC}` → `8443` in the surge template. Note: Surge does not support `mport=` / `ports:`, so only the port changes.

**Step 5: Add HY2_HOP_PORTS / TUIC_HOP_PORTS generation in entrypoint.sh**

In `init_port_hop_env`, after the existing code, add:

```bash
    # 生成 Clash ports 字段值（用于模板渲染）
    if [[ -n "${HY2_HOP_RANGE}" ]]; then
        export HY2_HOP_PORTS="${HY2_HOP_RANGE%-*}-${HY2_HOP_RANGE#*-}"
    else
        export HY2_HOP_PORTS=""
    fi
    if [[ -n "${TUIC_HOP_RANGE}" ]]; then
        export TUIC_HOP_PORTS="${TUIC_HOP_RANGE%-*}-${TUIC_HOP_RANGE#*-}"
    else
        export TUIC_HOP_PORTS=""
    fi
```

**Step 6: Handle empty HOP_PORTS in templates**

When `HY2_HOP_RANGE=""`, the `ports:` line would render as `ports: 443,` (trailing comma). We need to handle this in the template rendering. Two options:

Option A: Use conditional rendering in entrypoint.sh (sed to remove `ports:` line when HOP_PORTS is empty).

Option B: Set HY2_HOP_PORTS to just the base port when range is empty so `ports: 443` is still valid.

Choose Option B — simpler. When HOP_RANGE is empty, don't export HOP_PORTS at all, and use `envsubst` behavior (empty string). Then in the proxy template, the `ports:` line becomes `ports: 443,` which is invalid.

Better approach: conditionally include the `ports:` line. In `init_port_hop_env`:

```bash
    # Clash/Stash `ports:` field (full value including base port)
    if [[ -n "${HY2_HOP_RANGE}" ]]; then
        export HY2_PORTS_LINE="    ports: 443,${HY2_HOP_RANGE%-*}-${HY2_HOP_RANGE#*-}"
    else
        export HY2_PORTS_LINE=""
    fi
    if [[ -n "${TUIC_HOP_RANGE}" ]]; then
        export TUIC_PORTS_LINE="    ports: 8443,${TUIC_HOP_RANGE%-*}-${TUIC_HOP_RANGE#*-}"
    else
        export TUIC_PORTS_LINE=""
    fi
```

Then in templates, use:
```yaml
    port: 443
${HY2_PORTS_LINE}
```

When HOP_RANGE is empty, HY2_PORTS_LINE="" renders as a blank line (harmless in YAML).

**Step 7: Commit**

```bash
git add templates/proxies/all templates/proxies/clash templates/proxies/stash templates/proxies/surge scripts/entrypoint.sh
git commit -m "feat: update proxy templates with fixed ports and hop ports field"
```

---

### Task 9: Update client templates (OneSmartPro, FallBackPro, stash)

**Files:**
- Modify: `templates/client_template/OneSmartPro.yaml`
- Modify: `templates/client_template/FallBackPro.yaml`
- Modify: `templates/client_template/stash.yaml`

**Step 1: Check these files**

These templates use `${CLASH_PROXY_PROVIDERS}` and `${CLASH_ISP_PROXIES}` placeholders — they don't contain inline hy2/TUIC node definitions. The proxy node definitions come from `templates/proxies/*` which are already updated in Task 8.

Verify: search for `PORT_HYSTERIA2`, `PORT_TUIC`, `hysteria2`, or `tuic` in client templates.

Run: `grep -rn 'PORT_HYSTERIA2\|PORT_TUIC\|hysteria2\|tuic' templates/client_template/`

If no matches → **no changes needed** for client templates. The proxy definitions flow through `${CLASH_ISP_PROXIES}` from the proxy templates.

**Step 2: Commit (if changes needed)**

```bash
# Only if changes were made
git add templates/client_template/
git commit -m "feat: update client templates for port hopping"
```

---

### Task 10: Uncomment NET_ADMIN in docker-compose.yml

**Files:**
- Modify: `docker-compose.yml:48-50`

**Step 1: Uncomment cap_add section**

Replace:
```yaml
    # cap_add:
    #   - NET_ADMIN
    #   - SYS_MODULE
```
with:
```yaml
    cap_add:
      - NET_ADMIN
```

Note: `SYS_MODULE` is not needed (only needed for loading kernel modules, not for iptables).

**Step 2: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: enable NET_ADMIN capability for iptables port hopping"
```

---

### Task 11: Update documentation

**Files:**
- Modify: `docs/02-protocols-and-security.md` (§1.2 Hysteria2, §1.3 TUIC)

**Step 1: Find §1.2 and §1.3 sections**

Run: `grep -n '§1.2\|§1.3\|Hysteria2\|TUIC' docs/02-protocols-and-security.md | head -20`

**Step 2: Add port hopping documentation to §1.2 Hysteria2**

After the existing Hysteria2 description, add a subsection explaining:
- Listen port fixed to UDP 443 (QUIC masquerade)
- Port hopping via `HY2_HOP_RANGE` env var (default: `20000-37999`)
- iptables DNAT to redirect hop range to 443
- Client `mport=` / `ports:` configuration
- Set `HY2_HOP_RANGE=""` to disable

**Step 3: Add port hopping documentation to §1.3 TUIC**

Same pattern:
- Listen port fixed to UDP 8443
- Port hopping via `TUIC_HOP_RANGE` (default: `38000-48000`)
- DNAT to 8443
- Disable: `TUIC_HOP_RANGE=""`

**Step 4: Commit**

```bash
git add docs/02-protocols-and-security.md
git commit -m "docs: add port hopping documentation for hy2 and TUIC"
```

---

### Task 12: Final integration test

**Step 1: Verify template rendering**

Search for any remaining `${PORT_HYSTERIA2}` or `${PORT_TUIC}` references in the codebase:

Run: `grep -rn 'PORT_HYSTERIA2\|PORT_TUIC' scripts/ templates/ docker-compose.yml docs/`

Expected: No matches in scripts/ or templates/ (only in docs/plans/ design doc and migration code).

**Step 2: Verify no port range overlaps**

Confirm the port layout:
- `20000-37999` → HY2 hop range (DNAT → 443)
- `38000-48000` → TUIC hop range (DNAT → 8443)
- `60000-65000` → random ports (AnyTLS, XUI, DUFS)
- No overlap between ranges.

**Step 3: Review env var exports**

Ensure all new env vars (`HY2_HOP_RANGE`, `TUIC_HOP_RANGE`, `HY2_PORTS_LINE`, `TUIC_PORTS_LINE`) are exported and available to template rendering (envsubst).

**Step 4: Final commit (if any cleanup needed)**

```bash
git add -A
git commit -m "feat: complete hy2/TUIC port hopping implementation"
```
