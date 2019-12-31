# TEST

## 说明

`gosu` 和 `su-exec` 代替root用户执行。由于本服务需要root用户才能运行，因此没有配置。

关于`udp2raw_mp`参阅github [wiki](https://github.com/wangyu-/udp2raw-multiplatform/wiki/udp2raw%E5%8E%9F%E7%94%9F%E8%BF%90%E8%A1%8C%E5%9C%A8windows-macOS%E4%B8%8A%E2%80%9C%E5%8A%A0%E9%80%9F%E2%80%9Dkcptun)

```
Windows：
udp2raw_mp.exe -c -r45.66.77.88:8855 -l0.0.0.0:4000 --raw-mode easy-faketcp -k"passwd"

Mac：
./udp2raw_mp -c -r45.66.77.88:8855 -l0.0.0.0:4000 --raw-mode easy-faketcp -k"passwd"

```txt
crypt=blowfish;key=p@ssw0rd456;mtu=1400;sndwnd=4096;rcvwnd=1024;mode=fast2;datashard=10;parityshard=3;dscp=46;nocomp=true;tcp=true
```

```shell
docker run --rm -it --name ssrkcp --cap-add=NET_ADMIN --net host currycan/ssrkcp:1.0.0 sh
```
