#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  CentOS Debian or Ubuntu (32bit/64bit)
#   Description:  A tool to auto-compile & install ssrr on Linux
#   Intro: https://github.com/mongomongu/kcptun_for_ss_ssr/issues
#===============================================================================================
version="0.0.1"
sudo su root
cd ~
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install ssrr"
    exit 1
fi

# PORT
set_ssrr_port1=2018
set_ssrr_port2=2019

# LIBSODIUM
export LIBSODIUM_VER=$(wget -qO- "https://github.com/jedisct1/libsodium/tags"|grep "/jedisct1/libsodium/releases/tag/"|head -1|sed -r 's/.*tag\/(.+)\">.*/\1/')
export LIBSODIUM_LINK="https://github.com/jedisct1/libsodium/releases/download/${LIBSODIUM_VER}/libsodium-${LIBSODIUM_VER}.tar.gz"
# MBEDTLS
export MBEDTLS_VER=2.16.0
export MBEDTLS_LINK="https://tls.mbed.org/download/mbedtls-${MBEDTLS_VER}-gpl.tgz"
# SSRR
# export SSRR_VER=$(wget --no-check-certificate -qO- https://raw.githubusercontent.com/currycan/shadowsocksr/manyuser/shadowsocks/version.py| grep return | cut -d\' -f2 | awk '{print $1}')
export SSRR_VER=$(wget --no-check-certificate -qO- https://raw.githubusercontent.com/shadowsocksrr/shadowsocksr/manyuser/shadowsocks/version.py| grep return | cut -d\' -f2 | awk '{print $1}')

export SSRR_LINK="https://github.com/shadowsocksrr/shadowsocksr/archive/master.zip"
export SSRR_YUM_INIT="https://raw.githubusercontent.com/mongomongu/kcptun_for_ss_ssr/master/ssrr.init"
export SSRR_APT_INIT="https://raw.githubusercontent.com/mongomongu/kcptun_for_ss_ssr/master/ssrr_apt.init"
ssrr_config="/usr/local/shadowsocksrr/user-config.json"
contact_us="https://github.com/mongomongu/kcptun_for_ss_ssr/issues"

fun_clangcn(){
    local clear_flag=""
    clear_flag=$1
    if [[ ${clear_flag} == "clear" ]]; then
        clear
    fi
    echo ""
    echo "+----------------------------------------------------------------+"
    echo "|                    ssrr on Linux Server                        |"
    echo "+----------------------------------------------------------------+"
    echo "|  A tool to auto-compile & install ssrr on Linux   |"
    echo "+----------------------------------------------------------------+"
    echo "| Intro: ${contact_us} |"
    echo "+----------------------------------------------------------------+"
    echo ""
}
fun_set_text_color(){
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}
# Check OS
Get_Dist_Name(){
    release=''
    systemPackage=''
    DISTRO=''
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        release="centos"
        systemPackage='yum'
    elif grep -Eqi "centos|red hat|redhat" /etc/issue || grep -Eqi "centos|red hat|redhat" /etc/*-release; then
        DISTRO='RHEL'
        release="centos"
        systemPackage='yum'
    elif grep -Eqi "Aliyun" /etc/issue || grep -Eq "Aliyun" /etc/*-release; then
        DISTRO='Aliyun'
        release="centos"
        systemPackage='yum'
    elif grep -Eqi "Fedora" /etc/issue || grep -Eq "Fedora" /etc/*-release; then
        DISTRO='Fedora'
        release="centos"
        systemPackage='yum'
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        DISTRO='Debian'
        release="debian"
        systemPackage='apt'
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        release="ubuntu"
        systemPackage='apt'
    elif grep -Eqi "Raspbian" /etc/issue || grep -Eq "Raspbian" /etc/*-release; then
        DISTRO='Raspbian'
        release="debian"
        systemPackage='apt'
    elif grep -Eqi "Deepin" /etc/issue || grep -Eq "Deepin" /etc/*-release; then
        DISTRO='Deepin'
        release="debian"
        systemPackage='apt'
    else
        release='unknow'
    fi
    Get_OS_Bit
}
# Check OS bit
Get_OS_Bit(){
    ARCHS=""
    if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
        Is_64bit='y'
        ARCHS="amd64"
    else
        Is_64bit='n'
        ARCHS="386"
    fi
}
# Check system
check_sys(){
    local checkType=$1
    local value=$2
    if [[ ${checkType} == "sysRelease" ]]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [[ ${checkType} == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}
# Get version
getversion(){
if [[ -s /etc/redhat-release ]]; then
    grep -oE  "[0-9.]+" /etc/redhat-release
else
    grep -oE  "[0-9.]+" /etc/issue
fi
}
# CentOS version
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}
get_opsy(){
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}
debianversion(){
    if check_sys sysRelease debian;then
        local version=$( get_opsy )
        local code=${1}
        local main_ver=$( echo ${version} | sed 's/[^0-9]//g')
        if [ "${main_ver}" == "${code}" ];then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}
Check_OS_support(){
    # Check OS system
    if [ "${release}" == "unknow" ]; then
        echo
        echo -e "${COLOR_RED}Error: Unable to get Linux distribution name, or do NOT support the current distribution.${COLOR_END}"
        echo
        exit 1
    elif [ "${DISTRO}" == "CentOS" ]; then
        if centosversion 5; then
            echo
            echo -e "${COLOR_RED}Not support CentOS 5, please change to CentOS 6 or 7 and try again.${COLOR_END}"
            echo
            exit 1
        fi
    fi
}

Check_crontab(){
	[[ ! -e "/usr/bin/crontab" ]] && echo -e "${Error} 缺少依赖 Crontab ，请尝试手动安装 CentOS: yum install crond -y , Debian/Ubuntu: apt-get install cron -y !" && exit 1
}

Press_Install(){
    echo ""
    echo -e "${COLOR_GREEN}Press any key to install...or Press Ctrl+c to cancel${COLOR_END}"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}

Press_Start(){
    echo ""
    echo -e "${COLOR_GREEN}Press any key to continue...or Press Ctrl+c to cancel${COLOR_END}"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}
Press_Exit(){
    echo ""
    echo -e "${COLOR_GREEN}Press any key to Exit...or Press Ctrl+c${COLOR_END}"
    OLDCONFIG=`stty -g`
    stty -icanon -echo min 1 time 0
    dd count=1 2>/dev/null
    stty ${OLDCONFIG}
}
Print_Sys_Info(){
    cat /etc/issue
    cat /etc/*-release
    uname -a
    MemTotal=`free -m | grep Mem | awk '{print  $2}'`
    echo "Memory is: ${MemTotal} MB "
    df -h
}
Disable_Selinux(){
    if [ -s /etc/selinux/config ]; then
        sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
    fi
}
pre_install_packs(){
    local wget_flag=''
    local killall_flag=''
    local netstat_flag=''
    wget --version > /dev/null 2>&1
    wget_flag=$?
    killall -V >/dev/null 2>&1
    killall_flag=$?
    netstat --version >/dev/null 2>&1
    netstat_flag=$?
    if [[ ${wget_flag} -gt 1 ]] || [[ ${killall_flag} -gt 1 ]] || [[ ${netstat_flag} -gt 6 ]];then
        echo -e "${COLOR_GREEN} Install support packs...${COLOR_END}"
        if check_sys packageManager yum; then
            yum install -y wget psmisc net-tools
        elif check_sys packageManager apt; then
            apt-get -y update && apt-get -y install wget psmisc net-tools
        fi
    fi
}
get_ip(){
    local IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
    [ -z ${IP} ] && IP=$(wget -qO- -t1 -T2 ip.clang.cn | sed -r 's/\r//')
    [ -z ${IP} ] && IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com | sed -r 's/\r//')
    [ ! -z ${IP} ] && echo ${IP} || echo
}
# Install cleanup
install_cleanup(){
    cd ${cur_dir}
    rm -rf .version.sh shadowsocks-libev-* manyuser.zip shadowsocksr-manyuser shadowsocks-manyuser kcptun-linux-* libsodium-* mbedtls-* shadowsocksr-akkariiin-master ssrr.zip
}
check_ssr_installed(){
    ssrr_install_flag=""
    if [[ -x /usr/local/shadowsocksrr/shadowsocks/server.py ]] && [[ -s /usr/local/shadowsocksrr/shadowsocks/__init__.py ]]; then
        ssrr_installed_flag="true"
    else
        ssrr_installed_flag="false"
    fi
}
get_latest_version(){
    rm -f ${cur_dir}/.api_*.txt
    if [ ! -f /usr/lib/libsodium.a ] && [ ! -L /usr/local/lib/libsodium.so ]; then
        #echo -e "Loading libsodium version, please wait..."
        libsodium_laster_ver="libsodium-${LIBSODIUM_VER}"
        if [ "${libsodium_laster_ver}" == "" ] || [ "${LIBSODIUM_LINK}" == "" ]; then
            echo -e "${COLOR_RED}Error: Get libsodium version failed${COLOR_END}"
            exit 1
        fi
        #echo -e "Get the libsodium version:${COLOR_GREEN} ${LIBSODIUM_VER}${COLOR_END}"
    fi
    if [ ! -f /usr/lib/libmbedtls.a ] && [ ! -f /usr/include/mbedtls/version.h ]; then
        #echo -e "Loading mbedtls version, please wait..."
        mbedtls_laster_ver="mbedtls-${MBEDTLS_VER}"
        if [ "${mbedtls_laster_ver}" == "" ] || [ "${MBEDTLS_LINK}" == "" ]; then
            echo -e "${COLOR_RED}Error: Get mbedtls version failed${COLOR_END}"
            exit 1
        fi
        #echo -e "Get the mbedtls version:${COLOR_GREEN} ${MBEDTLS_VER}${COLOR_END}"
    fi
    if [[ "${ssrr_installed_flag}" == "false" && "${clang_action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]] || [[ "${ssrr_installed_flag}" == "true" && "${clang_action}" =~ ^[Uu]|[Uu][Pp][Dd][Aa][Tt][Ee]|-[Uu]|--[Uu]|[Uu][Pp]|-[Uu][Pp]|--[Uu][Pp]$ ]]; then
        echo -e "Loading Shadowsocksrr version, please wait..."
        ssrr_download_link="${SSRR_LINK}"
        ssrr_latest_ver="${SSRR_VER}"
        if check_sys packageManager yum; then
            ssrr_init_link="${SSRR_YUM_INIT}"
        elif check_sys packageManager apt; then
            ssrr_init_link="${SSRR_APT_INIT}"
        fi
        if [[ "${ssrr_installed_flag}" == "false" && "${clang_action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]]; then
            echo -e "Get the Shadowsocksrr version:${COLOR_GREEN} ${SSRR_VER}${COLOR_END}"
        fi
    fi
}
# Download latest
download_for_ssrr(){
    if [ ! -f /usr/lib/libsodium.a ] && [ ! -L /usr/local/lib/libsodium.so ]; then
        if [ -f ${libsodium_laster_ver}.tar.gz ]; then
            echo "${libsodium_laster_ver}.tar.gz [found]"
        else
            if ! wget --no-check-certificate -O ${libsodium_laster_ver}.tar.gz ${LIBSODIUM_LINK}; then
                echo -e "${COLOR_RED}Failed to download ${libsodium_laster_ver}.tar.gz${COLOR_END}"
                exit 1
            fi
        fi
    fi
    if [[ "${ssrr_installed_flag}" == "false" && "${clang_action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]] || [[ "${ssrr_installed_flag}" == "true" && "${ssrr_update_flag}" == "true" && "${clang_action}" =~ ^[Uu]|[Uu][Pp][Dd][Aa][Tt][Ee]|-[Uu]|--[Uu]|[Uu][Pp]|-[Uu][Pp]|--[Uu][Pp]$ ]]; then
        if [ -f ssrr.zip ]; then
            echo "ssrr.zip [found]"
        else
            if ! wget --no-check-certificate -O ssrr.zip ${ssrr_download_link}; then
                echo -e "${COLOR_RED}Failed to download Shadowsocksrr file!${COLOR_END}"
                exit 1
            fi
        fi
        if ! wget --no-check-certificate -O /etc/init.d/ssrr ${ssrr_init_link}; then
            echo -e "${COLOR_RED}Failed to download Shadowsocksrr init script!${COLOR_END}"
            exit 1
        fi
    fi
}
config_for_ssrr(){
    if [[ "${ssrr_installed_flag}" == "false" && "${clang_action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]]; then
        [ ! -d /usr/local/shadowsocksrr ] && mkdir -p /usr/local/shadowsocksrr
    fi
    curl -o /usr/local/shadowsocksrr/user-config.json https://raw.githubusercontent.com/currycan/key/master/user-config.json
}
install_for_ssrr(){
    #if [[ "${ss_libev_installed_flag}" == "false" && "${clang_action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]] || [[ "${ssr_installed_flag}" == "false" && "${clang_action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]] || [[ "${kcptun_installed_flag}" == "false" && "${clang_action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]]; then
        if check_sys packageManager yum; then
            yum install -y epel-release
            yum install -y unzip openssl-devel gcc swig autoconf libtool libevent vim automake make psmisc curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel xmlto asciidoc pcre pcre-devel python python-devel python-setuptools udns-devel libev-devel c-ares-devel mbedtls-devel
            if [ $? -gt 1 ]; then
                echo
                echo -e "${COLOR_RED}Install support packs failed!${COLOR_END}"
                exit 1
            fi
        elif check_sys packageManager apt; then
            if debianversion 7; then
                grep "jessie" /etc/apt/sources.list > /dev/null 2>&1
                if [ $? -ne 0 ] && [ -r /etc/apt/sources.list ]; then
                    echo "deb http://http.us.debian.org/debian jessie main" >> /etc/apt/sources.list
                fi
            fi
            apt-get -y update && apt-get -y install --no-install-recommends gettext curl wget vim unzip psmisc gcc swig autoconf automake make perl cpio build-essential libtool openssl libssl-dev zlib1g-dev xmlto asciidoc libpcre3 libpcre3-dev python python-dev python-pip python-m2crypto libev-dev libc-ares-dev libudns-dev
            if [ $? -gt 1 ]; then
                echo
                echo -e "${COLOR_RED}Install support packs failed!${COLOR_END}"
                exit 1
            fi
        fi
    #fi
    if [ ! -f /usr/lib/libsodium.a ] && [ ! -L /usr/local/lib/libsodium.so ]; then
        cd ${cur_dir}
        echo "+ Install libsodium for SS-Libev/SSR/KCPTUN"
        tar xzf ${libsodium_laster_ver}.tar.gz
        cd ${libsodium_laster_ver}
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            install_cleanup
            echo -e "${COLOR_RED}libsodium install failed!${COLOR_END}"
            exit 1
        fi
        ldconfig
        #echo "/usr/lib" > /etc/ld.so.conf.d/local.conf
    fi
    if [[ "${ssrr_installed_flag}" == "false" && "${clang_action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]] || [[ "${ssrr_installed_flag}" == "true" && "${ssrr_update_flag}" == "true" && "${clang_action}" =~ ^[Uu]|[Uu][Pp][Dd][Aa][Tt][Ee]|-[Uu]|--[Uu]|[Uu][Pp]|-[Uu][Pp]|--[Uu][Pp]$ ]]; then
        cd ${cur_dir}
        unzip -qo ssrr.zip
        mv shadowsocksr-akkariiin-master/* /usr/local/shadowsocksrr/
        if [ -x /usr/local/shadowsocksrr/shadowsocks/server.py ] && [ -s /usr/local/shadowsocksrr/shadowsocks/__init__.py ]; then
            chmod +x /etc/init.d/ssrr
            if check_sys packageManager yum; then
                chkconfig --add ssrr
                chkconfig ssrr on
            elif check_sys packageManager apt; then
                update-rc.d -f ssrr defaults
            fi
            /etc/init.d/ssrr start
            if [ $? -eq 0 ]; then
                [ -x /etc/init.d/ssrr ] && ln -s /etc/init.d/ssrr /usr/bin/ssrr
                echo -e "${COLOR_GREEN}Shadowsocksrr start success!${COLOR_END}"
            else
                echo -e "${COLOR_RED}Shadowsocksrr start failure!${COLOR_END}"
            fi
            ssrr_install_flag="true"
        else
            install_cleanup
            echo
            echo -e "${COLOR_RED}Shadowsocksrr install failed! Please visit ${contact_us} and contact.${COLOR_END}"
            exit 1
        fi
    fi
    install_cleanup
}
# Firewall set
firewall_set(){
    if [ "${ssrr_install_flag}" == "true" ]; then
        echo "+ firewall set start..."
        firewall_set_flag="false"
        if centosversion 6; then
            /etc/init.d/iptables status > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                if [ "${ssrr_install_flag}" == "true" ]; then
                    iptables -L -n | grep -i ${set_ssrr_port} > /dev/null 2>&1
                    if [ $? -ne 0 ]; then
                        iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${set_ssrr_port1} -j ACCEPT
                        iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${set_ssrr_port1} -j ACCEPT
                        iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${set_ssrr_port2} -j ACCEPT
                        iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${set_ssrr_port2} -j ACCEPT
                        firewall_set_flag="true"
                    else
                        echo "+ port ${set_ssrr_port} has been set up."
                    fi
                fi
            else
                echo "WARNING: iptables looks like shutdown or not installed, please manually set it if necessary."
            fi
        elif centosversion 7; then
            systemctl status firewalld > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                if [ "${ssrr_install_flag}" == "true" ]; then
                    firewall-cmd --permanent --zone=public --add-port=${set_ssrr_port1}/tcp
                    firewall-cmd --permanent --zone=public --add-port=${set_ssrr_port1}/udp
                    firewall-cmd --permanent --zone=public --add-port=${set_ssrr_port2}/tcp
                    firewall-cmd --permanent --zone=public --add-port=${set_ssrr_port2}/udp
                    firewall_set_flag="true"
                fi
                if [ "${firewall_set_flag}" == "true" ]; then
                    firewall-cmd --reload
                fi
            else
                echo "+ Firewalld looks like not running, try to start..."
                systemctl start firewalld
                if [ $? -eq 0 ]; then
                    if [ "${ssrr_install_flag}" == "true" ]; then
                        firewall-cmd --permanent --zone=public --add-port=${set_ssrr_port1}/tcp
                        firewall-cmd --permanent --zone=public --add-port=${set_ssrr_port1}/udp
                        firewall-cmd --permanent --zone=public --add-port=${set_ssrr_port2}/tcp
                        firewall-cmd --permanent --zone=public --add-port=${set_ssrr_port}2/udp
                        firewall_set_flag="true"
                    fi
                    if [ "${firewall_set_flag}" == "true" ]; then
                        firewall-cmd --reload
                    fi
                else
                    echo "WARNING: Try to start firewalld failed. please enable port manually if necessary."
                fi
            fi
        fi
        echo "+ firewall set completed..."
    fi
}
show_for_ssrr(){
    echo
    if [ "${ssrr_install_flag}" == "true" ]; then
        SERVER_IP=$(get_ip)
        fun_clangcn
        echo "Congratulations, install completed!"
        echo -e "========================= Your Server Setting ========================="
        echo -e "Your Server IP: ${COLOR_GREEN}${SERVER_IP}${COLOR_END}"
    fi
    nl ${ssrr_config}
    echo
}
crontab_monitor_ssr(){
    curl -o /usr/local/bin/check.sh https://raw.githubusercontent.com/currycan/check/master/check.sh
    chmod +x /usr/local/bin/check.sh
    touch /var/log/shadowsocks-crond.log
    (crontab -l ; echo "*/5 * * * * /usr/local/bin/check.sh") | crontab -
    crontab -u root -l
}

pre_install_for_ssrr(){
    fun_clangcn "clear"
    # Press_Install
    Print_Sys_Info
    Disable_Selinux
    check_ssr_installed
    cd ${cur_dir}
    ###############################   Shadowsocksrr   ###############################
    if [ "${ssrr_installed_flag}" == "false" ]; then
        echo
        echo "=========================================================="
        echo -e "${COLOR_PINK}configure Shadowsocksrr(SSRR) setting:${COLOR_END}"
        curl -o /usr/local/shadowsocksrr/user-config.json https://raw.githubusercontent.com/currycan/key/master/user-config.json
        echo "=========================================================="
    elif [ "${ssrr_installed_flag}" == "true" ]; then
        echo
        echo -e "${COLOR_PINK}Shadowsocksrr has been installed, nothing to do...${COLOR_END}"
        exit 0
    fi
    # Press_Start
    get_latest_version
    download_for_ssrr
    config_for_ssrr
    install_for_ssrr
    crontab_monitor_ssr
    install_cleanup
    if check_sys packageManager yum; then
        firewall_set
    fi
    show_for_ssrr
}
uninstall_for_ssrr(){
    Get_Dist_Name
    fun_clangcn "clear"
    echo -e "${COLOR_PINK}You will Uninstall Shadowsocksrr(python)${COLOR_END}"
    # Press_Start
    check_ssr_installed
    if [ "${ssrr_installed_flag}" == "true" ]; then
        /etc/init.d/ssrr status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/ssrr stop
        fi
        if check_sys packageManager yum; then
            chkconfig --del ssrr
        elif check_sys packageManager apt; then
            update-rc.d -f ssrr remove
        fi
        rm -f ${ssrr_config}
        rm -f /usr/bin/ssrr
        rm -f /etc/init.d/ssrr
        rm -f /var/log/shadowsocksrr.log
        rm -rf /usr/local/shadowsocksrr
        echo -e "${COLOR_GREEN}Shadowsocksrr uninstall success!${COLOR_END}"
    else
        echo -e "${COLOR_GREEN}Shadowsocksrr not install!${COLOR_END}"
    fi
}
configure_for_ssr(){
    if [ -f ${ssrr_config} ]; then
        echo -e "Shadowsocksrr config file:  ${COLOR_GREEN}${ssrr_config}${COLOR_END}"
    fi
}
update_for_ssr(){
    ssr_update_flag="false"
    fun_clangcn "clear"
    echo -e "${COLOR_PINK}You will update Shadowsocksrr(python)${COLOR_END}"
    check_ssr_installed
    get_latest_version
    echo "+-------------------------------------------------------------+"
    if [ "${ssrr_installed_flag}" == "true" ]; then
        ssrr_local_ver=$(ssrr version | grep -i "SSRR" | awk '{print $3}')
        if [ -z ${ssrr_local_ver} ] || [ -z ${SSRR_VER} ]; then
            echo -e "${COLOR_RED}Error: Get Shadowsocksrr shell version failed${COLOR_END}"
        else
            echo -e "Shadowsocksrr shell version : ${COLOR_GREEN}${SSRR_VER}${COLOR_END}"
            echo -e "Shadowsocksrr local version : ${COLOR_GREEN}${ssrr_local_ver}${COLOR_END}"
            if [[ "${ssrr_local_ver}" != "${SSRR_VER}" ]];then
                ssrr_update_flag="true"
            else
                echo "Shadowsocksrr local version is up-to-date."
            fi
        fi
    else
        echo -e "${COLOR_RED}Shadowsocksrr not install!${COLOR_END}"
    fi
    if [[ "${ssrr_update_flag}" == "true" ]]; then
        echo "+-------------------------------------------------------------+"
        echo -e "${COLOR_GREEN}Found a new version,update now...${COLOR_END}"
        # Press_Start
    fi
    if [[ "${ssrr_installed_flag}" == "true" && "${ssrr_update_flag}" == "true" ]]; then
        /etc/init.d/ssrr status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/ssrr stop
        fi
        if check_sys packageManager yum; then
            chkconfig --del ssrr
        elif check_sys packageManager apt; then
            update-rc.d -f ssrr remove
        fi
        rm -f /usr/bin/ssrr
        rm -f /etc/init.d/ssrr
        rm -f /var/log/shadowsocksrr.log
        rm -rf /usr/local/shadowsocksrr
    fi
    if [[ "${ssrr_update_flag}" == "true" ]]; then
        download_for_ssrr
        install_for_ssrr
        install_cleanup
    else
        echo
        echo -e "nothing to do..."
        echo
        exit 1
    fi
    if [[ "${ssrr_install_flag}" == "true" ]]; then
        fun_clangcn
        echo "Congratulations, update completed, Enjoy it!"
        echo
    else
        echo
        echo -e "${COLOR_RED}Update failed! Please visit ${contact_us} and contact.${COLOR_END}"
        exit 1
    fi
}

fun_set_text_color
# Initialization
clang_action=$1
clear
cur_dir=$(pwd)
fun_clangcn "clear"
Get_Dist_Name
Check_OS_support
Check_crontab
pre_install_packs
[  -z ${clang_action} ] && clang_action="install"
case "${clang_action}" in
[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii])
    pre_install_for_ssrr 2>&1 | tee ${cur_dir}/install.log
    ;;
[Cc]|[Cc][Oo][Nn][Ff][Ii][Gg]|-[Cc]|--[Cc])
    configure_for_ssr
    ;;
[Uu][Nn]|[Uu][Nn][Ii][Nn][Ss][Tt][Aa][Ll][Ll]|[Uu][Nn]|-[Uu][Nn]|--[Uu][Nn])
    uninstall_for_ssrr 2>&1 | tee ${cur_dir}/uninstall.log
    ;;
[Uu]|[Uu][Pp][Dd][Aa][Tt][Ee]|-[Uu]|--[Uu]|[Uu][Pp]|-[Uu][Pp]|--[Uu][Pp])
    update_for_ssr 2>&1 | tee ${cur_dir}/update.log
    ;;
*)
    fun_clangcn "clear"
    echo "Arguments error! [${clang_action}]"
    echo "Usage: `basename $0` {install|uninstall|update|config}"
    ;;
esac
