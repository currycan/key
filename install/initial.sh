#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

set -e

#检查系统
check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
}

#检查Linux版本
check_version() {
    if [[ -s /etc/redhat-release ]]; then
        version=$(grep -oE "[0-9.]+" /etc/redhat-release | cut -d . -f 1)
    else
        version=$(grep -oE "[0-9.]+" /etc/issue | cut -d . -f 1)
    fi
    bit=$(uname -m)
    if [[ ${bit} = "x86_64" ]]; then
        bit="x64"
    else
        bit="x32"
    fi
}

optimizing_system() {
    sudo \curl -SLo /etc/sysctl.conf https://raw.githubusercontent.com/currycan/key/master/sysctl.conf
    sudo \curl -SLo /etc/security/limits.conf https://raw.githubusercontent.com/currycan/key/master/limits.conf
    FLAG_PROFILE=$(sudo grep "ulimit -SHn 1000000" /etc/profile | wc -l)
    if [ FLAG_PROFILE == 0 ]; then
        echo "ulimit -SHn 1000000" >>/etc/profile
    fi
}

# pip_install() {
#     if [ $(which pip | wc -l) == 0 ]; then
#         sudo curl -SLo ./get-pip.py https://bootstrap.pypa.io/pip/2.7/get-pip.py
#         sudo python3 get-pip.py
#         rm -f get-pip.py
#     else
#         VERSION=$(pip --version | tr -s ' ' | cut -d' ' -f2 | cut -d'.' -f1)
#         if [ $VERSION != 19 ]; then
#             sudo curl -SLo ./get-pip.py https://bootstrap.pypa.io/pip/2.7/get-pip.py
#             sudo python3 get-pip.py
#             rm -f get-pip.py
#         fi
#     fi
# }

user_init() {
    mkdir -p /app
    FLAG_GROUP=$(grep andrew /etc/group | wc -l)
    if [ $FLAG_GROUP == 0 ]; then
        groupadd andrew
    fi
    if [[ ! -f /app/andrew/.bashrc ]] && [[ ! -f /home/andrew/.bashrc ]]; then
        useradd -m andrew -g andrew -s /bin/bash -d /app/andrew
    fi
}

download_ssh_key() {
    sudo mkdir -p ssh /app/andrew/.ssh/ /root/.ssh/
    sudo curl -SLo ssh/id_rsa.pub https://raw.githubusercontent.com/currycan/key/master/id_rsa.pub
    sudo curl -SLo ssh/authorized_keys https://raw.githubusercontent.com/currycan/key/master/authorized_keys
    sudo cp -a ssh/* /app/andrew/.ssh/
    sudo cp -a ssh/* /root/.ssh/
    sudo chmod 700 /app/andrew/.ssh/
    sudo chmod 600 /app/andrew/.ssh/*
    sudo chown -R andrew:andrew /app/andrew/.ssh/
    sudo chmod -R 600 /root/.ssh/
    sudo chown -R root:root /root/.ssh/
    sudo rm -rf ssh
}

yum_init() {
    sudo yum update -y
    sudo yum install -y sudo vim wget net-tools telnet lrzsz lsof bash-completion epel-release python3 psmisc git
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    rpm -Uvh --nodeps --force https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm
    yum install -y docker-ce docker-ce-cli containerd.io
    if [[ ${version} == "8" ]]; then
        ln -sf /usr/bin/python3 /usr/bin/python
    fi
    pip_install
    # pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
    # pip config set global.trusted-host mirrors.aliyun.com
    pip install -U speedtest-cli
    FLAG_LAN=$(grep 'LANG=en_US.utf-8' /etc/environment | wc -l)
    if [ $FLAG_LAN == 0 ]; then
        test -s /etc/environment && sed -i '$aLANG=en_US.utf-8' /etc/environment || echo 'LANG=en_US.utf-8' >>/etc/environment
    fi
    FLAG_ALL=$(grep 'LC_ALL=en_US.utf-8' /etc/environment | wc -l)
    if [ $FLAG_ALL == 0 ]; then
        sudo sed -i '$aLC_ALL=en_US.utf-8' /etc/environment
    fi
    sed -e 's/^#exclude=kernel*/exclude=kernel*/g' -i /etc/yum.conf
    FLAG_KERNEL=$(grep 'exclude=kernel' /etc/yum.conf | wc -l)
    if [ $FLAG_KERNEL == 0 ]; then
        echo 'exclude=kernel*' >>/etc/yum.conf
    fi
}

