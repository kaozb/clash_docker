# ---------- 阶段一：下载并解压所有二进制/静态资源 ----------
FROM alpine:3.21 AS builder

ARG ZASHBOARD_VERSION="v3.29.0"
ARG MIHOMO_VERSION="v1.19.31"

RUN apk add --no-cache wget unzip gzip && \
    # --- zashboard 静态资源：zip 内唯一顶层目录为 dist/，解压后取其内容铺到 /out/dashboard ---
    wget -q "https://github.com/Zephyruso/zashboard/releases/download/${ZASHBOARD_VERSION}/dist-no-fonts.zip" -O dist-no-fonts.zip && \
    mkdir -p /out/dashboard && \
    unzip -q dist-no-fonts.zip -d /tmp/zashboard && \
    if [ -d /tmp/zashboard/dist ]; then \
        cp -a /tmp/zashboard/dist/. /out/dashboard/; \
    else \
        cp -a /tmp/zashboard/. /out/dashboard/; \
    fi && \
    rm -rf /tmp/zashboard dist-no-fonts.zip && \
    test -f /out/dashboard/index.html && \
    # --- mihomo 内核：按架构选择对应 Release 资产，解压到 /out/mihomo ---
    ARCH=$(apk --print-arch) && \
    case "$ARCH" in \
        x86_64)  PKG="mihomo-linux-amd64-compatible-${MIHOMO_VERSION}.gz" ;; \
        aarch64) PKG="mihomo-linux-arm64-${MIHOMO_VERSION}.gz" ;; \
        armhf|armv6) PKG="mihomo-linux-armv6-${MIHOMO_VERSION}.gz" ;; \
        armv7)   PKG="mihomo-linux-armv7-${MIHOMO_VERSION}.gz" ;; \
        *)       PKG="mihomo-linux-armv7-${MIHOMO_VERSION}.gz" ;; \
    esac && \
    wget -q "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/${PKG}" -O /tmp/mihomo.gz && \
    gzip -dc /tmp/mihomo.gz > /out/mihomo && \
    chmod +x /out/mihomo && \
    rm -f /tmp/mihomo.gz

# ---------- 阶段二：运行镜像 ----------
FROM alpine:3.21

ENV SAFE_PATHS="/root/clash/dashboard/public"
ENV MIHOMO_VERSION="v1.19.31"

# 运行时依赖：bash(脚本使用 bash 语法)、openssl(生成 secret)、
# curl/wget(下载订阅配置)、ca-certificates(TLS)、libc6-compat(运行 glibc 二进制如 subconverter)
RUN apk add --no-cache bash openssl curl wget ca-certificates libc6-compat

# mihomo 内核：由 builder 阶段下载解压后 COPY 进来
COPY --from=builder /out/mihomo /usr/local/bin/mihomo

# zashboard 管理面板静态资源：由 builder 阶段从 GitHub Release 拉取
# dist-no-fonts.zip 并解压，这里直接 COPY 进 external-ui 目录（SAFE_PATHS），
# 容器内通过 :9090/ui 访问。更新面板只需改 builder 阶段的 ZASHBOARD_VERSION。
COPY --from=builder /out/dashboard/ /root/clash/dashboard/public/

ADD . /root/

RUN chmod +x /root/endpoint.sh

CMD /root/endpoint.sh
