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

create_user(){
    mkdir -p /app
    FLAG_GROUP=$(grep andrew /etc/group | wc -l)
    FLAG_USER=$(ls -la /app/andrew/.bashrc | wc -l)
    if [ $FLAG_GROUP == 0 ];then 
        groupadd andrew
    fi
    if [ $FLAG_USER == 0 ];then 
        useradd -m andrew -g andrew -s /bin/bash -d /app/andrew
    fi
}

pip_install(){
    VERSION=$(pip --version |tr -s ' '| cut -d' ' -f2 | cut -d'.' -f1)
    if [ $VERSION != 19 ];then
        curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python get-pip.py
        rm -f get-pip.py
    fi
}

down_key(){
    mkdir -p /app/andrew/.ssh/
    curl -so /app/andrew/.ssh/authorized_keys https://raw.githubusercontent.com/currycan/key/master/authorized_keys
    curl -so /app/andrew/.ssh/id_rsa.pub https://raw.githubusercontent.com/currycan/key/master/id_rsa.pub
    chmod 600  /app/andrew/.ssh/*
    chown -R andrew:andrew /app/andrew/.ssh/
}

init_centos(){
    echo "ZZT520.596msl*18" |passwd --stdin root
    yum update -y
    yum install -y vim wget net-tools telnet lrzsz lsof bash-completion epel-release crond
    pip_install
    pip install -U speedtest-cli
    systemctl stop firewalld && systemctl disable firewalld
}

init(){
    echo "root:ZZT520.596msl*18" | chpasswd
    apt update 
    apt upgrade -y
    apt install -y sudo vim wget net-tools telnet lrzsz lsof bash-completion curl cron
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

ssh_centos(){
    down_key
    cat << EOF > /etc/ssh/sshd_config
Port 38666
SyslogFacility AUTHPRIV
PermitRootLogin no
RSAAuthentication yes 
PermitRootLogin yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
GSSAPICleanupCredentials yes
UsePAM yes
X11Forwarding no
EOF
    echo "Subsystem sftp /usr/libexec/openssh/sftp-server" >> /etc/ssh/sshd_config
    echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config
    service sshd restart
    echo "Done~"
}

ssh_init(){
    down_key
    cat << EOF > /etc/ssh/sshd_config
Port 38666
SyslogFacility AUTHPRIV
PermitRootLogin no
RSAAuthentication yes 
PermitRootLogin yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
GSSAPICleanupCredentials yes
UsePAM yes
X11Forwarding no
EOF
    echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config
    service sshd restart
    wget --no-check-certificate -O ~/.bashrc https://raw.githubusercontent.com/currycan/key/master/bashrc
    source ~/.bashrc
    service sshd restart
    echo "Done~"
}

initial(){
    create_user
	check_sys
    FLAG_SUDO=$(grep andrew /etc/sudoers | wc -l)
	if [[ "${release}" == "centos" ]]; then
        echo "ZZT520.596msl*18" | passwd --stdin root
        echo "zzt2008zzt" | passwd --stdin andrew
        chcon -R unconfined_u:object_r:user_home_t:s0 /app/
        if [ $FLAG_SUDO == 0 ];then
            sed -i '93i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        fi
        init_centos
        ssh_centos
	elif [[ "${release}" == "debian" ]]; then
        echo "root:ZZT520.596msl*18" | chpasswd
        echo "andrew:zzt2008zzt" | chpasswd
        if [ $FLAG_SUDO == 0 ];then
            sed -i '21i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        fi
        init
        ssh_init
	elif [[ "${release}" == "ubuntu" ]]; then
        echo "root:ZZT520.596msl*18" | chpasswd
        echo "andrew:zzt2008zzt" | chpasswd
        if [ $FLAG_SUDO == 0 ];then
            sed -i '21i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        fi
        init
        ssh_init
	fi
}

initial | tee initial.log
