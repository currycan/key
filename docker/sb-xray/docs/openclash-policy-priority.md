# OpenClash Policy-Priority 优化指南

本文档详细说明如何在 OpenClash 的 Smart 模式下优化 `policy-priority` 配置,实现智能节点选择。

---

## 1. Policy-Priority 基础

### 1.1 什么是 Policy-Priority?

`policy-priority` 是 OpenClash Smart 模式的核心功能,用于定义节点的优先级权重。当多个节点都可用时,OpenClash 会根据权重自动选择最优节点。

### 1.2 工作原理

**权重计算**:
```
节点总分 = Σ(匹配的关键字权重)
```

**示例**:
```yaml
policy-priority: "Reality:10;Hysteria2:9;优:5;中:2;备:1"

节点A: [Reality] 🇭🇰HK|Reality|VLESS|优
匹配: Reality(10) + 优(5) = 15分

节点B: [Reality] 🇭🇰HK|Hysteria2|优
匹配: Hysteria2(9) + 优(5) = 14分

节点C: [Reality] 🇭🇰HK|VMess|中
匹配: 中(2) = 2分

选择顺序: A > B > C
```

---

## 2. 节点命名规则

### 2.1 本项目的节点格式

```
[${NODE_NAME}] ${REGION_INFO}|${PROTOCOL}|${SUFFIX}
```

**实际示例**:
```
[Reality] 🇭🇰HK|Reality|VLESS|优
[Reality] 🇺🇸US|Hysteria2|优
[Reality] 🇯🇵JP|Xhttp|VLESS|中
[Reality] 🇸🇬SG|VMess|备
```

### 2.2 可提取的维度

| 维度 | 示例 | 用途 |
|:---|:---|:---|
| **机场名称** | `[Reality]`, `[Backup]` | 区分不同订阅源 |
| **地区标识** | `🇭🇰HK`, `🇺🇸US` | 地理位置过滤 |
| **协议类型** | `Reality`, `Hysteria2`, `VMess` | 协议性能排序 |
| **质量后缀** | `优`, `中`, `备` | 节点质量分级 |

---

## 3. 优化方案

### 3.1 设计理念

> [!IMPORTANT]
> **职责分离原则**: `filter` 和 `policy-priority` 应该各司其职,避免重复配置
>
> *   **filter**: 负责**筛选节点范围** (基于特性标签,如 家宽/媒体/高速/地区)
> *   **policy-priority**: 负责在筛选结果中进行**多维度排序** (机场/协议/地区偏好/质量)

**错误示例** ❌:
```yaml
家宽-智选:
  filter: "住宅|isp|ISP"           # 已经筛选出家宽节点
  policy-priority: "住宅:15;..."   # 重复匹配,冗余配置
```

**正确示例** ✅:
```yaml
家宽-智选:
  filter: "住宅|isp|ISP"                                    # 筛选家宽节点
  policy-priority: "AllOne:10;Reality:10;香港:8;优:5;..."  # 在家宽节点中按其他维度排序
```

### 3.2 方案对比

| 方案 | 优势 | 劣势 | 推荐度 |
|:---|:---|:---|:---:|
| **硬编码** | 简单直接 | 维护困难,缺乏灵活性 | ⭐⭐ |
| **多维度权重** | 考虑全面 | 配置复杂 | ⭐⭐⭐⭐ |
| **锚点模板化** | 高度复用,易于维护 | 需要理解 YAML 锚点 | ⭐⭐⭐⭐⭐ |

### 3.3 推荐方案: 锚点模板化 + 职责分离

**核心思想**:
1.  使用 YAML 锚点定义可复用的优先级模板
2.  filter 负责筛选,policy-priority 负责排序
3.  避免重复配置,实现真正的多维度智能选择

**优势**:
*   ✅ 一次定义,多处使用
*   ✅ 修改模板即可全局生效
*   ✅ 避免重复配置导致的不一致
*   ✅ 清晰分类不同使用场景
*   ✅ 职责分离,逻辑清晰

---

## 4. 权重配置建议

### 4.1 权重分级表

| 维度 | 关键字 | 权重 | 说明 |
|:---|:---|:---:|:---|
| **机场标识** | `AllOne` | 10 | 主力机场 |
| **特性标签** | `高速` | 10 | 高速线路标识 |
| **协议性能** | `Reality/vless` | 10 | 最高优先级 |
| | `hysteria2` | 8 | 高速协议 |
| | `V2ray/vmess` | 6 | 通用协议 |
| | `tuic/TUIC` | 4 | QUIC协议 |
| | `anytls` | 2 | 基础协议 |
| **地区偏好** | 🇺🇸 美国 | 10 | 最高优先级 |
| | 🇰🇷 韩国 | 8 | 高优先级 |
| | 🇯🇵 日本 | 6 | 中优先级 |
| | 🇸🇬 新加坡 | 4 | 低优先级 |
| | 🇭🇹 香港 | 2 | 最低优先级 |
| **质量后缀** | `优` | 5 | 优质节点 |
| | `中` | 2 | 中等节点 |
| | `备` | 1 | 备用节点 |

