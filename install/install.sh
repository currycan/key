#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  CentOS Debian or Ubuntu (32bit/64bit)
#   Description:  A tool to auto-compile & install ssrr on Linux
#===============================================================================================
version="0.0.1"
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install ssrr"
    exit 1
fi

# LIBSODIUM
export LIBSODIUM_VER=$(wget -qO- "https://github.com/jedisct1/libsodium/tags"|grep "/jedisct1/libsodium/releases/tag/"|head -1|sed -r 's/.*tag\/(.+)\">.*/\1/')
export LIBSODIUM_LINK="https://github.com/jedisct1/libsodium/releases/download/${LIBSODIUM_VER}-RELEASE/libsodium-${LIBSODIUM_VER}.tar.gz"

# MBEDTLS
export MBEDTLS_VER=$(wget -qO- "https://tls.mbed.org/download"|grep "(GPL)"|cut -d'-' -f2)
export MBEDTLS_LINK="https://tls.mbed.org/download/mbedtls-${MBEDTLS_VER}-gpl.tgz"
# SSRR
export SSRR_VER=$(wget -qO- "https://github.com/shadowsocksrr/shadowsocksr/tags"|grep "/shadowsocksrr/shadowsocksr/releases/tag/"|head -1|sed -r 's/.*tag\/(.+)\">.*/\1/')
export SSRR_LINK="https://github.com/shadowsocksrr/shadowsocksr/archive/${SSRR_VER}.tar.gz"
export SSRR_INIT="https://raw.githubusercontent.com/currycan/key/master/install/ssrr.init"

ssr_folder="/usr/local/shadowsocksrr/"
config_user_api_file="${ssr_folder}/userapiconfig.py"
config_user_file="${ssr_folder}/user-config.json"
ssrr_config="/usr/local/shadowsocksrr/user-configR.json"
ssr_config="/usr/local/shadowsocksrr/user-config.json"
mudbjson="/usr/local/shadowsocksrr/mudb.json"


