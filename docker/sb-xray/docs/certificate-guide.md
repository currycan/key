# 证书生成与配置指南

本项目集成了 `acme.sh` 实现了全自动的证书申请、安装和续期。本指南将详细介绍支持的 CA 机构、配置方法以及针对性的优化建议。

## 🚀 推荐方案

| 比较项 | 🥇 **ZeroSSL** (推荐) | 🥈 **Google Public CA** | 🥉 **Let's Encrypt** |
| :--- | :--- | :--- | :--- |
| **泛域名支持** | ✅ 支持 (`*.domain.com`) | ✅ 支持 | ✅ 支持 |
| **OCSP Stapling** | ✅ **支持** (解决 Nginx 警告) | ✅ 支持 | ❌ **不支持** (已停止服务) |
| **ECC 证书** | ✅ 支持 (默认) | ✅ 支持 | ✅ 支持 |
| **自动化程度** | ⭐⭐⭐⭐⭐ (全自动) | ⭐⭐⭐ (需 EAB 凭据) | ⭐⭐⭐⭐⭐ (全自动) |
| **申请频率** | ⭐️ 无限制 | ⭐️ 高限制 | ⚠️ 严格限制 |
| **费用** | 免费 (90天自动续期) | 免费 | 免费 |

> [!TIP]
> **结论**：请优先使用 **ZeroSSL**。它是目前唯一无需复杂配置、完全免费、支持泛域名且完美支持 OCSP Stapling 的方案。

---

## 🛠 配置指南

配置通过 `docker-compose.yml` 中的环境变量完成。

### 1. ZeroSSL 配置 (默认推荐)

ZeroSSL 是本项目的默认推荐配置。脚本会自动使用您的邮箱注册账号。

```yaml
environment:
  # 必须: 设置 CA 为 ZeroSSL
  - ACMESH_SERVER_NAME=zerossl
  # 必须: 用于自动注册账户
  - ACMESH_REGISTER_EMAIL=your_email@example.com
```

**特点：**
*   自动申请泛域名证书（只要域名不是 IP）。
*   自动开启 Nginx 的 OCSP Stapling 优化。
*   证书有效期 90 天，容器会自动续期。

### 2. Google Public CA 配置

如果您希望使用 Google 的证书，需要先获取 EAB (External Account Binding) 凭据。
参考：
- [Google Trust Services CA · acmesh-official/acme.sh Wiki](https://github.com/acmesh-official/acme.sh/wiki/Google-Trust-Services-CA)
- [使用 acme.sh 申请 Google 公共证书 - atpX](https://atpx.com/blog/issue-free-google-public-cert/)

**前置步骤：**
1.  访问 [Google Cloud Shell](https://shell.cloud.google.com)。
2.  运行命令获取凭据：
    ```bash
    gcloud publicca external-account-keys create
    # 记录下返回的 keyId 和 b64MacKey
    ```

**配置方法：**

```yaml
environment:
  # 设置 CA 为 Google
  - ACMESH_SERVER_NAME=google
  - ACMESH_REGISTER_EMAIL=your_email@example.com
  # [新增] 必须填写 EAB 凭据
  - ACMESH_EAB_KID=xxxxxxxxxxxx  # 填入 keyId
  - ACMESH_EAB_HMAC_KEY=xxxxxxxx # 填入 b64MacKey
volumes:
  - ./acme_data:/root/.acme.sh  # 🚨 强烈建议：挂载此目录以持久化账户信息！
```

> [!CAUTION]
> **关于 EAB 凭据有效期**：
> 生成的 `keyId` 和 `HMAC Key` 有效期仅为 **7天**。请务必在生成后 7 天内启动容器完成首次注册。
> 1.  **挂载目录的重要性**：如果不挂载 `/root/.acme.sh`，重启容器会导致账户丢失。如果此时 EAB 凭据已过期（超过7天），容器将无法启动！
> 2.  **持久化后**：ACME 账户将永久有效，后续自动续期或重建容器都**不需要**新的凭据。

> [!NOTE]
> **EAB 参数通用性**：
> `ACMESH_EAB_KID` 和 `KEY` 是通用变量。如果您在配置 **ZeroSSL** 时填入这些变量，脚本也会将其发生给 ZeroSSL。这可用于将证书绑定到您的 ZeroSSL 官网账户。但请注意不要混用（如将 Google 的 Key 发给 ZeroSSL），否则会导致注册失败。



### 3. Let's Encrypt 配置

> [!WARNING]
> Let's Encrypt 已停止 OCSP 服务。使用此配置会导致 Nginx 启动时出现 `[warn] "ssl_stapling" ignored` 警告日志。虽然不影响使用，但不推荐。

```yaml
environment:
  - ACMESH_SERVER_NAME=letsencrypt
  - ACMESH_REGISTER_EMAIL=your_email@example.com
```

### 4. 其他 CA (不推荐)

*   **Actalis.com**:
    *   ❌ **不支持免费泛域名证书**: 如果您的域名是 `domain.com`，它无法申请 `*.domain.com`，导致子域名无法覆盖。
    *   ⚠️ 仅支持单域名证书。
*   **SSL.com**:
    *   ❌ **主要为付费服务**: 虽然有 90 天免费选项，但自动化支持不如 ZeroSSL 完善，且泛域名通常属于付费功能。
    *   ⚠️ ACME 接口主要面向企业/付费用户。

---

## 🔧 自动续期机制

本项目内置了智能续期守护进程，确保您的证书永不过期。

*   **开机检查**: 每次容器启动时，会自动检查证书有效期。
    *   如果有效期不足 **30天**，会自动强制触发续期。
    *   即使没有挂载 `.acme.sh` 目录，也能通过重新签发来"续期"。
*   **定时检查**: 容器内运行有 `acme.sh` 的守护进程，会定期尝试续期。

## ❓ 常见问题

**Q: 如何强制重签证书？**
A: 删除数据卷中的证书文件并重启容器。
```bash
rm -rf ./pki/* ./acmecerts/*
docker compose restart
```

**Q: 为什么日志里显示 "OCSP Stapling will remain DISABLED"?**
A: 这表示您当前使用的证书（如 Let's Encrypt）不支持 OCSP。如果在意这个警告，请切换到 ZeroSSL。

**Q: 泛域名证书包括哪些域名？**
A: 默认申请策略如下：
*   **主域名**: `example.com`
*   **泛域名**: `*.example.com`
这样可以覆盖您的主站及所有子域名。
