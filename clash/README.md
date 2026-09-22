[TOC]

# 服务器裸机部署（非 Docker）

> 本文档适用于**不使用 Docker**、直接在 Linux 服务器上运行脚本的部署方式。
> 若使用 Docker，请返回上级目录阅读 **[../README.md](../README.md)**。

此项目以开源项目 [mihomo（Clash.Meta）](https://github.com/MetaCubeX/mihomo) 作为核心程序，结合脚本实现简单的代理功能，主要用于解决服务器访问 GitHub 等境外资源速度慢的问题。管理面板使用 [zashboard](https://github.com/Zephyruso/zashboard)。

<br>

# 使用须知

- 运行本项目建议使用 root 用户，或使用 `sudo` 提权（透明代理 / 系统级代理需要）。
- 本项目是基于 [mihomo](https://github.com/MetaCubeX/mihomo)、[zashboard](https://github.com/Zephyruso/zashboard)、[subconverter](https://github.com/MetaCubeX/subconverter) 进行的配置整合。
- 此项目不提供任何订阅信息，请自行准备 Clash/Mihomo 订阅地址。
- 运行前请手动更改 `.env` 文件中的 `CLASH_URL` 变量值，否则无法正常运行。
- 当前在 RHEL 系列和 Debian 系列 Linux 系统中测试过，其他系列可能需要适当修改脚本。
- 支持 x86_64 / aarch64 平台。

<br>

# 使用教程

## 下载项目

下载项目

```bash
$ git clone https://github.com/wanhebin/clash-for-linux.git
```

进入到项目目录，编辑`.env`文件，修改变量`CLASH_URL`的值。

```bash
$ cd clash-for-linux
$ vim .env
```

> **注意：** `.env` 文件中的变量 `CLASH_SECRET` 为自定义 Clash Secret，值为空时，脚本将自动生成随机字符串。

<br>

## 启动程序

直接运行脚本文件`start.sh`

- 进入项目目录

```bash
$ cd clash-for-linux
```

- 运行启动脚本

```bash
$ sudo bash start.sh

正在检测订阅地址...
Clash订阅地址可访问！                                      [  OK  ]

正在下载Clash配置文件...
配置文件config.yaml下载成功！                              [  OK  ]

正在启动Clash服务...
服务启动成功！                                             [  OK  ]

Clash Dashboard 访问地址：http://<ip>:9090/ui
Secret：xxxxxxxxxxxxx

请执行以下命令加载环境变量: source /etc/profile.d/clash.sh

请执行以下命令开启系统代理: proxy_on

若要临时关闭系统代理，请执行: proxy_off

```

```bash
$ source /etc/profile.d/clash.sh
$ proxy_on
```

- 检查服务端口

```bash
$ netstat -tln | grep -E '9090|789.'
tcp        0      0 127.0.0.1:9090          0.0.0.0:*               LISTEN     
tcp6       0      0 :::7890                 :::*                    LISTEN     
tcp6       0      0 :::7891                 :::*                    LISTEN
```

- 检查环境变量

```bash
$ env | grep -E 'http_proxy|https_proxy'
http_proxy=http://127.0.0.1:7890
https_proxy=http://127.0.0.1:7890
```

以上步鄹如果正常，说明服务clash程序启动成功，现在就可以体验高速下载github资源了。

<br>

## 重启程序

如果需要对 Clash 配置进行修改，请修改 `conf/config.yaml` 文件，然后运行 `restart.sh` 脚本进行重启。

> **注意：**
> 重启脚本 `restart.sh` 只重启内核，**不会更新订阅信息**。

如需**重新拉取订阅并刷新节点**，请运行 `reload.sh`：

```bash
$ sudo bash reload.sh
```

`reload.sh` 会重新下载订阅、重新生成配置，并以 `killall mihomo` 方式重启内核，且**保留原有 Secret**（Dashboard 登录态不中断）。

<br>

## 停止程序

- 进入项目目录

```bash
$ cd clash-for-linux
```

- 关闭服务

```bash
$ sudo bash shutdown.sh

服务关闭成功，请执行以下命令关闭系统代理：proxy_off

```

```bash
$ proxy_off
```

然后检查程序端口、进程以及环境变量`http_proxy|https_proxy`，若都没则说明服务正常关闭。


<br>

## Clash Dashboard

- 访问 Clash Dashboard

通过浏览器访问 `start.sh` 执行成功后输出的地址，例如：http://192.168.0.1:9090/ui

- 登录管理界面

在`API Base URL`一栏中输入：http://\<ip\>:9090 ，在`Secret(optional)`一栏中输入启动成功后输出的Secret。

点击Add并选择刚刚输入的管理界面地址，之后便可在浏览器上进行一些配置。

- 更多教程

此 Clash Dashboard 使用的是 [zashboard](https://github.com/Zephyruso/zashboard) 项目（Clash.Meta 生态的现代管理面板），详细使用方法请移步到其项目页面查询。


<br>

# 常见问题

1. 部分Linux系统默认的 shell `/bin/sh` 被更改为 `dash`，运行脚本会出现报错（报错内容一般会有 `-en [ OK ]`）。建议使用 `bash xxx.sh` 运行脚本。

2. 部分用户在UI界面找不到代理节点，基本上是因为厂商提供的clash配置文件是经过base64编码的，且配置文件格式不符合clash配置标准。

   目前此项目已集成自动识别和转换clash配置文件的功能。如果依然无法使用，则需要通过自建或者第三方平台（不推荐，有泄露风险）对订阅地址转换。
   
3. 程序日志中出现 `error: unsupported rule type RULE-SET` 报错，说明订阅使用了 mihomo 暂不直接支持的 rule 类型，通常需改为对应的 `rule-provider`（见 [mihomo 文档](https://wiki.metacubex.one/)）或移除该规则。
