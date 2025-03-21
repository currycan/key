# 参考

https://github.com/Vauth/warp

https://blog.xmgspace.me/archives/nginx-sni-dispatcher.html

https://jollyroger.top/sites/361.html

https://github.com/XTLS/Xray-core/discussions/4118

## 镜像制作

```bash
docker buildx build --platform linux/amd64 \
  --build-arg DUFS_VERSION="0.43.0" \
  --build-arg XRAY_VERSION="25.3.6" \
  -t currycan/xray:25.3.21 .
```

### CDN 域名报错：您重定向的次数过多

如果使用Cloudflare等CDN，检查CDN/代理设置（如Cloudflare）

- 登录Cloudflare控制台，进入 SSL/TLS → 概述。
- 确保模式设置为 Full (严格) 或 Full，而非 Flexible。
- 进入 规则 → 重定向规则，检查是否有冲突的自定义重定向。
- 暂时暂停Cloudflare（开发模式），测试是否问题源自CDN。
