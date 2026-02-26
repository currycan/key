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
policy-priority: "Reality:20;Hysteria2:8;优:30;中:2;备:1"

节点A: [Reality] 🇭🇰HK|Reality|VLESS|优
匹配: Reality(20) + 优(30) = 50分

节点B: [Reality] 🇭🇰HK|Hysteria2|优
匹配: Hysteria2(8) + 优(30) = 38分

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
| **地区标识** | `🇭🇰HK`, `🇺🇸US` | 地理位置过滤 |
| **特性标签** | `super`, `good` | 特定线路特性优先级 |
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
  policy-priority: "Reality:20;香港:8;优:30;..."  # 在家宽节点中按其他维度排序
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
| **特性标签** | `高速` | 10 | 高速线路标识 |
| | `super` | 20 | 极佳体验线路 |
| | `good` | 10 | 良好体验线路 |
| **协议性能** | `Reality/vless` | 20/10 | 最高优先级 |
| | `Hysteria2/ysteria2` | 8 | Hysteria2 协议 |
| | `V2ray/vmess` | 3 | 通用协议 |
| | `tuic/TUIC` | 8 | QUIC协议 |
| | `anytls` | 1 | 基础协议 |
| **地区偏好** | 🇺🇸 美国 | 20 | AI/家宽场景最高优先级 |
| | 🇰🇷 韩国 | 10 | 家宽场景高优先级 |
| | 🇯🇵 日本 | 6-10 | 根据场景调整 |
| | 🇸🇬 新加坡 | 4 | 低优先级 |
| | 🇹🇼 台湾 | 2-15 | 一般场景低优先级,链式代理高优先级 |
| | 🇭🇰 香港 | 0~20 | 家宽场景排除(设为0或不配),链式代理最高(20) |
| | 🇨🇳 大陆 | 15 | 链式代理场景高优先级 |
| **质量后缀** | `优` | 30 | 优质节点 |
| | `中` | 2 | 中等节点 |
| | `备` | 1 | 备用节点 |

### 4.2 模板定义

```yaml
# ==================== Policy-Priority 模板 ====================
# 设计理念: filter 负责筛选节点范围, policy-priority 负责在筛选结果中进行多维度排序
#
# 权重维度说明:
#   - 特性标签: 高速(10), super(20), good(10)
#   - 协议性能: Reality(20), vless(10), Hysteria2(8), hysteria2(8), hy2(8), HY2(8), TUIC(8), tuic(8), V2ray(3), vmess(3), anytls(1)
#   - 质量后缀: 优(30), 中(2), 备(1)
#   - 地区偏好: 根据不同场景动态调整
#
# 基础权重配置 - 所有策略共享的协议和质量权重
# 格式: "特性:权重;协议:权重;...;质量:权重"
PolicyDefault:  &PolicyDefault  "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1"
# 家宽专用 - 基础权重 + 地区偏好(美🇺🇸:20 > 韩🇰🇷:10 > 日🇯🇵:6 > 新🇸🇬:4 > 台🇹🇼:2, 排除港🇭🇰:0 或不配置)
PolicyISP:      &PolicyISP      "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1;🇺🇸:20;🇰🇷:10;🇯🇵:6;🇸🇬:4;🇹🇼:2"
# 流媒体专用 - 基础权重 + 地区偏好(美🇺🇸:15 > 韩🇰🇷:8 > 日🇯🇵:6 > 新🇸🇬:4 > 台🇹🇼:2)
PolicyMedia:    &PolicyMedia    "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1;🇺🇸:15;🇰🇷:8;🇯🇵:6;🇸🇬:4;🇹🇼:2"
# 高速专用 - 基础权重 + 地区偏好(美🇺🇸:15 > 日🇯🇵:10 > 韩🇰🇷:8 > 新🇸🇬:4 > 台🇹🇼:2)
PolicyFast:     &PolicyFast     "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1;🇺🇸:15;🇯🇵:10;🇰🇷:8;🇸🇬:4;🇹🇼:2"
# AI 服务专用 - 基础权重 + 地区偏好(美🇺🇸:20 > 日🇯🇵:10 > 韩🇰🇷:8 > 新🇸🇬:4 > 台🇹🇼:2)
PolicyAI:       &PolicyAI       "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1;🇺🇸:20;🇯🇵:10;🇰🇷:8;🇸🇬:4;🇹🇼:2"
# 链式代理专用 - 基础权重 + 地区偏好(港🇭🇰:20 > 台🇹🇼:15 > 陆🇨🇳:15 > 韩🇰🇷:10 > 日🇯🇵:6 > 新🇸🇬:4 > 美🇺🇸:2)
PolicyDialer:   &PolicyDialer   "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1;🇭🇰:20;🇹🇼:15;🇨🇳:15;🇰🇷:10;🇯🇵:6;🇸🇬:4;🇺🇸:2"
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
PolicyISP: "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1;🇺🇸:20;🇰🇷:10;🇯🇵:6;🇸🇬:4;🇹🇼:2"
```

