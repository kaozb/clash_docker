#!/bin/bash

# validate_profile.sh —— 校验订阅是否为标准 clash 配置（proxies/proxy-groups/rules 三段齐全）
# 读取 $Server_Dir/temp/clash.yaml，通过则生成 $Server_Dir/temp/clash_config.yaml，不通过则报错退出
# 注：本镜像已移除内置 subconverter 转换功能（减小镜像体积），仅支持 clash yaml 订阅；
#     base64 / v2ray 等非标订阅请先用外部 subconverter 服务转换为 clash 格式后再配置 CLASH_URL。

raw_content=$(cat ${Server_Dir}/temp/clash.yaml)

# 判断订阅内容是否符合clash配置文件标准
if echo "$raw_content" | awk '/^proxies:/{p=1} /^proxy-groups:/{g=1} /^rules:/{r=1} p&&g&&r{exit} END{if(p&&g&&r) exit 0; else exit 1}'; then
  echo "订阅内容符合clash标准"
  echo "$raw_content" > ${Server_Dir}/temp/clash_config.yaml
else
  # 给出更具体的失败原因，方便排查
  if echo "$raw_content" | base64 -d &>/dev/null; then
    echo "订阅为 Base64 编码，本镜像不再内置 subconverter，无法自动转换！" >&2
    echo "请使用外部 subconverter 服务将订阅转换为 clash 格式后再配置 CLASH_URL" >&2
  else
    echo "订阅内容不符合clash标准（缺少 proxies / proxy-groups / rules 段）" >&2
  fi
  exit 1
fi
