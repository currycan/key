******
##<a name="plan"/>安装前的准备工作

命令都是在你的服务器上运行的，  
首先你要知道如何通过SSH远程登录到你的服务器上 [SSH教程][putty_url]  
其次安装时间较长，建议使用screen进行安装 [screen教程][screen_url]  
最后要会一点点的VI(VIM)编辑器使用方法 [VI/VIM教程][vim_url]

******
##<a name="Install"/>安装
------
###<a name="Install_command">安装命令
```Bash
wget --no-check-certificate -O ./kcptun_for_ss_ssr-install.sh https://raw.githubusercontent.com/mongomongu/kcptun_for_ss_ssr/master/kcptun_for_ss_ssr-install.sh
chmod 700 ./kcptun_for_ss_ssr-install.sh
./kcptun_for_ss_ssr-install.sh install
```
自用：
```Bash
wget --no-check-certificate -O ./install.sh https://raw.githubusercontent.com/mongomongu/kcptun_for_ss_ssr/master/install.sh
chmod 700 ./install.sh
./install.sh install
```
------
####<a name="Firewall">防火墙设置示例

centos7（请替换命令里的端口）：  
```Bash
firewall-cmd --permanent --zone=public --add-port=端口/tcp
firewall-cmd --permanent --zone=public --add-port=端口/udp
firewall-cmd --reload
```

centos6（请替换命令里的端口）：  
```Bash
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 端口 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 端口 -j ACCEPT
/etc/init.d/iptables save
/etc/init.d/iptables restart
```

Debian/Ubuntu（请替换命令里的端口）：  
```Bash
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 端口 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 端口 -j ACCEPT

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
##<a name="Update"/>更新
```Bash
    ./kcptun_for_ss_ssr-install.sh update
```

******
##<a name="UnInstall"/>卸载
```Bash
    ./kcptun_for_ss_ssr-install.sh uninstall
```