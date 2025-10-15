# nginx-quic

follow the below approach:

[ZoeyVid/nginx-quic: Docker image for Nginx + HTTP/3](https://github.com/ZoeyVid/nginx-quic)
[macbre/docker-nginx-http3 ](https://github.com/macbre/docker-nginx-http3)

## Multi platform building

[Multi-platform | Docker Docs](https://docs.docker.com/build/building/multi-platform/)
[containerd image store | Docker Docs](https://docs.docker.com/desktop/features/containerd/)
[目前国内可用Docker镜像源汇总（截至2025年8月） - CoderJia](https://www.coderjia.cn/archives/dba3f94c-a021-468a-8ac6-e840f85867ea)

docker buildx 等 BuildKit 功能构建镜像，在 ~/.docker/config.json 或 buildkit 配置里指定代理：

```json
{
  "proxies": {
    "default": {
      "httpProxy": "http://xxxxx:7890",
      "httpsProxy": "http://xxxxx:7890",
      "noProxy": "localhost,127.0.0.1,github.com"
    }
  }
}

```bash
# 创建目录
sudo mkdir -p /etc/docker

# 写入配置文件
sudo tee /etc/docker/daemon.json <<-'EOF'
{
    "registry-mirrors": [
     "https://docker-0.unsee.tech",
        "https://docker-cf.registry.cyou",
        "https://docker.1panel.live"
    ]
}
EOF

# 重启docker服务
sudo systemctl daemon-reload && sudo systemctl restart docker
```

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx create --name mybuilder --use
docker buildx inspect --bootstrap

docker buildx build --platform linux/amd64,linux/arm64 -t currycan/nginx:1.29.2 --output ./bin .

docker build \
  --platform linux/amd64,linux/arm64 \
  --tag currycan/nginx:1.29.2 \
  --push .
```
