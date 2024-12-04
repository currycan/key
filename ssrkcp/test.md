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

获取配置`ss link`

```shell
docker exec -it ssrkcp show
```

- 参数“crypt”
因为我们是配合ss使用的，所以不必加密，直接选none就行

- 参数“mode”
可选fast、fast2、fast3、normal 、default
其中传输速度自然是fast3最大，流量也消耗最大。所以追求速度的可以选fast3，fast2是最折中的。

- 参数“mtu”
这个要自己计算，假设你的服务器ip为1.1.1.1，那么在终端中输入

```sh
ping -l 1472 1.1.1.1
```

意思是向1.1.1.1发一个1472字节的数据包。如果服务器正常响应，那么mtu就是数据包大小+28字节，这里就是1472+28=1500
如果提示说

``` txt
Packet needs to be fragmented but DF set.
```

就说明1472太大了。调小一些，再进行计算即可，不要盲目使用网上的参数！！！
我原来直接学着网上填了一个，速度不佳。计算后的参数视频可以直接从720p->1080p

- 参数“sndwnd”和“rcvwnd”
这是直接影响速度的两个参数！！！服务端要和客户端一致！！！
sndwnd是上传的包的大小，rcvwnd是下载的包的大小。
由于上传和传输速度没什么大关系，所以客户端的snd和服务端的rcv可以设的小一点，512即可。
但是，客户端的rcv和服务端的snd是非常重要的！直接关系到速度！建议都先调到1024，试试速度，在我这儿，两端都设了2048是最快的。不要设太大，不然会变慢的！
合理设置后，由1080p->2k
顺便给个计算公式：
你的速度=服务端snd（或客户端rcv）*1KB / 延迟
我可以达到8MB/s,也就是64Mb

- 参数“datashard”和“parityshard”
这是两个经常要改的参数！
datashard和parityshard是拯救丢包严重的线路用的。大致原理是多发包，丢了包靠多发的包纠错。计算公式如下
（datashard+parityshard）/ datashard * 之前算的速度=纠错后的速度
所以要看情况。比如说我白天，几乎不丢包，那么设置这个就是作死，但到了晚上，丢包率到了25%，那么我就知道原来4个包，现在要发5个，所以（datashard+parityshard）/ datashard = 5/4，datashard就设置为4，parityshard就是1，这样就维持了速度。
这样完整配置后，速度成功达到4k60帧！

nodelay ：是否启用 nodelay模式，0不启用；1启用。
interval ：协议内部工作的 interval，单位毫秒，比如 10ms或者 20ms
resend ：快速重传模式，默认0关闭，可以设置2（2次ACK跨越将会直接重传）
nc ：是否关闭流控，默认是0代表不关闭，1代表关闭。
普通模式： ikcp_nodelay(kcp, 0, 40, 0, 0);
极速模式： ikcp_nodelay(kcp, 1, 10, 2, 1);
