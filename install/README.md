******
## 安装前的准备工作

命令都是在你的服务器上运行的，  
首先你要知道如何通过SSH远程登录到你的服务器上 [SSH教程][putty_url]  
其次安装时间较长，建议使用screen进行安装 [screen教程][screen_url]  
最后要会一点点的VI(VIM)编辑器使用方法 [VI/VIM教程][vim_url]

******
## 安装
------
```Bash
wget --no-check-certificate -O ./initial.sh https://raw.githubusercontent.com/currycan/key/master/install/initial.sh
wget --no-check-certificate -O ./ssr_install.sh https://raw.githubusercontent.com/currycan/key/master/install/install.sh
wget --no-check-certificate -O ./speed.sh https://raw.githubusercontent.com/currycan/key/master/install/tcp.sh
chmod 700 ./*.sh
./initial.sh
./ssr_install.sh
./speed.sh install
./speed.sh start
./speed.sh status
```
------
#### 防火墙设置示例

centos7（请替换命令里的端口）：  
```Bash
firewall-cmd --permanent --zone=public --add-port=2018/tcp
firewall-cmd --permanent --zone=public --add-port=2018/udp
firewall-cmd --permanent --zone=public --add-port=2019/tcp
firewall-cmd --permanent --zone=public --add-port=2019/udp
firewall-cmd --reload
```

centos6/OVZ（请替换命令里的端口）：  
```Bash
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 2018 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 2018 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 2019 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 2019 -j ACCEPT
/etc/init.d/iptables save
/etc/init.d/iptables restart
```

Debian/Ubuntu（请替换命令里的端口）：  
```Bash
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 2018 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 2018 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 2019 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 2019 -j ACCEPT

#下面这些代码是让Debian/Ubuntu关机自动备份Iptables和启动自动加载Iptables
echo '#!/bin/bash' > /etc/network/if-post-down.d/iptables && \
echo 'iptables-save > /etc/iptables.rules' >> /etc/network/if-post-down.d/iptables && \
echo 'exit 0;' >> /etc/network/if-post-down.d/iptables && \
chmod +x /etc/network/if-post-down.d/iptables && \

echo '#!/bin/bash' > /etc/network/if-pre-up.d/iptables && \
echo 'iptables-restore < /etc/iptables.rules' >> /etc/network/if-pre-up.d/iptables && \
echo 'exit 0;' >> /etc/network/if-pre-up.d/iptables && \
chmod +x /etc/network/if-pre-up.d/iptables
```

******
## 更新
```Bash
    ./ssr_install.sh update
```

******
## 卸载

```Bash
    ./ssr_install.sh uninstall
```

--------------------------------
[putty_url]:https://www.vpser.net/other/putty-ssh-linux-vps.html "如何使用Putty远程(SSH)管理Linux VPS"
[screen_url]:https://www.vpser.net/manage/screen.html "SSH远程会话管理工具 - screen使用教程"
[vim_url]:https://www.vpser.net/manage/vi.html "Linux上vi(vim)编辑器使用教程"