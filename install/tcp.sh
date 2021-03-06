#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

set -e

github="raw.githubusercontent.com/chiakge/Linux-NetSpeed/master"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#############系统检测组件#############
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

#检查安装Lotsever的系统要求
check_sys_Lotsever(){
    check_version
    if [[ "${release}" == "centos" ]]; then
        if [[ ${version} == "6" ]]; then
            kernel_version="2.6.32-504"
            installlot
        elif [[ ${version} == "7" ]]; then
            yum -y install net-tools
            kernel_version="3.10.0-327"
            installlot
        else
            echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
        fi
    elif [[ "${release}" == "debian" ]]; then
        if [[ ${bit} == "x64" ]]; then
            kernel_version="3.16.0-4"
            installlot
        elif [[ ${bit} == "x32" ]]; then
            kernel_version="3.2.0-4"
            installlot
        else
            echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
        fi
    elif [[ "${release}" == "ubuntu" ]]; then
        if [[ ${bit} == "x64" ]]; then
            kernel_version="4.4.0-47"
            installlot
        elif [[ ${bit} == "x32" ]]; then
            kernel_version="3.13.0-29"
            installlot
        else
            echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
        fi
    else
        echo -e "${Error} Lotsever不支持当前系统 ${release} ${version} ${bit} !" && exit 1
    fi
}

check_status(){
    kernel_version=`uname -r | awk -F "-" '{print $1}'`-`uname -r | awk -F "-" '{print $2}' | awk -F "." '{print $1}'`
    if [[ ${kernel_version} = "3.13.0-29" || ${kernel_version} = "3.16.0-4" || ${kernel_version} = "3.2.0-4" || ${kernel_version} = "4.4.0-47" || ${kernel_version} = "3.13.0-29"  || ${kernel_version} = "2.6.32-504" ]]; then
        kernel_status="Lotserver"
    else 
        kernel_status="noinstall"
    fi

    if [[ ${kernel_status} == "Lotserver" ]]; then
        if [[ -e /appex/bin/serverSpeeder.sh ]]; then
            run_status=`bash /appex/bin/serverSpeeder.sh status | grep "ServerSpeeder" | awk  '{print $3}'`
            if [[ ${run_status} = "running!" ]]; then
                run_status="启动成功"
            else 
                run_status="启动失败"
            fi
        else 
            run_status="未安装加速模块"
        fi
    fi
}

#安装Lotserver内核
installlot(){
    if [[ "${release}" == "centos" ]]; then
        rpm --import http://${github}/lotserver/${release}/RPM-GPG-KEY-elrepo.org
        yum remove -y kernel-firmware
        # yum install -y http://${github}/lotserver/${release}/${version}/${bit}/kernel-firmware-${kernel_version}.rpm
        yum install -y http://${github}/lotserver/${release}/${version}/${bit}/kernel-${kernel_version}.rpm
        yum remove -y kernel-headers
        yum install -y http://${github}/lotserver/${release}/${version}/${bit}/kernel-headers-${kernel_version}.rpm
        yum install -y http://${github}/lotserver/${release}/${version}/${bit}/kernel-devel-${kernel_version}.rpm
    elif [[ "${release}" == "ubuntu" ]]; then
        mkdir -p bbr && cd bbr
        wget -N --no-check-certificate http://${github}/lotserver/${release}/${bit}/linux-headers-${kernel_version}-all.deb
        wget -N --no-check-certificate http://${github}/lotserver/${release}/${bit}/linux-headers-${kernel_version}.deb
        wget -N --no-check-certificate http://${github}/lotserver/${release}/${bit}/linux-image-${kernel_version}.deb
    
        dpkg -i linux-headers-${kernel_version}-all.deb
        dpkg -i linux-headers-${kernel_version}.deb
        dpkg -i linux-image-${kernel_version}.deb
        cd .. && rm -rf bbr
    elif [[ "${release}" == "debian" ]]; then
        mkdir -p bbr && cd bbr
        wget -N --no-check-certificate http://${github}/lotserver/${release}/${bit}/linux-image-${kernel_version}.deb
    
        dpkg -i linux-image-${kernel_version}.deb
        cd .. && rm -rf bbr
    fi
    detele_kernel
    BBR_grub
    echo -e "${Tip} 重启VPS后，请重新运行脚本开启${Red_font_prefix}Lotserver${Font_color_suffix}"
    stty erase '^H' && read -p "需要重启VPS后，才能开启Lotserver，是否现在重启 ? [Y/n] :" yn
    [ -z "${yn}" ] && yn="y"
    if [[ $yn == [Yy] ]]; then
        echo -e "${Info} VPS 重启中..."
        reboot
    fi
}

