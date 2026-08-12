#!/bin/bash

# reload.sh —— 重新拉取订阅并热重载 mihomo（不重启容器、不重置 secret）
# 用途：被 endpoint.sh 定时调用，实现节点定时刷新而不断线登录态

#################### 脚本初始化 ####################
export Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

Conf_Dir="$Server_Dir/conf"
Temp_Dir="$Server_Dir/temp"
Log_Dir="$Server_Dir/logs"


#################### 通用函数 ####################
success() { echo -en "\\033[60G[\\033[1;32m  OK  \\033[0;39m]\r"; return 0; }
failure() { local rc=$?; echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"; return $rc; }
action()  { local STRING rc; STRING=$1; echo -n "$STRING "; shift; "$@" && success || failure; rc=$?; echo; return $rc; }
if_success() {
	local ReturnStatus=$3
	if [ $ReturnStatus -eq 0 ]; then
		action "$1" /bin/true
	else
		action "$2" /bin/false
		exit 1
	fi
}


#################### 变量 ####################
URL=${CLASH_URL:?Error: CLASH_URL variable is not set or empty}

# 热重载必须保留原 secret，否则 dashboard 登录态会失效
if [[ -f "$Conf_Dir/config.yaml" ]]; then
	ExistingSecret=$(grep -m1 '^secret:' "$Conf_Dir/config.yaml" | sed -E "s/^secret:[[:space:]]*['\"]?([^'\"]*)['\"]?/\1/")
fi
Secret=${ExistingSecret:-${CLASH_SECRET:-$(openssl rand -hex 32)}}

# 取消可能干扰下载的代理环境变量
unset http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY


#################### 拉取订阅 ####################
# 检测订阅地址可访问性
echo -e '\n正在检测订阅地址...'
Text1="Clash订阅地址可访问！"
Text2="Clash订阅地址不可访问！"
curl -o /dev/null -L -k -sS --retry 5 -m 10 --connect-timeout 10 -w "%{http_code}" $URL | grep -E '^[23][0-9]{2}$' &>/dev/null
if_success $Text1 $Text2 $?

# 下载到临时文件
echo -e '\n正在下载Clash配置文件...'
Text3="配置文件下载成功！"
Text4="配置文件下载失败，放弃本次刷新！"
curl -L -k -sS --retry 5 -m 10 -o $Temp_Dir/clash.yaml.$ $URL
ReturnStatus=$?
if [ $ReturnStatus -ne 0 ]; then
	for i in {1..10}; do
		wget -q --no-check-certificate -O $Temp_Dir/clash.yaml.$ $URL
		ReturnStatus=$?
		[ $ReturnStatus -eq 0 ] && break
	done
fi
if [ $ReturnStatus -ne 0 ]; then
	action "$Text4" /bin/false
	exit 1
fi
action "$Text3" /bin/true

# 原子替换，避免热重载时读到半截文件
\mv -f $Temp_Dir/clash.yaml.$ $Temp_Dir/clash.yaml
\cp -a $Temp_Dir/clash.yaml $Temp_Dir/clash_config.yaml


#################### 订阅格式检测与转换 ####################
source $Server_Dir/scripts/get_cpu_arch.sh
if [[ $CpuArch =~ "x86_64" || $CpuArch =~ "amd64" ]]; then
	echo -e '\n判断订阅内容是否符合clash配置文件标准:'
	bash $Server_Dir/scripts/clash_profile_conversion.sh
	sleep 1
fi


#################### 重新生成 config.yaml ####################
sed -n '/^proxies:/,$p' $Temp_Dir/clash_config.yaml > $Temp_Dir/proxy.txt
cat $Temp_Dir/templete_config.yaml > $Temp_Dir/config.yaml
cat $Temp_Dir/proxy.txt >> $Temp_Dir/config.yaml
\cp $Temp_Dir/config.yaml $Conf_Dir/

# 注入 external-ui 与 secret（secret 沿用旧值，保持登录态）
Dashboard_Dir="${Server_Dir}/dashboard/public"
sed -ri "s@^# external-ui:.*@external-ui: ${Dashboard_Dir}@g" $Conf_Dir/config.yaml
# 用 awk 注入 secret，避免 sed 把 secret 中的 & \ 当成特殊字符
awk -v s="$Secret" 'BEGIN{q="\047"} /^secret: /{print "secret: " q s q; next} {print}' \
	"$Conf_Dir/config.yaml" > "$Conf_Dir/config.yaml.tmp" \
	&& \mv -f "$Conf_Dir/config.yaml.tmp" "$Conf_Dir/config.yaml"

echo -e '\n配置已更新，准备热重载 mihomo...'


#################### 重启 mihomo（粗鲁但可靠，避免 alpine/busybox ps 列序坑与多实例堆积） ####################
echo -e '\n停止所有 mihomo 进程...'
killall mihomo 2>/dev/null
sleep 2

echo -e '启动 mihomo...'
nohup mihomo -d $Conf_Dir &> $Log_Dir/clash.log &
ReturnStatus=$?
if_success "mihomo 启动成功！" "mihomo 启动失败！" $ReturnStatus

echo -e "\nSecret 保持不变: ${Secret}\n"
