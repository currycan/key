# /bin/env bash

# docker build -t currycan/acme.sh:1.0.2 .
docker build -t currycan/acme.sh:1.0.3 .

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
docker exec acme.sh --installcert -d ${domain} --fullchainpath ${CERT_PATH} --keypath /${KEY_PATH} --ecc --force

# 查看证书信息
openssl x509 -in /root/acme_out/${domain}_ecc/${domain}.cer -noout -text
# 查看证书过期时间
openssl x509 -in /root/acme_out/${domain}_ecc/${domain}.cer -noout -dates
