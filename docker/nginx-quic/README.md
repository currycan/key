# nginx-quic

follow the below approach:

[ZoeyVid/nginx-quic: Docker image for Nginx + HTTP/3](https://github.com/ZoeyVid/nginx-quic)
[macbre/docker-nginx-http3 ](https://github.com/macbre/docker-nginx-http3)

## Multi platform building

[Multi-platform | Docker Docs](https://docs.docker.com/build/building/multi-platform/)
[containerd image store | Docker Docs](https://docs.docker.com/desktop/features/containerd/)

```bash

docker run --privileged --rm tonistiigi/binfmt --install all

docker buildx create --use --name=mybuilder-cn --driver docker-container --driver-opt image=dockerpracticesig/buildkit:master

docker buildx build --platform linux/amd64,linux/arm64 -t currycan/nginx:1.29.1 --output ./bin .

docker build \
  --platform linux/amd64,linux/arm64 \
  --tag currycan/nginx:1.29.1 \
  --push .
```
