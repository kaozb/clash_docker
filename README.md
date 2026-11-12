# Clash VPN (Docker)

基于 [mihomo](https://github.com/MetaCubeX/mihomo)（Clash.Meta 内核）的 Docker 化代理网关，内置 [zashboard](https://github.com/Zephyruso/zashboard) 管理面板。一条命令拉起，自动拉取订阅配置并对外提供 HTTP/SOCKS 代理与可视化控制台。

> 适用场景：在服务器/网关上以 `host` 网络模式运行，为局域网或本机提供全局/规则代理出口。

---

## 目录

- [1. 功能特性](#1-功能特性)
- [2. 架构与工作原理](#2-架构与工作原理)
- [3. 目录结构](#3-目录结构)
- [4. 环境要求](#4-环境要求)
- [5. 快速开始](#5-快速开始)
- [6. 配置项说明](#6-配置项说明)
- [7. 自定义配置模板](#7-自定义配置模板)
- [8. 端口与代理说明](#8-端口与代理说明)
- [9. 管理面板（Dashboard）](#9-管理面板dashboard)
- [10. 管理脚本](#10-管理脚本)
- [11. 定时刷新机制](#11-定时刷新机制)
- [12. 构建镜像](#12-构建镜像)
- [13. 常见问题与故障排查](#13-常见问题与故障排查)
- [14. 安全说明](#14-安全说明)
- [15. 许可与免责](#15-许可与免责)

---

## 1. 功能特性

- **一键部署**：单条 `docker run` 即可运行，无需手动安装依赖。
- **自动订阅拉取与校验**：启动时自动下载订阅并校验是否为标准 Clash 配置（含 `proxies`/`proxy-groups`/`rules`），不合格直接报错退出（镜像为减小体积已移除 subconverter 转换功能，base64/非标订阅请先用外部服务转换）。
- **热更新订阅**：内置定时任务，按周期重新拉取订阅并重启内核，**刷新节点而不改变 Secret（Dashboard 登录态保持）**。
- **可视化控制台**：集成 zashboard，通过 `:9090/ui` 直接访问，支持节点选择、延迟测试、规则调试。
- **GeoIP 路由**：内置 `Country.mmdb`，支持基于地理位置的规则分流。
- **多架构镜像**：支持 `linux/amd64`、`linux/arm64`、`linux/arm/v7`、`linux/arm/v6`（armhf）。
- **低资源占用**：实测常驻内存约 45MB，CPU 占用 < 1%。

---

## 2. 架构与工作原理

```
┌─────────────────────────────────────────────────────────────┐
│                         Docker 容器                          │
│                                                              │
│  /bin/sh -c /root/endpoint.sh  (容器入口 / PID 1)            │
│       │                                                      │
│       ├─ bash /root/clash/start.sh                          │
│       │    1. 解析 CLASH_URL / CLASH_SECRET                  │
│       │    2. curl/wget 下载订阅 → temp/clash.yaml           │
│       │    3. 校验格式（proxies/proxy-groups/rules 齐全）   │
│       │    4. 拼接模板 + 代理段 → conf/config.yaml           │
│       │    5. 注入 external-ui 与 secret                     │
│       │    6. nohup mihomo -d /root/clash/conf &             │
│       │                                                      │
│       └─ while true; do sleep <周期>;  bash reload.sh; done  │
│            reload.sh: 重新执行 ①~⑥，再 killall mihomo 重启   │
│                                                              │
│  mihomo (Clash.Meta)                                         │
│       ├─ :7890  HTTP 代理                                    │
│       ├─ :7891  SOCKS5 代理                                  │
│       └─ :9090  RESTful API + /ui (zashboard)                │
└─────────────────────────────────────────────────────────────┘
```

**关键点**

- 内核 `mihomo` 以 `-d /root/clash/conf` 指定配置目录，端口、`external-controller`、Secret、`external-ui` 全部来自该目录下的 `config.yaml`。
- 最终运行的 `config.yaml` 由**模板**（`temp/templete_config.yaml`）与**订阅中的代理段**拼接而成，模板决定端口/模式等全局设置。
- `reload.sh` 会先从已生成的 `config.yaml` 中读取现有 Secret 再重新生成，因此定时刷新不会改变登录口令。

---

## 3. 目录结构

```
clash_docker/
├── Dockerfile                  # 镜像构建（alpine:3.21 + mihomo + 依赖）
├── .dockerignore
├── .gitignore
├── README.md                   # 本文档入口
├── endpoint.sh                 # 容器入口：启动 + 定时刷新循环
├── .github/workflows/
│   └── docker-image.yml        # 多架构镜像 CI
└── clash/
    ├── start.sh                # 首次启动：拉取订阅 → 校验 → 生成配置 → 拉起 mihomo
    ├── reload.sh               # 定时刷新：重新拉取订阅 + 重启 mihomo（保留 Secret）
    ├── restart.sh              # 仅重启内核（不重新拉取订阅）
    ├── shutdown.sh             # 停止内核
    ├── .env                    # 本地/非 Docker 部署的订阅配置样例
    ├── README.md               # 服务器裸机部署说明
    ├── conf/
    │   ├── config.yaml         # ⚠ 运行时由脚本生成，初始为空
    │   └── Country.mmdb        # GeoIP 数据库
    ├── temp/
    │   ├── templete_config.yaml# 配置模板（文件名确为 templete，历史拼写）
    │   ├── clash.yaml           # 订阅原始下载（运行时下载）
    │   ├── clash_config.yaml    # 订阅副本（运行时生成）
    │   ├── config.yaml          # 拼接中间产物（运行时生成）
    │   └── proxy.txt            # 提取出的代理段（运行时生成）
    ├── scripts/
    │   └── validate_profile.sh  # 订阅格式校验（proxies/proxy-groups/rules）
    ├── dashboard/public/        # zashboard 静态资源（external-ui，构建期从 release 解压覆盖）
    └── logs/
        └── clash.log            # mihomo 运行日志（log-level: silent，默认极小）
```

---

## 4. 环境要求

| 项目 | 说明 |
|------|------|
| Docker | 任意较新版本（建议 20.10+） |
| 网络模式 | 必须使用 `--net host`，代理端口才能直接暴露在宿主机 |
| 权限 | 默认以 `root` 运行；仅用 `port`/`socks-port` 时无需额外 `cap-add`，需透明代理（`redir-port`）时才需 `NET_ADMIN` |
| 订阅 | 自备有效的 Clash/Mihomo 订阅地址（`CLASH_URL`） |
| 架构 | amd64 / arm64 / arm/v7 / arm/v6 (armhf) |

> **注意**：因使用 `--net host`，容器内端口即宿主机端口，请勿与宿主机上其他服务（尤其是另一个 clash 实例）的 `7890/7891/9090` 冲突。

---

## 5. 快速开始

### 5.1 最小启动

```bash
docker run -d \
  --name clash \
  --net host \
  --restart unless-stopped \
  -e CLASH_SECRET='your_secret_here' \
  -e CLASH_URL='https://your-subscription-url/xxx' \
  admibo/clash_vpn
```

> 两个变量的详细用法：`CLASH_SECRET` 见 [6.2](#62-dashboard-登录密码clash_secret)；
> 代理端口加密码、改端口见 [6.3](#63-代理连接密码authentication) / [6.4](#64-端口与监听配置)。

### 5.2 带自定义模板挂载

如需覆盖默认配置模板（修改端口、代理模式、DNS 等），将宿主机模板文件挂载到容器模板路径：

```bash
docker run -d \
  --name clash \
  --net host \
  --restart unless-stopped \
  -e CLASH_SECRET='your_secret_here' \
  -e CLASH_URL='https://your-subscription-url/xxx' \
  -v /root/auto/nsfcous.yaml:/root/clash/temp/templete_config.yaml \
  admibo/clash_vpn
```

> 模板文件即 `clash/temp/templete_config.yaml` 的格式（含 `port`/`socks-port`/`mode`/`external-controller` 等）。挂载后每次 `reload.sh` 都会基于该文件重新拼接配置。

### 5.3 验证

```bash
# 查看日志
docker logs clash

# 检查端口监听（应在 *:9090 / *:7890 / *:7891）
docker exec clash sh -c "netstat -tlnp 2>/dev/null | grep -E '9090|7890|7891'"

# 只应存在 1 个 mihomo 进程
docker exec clash sh -c "pidof mihomo | wc -w"
```

---

## 6. 配置项说明

### 6.1 环境变量总览（`docker run -e`）

| 变量 | 必填 | 说明 |
|------|------|------|
| `CLASH_URL` | ✅ | 订阅地址（须为标准 Clash YAML 格式；脚本只做校验，不做格式转换）。 |
| `CLASH_SECRET` | ⭕ | Dashboard / API 登录密码，详见 [6.2](#62-dashboard-登录密码clash_secret)。 |
| `SAFE_PATHS` | ❌ | external-ui 安全路径，镜像内已默认设置，无需覆盖。 |

### 6.2 Dashboard 登录密码（`CLASH_SECRET`）

`CLASH_SECRET` 是面板与 API 共用的登录口令，同时用于：

- zashboard 面板登录：`http://<ip>:9090/ui`
- RESTful API 鉴权：`curl -H "Authorization: Bearer <secret>" http://<ip>:9090/version`

| 事项 | 说明 |
|------|------|
| 设置方式 | `docker run -e CLASH_SECRET='你的密码' ...` |
| 不设置时 | 每次启动自动生成随机串（可在 `docker logs clash` 查看），**重建容器后会变** |
| 建议 | 显式设置强随机串，重建容器后面板登录态不丢 |
| 修改密码 | 停掉容器，用新 `-e CLASH_SECRET` 重新 `docker run` |

```bash
docker run -d \
  --name clash \
  --net host \
  --restart unless-stopped \
  -e CLASH_SECRET='My-Dashboard-Passw0rd' \
  -e CLASH_URL='https://your-subscription-url/xxx' \
  admibo/clash_vpn
```

> 定时刷新（`reload.sh`）会沿用现有 Secret，面板登录态始终不中断。

### 6.3 代理连接密码（`authentication`）

`7890/7891` 代理端口**默认无认证**：默认 `allow-lan: true` 且监听 `0.0.0.0`，任何能访问该端口的主机都可以直接走你的代理。给代理连接加用户名密码，需在自定义模板中配置 `authentication` 字段：

```yaml
# 单组用户名密码
authentication:
  - "user1:pass1"

# 多组写法
authentication:
  - "user1:pass1"
  - "user2:pass2"
```

配置后客户端必须携带账号密码：

| 协议 | 客户端配置示例 |
|------|----------------|
| HTTP 代理 | `http://user1:pass1@<宿主机IP>:7890` |
| SOCKS5 代理 | `socks5://user1:pass1@<宿主机IP>:7891` |

验证（未带密码的请求应返回 `407`）：

```bash
# 带密码：应返回代理出口 IP
curl -x http://user1:pass1@127.0.0.1:7890 https://api.ip.sb/ip
# 不带密码：应返回 407 Proxy Authentication Required
curl -x http://127.0.0.1:7890 https://api.ip.sb/ip
```

> 进阶：mihomo 支持 `skip-auth-prefixes: [127.0.0.0/8]`，可让指定网段（如本机）免认证直连。

### 6.4 端口与监听配置

默认端口一览：

| 端口 | 协议 | 用途 | 默认监听 |
|------|------|------|----------|
| `7890` | HTTP | HTTP 代理 | `0.0.0.0`（allow-lan） |
| `7891` | SOCKS5 | SOCKS5 代理 | `0.0.0.0` |
| `9090` | HTTP | RESTful API + Dashboard `/ui` | `0.0.0.0` |
| `redir-port` | — | 透明代理 | `0`（默认关闭） |

修改端口需在自定义模板中设置以下字段（模板挂载方式见 [6.5](#65-模板挂载与生效时机)）：

| 模板字段 | 默认值 | 说明 |
|----------|--------|------|
| `port` | `7890` | HTTP 代理端口，`0` 为关闭 |
| `socks-port` | `7891` | SOCKS5 代理端口，`0` 为关闭 |
| `mixed-port` | 未启用 | HTTP + SOCKS5 混合单端口，单端口场景推荐 |
| `redir-port` | `0` | 透明代理端口，容器需额外 `--cap-add NET_ADMIN` |
| `external-controller` | `'0.0.0.0:9090'` | API/面板监听地址，仅本机访问可改 `'127.0.0.1:9090'` |
| `allow-lan` | `true` | 是否允许非本机连接代理，仅本机使用改 `false` |

完整自定义模板示例（按需裁剪）：

```yaml
port: 7890                  # HTTP 代理端口
socks-port: 7891            # SOCKS5 代理端口
mixed-port: 7892            # 可选：混合端口
redir-port: 0
allow-lan: true
mode: Rule                  # 规则分流（默认模板为 Global，多数订阅建议改 Rule）
log-level: info
external-controller: '0.0.0.0:9090'
secret: 'placeholder'       # 占位即可，运行时由 CLASH_SECRET 覆盖
authentication:             # 代理连接密码（见 6.3）
  - "user1:pass1"
```

挂载运行：

```bash
docker run -d \
  --name clash \
  --net host \
  --restart unless-stopped \
  -e CLASH_SECRET='My-Dashboard-Passw0rd' \
  -e CLASH_URL='https://your-subscription-url/xxx' \
  -v /root/clash-template.yaml:/root/clash/temp/templete_config.yaml \
  admibo/clash_vpn
```

> **⚠ 自定义模板两条红线**（脚本按行匹配注入，删行会丢功能）：
> 1. 必须保留 `secret: ` 行（值随意）——否则 API/面板变成无密码裸奔；
> 2. 必须保留 `# external-ui: ...` 注释行——否则面板静态资源不会挂到 `:9090/ui`，访问 404。
>
> **端口与 `--net host`**：容器直接监听宿主机端口，无需 `-p` 映射；模板改端口后客户端连新端口；同机跑多实例时务必把三组端口全部错开。客户端接入示例见第 8 节。

### 6.5 模板挂载与生效时机

1. 在宿主机准备模板文件（可复制仓库内 `clash/temp/templete_config.yaml` 修改，或参照 6.4 示例编写）；
2. `-v /path/your_template.yaml:/root/clash/temp/templete_config.yaml` 挂载进容器；
3. 生效时机：
   - 新起容器：立即生效；
   - 运行中的容器：`docker exec clash bash /root/clash/reload.sh` 立即生效，否则等下一次定时刷新；
   - 注意 `restart.sh` 只重启内核、不重新拼接模板，改模板后请用 `reload.sh`。

### 6.6 构建时变量（Dockerfile `ARG` / `ENV`）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `MIHOMO_VERSION` | `v1.19.34` | mihomo 内核版本，构建时从 GitHub Release 拉取对应架构二进制。 |
| `ZASHBOARD_VERSION` | `v3.30.0` | zashboard 面板版本，构建时从 GitHub Release 拉取 `dist-no-fonts.zip` 解压到 Dashboard 目录。 |
| `SAFE_PATHS` | `/root/clash/dashboard/public` | Dashboard 静态目录。 |

> 需要人工维护的外部依赖只有两个，详见 [DEPENDENCIES.md](./DEPENDENCIES.md)：
> 1. **mihomo 内核版本**：只改 `Dockerfile` 里的 `MIHOMO_VERSION`，GitHub Actions 流水线会自行构建并推送镜像。
> 2. **zashboard 面板版本**：只改 `Dockerfile` 里的 `ZASHBOARD_VERSION`，构建时自动下载
>    `dist-no-fonts.zip` 并解压到 `clash/dashboard/public/`，同样是提交后流水线自动出镜像。

---

## 7. 自定义配置模板

默认模板位于 `clash/temp/templete_config.yaml`，内容节选：

```yaml
port: 7890            # HTTP 代理端口
socks-port: 7891      # SOCKS5 代理端口
redir-port: 0         # 透明代理端口（0=关闭）
allow-lan: true       # 允许局域网连接
mode: Global          # Rule / Global / Direct
log-level: silent     # silent/info/warning/error/debug
external-controller: '0.0.0.0:9090'
secret: 'b&ZlKTte5OnEt2Sn'   # 占位，运行时会由脚本注入真实 Secret
# external-ui: /root/clash/dashboard/public
```

- 各字段含义、常用改法（端口、代理认证、仅本机监听）见 **[6.4 端口与监听配置](#64-端口与监听配置)**；
- 挂载方式与生效时机见 **[6.5 模板挂载与生效时机](#65-模板挂载与生效时机)**。

> `secret` 行无需手动维护——`start.sh` / `reload.sh` 会用 `CLASH_SECRET`（或已有值）自动覆盖注入。
> 两条红线再强调一次：`secret: ` 行与 `# external-ui:` 注释行**不可删除**（脚本按行匹配注入，删行会导致 API 裸奔或面板 404，详见 [6.4](#64-端口与监听配置)）。

---

## 8. 端口与代理说明

| 端口 | 协议 | 用途 | 监听地址 |
|------|------|------|----------|
| `7890` | HTTP | HTTP 代理入口 | `0.0.0.0`（allow-lan） |
| `7891` | SOCKS5 | SOCKS5 代理入口 | `0.0.0.0` |
| `9090` | HTTP | RESTful API + Dashboard `/ui` | `0.0.0.0` |

**客户端配置示例**

- HTTP 代理：`http://<宿主机IP>:7890`
- SOCKS5 代理：`socks5://<宿主机IP>:7891`
- 配置了代理认证后（见 [6.3](#63-代理连接密码authentication)）：`http://user1:pass1@<宿主机IP>:7890`
- 修改端口/仅本机监听见 [6.4](#64-端口与监听配置)；容器内置 `proxy_on` / `proxy_off` 函数（写入 `/etc/profile.d/clash.sh`），可在容器内一键开关系统级代理：

```bash
source /etc/profile.d/clash.sh
proxy_on     # 导出 http_proxy/https_proxy 指向 127.0.0.1:7890
proxy_off    # 取消导出
```

---

## 9. 管理面板（Dashboard）

1. 浏览器访问 `http://<宿主机IP>:9090/ui`
2. 在 `API Base URL` 填入 `http://<宿主机IP>:9090`
3. 在 `Secret` 填入 `CLASH_SECRET`（或容器日志中输出的 Secret）
4. 点击连接，即可在面板中选择节点、测试延迟、编辑规则

> 面板为 **zashboard**（Clash.Meta 生态的现代 Dashboard），非旧版 yacd。

---

## 10. 管理脚本

容器内 `/root/clash/` 下提供以下脚本：

| 脚本 | 作用 | 是否重新拉取订阅 |
|------|------|------------------|
| `start.sh` | 首次启动：拉订阅→校验→生成配置→拉起 mihomo | ✅ |
| `reload.sh` | 定时刷新：重新拉订阅→生成配置→`killall mihomo`→重启（**保留 Secret**） | ✅ |
| `restart.sh` | 仅重启内核（基于已有 `conf/config.yaml`，不更新订阅） | ❌ |
| `shutdown.sh` | 停止内核并清理 `/etc/profile.d/clash.sh` | — |

在容器内手动执行示例：

```bash
docker exec clash bash /root/clash/reload.sh     # 立即刷新订阅并重启
docker exec clash bash /root/clash/restart.sh    # 仅重启（不刷新节点）
docker exec clash bash /root/clash/shutdown.sh   # 停止
```

> **实现说明（killall 策略）**：由于基础镜像为 Alpine（busybox），`ps` 的列序与 GNU 不同，脚本统一采用 `killall mihomo` 终止全部内核进程后再启动，确保不会出现多实例堆积、且端口不被旧进程占用。

---

## 11. 定时刷新机制

`endpoint.sh` 在首次启动后进入循环：

```bash
while true; do
    sleep 267840        # ≈ 74 小时
    bash /root/clash/reload.sh
done
```

- 默认每约 **74 小时**重新拉取一次订阅并热重启，实现节点周期性更新。
- `reload.sh` 重启时复用已有 Secret，Dashboard 登录态不中断。
- 调试时可临时缩短 `sleep` 值观察刷新效果（注意过短的周期会频繁请求订阅源）。

---

## 12. 构建镜像

### 12.1 本地构建

```bash
docker build -t admibo/clash_vpn:local .
docker run -d --net host -e CLASH_URL=... -e CLASH_SECRET=... admibo/clash_vpn:local
```

### 12.2 CI 多架构构建

`.github/workflows/docker-image.yml` 在 push / PR 到 `main` 时触发，通过 `docker/build-push-action` 构建并推送 `linux/amd64`、`linux/arm64`、`linux/arm/v7`、`linux/arm/v6` 四架构镜像至 `admibo/clash_vpn`，tag 包括 `latest` 与 `${{ github.event.head_commit.message }}`。

> 注意：当前 CI 直接把 commit message 用作镜像 tag，若 commit message 含空格或特殊字符会导致推送失败，建议改用 `github.sha` 或经过清洗的标签。

---

## 13. 常见问题与故障排查

**Q1：Dashboard 连不上 / 端口没监听**
- 确认容器使用 `--net host`；
- `docker exec clash sh -c "pidof mihomo"` 确认内核在运行；
- 查看 `docker logs clash` 与 `/root/clash/logs/clash.log`。

**Q2：两个 clash 容器同时跑，端口疑似冲突**
- `--net host` 下所有实例共享宿主机端口。请确保只有一个实例使用 `7890/7891/9090`，或给不同实例分配不同端口（通过自定义模板，见 [6.4](#64-端口与监听配置)）。

**Q3：UI 里看不到代理节点**
- 多为订阅是 Base64 编码等非标格式。**本镜像不内置订阅转换**（为减小体积已移除 subconverter），请先用第三方 subconverter 服务把订阅转成标准 Clash 配置，再把转换后的地址填入 `CLASH_URL`。

**Q4：日志出现 `error: unsupported rule type RULE-SET`**
- 见 mihomo 官方 FAQ；通常需补充对应 rule-provider 配置或移除不支持的规则类型。

**Q5：定时刷新后节点没变 / 出现多个 mihomo 进程**
- 确保使用的是 `reload.sh`（会 `killall` 旧进程）；旧版通过 `ps|awk` 取 PID 在 Alpine 下取到的是 USER 而非 PID，会导致旧进程残留。当前版本已修复。

**Q6：订阅是 https 但下载报错证书相关**
- 下载命令带 `-k` 跳过证书校验（兼容性考虑）。如订阅源证书可信，可移除 `-k` 以提升安全性。

---

## 14. 安全说明

- **以 root 运行**：容器默认 root。仅启用 `port`/`socks-port` 时并非必需，如需降权请评估透明代理（`redir-port`/`TPROXY`）对 `NET_ADMIN` 的需求。
- **Secret 明文**：`CLASH_SECRET` 通过环境变量传入，`docker inspect` 可见。生产环境建议使用编排平台的 secret 管理机制。
- **自动重启**：示例命令使用 `--restart unless-stopped`；若遗漏，容器退出后不会被 Docker 拉起（且 mihomo 非 PID 1，其崩溃不会连带停止容器）。
- **订阅下载 `-k`**：跳过 TLS 校验，存在中间人篡改风险，仅在订阅源证书异常时必要。
- **外部访问**：`external-controller` 监听 `0.0.0.0:9090` 且 `allow-lan: true`，请确保 Secret 强度足够，避免 Dashboard/API 暴露到公网被未授权访问。

---

## 15. 许可与免责

- 本项目整合 mihomo、zashboard 等开源项目，相关权利归各自作者所有。
- 本项目**不提供任何订阅信息**，请自行准备合法合规的 Clash 订阅。
- 使用者需遵守所在地区法律法规，因使用本项目产生的任何后果由使用者自行承担。
