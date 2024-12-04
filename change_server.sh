#! /bin/bash

set -e

print_usage () {
    echo "USAGE: change_server <IP>"
}

check_ip() {
    IP=$1
    result=false
    if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        FIELD1=$(echo $IP|cut -d. -f1)
        FIELD2=$(echo $IP|cut -d. -f2)
        FIELD3=$(echo $IP|cut -d. -f3)
        FIELD4=$(echo $IP|cut -d. -f4)
        if [ $FIELD1 -le 255 -a $FIELD2 -le 255 -a $FIELD3 -le 255 -a $FIELD4 -le 255 ]; then
            echo "IP $IP available."
            result=true
        else
            echo "IP $IP not available!"
        fi
    else
        echo "IP format error!"
    fi
}

change_server(){
    perl -pe 's/\b(?:(?!127\.0\.0\.1)\d{1,3}(?:\.\d{1,3}){3})\b/'"$IP"'/g' -i /usr/local/etc/shadowsocks-libev.json
    brew services restart shadowsocks-libev
}


if [ ! -n "$1" ];then
    echo "Server IP doesnt exist, please input IP!"
    print_usage
    exit 1
fi
check_ip $1
case "$result" in
    true)
        change_server
        ;;
    *)
        print_usage
        exit 1
esac
exit 0;