apt_init() {
    apt update
    apt upgrade -y
    apt install -y python3-pip vim ca-certificates curl

    if [[ "${release}" == "ubuntu" ]]; then
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        # Add the repository to Apt sources:
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    elif [[ "${release}" == "debian" ]]; then
        sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        # Add the repository to Apt sources:
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    if [ -f /usr/lib/python3.11/EXTERNALLY-MANAGED ];then
        sudo mv /usr/lib/python3.11/EXTERNALLY-MANAGED /usr/lib/python3.11/EXTERNALLY-MANAGED.old
    fi
    # pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
    # pip config set global.trusted-host mirrors.aliyun.com
    pip3 install -U speedtest-cli
}

ssh_init() {
    sudo sed -i /etc/ssh/sshd_config -e "s/^[#]*Port.*/Port 38666/g"
    sudo sed -i /etc/ssh/sshd_config -e "s/^PasswordAuthentication.*/PasswordAuthentication yes/g"
    sudo sed -i /etc/ssh/sshd_config -e "s/^#PubkeyAuthentication.*/PubkeyAuthentication yes/g"
    sudo sed -i /etc/ssh/sshd_config -e "s/^[#]*PermitRootLogin.*/PermitRootLogin yes/g"
    sudo sed -i /etc/ssh/sshd_config -e "s/^[#]*ClientAliveInterval.*/ClientAliveInterval 0/g"
    sudo sed -i /etc/ssh/sshd_config -e "s/^[#]*ClientAliveCountMax.*/ClientAliveCountMax 86400/g"
    sudo \curl -SLo /root/.bashrc https://raw.githubusercontent.com/currycan/key/master/bashrc
    sudo \curl -SLo /root/.vimrc https://raw.githubusercontent.com/currycan/key/master/vimrc
    sudo \curl -SLo /app/andrew/.bashrc https://raw.githubusercontent.com/currycan/key/master/bashrc
    sudo \curl -SLo /app/andrew/.vimrc https://raw.githubusercontent.com/currycan/key/master/vimrc

    chown -R andrew:andrew /app/andrew/.bashrc
}

