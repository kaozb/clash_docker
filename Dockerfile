FROM ubuntu

RUN apt update && apt install curl -y && rm -rf /var/cache/apt


RUN \
    CpuArch=$(dpkg --print-architecture) && \
    if [ "$CpuArch" = "amd64" ]; then \
        curl -sSL https://github.com/MetaCubeX/mihomo/releases/download/v1.19.2/mihomo-linux-amd64-v1.19.2.deb -o /tmp/mihomo.deb; \
    elif [ "$CpuArch" = "aarch64" ] || [ "$CpuArch" = "arm64" ]; then \
        curl -sSL https://github.com/MetaCubeX/mihomo/releases/download/v1.19.2/mihomo-linux-arm64-v1.19.2.deb -o /tmp/mihomo.deb; \
    elif [ "$CpuArch" = "armv7l" ]; then \
        curl -sSL https://github.com/MetaCubeX/mihomo/releases/download/v1.19.2/mihomo-linux-armv7-v1.19.2.deb -o /tmp/mihomo.deb; \
    else \
        echo "Unsupported architecture: $CpuArch"; \
        exit 1; \
    fi && \
    dpkg -i /tmp/mihomo.deb && \
    rm -rf /tmp/mihomo.deb
	
ADD . /root/

RUN chmod +x /root/endpoint.sh

CMD /root/endpoint.sh
