# 依赖记录（需手工维护的两个外部依赖）

本仓库只有以下两处依赖需要「人」来更新，其余全部由 Docker 构建流水线自动完成。

## 1. mihomo 内核版本 MIHOMO_VERSION

- 位置：`Dockerfile` 第一阶段（`FROM alpine AS builder`）的构建参数
  ```dockerfile
  ARG MIHOMO_VERSION="v1.19.31"
  ```
- 维护方式：只改 `Dockerfile` 里的这一个变量即可。
  构建时（第一阶段）按架构拼接文件名，从 GitHub Release 下载对应二进制，
  解压后由运行阶段 `COPY --from=builder /out/mihomo /usr/local/bin/mihomo` 取用：

  | 容器架构 | 归档文件 |
  |---|---|
  | x86_64 | mihomo-linux-amd64-compatible-<VERSION>.gz |
  | aarch64 | mihomo-linux-arm64-<VERSION>.gz |
  | armv7 | mihomo-linux-armv7-<VERSION>.gz |
  | armhf / armv6 | mihomo-linux-armv6-<VERSION>.gz |

- 不需要改 `.github/workflows/docker-image.yml`。
  GitHub Actions 流水线会自己出镜像（多架构 buildx：amd64 / arm64 / arm/v7 / arm/v6），
  改完 Dockerfile 提交到 main 分支，流水线自动构建并推送 `admibo/clash_vpn`。

- 版本来源：https://github.com/MetaCubeX/mihomo/releases

## 2. zashboard 面板版本 ZASHBOARD_VERSION

- 位置：`Dockerfile` 第一阶段（`FROM alpine AS builder`）的构建参数
  ```dockerfile
  ARG ZASHBOARD_VERSION="v3.29.0"
  ```
- 上游仓库：https://github.com/Zephyruso/zashboard
- 维护方式：只改 `Dockerfile` 里的 `ZASHBOARD_VERSION` 这一个变量即可。
  构建时在第一阶段（`builder`）从 GitHub Release 下载官方产物 `dist-no-fonts.zip`
  并解压，运行阶段用 `COPY --from=builder` 把静态资源放进
  `/root/clash/dashboard/public`（即 `external-ui` 目录，容器内通过 `:9090/ui` 访问）。
  所用命令与 mihomo 一致，都是构建期 wget 拉取：

  ```dockerfile
  wget -q "https://github.com/Zephyruso/zashboard/releases/download/${ZASHBOARD_VERSION}/dist-no-fonts.zip" -O /tmp/zashboard.zip
  ```

- 下载解压统一放在单独的构建阶段（`FROM alpine AS builder`），
  mihomo 与 zashboard 都在这一阶段下载解压，
  `unzip`/`gzip`/临时文件都留在该阶段，最终镜像只 COPY 产物，不引入这些工具，体积更小。
  产物路径：`/out/mihomo`（内核）、`/out/dashboard/`（面板静态资源）。
- 之所以用 `dist-no-fonts.zip`：去掉内嵌字体，减小镜像体积，字体走系统/浏览器默认。
- 解压层兼容两种压缩包结构（直接含 index.html，或带一层 `dist/` 目录），
  最后会校验 `index.html` 存在，失败则构建报错。
- 不需要改 `.github/workflows/docker-image.yml`，提交后流水线自动构建出镜像。

- 版本来源：https://github.com/Zephyruso/zashboard/releases
- 注意：`clash/dashboard/public/` 里的内容是构建期覆盖的产物，
  更新版本只需改上面的变量，不必手工往仓库里提交静态文件。