### 4.2 模板定义

```yaml
# ==================== Policy-Priority 模板 ====================
# 设计理念: filter 负责筛选节点范围, policy-priority 负责在筛选结果中进行多维度排序
# 协议优先级: Reality/vless(10) > hysteria2(8) > V2ray/vmess(6) > tuic(4) > anytls(2)
# 地区优先级: 美国🇺🇸(10) > 韩国🇰🇷(8) > 日本🇯🇵(6) > 新加坡🇸🇬(4) > 香港🇭🇹(2)
# 特性标签: 高速(10)

# 默认模板 - 适用于地区节点
PolicyDefault:  &PolicyDefault  "AllOne:10;高速:10;Reality:10;vless:10;hysteria2:8;V2ray:6;vmess:6;tuic:4;TUIC:4;anytls:2;优:5;中:2;备:1"

# 家宽模板 - 优先美国/韩国/日本
PolicyISP:      &PolicyISP      "AllOne:10;高速:10;Reality:10;vless:10;hysteria2:8;V2ray:6;vmess:6;tuic:4;TUIC:4;anytls:2;优:5;中:2;备:1;🇺🇸:10;🇰🇷:8;🇯🇵:6;🇸🇬:4;🇭🇹:2"

# 媒体模板 - 优先美国/韩国/日本
PolicyMedia:    &PolicyMedia    "AllOne:10;高速:10;Reality:10;vless:10;hysteria2:8;V2ray:6;vmess:6;tuic:4;TUIC:4;anytls:2;优:5;中:2;备:1;🇺🇸:10;🇰🇷:8;🇯🇵:6;🇸🇬:4;🇭🇹:2"

# 高速模板 - 优先美国/韩国/日本
PolicyFast:     &PolicyFast     "AllOne:10;高速:10;Reality:10;vless:10;hysteria2:8;V2ray:6;vmess:6;tuic:4;TUIC:4;anytls:2;优:5;中:2;备:1;🇺🇸:10;🇯🇵:6;🇰🇷:8;🇸🇬:4;🇭🇹:2"

# 链式代理模板 - 只关注质量
PolicyDialer:   &PolicyDialer   "优:10;中:5;备:1"
```

### 4.3 使用示例

```yaml
proxy-groups:
  # 家宽线路 - 使用家宽模板
  - name: 家宽-智选
    type: smart
    filter: *FilterISP
    include-all: true
    policy-priority: *PolicyISP

  # 媒体线路 - 使用媒体模板
  - name: 媒体-智选
    type: smart
    filter: *FilterMedia
    include-all: true
    policy-priority: *PolicyMedia

  # 香港节点 - 使用默认模板
  - name: 香港-智选
    type: smart
    filter: *FilterHK
    include-all: true
    policy-priority: *PolicyDefault
```

---

## 5. 实际效果示例

### 5.1 节点排序示例

**场景: 家宽-智选** (filter 已筛选出家宽节点)

假设有以下家宽节点:

```
A: [Reality] 🇺🇸US|住宅|Reality|vless|优
B: [Reality] 🇰🇷KR|住宅|hysteria2|优
C: [Reality] 🇯🇵JP|isp|vmess|中
D: [Reality] 🇸🇬SG|ISP|anytls|备
```

**使用 PolicyISP 模板的权重计算**:

```yaml
PolicyISP: "AllOne:10;Reality:10;vless:10;hysteria2:8;V2ray:6;vmess:6;tuic:4;TUIC:4;anytls:2;优:5;中:2;备:1;🇺🇸:10;🇰🇷:8;🇯🇵:6;🇸🇬:4;🇭🇹:2"
```

| 节点 | 匹配关键字 | 权重计算 | 总分 |
|:---|:---|:---|:---:|
| A | `AllOne(10) + Reality(10) + vless(10) + 🇺🇸(10) + 优(5)` | 10+10+10+10+5 | **45** |
| B | `AllOne(10) + Reality(10) + hysteria2(8) + 🇰🇷(8) + 优(5)` | 10+10+8+8+5 | **41** |
| C | `AllOne(10) + Reality(10) + vmess(6) + 🇯🇵(6) + 中(2)` | 10+10+6+6+2 | **34** |
| D | `AllOne(10) + Reality(10) + anytls(2) + 🇸🇬(4) + 备(1)` | 10+10+2+4+1 | **27** |

**最终选择顺序**: A (美国Reality/vless优) > B (韩国Reality/hysteria2优) > C (日本Reality/vmess中) > D (新加坡Reality/anytls备)

**分析**:
- ✅ 美国节点优先 (地区偏好 10分)
- ✅ Reality/vless 协议优先 (协议性能 10分)
- ✅ 优质节点优先 (质量后缀 5分)
- ✅ 多维度权重自动叠加

