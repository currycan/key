# Subconverter Docker Build Guide

This guide describes how to build the Docker image for `subconverter` supporting multiple architectures (AMD64 and ARM64).

## Prerequisites

- **Docker**: Ensure you have Docker installed.
- **Docker Buildx**: This is required for multi-platform builds. It is included in Docker Desktop and recent versions of Docker Engine.

To verify buildx support:
```bash
docker buildx version
```

## Building the Image

### 1. Local Build (Single Architecture)
If you only need to build for the architecture of your current machine (e.g., just ARM64 on an M1 Mac, or AMD64 on a standard PC):

```bash
# Navigate to the docker/subconverter directory
cd docker/subconverter

# Build the image
docker build -t subconverter:local .
```

### 2. Multi-Architecture Build (AMD64 + ARM64)
To build an image that works on both Intel/AMD chips and ARM chips (like Apple Silicon or Raspberry Pi), follow these steps.

#### Step 1: Create a Buildx Builder
If you haven't already, create a builder instance that supports multi-platform builds:

```bash
# Create a new builder called 'mybuilder'
docker buildx create --name mybuilder --use

# Inspect to ensure it's successfully created and bootstrapped
docker buildx inspect --bootstrap
```

#### Step 2: Build and Push (Recommended)
Multi-arch builds usually require pushing to a registry (like Docker Hub or GitHub Container Registry) because the local Docker daemon acts as a single-architecture store.

```bash
# Login to your registry (if pushing to Docker Hub)
docker login

# Build and Push
docker buildx build --platform linux/amd64,linux/arm64 -t currycan/subconverter:25.12.12 -t currycan/subconverter:latest --push .
```

#### Step 3: Local Export (Alternative)
If you don't want to push to a registry and only want the image for your local architecture loaded into your Docker daemon:

```bash
# This will only load the architecture matching your current docker daemon
docker buildx build --platform linux/amd64,linux/arm64 -t subconverter:local --load .
```
*Note: `--load` typically only supports loading one architecture at a time.*

## Running the Container

Once built, you can run the subconverter container.

```bash
docker run -d \
  --name subconverter \
  --restart always \
  -p 25500:25500 \
  currycan/subconverter:25.12.12
```

### With Custom Configuration
If you want to use your own specific configuration files (e.g., `pref.toml` or `profiles`), mount the `/base` directory or specific files.

```bash
docker run -d \
  --name subconverter \
  -p 25500:25500 \
  -v $(pwd)/base/pref.toml:/base/pref.toml \
  subconverter:local
```

## Troubleshooting

- **QEMU Error**: If you see errors related to `exec format error`, ensure you have QEMU installed for emulation.
  ```bash
  docker run --privileged --rm tonistiigi/binfmt --install all
  ```

- **Build Failures**: Ensure you are in the `docker/subconverter` directory and that the source code is present. The Dockerfile copies the current directory content into the build container.
