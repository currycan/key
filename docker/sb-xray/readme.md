# 参考

https://github.com/lxhao61/integrated-examples

https://github.com/Vauth/warp

https://blog.xmgspace.me/archives/nginx-sni-dispatcher.html

https://jollyroger.top/sites/361.html

https://github.com/XTLS/Xray-core/discussions/4118

https://github.com/fscarmen/sing-box


https://bianyuan.xyz/

## 镜像制作

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg HTTP_PROXY=http://host.docker.internal:7890 \
  --build-arg HTTPS_PROXY=http://host.docker.internal:7890 \
  --build-arg NO_PROXY=localhost,127.0.0.1,github.com \
  --build-arg XUI_VERSION="2.8.3" \
  --build-arg XRAY_VERSION="25.9.11" \
  --build-arg V2RAY_VERSION="5.39.0" \
  --tag currycan/sb-xray:25.9.11 \
  --push .
```

### CDN 域名报错：您重定向的次数过多

如果使用Cloudflare等CDN，检查CDN/代理设置（如Cloudflare）

- 登录Cloudflare控制台，进入 SSL/TLS → 概述。
- 确保模式设置为 Full (严格) 或 Full，而非 Flexible。
- 进入 规则 → 重定向规则，检查是否有冲突的自定义重定向。
- 暂时暂停Cloudflare（开发模式），测试是否问题源自CDN。
