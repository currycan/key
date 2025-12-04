# 参考

https://github.com/lxhao61/integrated-examples

https://github.com/XTLS/Xray-core/discussions/4113

https://github.com/XTLS/Xray-core/discussions/4118

https://jollyroger.top/sites/361.html

https://github.com/fscarmen/sing-box

https://bianyuan.xyz/

# 节点重命名
https://github.com/sub-store-org/Sub-Store/blob/master/scripts/vmess-ws-obfs-host.js

https://github.com/v2rayA/v2rayA
https://github.com/v2raya/v2raya-openwrt
https://v2raya.org/docs/prologue/installation/openwrt/
https://pengtech.net/network/v2rayA_install.html

## 镜像制作

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg DUFS_VERSION="0.45.0" \
  --build-arg CLOUDFLARED_VERSION="2025.11.1" \
  --build-arg XUI_VERSION="2.8.5" \
  --build-arg SING_BOX_VERSION="1.12.12" \
  --build-arg XRAY_VERSION="25.12.2" \
  --tag currycan/sb-xray:25.12.2 \
  --push .
```

### 订阅转换

https://github.com/LM-Firefly/subconverter

https://github.com/LM-Firefly/Firefly-sub

https://github.com/DoingDog/clashconf?tab=readme-ov-file

相关教程：https://ednovas.xyz/2021/06/06/subs/

```bash
docker run -d --restart=always --name subconverter -p 25500:25500 ghcr.io/lm-firefly/subconverter:latest
````

http://172.18.18.254:25500/sub?

### CDN 域名报错：您重定向的次数过多

如果使用Cloudflare等CDN，检查CDN/代理设置（如Cloudflare）

- 登录Cloudflare控制台，进入 SSL/TLS → 概述。
- 确保模式设置为 Full (严格) 或 Full，而非 Flexible。
- 进入 规则 → 重定向规则，检查是否有冲突的自定义重定向。
- 暂时暂停Cloudflare（开发模式），测试是否问题源自CDN。