### 5.2 不同场景的优先级

**场景1: 媒体-智选** (filter 已筛选出媒体节点)

```yaml
PolicyMedia: "AllOne:10;Reality:10;vless:10;hysteria2:8;V2ray:6;vmess:6;tuic:4;TUIC:4;anytls:2;优:5;中:2;备:1;🇺🇸:10;🇰🇷:8;🇯🇵:6;🇸🇬:4;🇭🇹:2"
```

```
节点: [Reality] 🇺🇸US|流媒体|Reality|vless|优
权重: AllOne(10) + Reality(10) + vless(10) + 🇺🇸(10) + 优(5) = 45分

节点: [Reality] 🇰🇷KR|SsrDog|hysteria2|优
权重: AllOne(10) + Reality(10) + hysteria2(8) + 🇰🇷(8) + 优(5) = 41分
```

**优先级**: 美国 > 韩国 (媒体库更全)

**场景2: 高速-智选** (filter 已筛选出高速节点)

```yaml
PolicyFast: "AllOne:10;Reality:10;vless:10;hysteria2:8;V2ray:6;vmess:6;tuic:4;TUIC:4;anytls:2;优:5;中:2;备:1;🇺🇸:10;🇯🇵:6;🇰🇷:8;🇸🇬:4;🇭🇹:2"
```

```
节点: [Reality] 🇺🇸US|高速|Reality|vless|优
权重: AllOne(10) + Reality(10) + vless(10) + 🇺🇸(10) + 优(5) = 45分

节点: [Reality] 🇰🇷KR|[优]|hysteria2|优
权重: AllOne(10) + Reality(10) + hysteria2(8) + 🇰🇷(8) + 优(5) = 41分
```

**优先级**: 美国Reality/vless > 韩国hysteria2 (协议和地区双重优势)

### 5.3 职责分离的优势

**传统方案** (重复配置):
```yaml
家宽-智选:
  filter: "住宅|isp|ISP"
  policy-priority: "住宅:15;isp:15;ISP:15;AllOne:10;..."
  # ❌ 问题: filter 已经筛选出家宽节点,policy-priority 再次匹配 "住宅" 是冗余的
```

**优化方案** (职责分离):
```yaml
家宽-智选:
  filter: "住宅|isp|ISP"                                    # 筛选家宽节点
  policy-priority: "AllOne:10;Reality:10;🇺🇸:10;优:5;..."  # 在家宽节点中按其他维度排序
  # ✅ 优势: filter 负责筛选,policy-priority 负责排序,逻辑清晰
```

---

## 6. 注意事项

### 6.1 关键字匹配规则

> [!IMPORTANT]
> 1.  **子字符串匹配**: `Reality` 会匹配 `[Reality]`, `Reality-Vision` 等
> 2.  **权重叠加**: 多个关键字匹配时,权重会**累加**
> 3.  **大小写敏感**: 关键字区分大小写
> 4.  **正则转义**: 特殊字符需要转义,如 `\\[优\\]` 匹配 `[优]`

### 6.2 常见问题

**Q: 为什么我的节点优先级不生效?**

A: 检查以下几点:
1.  关键字是否正确匹配节点名称
2.  是否重新加载了 OpenClash 配置
3.  查看 OpenClash 日志确认匹配结果

**Q: 如何调试 policy-priority?**

A:
```bash
# 查看 OpenClash 日志
/tmp/openclash.log

# 搜索策略选择日志
grep "policy-priority" /tmp/openclash.log
```

**Q: 权重应该设置多少合适?**

A: 建议:
*   特性标签 (家宽/媒体/高速): 15
*   主力机场: 10
*   协议性能: 5-10
*   质量后缀: 1-5

---

## 7. 最佳实践

### 7.1 模板命名规范

```yaml
PolicyDefault:    # 默认模板,适用于大部分场景
PolicyISP:        # 家宽专用模板
PolicyMedia:      # 媒体专用模板
PolicyFast:       # 高速专用模板
PolicyDialer:     # 链式代理专用模板
```

### 7.2 权重设置原则

1.  **特性优先**: 特殊用途节点 (家宽/媒体) 权重最高 (15)
2.  **协议次之**: 按性能排序 Reality(10) > Hysteria2(9) > Xhttp(8)
3.  **质量最后**: 优(5) > 中(2) > 备(1)

### 7.3 维护建议

*   定期检查节点命名是否符合规范
*   根据实际使用情况调整权重
*   保持模板定义的一致性
*   在 OpenClash 日志中验证选择结果

---

## 8. 参考资料

*   [OpenClash 官方文档](https://github.com/vernesong/OpenClash)
*   [Mihomo Smart 模式说明](https://wiki.metacubex.one/config/proxy-groups/smart/)
*   [YAML 锚点语法](https://yaml.org/spec/1.2.2/#3222-anchors-and-aliases)
