# docker 版

git clone 

进入目录


修改 clash/.env 中的

登录密码、clash的订阅地址

docker build -t clash_vpn .


执行

docker run -id --net host --name clash clash_vpn


其他使用方式见 clash/readme
