get_str_base64_encode(){
    echo -n $1 | base64
}

get_str_replace(){
    echo -n $1 | sed 's/:/%3A/g;s/;/%3B/g;s/=/%3D/g;s/\//%2F/g'
}
# get vps ip
get_ip() {
  local ip=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${ip} ] && ip=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${ip} ] && ip=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    echo ${ip}
	ip=''
	[[ -z $ip ]] && ip=$(curl -s https://ipinfo.io/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.ip.sb/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.ipify.org)
	[[ -z $ip ]] && ip=$(curl -s https://ip.seeip.org)
	[[ -z $ip ]] && ip=$(curl -s https://ifconfig.co/ip)
	[[ -z $ip ]] && ip=$(curl -s https://api.myip.com | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
	[[ -z $ip ]] && ip=$(curl -s icanhazip.com)
	[[ -z $ip ]] && ip=$(curl -s myip.ipip.net | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
	[[ -z $ip ]] && echo -e "\n$red 这垃圾小鸡扔了吧！$none\n" && exit
}

# ss + kcptun show
ss_kcptun_show(){
    local link_head="ss://"
    local cipher_pwd=$(get_str_base64_encode "${SS_METHOD}:${SS_PASSWD}")
    local ip_port_plugin="@$(get_ip):${KCP_PORT}/?plugin=${PLUGIN_CLIENT_NAME}"
    local plugin_opts="sndwnd=${KCP_RCVWND};rcvwnd=${KCP_SNDWND};datashard=${KCP_DATASHARD};parityshard=${KCP_PARITYSHARD};mtu=${KCP_MTU};mode=${KCP_MODE};crypt=${KCP_CRYPT};key=${KCP_PASSWD};dscp=${KCP_DSCP};smuxver=${KCP_SMUXVER};conn=2;keepalive=10;autoexpire=1800;scavengettl=600;sockbuf=16777217;smuxbuf=16777217;streambuf=2097152"
    if [[ ${KCP_NOCOMP} == true ]];then
      plugin_opts=${plugin_opts}";nocomp=${KCP_NOCOMP}"
      # if [[ ${KCP_TCP} == true ]]; then
      #   plugin_opts=${plugin_opts}";tcp=${KCP_TCP}"
      # fi
    fi
    ss_link="${link_head}${cipher_pwd}${ip_port_plugin};${plugin_opts}#$(hostname)"
    local kcptun_paras="--sndwnd ${KCP_RCVWND} --rcvwnd ${KCP_SNDWND} --datashard ${KCP_DATASHARD} --parityshard ${KCP_PARITYSHARD} --mtu ${KCP_MTU} --mode ${KCP_MODE} --crypt ${KCP_CRYPT} --key ${KCP_PASSWD} --dscp ${KCP_DSCP} --smuxver ${KCP_SMUXVER} --conn 2 --keepalive 10 --autoexpire 1800 --scavengettl 600 --sockbuf 16777217 --smuxbuf 16777217 --streambuf 2097152"
    if [[ ${KCP_NOCOMP} == true ]];then
      kcptun_paras=${kcptun_paras}" --nocomp ${KCP_NOCOMP}"
      # if [[ ${KCP_TCP} == true ]]; then
      #   kcptun_paras=${kcptun_paras}" --tcp ${KCP_TCP}"
      # fi
    fi
    echo >> ${HUMAN_CONFIG}
    echo -e " Shadowsocks的配置信息：" >> ${HUMAN_CONFIG}
    echo >> ${HUMAN_CONFIG}
    echo -e " 地址     : ${Red}$(get_ip)${suffix}" >> ${HUMAN_CONFIG}
    echo -e " 端口     : ${Red}${KCP_PORT}${suffix}" >> ${HUMAN_CONFIG}
    echo -e " 密码     : ${Red}${SS_PASSWD}${suffix}" >> ${HUMAN_CONFIG}
    echo -e " 加密     : ${Red}${SS_METHOD}${suffix}" >> ${HUMAN_CONFIG}
    echo -e " 插件程序 : ${Red}${PLUGIN_CLIENT_NAME}${suffix}" >> ${HUMAN_CONFIG}
    echo -e " 插件选项 :                                      " >> ${HUMAN_CONFIG}
    echo -e " 插件参数 : ${Red}-l %SS_LOCAL_HOST%:%SS_LOCAL_PORT% -r %SS_REMOTE_HOST%:%SS_REMOTE_PORT% ${kcptun_paras}${suffix}" >> ${HUMAN_CONFIG}
    echo >> ${HUMAN_CONFIG}
    echo -e " 手机参数 : ${plugin_opts}" >> ${HUMAN_CONFIG}
    echo >> ${HUMAN_CONFIG}
    echo -e " SS  链接 : ${Green}${ss_link}${suffix}" >> ${HUMAN_CONFIG}
    echo >> ${HUMAN_CONFIG}
    echo -e " ${Tip} SS链接${Red}不支持插件参数${suffix}导入，请手动填写。使用${Red}kcptun${suffix}插件时，该链接仅支持${Red}手机${suffix}导入." >> ${HUMAN_CONFIG}
    echo -e "        插件程序下载：https://github.com/xtaci/kcptun/releases 下载 windows-amd64 版本." >> ${HUMAN_CONFIG}
    echo -e "        请解压将带client字样的文件重命名为 ${PLUGIN_CLIENT_NAME}.exe 并移至 SS-Windows 客户端-安装目录的${Red}根目录${suffix}." >> ${HUMAN_CONFIG}
    echo >> ${HUMAN_CONFIG}
}

show_config(){
    ss_kcptun_show
    local mark=$1
    if [ -e $HUMAN_CONFIG ]; then
        if [[ ${mark} == "standalone" ]]; then
            clear -x
        fi
        cat $HUMAN_CONFIG
    else
        echo "The visual configuration was not found."
    fi
}
