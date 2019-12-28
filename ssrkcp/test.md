# TEST

## 说明

`gosu` 和 `su-exec` 代替root用户执行。由于本服务需要root用户才能运行，因此没有配置。


```txt
key=p@ssw0rd456;raw=YES;crypt=aes-128;mode=fast3;mtu=1200;sndwnd=512;rcvwnd=4096;datashard=1;parityshard=1;dscp=46;nocomp=true;autoexpire=1800
```

```shell
docker run --rm -it --cap-add=NET_ADMIN currycan/ssrkcp:1.0.0 sh
```

```shell
entrypoint.sh ss-server -s 0.0.0.0   -p 2019   -k p@ssw0rd12^3a   -m chacha20-ietf-poly1305   -t 300   -d 8.8.8.8,8.8.4.4   -u   --fast-open   --mtu 1200   --no-delay --plugin kcptun-server-plugin --plugin-opts "key=${key};raw=${raw}"
```
