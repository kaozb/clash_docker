#!/bin/bash

# 关闭clash服务（busybox 下 ps 列序不同，统一用 killall）
killall mihomo 2>/dev/null

# 清除环境变量
[ -f /etc/profile.d/clash.sh ] && > /etc/profile.d/clash.sh

echo -e "\n服务关闭成功，请执行以下命令关闭系统代理：proxy_off\n"