initial() {
    timedatectl set-timezone Asia/Shanghai
    check_sys
    check_version
    optimizing_system
    user_init
    download_ssh_key
    if [[ "${release}" == "centos" ]]; then
        sudo echo "ZZT520.596msl*18" | passwd --stdin root
        sudo echo "zzt2008zzt" | passwd --stdin andrew
        # chcon -R unconfined_u:object_r:user_home_t:s0 /app/
        yum_init
        FLAG_SUDO=$(grep andrew /etc/sudoers | wc -l)
        if [ $FLAG_SUDO == 0 ]; then
            # sudo sed -i '93i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
            sudo sed -i '101i  %andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        fi
        if [[ ${version} == "6" ]]; then
            echo "centos 6"
        elif [[ ${version} != "6" ]]; then
            sudo systemctl stop firewalld && systemctl disable firewalld
        else
            echo "unkown error"
        fi
        ssh_init
        sudo echo 'export PS1="[\[\e[31;43m\]\[\e[5m\]\u\[\e[0m\]\[\e[37;40m\]@\[\e[32;40m\]\h\[\e[33;40m\] \w\[\e[0m\]]\\$ "' >>~/.bashrc
        sudo echo 'export PS1="[\u@\h \W]\$"' >>/app/andrew/.bashrc
        sudo sed "s/nofile 6553600/nofile 65536/g" -i /etc/security/limits.conf
        echo "Done~"
    elif [[ "${release}" == "debian" ]] || [[ "${release}" == "ubuntu" ]]; then
        sudo echo "root:ZZT520.596msl*18" | chpasswd
        sudo echo "andrew:zzt2008zzt" | chpasswd
        apt_init
        sudo systemctl stop firewalld && systemctl disable firewalld
        FLAG_SUDO=$(grep andrew /etc/sudoers | wc -l)
        if [ $FLAG_SUDO == 0 ]; then
            sudo sed -i '21i  %andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        fi
        ssh_init
        sudo echo 'export PS1="\[\e[31;43m\]\[\e[5m\]\u\[\e[0m\]\[\e[37;40m\]@\[\e[32;40m\]\h\[\e[33;40m\]:\w\[\e[0m\]\\$ "' >>~/.bashrc
        sudo echo 'export PS1="\u@\h:\w\$ "' >>/app/andrew/.bashrc
        echo "Done~"
    else
        echo "unkown system"
    fi
    COMPOSE_VERSION=$(curl -s https://github.com/docker/compose/tags | grep "/docker/compose/releases/tag/" | grep -v "rc" | head -1 | sed -r 's/.*tag\/(.+)\">.*/\1/' | awk -F'"' '{print $1}')
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    curl -L https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker
    # curl -L https://raw.githubusercontent.com/docker/compose/${COMPOSE_VERSION}/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
    curl -L https://raw.githubusercontent.com/docker/compose/1.28.x/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
    systemctl enable --now docker
    mkdir -p ~/ssrkcp
    curl -o ~/ssrkcp/docker-compose.yml https://raw.githubusercontent.com/currycan/key/master/ssrkcp/docker-compose.yml
    mkdir -p ~/ssrpolipo
    curl -o ~/ssrpolipo/docker-compose.yml https://raw.githubusercontent.com/currycan/key/master/ssrpolipo/docker-compose.yml
    mkdir -p ~/v2ray
    echo domain=$(hostname) >~/v2ray/.env
    curl -o ~/v2ray/docker-compose.yml https://raw.githubusercontent.com/currycan/key/master/v2ray/docker-compose.yml
    mkdir -p /root/file/data
    curl -o /root/file/docker-compose.yml https://raw.githubusercontent.com/currycan/key/master/file/docker-compose.yml
    cd /root/file/data; dd if=/dev/zero of=`hostname` bs=1M count=1k conv=fdatasync;cd -
    # curl -o /usr/local/bin/tcp.sh https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh
    curl -o /usr/local/bin/tcp.sh https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh
    curl -Lso /usr/local/bin/kernel.sh https://git.io/kernel.sh
    curl -o /usr/local/bin/superspeed https://raw.githubusercontent.com/ernisn/superspeed/master/superspeed.sh
    chmod 700 /usr/local/bin/*
    [[ $(grep 'docker exec -it ssrkcp show' ~/.bashrc | wc -l) == 0 ]] && echo 'alias ssrshow="docker exec -it ssrkcp show"' >>~/.bashrc
    [[ $(grep 'docker logs -f ssrkcp' ~/.bashrc | wc -l) == 0 ]] && echo 'alias ssrlogs="docker logs -f ssrkcp"' >>~/.bashrc
    [[ $(grep 'docker restart ssrkcp' ~/.bashrc | wc -l) == 0 ]] && echo 'alias ssrrestart="docker restart ssrkcp"' >>~/.bashrc
    [[ $(grep 'docker exec -it v2ray show' ~/.bashrc | wc -l) == 0 ]] && echo 'alias show="docker exec -it v2ray show"' >>~/.bashrc
    [[ $(grep 'docker logs -f v2ray' ~/.bashrc | wc -l) == 0 ]] && echo 'alias logs="docker logs -f v2ray"' >>~/.bashrc
    [[ $(grep 'docker restart v2ray' ~/.bashrc | wc -l) == 0 ]] && echo 'alias restart="docker restart v2ray"' >>~/.bashrc
    service sshd restart
    sudo sysctl -p
}

initial | tee initial.log
