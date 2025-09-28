# 参考

https://github.com/lxhao61/integrated-examples

https://github.com/Vauth/warp

https://blog.xmgspace.me/archives/nginx-sni-dispatcher.html

https://jollyroger.top/sites/361.html

https://github.com/XTLS/Xray-core/discussions/4118

https://github.com/fscarmen/sing-box

https://bianyuan.xyz/

## 镜像制作


docker buildx 等 BuildKit 功能构建镜像，在 ~/.docker/config.json 或 buildkit 配置里指定代理：

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://xxxxx:7890",
      "httpsProxy": "http://xxxxx:7890",
      "noProxy": "localhost,127.0.0.1,github.com"
    }
  }
}
```

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg XUI_VERSION="2.8.3" \
  --build-arg XRAY_VERSION="25.9.11" \
  --build-arg V2RAY_VERSION="5.39.0" \
  --tag currycan/sb-xray:25.9.11 \
  --push .
```

### 订阅转换

https://kb.nssurge.com/surge-knowledge-base/zh/guidelines/detached-profile

自建订阅转换不会有隐私泄露等风险，但需要一定技术基础。

以下教程源自网络收集，与本文无关，仅作为示例：

前端：https://github.com/CareyWang/sub-web

后端：https://github.com/tindy2013/subconverter

相关教程：https://ednovas.xyz/2021/06/06/subs/

### CDN 域名报错：您重定向的次数过多

如果使用Cloudflare等CDN，检查CDN/代理设置（如Cloudflare）

- 登录Cloudflare控制台，进入 SSL/TLS → 概述。
- 确保模式设置为 Full (严格) 或 Full，而非 Flexible。
- 进入 规则 → 重定向规则，检查是否有冲突的自定义重定向。
- 暂时暂停Cloudflare（开发模式），测试是否问题源自CDN。
