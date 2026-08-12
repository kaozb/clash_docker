FROM alpine:3.21

ENV SAFE_PATHS="/root/clash/dashboard/public"
ENV MIHOMO_VERSION="v1.19.29"

# 运行时依赖：bash(脚本使用 bash 语法)、openssl(生成 secret)、
# curl/wget(下载订阅配置)、ca-certificates(TLS)、libc6-compat(运行 glibc 二进制如 subconverter)
RUN apk add --no-cache bash openssl curl wget ca-certificates libc6-compat && \
    ARCH=$(apk --print-arch) && \
    case "$ARCH" in \
        x86_64)  PKG="mihomo-linux-amd64-compatible-${MIHOMO_VERSION}.gz" ;; \
        aarch64) PKG="mihomo-linux-arm64-${MIHOMO_VERSION}.gz" ;; \
        armhf|armv6) PKG="mihomo-linux-armv6-${MIHOMO_VERSION}.gz" ;; \
        armv7)   PKG="mihomo-linux-armv7-${MIHOMO_VERSION}.gz" ;; \
        *)       PKG="mihomo-linux-armv7-${MIHOMO_VERSION}.gz" ;; \
    esac && \
    wget -q "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/${PKG}" -O /tmp/mihomo.gz && \
    gzip -dc /tmp/mihomo.gz > /usr/local/bin/mihomo && \
    chmod +x /usr/local/bin/mihomo && \
    rm -f /tmp/mihomo.gz

ADD . /root/

RUN chmod +x /root/endpoint.sh

CMD /root/endpoint.sh
