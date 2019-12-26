FROM centos:7

LABEL maintainer="andrew <ansandy@foxmail.com>"

RUN set -ex; \
    curl -o ./get-pip.py https://bootstrap.pypa.io/get-pip.py; \
    python get-pip.py; rm -f get-pip.py; \
    pip install -U shadowsocks supervisor; \
    mkdir -p /etc/shadowsocks /logs/ssserver /logs/sslocal; \
    printf \
    '{\n\
    "server": "127.0.0.1",\n\
    "server_port": 2018,\n\
    "password": "1qaz2wsx3edc",\n\
    "method": "aes-256-cfb",\n\
    "local_address":"0.0.0.0",\n\
    "local_port":12018,\n\
    "timeout": 600,\n\
    "workers": 2\n\
}' \
    > /etc/shadowsocks/ssserver.json; \
    printf \
    '{\n\
    "server": "127.0.0.1",\n\
    "server_port": 2018,\n\
    "password": "1qaz2wsx3edc",\n\
    "method": "aes-256-cfb",\n\
    "local_address":"0.0.0.0",\n\
    "local_port":2019,\n\
    "timeout": 600,\n\
    "workers": 2\n\
}' \
    > /etc/shadowsocks/sslocal.json; \
    yum install -y vim texinfo make git gcc-c++; \
    git clone https://github.com/jech/polipo.git; \
    cd polipo && make all && make install; \
    mkdir -p /etc/polipo /logs/polipo; \
    printf \
    'socksParentProxy = "127.0.0.1:2019"\n\
socksProxyType = socks5\n\
proxyAddress = "0.0.0.0"\n\
authCredentials = "currycan:shachao123321"\n\
proxyPort = 18080\n\
logSyslog = true\n\
logLevel = 4\n\
logFile = /logs/polipo/polipo.log\n\
chunkHighMark = 50331648\n\
objectHighMark = 16384\n\
serverMaxSlots = 64\n\
serverSlots = 16\n\
serverSlots1 = 32' \
> /etc/polipo/config; \
    mkdir -p /var/log/supervisor; \
    printf \
    '[supervisord]\n\
nodaemon=true\n\
[program:ssserver]\n\
command=/usr/bin/ssserver -c /etc/shadowsocks/ssserver.json\n\
[program:sslocal]\n\
command=/usr/bin/sslocal -c /etc/shadowsocks/sslocal.json\n\
[program:polipo]\n\
command=/usr/local/bin/polipo -c /etc/polipo/config' > /etc/supervisord.conf; \
    yum remove -y texinfo make git gcc-c++ && yum clean all && rm -rf ~/.cache

ENV TZ=Asia/Shanghai

VOLUME [ "/etc/shadowsocks", "/etc/polipo", "/logs/ssserver", "/logs/sslocal", "/logs/polipo" ]

CMD ["supervisord"]
