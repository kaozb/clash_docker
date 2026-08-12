#!/bin/bash

bash /root/clash/start.sh

# 定时重新拉取订阅并热重载（保持登录态、不断线）
# 267840s ≈ 74h，可按需调整
while true
do
    sleep 267840
    bash /root/clash/reload.sh
done
