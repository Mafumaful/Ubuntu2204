# ROS 2 Humble Docker Environment

这个仓库提供一个 Ubuntu 22.04 + ROS 2 Humble + zsh/oh-my-zsh 的 Docker 开发环境，可通过 Docker Compose 一键启动。

## 目录

```text
.
├── compose.yaml
├── docker/
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── zshrc
├── workspace/   # ROS 2 工作空间，挂载到容器 /home/ros/ws
├── data/        # 数据目录，挂载到容器 /data
└── config/      # 配置目录，挂载到容器 /config
```

## 准备

1. 安装 Docker 和 Docker Compose v2。
2. 按需复制环境变量模板：

```bash
cp .env.example .env
```

如果宿主机用户不是 UID/GID `1000`，建议在 `.env` 里改成宿主机当前值，避免挂载目录权限问题：

```bash
id -u
id -g
```

## 安装 Docker

如果当前机器还没有 Docker，可在仓库根目录的上一级执行：

```bash
sudo bash Ubuntu2204/scripts/install-docker-cn.sh
```

这个脚本会执行以下操作：

- 配置 Docker CE apt 源为清华镜像：`https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu`。
- 安装 `docker-ce`、`docker-ce-cli`、`containerd.io`、`docker-buildx-plugin`、`docker-compose-plugin`。
- 写入 `/etc/docker/daemon.json`，配置 Docker Hub 镜像加速。
- 启用并重启 Docker 服务。
- 将当前 sudo 用户加入 `docker` 组。

安装完成后，退出当前终端重新登录，让 `docker` 用户组权限生效。部分系统安装了 `newgrp` 时也可以执行：

```bash
newgrp docker
```

如果系统没有 `newgrp`，可以直接重新登录。也可以安装提供 `newgrp`/`sg` 的系统包后再刷新组权限：

```bash
sudo apt-get update
sudo apt-get install -y passwd
newgrp docker
```

验证：

```bash
docker --version
docker compose version
docker run --rm hello-world
```

如果清华 Docker CE 源暂时不支持你的 Ubuntu 版本，可切换为阿里云 Docker CE 源：

```bash
sudo DOCKER_APT_MIRROR=https://mirrors.aliyun.com/docker-ce/linux/ubuntu bash Ubuntu2204/scripts/install-docker-cn.sh
```

单独的 Docker daemon 中国镜像源模板也放在：

```bash
Ubuntu2204/docker-config/daemon.cn.json
```

## 启动

首次构建并进入容器：

```bash
docker compose run --rm ros2
```

后台启动一个常驻开发容器：

```bash
docker compose up -d
docker compose exec ros2 zsh
```

停止：

```bash
docker compose down
```

重新构建镜像：

```bash
docker compose build --no-cache
```

## 构建镜像源

Dockerfile 默认使用国内镜像来减少构建超时：

- ROS 2 apt 源：`https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu`
- ROS key：`https://mirrors.tuna.tsinghua.edu.cn/rosdistro/ros.key`
- oh-my-zsh：`https://gitee.com/mirrors/oh-my-zsh.git`
- zsh-autosuggestions：`https://gitee.com/mirrors/zsh-autosuggestions.git`
- zsh-syntax-highlighting：`https://gitee.com/mirrors/zsh-syntax-highlighting.git`

如果某个 Gitee 镜像临时不可用，可以在 `.env` 里改成 GitHub 原始地址后重新构建：

```bash
OH_MY_ZSH_REPO=https://github.com/ohmyzsh/ohmyzsh.git
ZSH_AUTOSUGGESTIONS_REPO=https://github.com/zsh-users/zsh-autosuggestions.git
ZSH_SYNTAX_HIGHLIGHTING_REPO=https://github.com/zsh-users/zsh-syntax-highlighting.git
```

## ROS 2 使用

容器启动时会自动 source：

```bash
/opt/ros/humble/setup.bash
/home/ros/ws/install/setup.bash  # 如果存在
```

镜像构建阶段会执行一次 `rosdep update --rosdistro humble`。如果后续依赖索引需要更新，可在容器内手动执行：

```bash
rosdep update --rosdistro humble
```

zsh 交互 shell 会自动 source：

```bash
/opt/ros/humble/setup.zsh
/home/ros/ws/install/setup.zsh  # 如果存在
```

创建并构建工作空间示例：

```bash
mkdir -p src
cd ~/ws
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.zsh
```

验证 ROS 2：

```bash
ros2 --help
ros2 run demo_nodes_cpp talker
```

另开一个终端：

```bash
docker compose exec ros2 zsh
ros2 run demo_nodes_py listener
```

## zsh 配置

`docker/zshrc` 参考了当前宿主机的配置：

- 使用 oh-my-zsh `robbyrussell` 主题。
- 启用 `git`、`z`、`docker`、`npm`、`extract`、`zsh-autosuggestions`、`zsh-syntax-highlighting` 插件。
- 保留 `alias python=python3`。
- 保留 `proxyon` / `proxyoff`，容器内默认代理地址为 `host.docker.internal:17891`。
- 自动 source ROS 2 Humble 和工作空间 overlay。

如果需要改代理端口，在 `compose.yaml` 或 `.env` 扩展 `PROXY_PORT` 即可。

## 网络端口接口

`compose.yaml` 已预留常用暴露接口：

```yaml
ports:
  - "7400-7600:7400-7600/udp"
  - "7400-7600:7400-7600/tcp"
  - "8080:8080"
  - "8765:8765"
```

- `7400-7600/udp,tcp`：预留给 DDS/ROS 2 通信调试。
- `8080`、`8765`：预留给 Web UI、桥接服务或自定义节点。

如需暴露更多端口，直接在 `compose.yaml` 的 `ports` 下追加，例如：

```yaml
- "9090:9090"
```

如果只在同一台机器上的多个容器间通信，也可以改用 Docker network，不一定需要映射到宿主机。

## Volume 接口

默认保留三个挂载接口：

```yaml
volumes:
  - ./workspace:/home/ros/ws
  - ./data:/data
  - ./config:/config
```

- `workspace`：放 ROS 2 packages 和构建输出。
- `data`：放 rosbag、模型、点云、日志等大文件。
- `config`：放 YAML、RViz 配置、启动参数等。

如需挂载额外目录，继续在 `volumes` 下追加：

```yaml
- /path/on/host:/path/in/container
```

## 图形界面

当前配置没有默认开启 X11/Wayland 图形转发。需要运行 RViz、Gazebo 等 GUI 时，可按宿主机环境追加：

```yaml
environment:
  DISPLAY: ${DISPLAY}
volumes:
  - /tmp/.X11-unix:/tmp/.X11-unix
```

然后在宿主机允许本地 Docker 访问 X server。