| 节点 | 匹配关键字 | 权重计算 | 总分 |
|:---|:---|:---|:---:|
| A | `Reality(20) + vless(10) + 🇺🇸(20) + 优(30)` | 20+10+20+30 | **80** |
| B | `Reality(20) + hysteria2(8) + 🇰🇷(10) + 优(30)` | 20+8+10+30 | **68** |
| C | `Reality(20) + vmess(3) + 🇯🇵(6) + 中(2)` | 20+3+6+2 | **31** |
| D | `Reality(20) + anytls(1) + 🇸🇬(4) + 备(1)` | 20+1+4+1 | **26** |

**最终选择顺序**: A (美国Reality/vless优) > B (韩国Reality/hysteria2优) > C (日本Reality/vmess中) > D (新加坡Reality/anytls备)

**分析**:
- ✅ 美国节点优先 (地区偏好 20分,家宽场景最高权重)
- ✅ 香港节点排除 (零权重或不配置,避免家宽使用香港)
- ✅ Reality协议最高优先 (协议性能 20分)
- ✅ 优质节点优先 (质量后缀 30分)
- ✅ 多维度权重自动叠加

### 5.2 不同场景的优先级

**场景1: 媒体-智选** (filter 已筛选出媒体节点)

```yaml
PolicyMedia: "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1;🇺🇸:15;🇰🇷:8;🇯🇵:6;🇸🇬:4;🇹🇼:2"
```

```
节点: [Reality] 🇺🇸US|流媒体|Reality|vless|优
权重: Reality(20) + vless(10) + 🇺🇸(15) + 优(30) = 75分

节点: [Reality] 🇰🇷KR|SsrDog|hysteria2|优
权重: Reality(20) + hysteria2(8) + 🇰🇷(8) + 优(30) = 66分
```

**优先级**: 美国 > 韩国 (媒体库更全)

**场景2: 高速-智选** (filter 已筛选出高速节点)

```yaml
PolicyFast: "高速:10;super:20;good:10;Reality:20;vless:10;Hysteria2:8;hysteria2:8;hy2:8;HY2:8;TUIC:8;tuic:8;V2ray:3;vmess:3;anytls:1;优:30;中:2;备:1;🇺🇸:15;🇯🇵:10;🇰🇷:8;🇸🇬:4;🇹🇼:2"
```

```
节点: [Reality] 🇺🇸US|高速|Reality|vless|优
权重: 高速(10) + Reality(20) + vless(10) + 🇺🇸(15) + 优(30) = 85分

节点: [Reality] 🇰🇷KR|高速|hysteria2|优
权重: 高速(10) + Reality(20) + hysteria2(8) + 🇰🇷(8) + 优(30) = 76分
```

**优先级**: 美国Reality/vless > 韩国Hysteria2 (协议和地区双重优势,高速标签额外加分)

### 5.3 职责分离的优势

**传统方案** (重复配置):
```yaml
家宽-智选:
  filter: "住宅|isp|ISP"
  policy-priority: "住宅:15;isp:15;ISP:15;..."
  # ❌ 问题: filter 已经筛选出家宽节点,policy-priority 再次匹配 "住宅" 是冗余的
```

**优化方案** (职责分离):
```yaml
家宽-智选:
  filter: "住宅|isp|ISP"                                    # 筛选家宽节点
  policy-priority: "Reality:20;🇺🇸:10;优:30;..."  # 在家宽节点中按其他维度排序
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
*   特性标签 (super/good/高速): 10-20
*   主力协议性能: 10-20
*   质量后缀: 10-30
*   地区偏好: 5-20

---

---

## 6. Smart 模式延迟容忍度机制

### 6.1 什么是延迟容忍度(tolerance)?

Smart 模式不仅考虑权重分数,还会综合**延迟因素**来选择节点。`tolerance` 参数控制延迟在节点选择中的影响程度。

**配置位置**:
```yaml
BaseSmart: &BaseSmart {
  type: smart,
  interval: 180,
  tolerance: 300,  # 延迟容忍度(ms)
  lazy: true,
  url: "https://www.google.com/generate_204"
}
```

### 6.2 工作原理

Smart 模式的最终得分计算逻辑:

```
最终得分 = 权重分数 × 延迟因子

