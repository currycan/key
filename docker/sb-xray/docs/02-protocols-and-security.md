# 02. 后量子加密与 Reality 防探测引擎详解

本指南着重探讨 SB-Xray 中运用的前沿网络加密机制以及防御主动探测的隐蔽逻辑。

---

## 1. ⚛️ MLKEM 后量子密码学协议 (Post-Quantum Cryptography)

在 Xray 的 VLESS 协议及最新的 XHTTP 隧道中，本项目率先启用了 **MLKEM768 后量子端到端加密机制**。

> **理论参考文献**：
> 1. [NIST FIPS 203 标准](https://csrc.nist.gov/pubs/fips/203/final) (Module-Lattice-Based Key-Encapsulation Mechanism)
> 2. XTLS 社区关于 VLESS Encryption 的架构探讨。

### 为什么需要 VLESS Encryption (MLKEM)？
传统的加密算法（如 RSA、ECC）在未来十年内可能会被拥有强大算力的量子计算机“先存储，后破解 (Store Now, Decrypt Later)”。MLKEM 采用基于格的密码学 (Lattice-based cryptography) 彻底免疫此类攻击。

### 核心设计理念
> [!WARNING]
> **切记**：VLESS Encryption（端到端加密层）**不是用来直接建立网络通信包的**。直接建立越境通信依然需要依赖其外层的 TLS 或 REALITY/Vision！

它的核心使命是在极其严苛的场景下提供内层绝对的安全保护：
1. **CDN 裸奔保护**：当流量通过 Cloudflare 等中转时，避免向 CDN 平台暴露您的真实 UUID 与数据特征。
2. **多跳节点保护**：在机场或不受信任的中转机上，即便攻击者拿到了您的客户端配置文件（Client Config），基于非对称设计的 MLKEM 也让他们**绝对无法解密历史流量**，更无法实施中间人攻击 (MITM)。

*(对比说明：传统的 SS 2022/AEAD 或 VMess 由于是对称 PSK 设计，一旦配置泄露，历史流量底裤全露。)*

---

## 2. 🛡️ Reality 深度伪装机制与 Fallback 回落

Reality 协议的核心理念是：**“借刀杀人”，抛弃自有证书，完全模拟各大科技巨头（如微软、苹果）的真实握手特征**。

### Reality 伪装进化的本质

在传统的 TLS 链路时代，无论你怎么伪装，审查者只要提取你的服务端证书，就会发现这是由 Let's Encrypt 签发给某个不知名小域名（如 `my-proxy.abc.com`）的证书，特征极为明显。

而 Reality 通过截获并转发真实目标网站（`DEST_HOST`）的公钥参数，达成了**深度伪装 (Deep Masquerading)**：

*   **旧模式的劣势**: 主动探测者 -> 请求你的 IP -> 返回你自己小域名的证书 -> 被认定为特定信道。
*   **Reality 新模式**: 主动探测者 -> 请求你的 IP -> Reality 将请求透传给 `www.microsoft.com` -> 探测者收到了真正来自微软的、包含完整信任链的豪华证书。审查者无从下手。

### Fallback (回落) 逻辑

虽然伪装做到了极致，但当“自己人”（客户端）发起连接时，我们依然需要通过内部隐蔽通道将他们剥离出来。

```json
{
  "name": "http-fallback",
  "dest": "unix:/dev/shm/nginx.sock",
  "xver": 1
}
```

在 `templates/xray/01_reality_inbounds.json` 的入站规则中：
1. 若流量符合 **XTLS-Vision** 严格的长度与时序控制，直接放行进行分发。
2. 若流量是通过 Reality 解密成功，但却是一般的 HTTP 请求（如 XHTTP 流量，或是您自己在浏览器里访问了这个入口），Xray 会触发 `dest` 回落。
3. 它会将这个干净的 HTTP 明文流通过 `nginx.sock` 扔回给内部的 Nginx Web 引擎进行下一步的业务分发。

---

## 3. 📜 ACME 全自动证书管家 (Certificate Automation)

尽管 Reality 通道不需要我们自己的证书，但为了保护面板入口，以及支持 CDN / VMess 等传统备用协议，系统内建了完善的 `acme.sh` 机制。

### 推荐的 CA 机构评级

我们在 `entrypoint.sh` 的扇区三中植入了证书生命周期守护逻辑：每日自检，当证书剩余寿命不足 7 天时，立刻触发强制轮换续签。

| CA 机构名称 | 泛域名支持 | OCSP 状态装订 | 自动化评级 | 综合推荐度 |
| :--- | :---: | :---: | :---: | :--- |
| 🥇 **ZeroSSL** | ✅ 支持 | ✅ 完美支持 | ⭐⭐⭐⭐⭐ | 默认推荐，彻底解决 Nginx 证书链警告，申请频率宽容。 |
| 🥈 **Google Public CA** | ✅ 支持 | ✅ 支持 | ⭐⭐⭐ | 稳定，但首次需配置 EAB 凭据，对高频重置不太友好。 |
| 🥉 **Let's Encrypt** | ✅ 支持 | ❌ 已停止支持 | ⭐⭐⭐⭐ | 限制过于严格，容易被 Rate Limit 封锁。 |

### 环境配置示例

在 `docker-compose.yml` 中，只需填入以下变量即可激活全自动流程：

```yaml
environment:
  # 设置 CA 机构为 ZeroSSL (默认值)
  - ACMESH_SERVER_NAME=zerossl
  # 必须填写：用于自动化注册账户
  - ACMESH_REGISTER_EMAIL=admin@your_domain.com
```
系统将会全自动完成 DNS 挑战（若是基于域名的 HTTP 挑战则会由 Nginx 配合拦截），最终将生成的 `.crt` 与 `.key` 持久化存储至挂载的 `/pki` 目录供各大微服务共享。
