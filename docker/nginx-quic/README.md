# nginx-quic

follow the below approach:

[ZoeyVid/nginx-quic: Docker image for Nginx + HTTP/3](https://github.com/ZoeyVid/nginx-quic)
[macbre/docker-nginx-http3 ](https://github.com/macbre/docker-nginx-http3)

## Multi platform building

[Multi-platform | Docker Docs](https://docs.docker.com/build/building/multi-platform/)
[containerd image store | Docker Docs](https://docs.docker.com/desktop/features/containerd/)



```bash

vim /etc/docker/daemon.json
#添加配置
{
 "experimental": true
}
systemctl daemon-reload && systemctl restart docker
docker info | grep Experimental # 此时特性将开启

docker run --privileged --rm tonistiigi/binfmt --install all

docker buildx create --name mybuilder --driver docker-container --use

docker buildx use xxx

docker buildx build --platform linux/amd64,linux/arm64 -t currycan/nginx:1.29.2 --output ./bin .

docker build \
  --platform linux/amd64,linux/arm64 \
  --tag currycan/nginx:1.29.2 \
  --push .
```