fun_clear(){
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
# Disable selinux
Disable_Selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
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
Print_Sys_Info(){
    cat /etc/issue
    cat /etc/*-release
    uname -a
    MemTotal=`free -m | grep Mem | awk '{print  $2}'`
    echo "Memory is: ${MemTotal} MB "
    df -h
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
    rm -rf .version.sh shadowsocks-libev-* manyuser.zip shadowsocksr-manyuser shadowsocks-manyuser kcptun-linux-* libsodium-* mbedtls-* shadowsocksr-* ssrr.zip
}
# Check installed
check_ssr_installed(){
    ssrr_install_flag=""
    if [[ -x /usr/local/shadowsocksrr/shadowsocks/server.py ]] && [[ -s /usr/local/shadowsocksrr/shadowsocks/__init__.py ]]; then
        ssrr_installed_flag="true"
    else
        ssrr_installed_flag="false"
    fi
}
# Get latest version
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
    if [[ "${ssrr_installed_flag}" == "false" && "${action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]] || [[ "${ssrr_installed_flag}" == "true" && "${action}" =~ ^[Uu]|[Uu][Pp][Dd][Aa][Tt][Ee]|-[Uu]|--[Uu]|[Uu][Pp]|-[Uu][Pp]|--[Uu][Pp]$ ]]; then
        echo -e "Loading Shadowsocksrr version, please wait..."
        ssrr_download_link="${SSRR_LINK}"
        ssrr_latest_ver="${SSRR_VER}"
        ssrr_init_link="${SSRR_INIT}"
        if [[ "${ssrr_installed_flag}" == "false" && "${action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]]; then
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
            echo -e "${COLOR_RED}start to download ${libsodium_laster_ver}.tar.gz${COLOR_END}"
            wget --no-cookie --no-check-certificate -O ${libsodium_laster_ver}.tar.gz ${LIBSODIUM_LINK}
        fi
    fi
    if [[ "${ssrr_installed_flag}" == "false" && "${action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]] || [[ "${ssrr_installed_flag}" == "true" && "${ssrr_update_flag}" == "true" && "${action}" =~ ^[Uu]|[Uu][Pp][Dd][Aa][Tt][Ee]|-[Uu]|--[Uu]|[Uu][Pp]|-[Uu][Pp]|--[Uu][Pp]$ ]]; then
        if [ -f shadowsocksr-${ssrr_latest_ver}.tar.gz ]; then
            echo "shadowsocksr-${ssrr_latest_ver}.tar.gz [found]"
        else
            echo -e "${COLOR_RED}start to download Shadowsocksrr file!${COLOR_END}"
            wget --no-cookie --no-check-certificate -O shadowsocksr-${ssrr_latest_ver}.tar.gz ${ssrr_download_link}
            echo -e "${COLOR_RED}start to download Shadowsocksrr init script!${COLOR_END}"
            wget --no-cookie --no-check-certificate -O /etc/init.d/ssrr ${ssrr_init_link}
        fi
    fi
}
# Downlaod config
config_for_ssrr(){
    mkdir -p /usr/local/shadowsocksrr
    rm -f ${ssrr_config} ${ssr_config}
    wget --no-cookie --no-check-certificate -O ${ssrr_config} https://raw.githubusercontent.com/currycan/key/master/user-configR.json
    wget --no-cookie --no-check-certificate -O ${ssr_config} https://raw.githubusercontent.com/currycan/key/master/user-config.json
}
# Install ssr
install_for_ssrr(){
    if check_sys packageManager yum; then
        yum install -y epel-release
        yum install -y unzip openssl-devel gcc swig autoconf libtool libevent vim automake make psmisc curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel xmlto asciidoc pcre pcre-devel python3 libev-devel c-ares-devel mbedtls-devel
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
    if [ ! -f /usr/lib/libsodium.a ] && [ ! -L /usr/local/lib/libsodium.so ]; then
        cd ${cur_dir}
        echo "+ Install libsodium"
        tar xzf ${libsodium_laster_ver}.tar.gz
        cd ${libsodium_laster_ver}
        ./configure && make -j4 && make install
        if [ $? -ne 0 ]; then
            install_cleanup
            echo -e "${COLOR_RED}libsodium install failed!${COLOR_END}"
            exit 1
        fi
        ldconfig
        #echo "/usr/lib" > /etc/ld.so.conf.d/local.conf
    fi
    if [[ "${ssrr_installed_flag}" == "false" && "${action}" =~ ^[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii]$ ]] || [[ "${ssrr_installed_flag}" == "true" && "${ssrr_update_flag}" == "true" && "${action}" =~ ^[Uu]|[Uu][Pp][Dd][Aa][Tt][Ee]|-[Uu]|--[Uu]|[Uu][Pp]|-[Uu][Pp]|--[Uu][Pp]$ ]]; then
        # cd ${cur_dir}
        # tar xzf shadowsocksr-${ssrr_latest_ver}.tar.gz
        # mv shadowsocksr-${ssrr_latest_ver}/* /usr/local/shadowsocksrr/
        git clone -b akkariiin/dev https://github.com/shadowsocksrr/shadowsocksr.git
        mv shadowsocksr/* /usr/local/shadowsocksrr/
        cp "${ssr_folder}/apiconfig.py" "${config_user_api_file}"
        cp "${ssr_folder}/config.json" "${config_user_file}"
        cp "${ssr_folder}/mysql.json" "${ssr_folder}/usermysql.json"
        [[ ! -e ${config_user_api_file} ]] && echo -e "${Error} ShadowsocksR服务端 apiconfig.py 复制失败 !" && exit 1
	    sed -i "s/API_INTERFACE = 'sspanelv2'/API_INTERFACE = 'mudbjson'/" ${config_user_api_file}
        server_pub_addr=$(cat ${config_user_api_file}|grep "SERVER_PUB_ADDR = "|awk -F "[']" '{print $2}')
        ssr_server_pub_addr=$(get_ip)
        sed -i "s/SERVER_PUB_ADDR = '${server_pub_addr}'/SERVER_PUB_ADDR = '${ssr_server_pub_addr}'/" ${config_user_api_file}
        sed -i 's/ \/\/ only works under multi-user mode//g' "${config_user_file}"
        wget --no-cookie --no-check-certificate -O ${mudbjson} https://raw.githubusercontent.com/currycan/key/master/mudb.json

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
            echo -e "${COLOR_RED}Shadowsocksrr install failed!${COLOR_END}"
            exit 1
        fi
    fi
    install_cleanup
}
# Show config
show_for_ssrr(){
    echo
    if [ "${ssrr_install_flag}" == "true" ]; then
        SERVER_IP=$(get_ip)
        fun_clear
        echo "Congratulations, install completed!"
        echo -e "========================= Your Server Setting ========================="
        echo -e "Your Server IP: ${COLOR_GREEN}${SERVER_IP}${COLOR_END}"
    fi
    nl ${ssrr_config}
    echo "=========================================="
    nl ${mudbjson}
    echo "=========================================="
    echo
}
# check ssr
crontab_monitor_ssr(){
    curl -o /usr/local/bin/check.sh https://raw.githubusercontent.com/currycan/check/master/check.sh
    chmod +x /usr/local/bin/check.sh
    touch /var/log/shadowsocks-crond.log
    (crontab -l ; echo "*/5 * * * * /usr/local/bin/check.sh") | crontab -
    crontab -u root -l
}
# install
pre_install_for_ssrr(){
    fun_clear "clear"
    Print_Sys_Info
    Disable_Selinux
    check_ssr_installed
    cd ${cur_dir}
    ###############################   Shadowsocksrr   ###############################
    if [ "${ssrr_installed_flag}" == "false" ]; then
        echo
        echo "=========================================================="
        echo -e "${COLOR_PINK}configure Shadowsocksrr(SSRR) setting:${COLOR_END}"   
        echo "=========================================================="
    elif [ "${ssrr_installed_flag}" == "true" ]; then
        echo
        echo -e "${COLOR_PINK}Shadowsocksrr has been installed, nothing to do...${COLOR_END}"
        exit 0
    fi
    get_latest_version
    download_for_ssrr
    config_for_ssrr
    install_for_ssrr
    crontab_monitor_ssr
    install_cleanup
    show_for_ssrr
}
uninstall_for_ssrr(){
    Get_Dist_Name
    fun_clear "clear"
    echo -e "${COLOR_PINK}You will Uninstall Shadowsocksrr(python)${COLOR_END}"
    check_ssr_installed
    if [ "${ssrr_installed_flag}" == "true" ]; then
        /etc/init.d/ssrr status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/ssrr stop > /dev/null 2>&1
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
    install_cleanup
}

update_for_ssr(){
    ssr_update_flag="false"
    fun_clear "clear"
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
        fun_clear
        echo "Congratulations, update completed, Enjoy it!"
        echo
    else
        echo
        echo -e "${COLOR_RED}Update failed!${COLOR_END}"
        exit 1
    fi
}

fun_set_text_color
# Initialization
action=$1
clear
cur_dir=$(pwd)
fun_clear "clear"
Get_Dist_Name
Check_OS_support
[  -z ${action} ] && action="install"
case "${action}" in
[Ii]|[Ii][Nn]|[Ii][Nn][Ss][Tt][Aa][Ll][Ll]|-[Ii]|--[Ii])
    pre_install_for_ssrr 2>&1 | tee ${cur_dir}/ssr_install.log
    ;;
[Uu][Nn]|[Uu][Nn][Ii][Nn][Ss][Tt][Aa][Ll][Ll]|[Uu][Nn]|-[Uu][Nn]|--[Uu][Nn])
    uninstall_for_ssrr 2>&1 | tee ${cur_dir}/ssr_uninstall.log
    ;;
[Uu]|[Uu][Pp][Dd][Aa][Tt][Ee]|-[Uu]|--[Uu]|[Uu][Pp]|-[Uu][Pp]|--[Uu][Pp])
    update_for_ssr 2>&1 | tee ${cur_dir}/ssr_update.log
    ;;
*)
    fun_clear "clear"
    echo "Arguments error! [${action}]"
    echo "Usage: `basename $0` {install|uninstall|update}"
    ;;
esac
