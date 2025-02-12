FROM python:3-alpine

WORKDIR /app

# Install dependencies for building some Python packages
# Check if in Github Actions, if not, change Alpine source and PyPI source to Aliyun
ARG GITHUB_ACTIONS
RUN if [ "$GITHUB_ACTIONS" != "true" ]; then \
        sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
        pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/; \
    fi; \
    apk add --no-cache bash build-base libffi-dev openssl-dev gcompat

# Install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the code
COPY . .
RUN chmod +x ./scripts/*.sh

# Set environment variables
ENV RUN_IN_DOCKER=true

CMD ["/bin/sh", "./scripts/run.sh"]