延迟因子计算:
- 如果节点延迟差距 ≤ tolerance: 主要看权重分数
- 如果节点延迟差距 > tolerance: 延迟因素权重增加
```

### 6.3 实际案例分析

**场景**: 家宽-智选策略,有以下两个节点:

| 节点 | 权重分数 | 延迟 |
|------|---------|------|
| 🇺🇸 美国 Reality 优 | 45分 | 150ms |
| 🇭🇰 香港 Reality 优 | 25分 | 20ms |

**权重计算**:
```yaml
PolicyISP: "Reality:20;优:30;🇺🇸:20;🇰🇷:10;🇯🇵:6;🇸🇬:4;🇹🇼:2;🇭🇰:0"

🇺🇸 美国: Reality(20) + 优(30) + 🇺🇸(20) = 70分
🇭🇰 香港: Reality(20) + 优(30) + 🇭🇰(0) = 50分
```

**不同 tolerance 值的选择结果**:

#### tolerance = 100ms (默认)

```
延迟差距 = 150ms - 20ms = 130ms > 100ms
→ 延迟因素权重增加,香港节点因低延迟被优先选择 ❌
```

#### tolerance = 200ms

```
延迟差距 = 130ms,接近 200ms
→ 权重和延迟因素平衡,美国节点可能被选择 ⚠️
```

#### tolerance = 300ms (推荐)

```
延迟差距 = 130ms < 300ms
→ 权重因素占主导,美国节点(70分)优先于香港节点(50分) ✅
```

### 6.4 调优建议

#### 场景 1: 优先考虑权重(地区/协议偏好)

**适用**: 家宽策略、AI 服务策略、流媒体策略

```yaml
BaseSmart: {tolerance: 300}  # 或更高
```

**效果**: 即使目标地区延迟较高,仍会优先选择

#### 场景 2: 平衡权重和延迟

**适用**: 高速策略、日常使用

```yaml
BaseSmart: {tolerance: 200}
```

**效果**: 权重和延迟各占一定比重

#### 场景 3: 优先考虑延迟

**适用**: 游戏加速、实时通信

```yaml
BaseSmart: {tolerance: 100}  # 或更低
```

**效果**: 低延迟节点优先,权重影响较小

### 6.5 常见问题

**Q: 为什么设置了高权重,仍选择低权重的节点?**

A: 检查 `tolerance` 值。如果延迟差距超过 tolerance,低延迟节点会被优先选择。

**解决方案**:
1.  提高 `tolerance` 值(如 300ms)
2.  或在 filter 中直接排除不想要的地区

**Q: tolerance 设置多少合适?**

A: 根据实际需求:
-  **重视地区偏好**: 300-500ms
-  **平衡选择**: 150-250ms
-  **重视延迟**: 50-100ms

**Q: 如何完全忽略延迟,只看权重?**

A: Mihomo Smart 模式无法完全忽略延迟。如需纯权重排序,建议:
1.  设置极高的 tolerance(如 1000ms)
2.  或使用 `fallback` 模式 + 手动排序

### 6.6 最佳实践

#### 家宽策略配置示例

```yaml
# 1. 设置较高的 tolerance
BaseSmart: {tolerance: 300}

# 2. 给目标地区高权重,非目标地区低权重或 0 权重
PolicyISP: "Reality:20;优:30;🇺🇸:20;🇰🇷:10;🇯🇵:6;🇸🇬:4;🇹🇼:2;🇭🇰:0"

# 3. 或在 filter 中直接排除
FilterISP: "^(?=.*(?i)(住宅|isp))(?!.*(🇭🇰|HK|Hong|香港)).*$"
```

**效果**: 美国节点优先,香港节点作为最后备选或完全排除

---

## 7. 最佳实践

### 7.1 模板命名规范

```yaml
PolicyDefault:    # 默认模板,纯协议质量优先,无地区偏好
PolicyISP:        # 家宽专用模板,美国权重最高(20),排除香港(零权重或不配置)
PolicyMedia:      # 媒体专用模板,美国权重较高(15)
PolicyFast:       # 高速专用模板,美日优先
PolicyAI:         # AI服务专用模板,美国权重最高(20)
PolicyDialer:     # 链式代理专用模板,港台陆优先
```

### 7.2 权重设置原则

1.  **基础权重**: 所有策略共享协议和质量权重
2.  **地区偏好**: 根据使用场景动态调整 (家宽/AI: 美国20且排除香港, 媒体: 美国15, 链式代理: 香港20)
3.  **协议性能**: Reality(20) > vless(10) > Hysteria2(8) > V2ray/vmess(3) > tuic(8) > anytls(1)
4.  **质量后缀**: 优(30) > 中(2) > 备(1)

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
