#!/bin/sh
. /usr/share/openclash/log.sh

# $1 是 OpenClash 传入的当前生成的配置文件路径
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
CONFIG_FILE="$1"

if [ -f "$CONFIG_FILE" ]; then
    log_file_path="/tmp/openclash.log"
    echo "${LOGTIME} - [Custom Overwrite] 开始处理 AnyTLS 协议的跳过证书验证配置..." >> $log_file_path

    # 使用 OpenClash 内置的 Ruby 来安全处理 YAML
    # 逻辑：读取配置 -> 遍历 proxies -> 找到 type 为 anytls 的节点 -> 添加 skip-cert-verify: true -> 保存
    ruby -r yaml -e "
    begin
        config = YAML.load_file('$CONFIG_FILE')
        modified = false

        if config.key?('proxies')
            config['proxies'].each do |proxy|
                # 判断条件：协议类型为 anytls
                # 注意：Clash 配置文件中 type 通常是小写，这里做个强制小写转换以防万一
                if proxy['type'].to_s.downcase == 'anytls'
                    proxy['skip-cert-verify'] = true
                    # 如果需要同时也跳过 UDP 的验证，有些内核版本可能需要 fingerpoint 等其他参数，这里仅处理 TLS 验证
                    modified = true
                end
            end
        end

        if modified
            File.open('$CONFIG_FILE', 'w') { |f| f.write(config.to_yaml) }
            puts 'Modified'
        else
            puts 'NoChange'
        end
    rescue => e
        puts 'Error: ' + e.message
    end
    " >> $log_file_path 2>&1

    echo "${LOGTIME} - [Custom Overwrite] AnyTLS 协议处理完成" >> $log_file_path
else
    echo "${LOGTIME} - [Custom Overwrite] 配置文件未找到，跳过处理" >> /tmp/openclash.log
fi

exit 0
