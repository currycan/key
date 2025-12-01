# 说明

[ACL4SSR 在线订阅转换](https://acl4ssr-sub.github.io/)

[zsokami/ACL4SSR: 自定义 订阅转换 配置转换 规则转换 的远程配置。正则匹配大小写、简繁体，更好地匹配中转、IPLC节点。自带旗帜 emoji 添加逻辑，原名不包含旗帜 emoji 才添加，原名已包含旗帜 emoji 则不添加。添加某些影视/动漫 APP 广告拦截规则（附 hosts 文件）。附无 DNS 泄漏配置。修改自 ACL4SSR\_Online\_Full.ini](https://github.com/zsokami/ACL4SSR)

[ios\_rule\_script/rule/Clash at master · blackmatrix7/ios\_rule\_script](https://github.com/blackmatrix7/ios_rule_script/tree/master/rule/Clash)

https://mylink.ansandy.site/sub?

https://raw.githubusercontent.com/currycan/key/master/docker/sb-xray/templates/ACL4SSR/ACL4SSR_Online_Full.ini

## Tailscale 设置

[openwrt软路由安装tailscale - DEV Community](https://dev.to/dragon72463399/openwrtruan-lu-you-an-zhuang-tailscale-a7j)

[pkgs.tailscale.com/stable/](https://pkgs.tailscale.com/stable/)

> https://pkgs.tailscale.com/stable/tailscale_1.90.9_amd64.tgz

### 安装

首先直接在 iStore 商店安装tailscale, **不要启动服务**，然后进行如下升级:

```bash
VERSION=1.90.9
ARCH=amd64

wget https://pkgs.tailscale.com/stable/tailscale_${VERSION}_${ARCH}.tgz

tar -zxvf tailscale_${VERSION}_${ARCH}.tgz

mv tailscale_${VERSION}_${ARCH}/tailscale /usr/sbin/
mv tailscale_${VERSION}_${ARCH}/tailscaled /usr/sbin/
```

```bash
tailscale up --accept-dns=false --accept-routes --advertise-exit-node --advertise-routes=172.18.18.0/23 --hostname=n305-op

tailscale up --auth-key=tskey-auth-k4b4ZhKopD11CNTRL-BPYfNiKp7uE5ZFMsFDXDtEVrfSR7em9G XXX

```

在OpenWrt上新建一个接口，协议选**静态地址**，设备选**tailscale0**，地址为Taliscale管理页面上分配的**地址100.X.X.X**，掩码255.0.0.0。防火墙区域选lan区域。
