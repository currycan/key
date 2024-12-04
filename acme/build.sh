# /bin/env bash

docker build -t currycan/acme.sh:1.0.4 .

# 运行服务
docker run --rm -itd --name=acme.sh \
  -v ~/acme_out:/acme.sh \
  --net=host \
  currycan/acme.sh:1.0.3 daemon

docker run --rm -itd --name=acme.sh \
  -v /root/acme_out:/acme.sh \
  --net=host \
  currycan/acme.sh:1.0.3 daemon

# 生成证书
docker exec acme.sh --help

domain=big.ansandy.com
domain=hk.ansandy.com
# 证书测试签发
docker exec acme.sh --issue -d "${domain}" --standalone -k ec-256 --force --test
rm -rf /root/acme_out/${domain}_ecc
docker exec acme.sh --issue -d "${domain}" --standalone -k ec-256 --force
docker exec acme.sh --installcert -d ${domain} --fullchainpath ${SSL_PATH}/${DOMAIN}.crt --keypath /${SSL_PATH}/${DOMAIN}.key --ecc --force

acme.sh --installcert -d ${domain} --fullchainpath ${SSL_PATH}/${DOMAIN}.crt --keypath "/etc/v2ray-agent/tls/${tlsDomain}.key" --ecc >/dev/null

# 查看证书信息
openssl x509 -in /root/acme_out/${domain}_ecc/${domain}.cer -noout -text
# 查看证书过期时间
openssl x509 -in /root/acme_out/${domain}_ecc/${domain}.cer -noout -dates
