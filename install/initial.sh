#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

set -e

#检查系统
check_sys(){
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
check_version(){
    if [[ -s /etc/redhat-release ]]; then
        version=`grep -oE  "[0-9.]+" /etc/redhat-release | cut -d . -f 1`
    else
        version=`grep -oE  "[0-9.]+" /etc/issue | cut -d . -f 1`
    fi
    bit=`uname -m`
    if [[ ${bit} = "x86_64" ]]; then
        bit="x64"
    else
        bit="x32"
    fi
}

optimizing_system(){
    wget --no-check-certificate -O /etc/sysctl.conf https://raw.githubusercontent.com/currycan/key/master/sysctl.conf
    wget --no-check-certificate -O /etc/security/limits.conf https://raw.githubusercontent.com/currycan/key/master/limits.conf
    FLAG_PROFILE=$(grep "ulimit -SHn 1000000" /etc/profile | wc -l)
    if [ FLAG_PROFILE == 0 ];then
        echo "ulimit -SHn 1000000">>/etc/profile
    fi
}

pip_install(){
    if [ $(which pip | wc -l) == 0 ];then
        wget --no-check-certificate -O ./get-pip.py https://bootstrap.pypa.io/get-pip.py
        python get-pip.py
        rm -f get-pip.py
    else
        VERSION=$(pip --version |tr -s ' '| cut -d' ' -f2 | cut -d'.' -f1)
        if [ $VERSION != 19 ];then
            wget --no-check-certificate -O ./get-pip.py https://bootstrap.pypa.io/get-pip.py
            python get-pip.py
            rm -f get-pip.py
        fi
    fi
}

user_init(){
    mkdir -p /app
    FLAG_GROUP=$(grep andrew /etc/group | wc -l)
    if [ $FLAG_GROUP == 0 ];then 
        groupadd andrew
    fi
    if [ ! -f /app/andrew/.bashrc ];then 
        useradd -m andrew -g andrew -s /bin/bash -d /app/andrew
    fi
}

download_ssh_key(){
    mkdir -p /app/andrew/.ssh/
    wget --no-check-certificate -O /app/andrew/.ssh/authorized_keys https://raw.githubusercontent.com/currycan/key/master/authorized_keys
    wget --no-check-certificate -O /app/andrew/.ssh/id_rsa.pub https://raw.githubusercontent.com/currycan/key/master/id_rsa.pub
    chmod 600  /app/andrew/.ssh/*
    chown -R andrew:andrew /app/andrew/.ssh/
}

yum_init(){
    yum update -y
    yum install -y sudo vim wget net-tools telnet lrzsz lsof bash-completion epel-release python psmisc crond git
    pip_install
    pip install -U speedtest-cli
}

apt_init(){
    apt update 
    apt upgrade -y
    apt install -y sudo vim wget net-tools telnet lrzsz lsof bash-completion python curl psmisc cron git
    pip_install
    cat << EOF > /usr/bin/pip
#!/usr/bin/python
# GENERATED BY DEBIAN

import sys

# Run the main entry point, similarly to how setuptools does it, but because
# we didn't install the actual entry point from setup.py, don't use the
# pkg_resources API.
from pip import __main__
if __name__ == '__main__':
    sys.exit(__main__._main())
EOF
    pip install -U speedtest-cli
}

ssh_init(){
    wget --no-check-certificate -O /etc/ssh/sshd_config https://raw.githubusercontent.com/currycan/key/master/sshd_config
    wget --no-check-certificate -O ~/.bashrc https://raw.githubusercontent.com/currycan/key/master/bashrc
    wget --no-check-certificate -O /app/andrew/.bashrc https://raw.githubusercontent.com/currycan/key/master/bashrc
    chown -R andrew:andrew /app/andrew/.bashrc
}

initial(){
    check_sys
    check_version
    user_init
    download_ssh_key
    if [[ "${release}" == "centos" ]]; then
        echo "ZZT520.596msl*18" | passwd --stdin root
        echo "zzt2008zzt" | passwd --stdin andrew
        chcon -R unconfined_u:object_r:user_home_t:s0 /app/
        yum_init
        FLAG_SUDO=$(grep andrew /etc/sudoers | wc -l)
        if [ $FLAG_SUDO == 0 ];then
            sed -i '93i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        fi
        if [[ ${version} == "6" ]]; then
            echo "centos 6"
        elif [[ ${version} == "7" ]]; then
            systemctl stop firewalld && systemctl disable firewalld
        else
            echo "unkown error"
        fi
        ssh_init
        echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config
        echo 'export PS1="[\[\e[31;40m\]\u\[\e[37;40m\]@\[\e[32;40m\]\h\[\e[33;40m\] \w\[\e[0m\]]\\$ "' >> ~/.bashrc
        echo 'export PS1="[\u@\h \W]\$"' >> /app/andrew/.bashrc
        sed "s/6553600/65536/" -i /etc/security/limits.conf
        service sshd restart
        echo "Done~"
    elif [[ "${release}" == "debian" ]] || [[ "${release}" == "ubuntu" ]]; then
        echo "root:ZZT520.596msl*18" | chpasswd
        echo "andrew:zzt2008zzt" | chpasswd
        apt_init
        systemctl stop firewalld && systemctl disable firewalld
        FLAG_SUDO=$(grep andrew /etc/sudoers | wc -l)
        if [ $FLAG_SUDO == 0 ];then
            sed -i '21i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        fi
        ssh_init
        echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config
        echo 'export PS1="\[\e[31;40m\]\u\[\e[37;40m\]@\[\e[32;40m\]\h\[\e[33;40m\]:\w\[\e[0m\]\\$ "' >> ~/.bashrc
        echo 'export PS1="\u@\h:\w\$ "' >> /app/andrew/.bashrc
        service sshd restart
        echo "Done~"
    else
        echo "unkown system"
    fi
    optimizing_system
    stty erase '^H' && read -p "需要重启VPS，是否现在重启 ? [Y/n] :" yn
    [ -z "${yn}" ] && yn="y"
    if [[ $yn == [Yy] ]]; then
        echo -e "${Info} VPS 重启中..."
        reboot
    fi
    sysctl -p
}

initial | tee initial.log
