# docker 版

CLASH_SECRET 端口9090的登录密码    
CLASH_URL  订阅链接的url    
 
执行启动方式    

```

docker pull admibo/clash_vpn
docker run -id --net host -e CLASH_SECRET='password' -e CLASH_URL='https://111111111111112344.com/1111' --name clash admibo/clash_vpn

```

web登录控制台

访问 http://【ip】:9090/ui/

输入   
- APIBaseURL   http://【ip】:9090   
- 密码    password

直接登录、配置好就可使用


其他使用方式见 [clash/README.md](./clash/README.md)     