#启用Lotserver
startlotserver(){
    remove_all
    if [[ "${release}" == "centos" ]]; then
        yum install -y unzip
    else
        apt-get update
        apt-get install -y unzip
    fi
    wget --no-check-certificate -O appex.sh https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh && chmod +x appex.sh && bash appex.sh install
    rm -f appex.sh
}

#卸载全部加速
remove_all(){
    rm -rf bbrmod
    if [[ -e /appex/bin/serverSpeeder.sh ]]; then
        wget --no-check-certificate -O appex.sh https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh && chmod +x appex.sh && bash appex.sh uninstall
        rm -f appex.sh
    fi
    clear
    echo -e "${Info}:清除加速完成。"
    sleep 1s
}

#删除多余内核
detele_kernel(){
    if [[ "${release}" == "centos" ]]; then
        rpm_total=`rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | wc -l`
        if [ "${rpm_total}" > "1" ]; then
            echo -e "检测到 ${rpm_total} 个其余内核，开始卸载..."
            for((integer = 1; integer <= ${rpm_total}; integer++)); do
                rpm_del=`rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | head -${integer}`
                echo -e "开始卸载 ${rpm_del} 内核..."
                rpm --nodeps -e ${rpm_del}
                echo -e "卸载 ${rpm_del} 内核卸载完成，继续..."
            done
            echo --nodeps -e "内核卸载完毕，继续..."
        else
            echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
        fi
    elif [[ "${release}" == "debian" || "${release}" == "ubuntu" ]]; then
        deb_total=`dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | wc -l`
        if [ "${deb_total}" > "1" ]; then
            echo -e "检测到 ${deb_total} 个其余内核，开始卸载..."
            for((integer = 1; integer <= ${deb_total}; integer++)); do
                deb_del=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | head -${integer}`
                echo -e "开始卸载 ${deb_del} 内核..."
                apt-get purge -y ${deb_del}
                echo -e "卸载 ${deb_del} 内核卸载完成，继续..."
            done
            echo -e "内核卸载完毕，继续..."
        else
            echo -e " 检测到 内核 数量不正确，请检查 !" && exit 1
        fi
    fi
}

#更新引导
BBR_grub(){
    if [[ "${release}" == "centos" ]]; then
        if [[ ${version} = "6" ]]; then
            if [ ! -f "/boot/grub/grub.conf" ]; then
                echo -e "${Error} /boot/grub/grub.conf 找不到，请检查."
                exit 1
            fi
            sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
        elif [[ ${version} = "7" ]]; then
            if [ ! -f "/boot/grub2/grub.cfg" ]; then
                echo -e "${Error} /boot/grub2/grub.cfg 找不到，请检查."
                exit 1
            fi
            grub2-set-default 0
        fi
    elif [[ "${release}" == "debian" ]]; then
        sed -i /etc/default/grub -e "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"Advanced options for Debian GNU\/Linux>Debian GNU\/Linux, with Linux 3.16.0-4-amd64\"/g"
        /usr/sbin/update-grub
    elif [[ "${release}" == "ubuntu" ]]; then
        sed -i /etc/default/grub -e "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"Advanced options for Debian GNU\/Linux>Debian GNU\/Linux, with Linux 4.4.0-47-amd64\"/g"
        /usr/sbin/update-grub
    fi
}

install_kernel(){
    check_status
    if [[ ${kernel_status} == "noinstall" ]]; then
        echo -e " 当前状态: ${Green_font_prefix}未安装${Font_color_suffix} 加速内核 ${Red_font_prefix}请先安装内核${Font_color_suffix}"
        check_sys_Lotsever
    else
        echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} ${_font_prefix}${kernel_status}${Font_color_suffix} 加速内核 , ${Green_font_prefix}${run_status}${Font_color_suffix}"
    fi
}

status(){
    check_status
    if [[ ${kernel_status} == "Lotserver" ]]; then
        echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} ${_font_prefix}${kernel_status}${Font_color_suffix} 加速内核 , ${Green_font_prefix}${run_status}${Font_color_suffix}"
    else
        echo -e " 当前状态: ${Green_font_prefix}未安装${Font_color_suffix} 加速内核 ${Red_font_prefix}请先安装内核${Font_color_suffix}"
        
    fi
}

action=$1
clear
cur_dir=$(pwd)
check_sys
check_version
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
[  -z ${action} ] && action="install"
case "${action}" in
install)
    install_kernel 2>&1 | tee ${cur_dir}/speed.log
    rm -f 1 Debian
    ;;
start)
    startlotserver 2>&1
    rm -f 1 Debian
    ;;
uninstall)
    remove_all 2>&1
    ;;
status)
    status 2>&1 
    ;;  
*)
    clear
    echo "Arguments error! [${action}]"
    echo "Usage: `basename $0` {install|uninstall|start|status}"
    ;;
esac
