FROM ubuntu

RUN apt update && apt install curl -y && rm -rf /var/cache/apt

ENV SAFE_PATHS="/root/clash/dashboard/public"
# 上述是mihomo破坏性更新，V1.19.12 出于安全考虑，restful api 中的 “path” 参数已受到限制，其目录也需要位于 workdir 或 ./configsSAFE_PATHS

RUN \
    CpuArch=$(dpkg --print-architecture) && \
    if [ "$CpuArch" = "amd64" ]; then \
        curl -sSL https://github.com/MetaCubeX/mihomo/releases/download/v1.19.12/mihomo-linux-amd64-v1.19.12.deb -o /tmp/mihomo.deb; \
    elif [ "$CpuArch" = "aarch64" ] || [ "$CpuArch" = "arm64" ]; then \
        curl -sSL https://github.com/MetaCubeX/mihomo/releases/download/v1.19.12/mihomo-linux-arm64-v1.19.12.deb -o /tmp/mihomo.deb; \
    elif [ "$CpuArch" = "armv7l" ]; then \
        curl -sSL https://github.com/MetaCubeX/mihomo/releases/download/v1.19.12/mihomo-linux-armv7-v1.19.12.deb -o /tmp/mihomo.deb; \
    else \
        curl -sSL https://github.com/MetaCubeX/mihomo/releases/download/v1.19.12/mihomo-linux-armv7-v1.19.12.deb -o /tmp/mihomo.deb; \
    fi && \
    dpkg -i /tmp/mihomo.deb && \
    rm -rf /tmp/mihomo.deb
	
ADD . /root/

RUN chmod +x /root/endpoint.sh

CMD /root/endpoint.sh
