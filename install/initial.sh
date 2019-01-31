#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH


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
    groupadd andrew
    useradd -m andrew -g andrew -s /bin/bash -d /app/andrew
    echo "zzt2008zzt" |passwd --stdin andrew
}

init_centos(){
    echo "ZZT520.596msl*18" |passwd --stdin root
    yum update -y
    yum -y install vim wget net-tools telnet lrzsz lsof bash-completion epel-release
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py
    pip install -U speedtest-cli
    yum install firewalld -y
    systemctl enable firewalld && systemctl start firewalld.service
    firewall-cmd --add-port=38666/tcp --permanent
    firewall-cmd --add-port=2018-2050/tcp --permanent
    firewall-cmd --reload
}

init(){
    echo "root:ZZT520.596msl*18" | chpasswd
    apt update 
    apt upgrade -y
    apt install -y sudo vim wget net-tools telnet lrzsz lsof bash-completion curl
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    python get-pip.py
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
    mkdir -p ~/.ssh/
    curl -so ~/.ssh/authorized_keys https://raw.githubusercontent.com/currycan/key/master/authorized_keys
    curl -so ~/.ssh/id_rsa.pub https://raw.githubusercontent.com/currycan/key/master/id_rsa.pub
    chmod 600  ~/.ssh/*
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
    mkdir -p ~/.ssh/
    curl -so ~/.ssh/authorized_keys https://raw.githubusercontent.com/currycan/key/master/authorized_keys
    curl -so ~/.ssh/id_rsa.pub https://raw.githubusercontent.com/currycan/key/master/id_rsa.pub
    chmod 600  ~/.ssh/*
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
	if [[ "${release}" == "centos" ]]; then
        chcon -R unconfined_u:object_r:user_home_t:s0 /app/
        sed -i '93i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        init_centos
        ssh_centos
	elif [[ "${release}" == "debian" ]]; then
        sed -i '21i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        init
        ssh_init
	elif [[ "${release}" == "ubuntu" ]]; then
        sed -i '21i  andrew    ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers
        init
        ssh_init
	fi
}

initial