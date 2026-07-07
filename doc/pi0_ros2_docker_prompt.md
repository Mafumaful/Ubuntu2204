# 任务：构建 ROS2 Humble + π0 (PyTorch) 一体化 Docker 开发环境

你是一名资深的机器人系统工程师，精通 Docker、ROS2 和深度学习部署。请为我构建一个可复现的 Docker 开发环境，用于在 ROS2 Humble 中调用 Physical Intelligence 的 π0 模型（PyTorch 实现）进行机器人策略推理。请严格遵循以下需求和约束。

## 一、目标

交付一套完整的、可一键构建和启动的 Docker 环境，包含：

1. `Dockerfile`（多阶段构建，注释清晰）
2. `docker-compose.yml`（含 GPU 配置）
3. `entrypoint.sh`（环境初始化脚本）
4. 一个最小可用的 ROS2 bridge 节点示例（Python），演示如何将 ROS2 话题数据送入 π0 并发布动作
5. `README.md`（构建、启动、验证的完整步骤）
6. 每一步的验证命令（见第六节）

## 二、核心架构约束（必须遵守）

**关键冲突**：ROS2 Humble 依赖 Ubuntu 22.04 的系统 Python 3.10，而 openpi 要求 Python 3.11。**禁止**尝试将两者合并到同一个 Python 环境中。

**必须采用 openpi 官方的 policy server / client 分离架构**，在同一容器内运行两个进程：

- **进程 A（π0 policy server）**：运行在由 uv 管理的独立 Python 3.11 虚拟环境中，加载 π0 PyTorch 模型，通过 WebSocket 对外提供推理服务（使用 openpi 自带的 `scripts/serve_policy.py`）。
- **进程 B（ROS2 bridge 节点）**：运行在系统 Python 3.10 + ROS2 Humble 环境中，只安装轻量的 `openpi-client` 包（该包依赖极少，兼容 Python 3.10），通过 WebSocket 连接进程 A。

两个环境的 site-packages 必须完全隔离，不允许交叉 pip install。

## 三、基础镜像与系统依赖

- 基础镜像：`ros:humble`（基于 Ubuntu 22.04，与 openpi 官方测试的操作系统一致）。
- **不要**在镜像内安装系统级 CUDA toolkit。PyTorch 的 pip wheel 自带 CUDA runtime；openpi 官方也明确建议避免系统 CUDA 库以防冲突。宿主机只需要 NVIDIA 驱动 + nvidia-container-toolkit。
- 安装必要的系统包：`git`、`git-lfs`、`curl`、`build-essential`、`python3-pip`、`ros-humble-cv-bridge`、`ros-humble-image-transport` 及其他 ROS2 常用工具。
- 安装 uv（Python 包管理器，openpi 官方指定），并用它创建 Python 3.11 环境。

## 四、openpi 安装要求（PyTorch 路线）

按以下顺序执行，每一步都要写进 Dockerfile 并附注释：

1. 克隆仓库时必须带子模块，并跳过 LFS 大文件下载：
   `GIT_LFS_SKIP_SMUDGE=1 git clone --recurse-submodules https://github.com/Physical-Intelligence/openpi.git`
2. 用 uv 同步依赖：`GIT_LFS_SKIP_SMUDGE=1 uv sync`（openpi 通过 `.python-version` 锁定 Python 3.11，让 uv 自动处理）。
3. **PyTorch 专属补丁（不可省略）**：openpi 的 PyTorch 实现要求 `transformers==4.53.2`，且必须将仓库内提供的补丁文件手动覆盖到虚拟环境的 transformers 包目录（涉及 AdaRMS、精度控制和 KV cache 相关修改）。请在 Dockerfile 中查阅 openpi 仓库 README 的 "PyTorch" 章节，按其当前指引完成拷贝，并加注释说明每个文件的用途。注意此操作只影响容器内的隔离环境，无污染风险。
4. 在 ROS2 的 Python 3.10 环境中安装客户端：`pip install -e /openpi/packages/openpi-client`。
5. 模型权重**不要**打进镜像。在 `docker-compose.yml` 中将宿主机目录挂载为权重缓存（openpi 默认缓存路径为 `~/.cache/openpi`），并在 README 中说明首次启动会从 `gs://openpi-assets` 自动下载 checkpoint。

## 五、运行时配置

- `docker-compose.yml` 必须包含：`gpus: all`（或等价的 deploy.resources 配置）、`network_mode: host`（便于 ROS2 DDS 发现与 WebSocket 通信）、共享内存大小 `shm_size: 8gb` 以上、权重缓存卷挂载、以及源码目录挂载以便开发迭代。
- 环境变量：设置 `ROS_DOMAIN_ID`（可配置，默认 0）。
- entrypoint 需要 source ROS2 环境（`/opt/ros/humble/setup.bash`），并支持两种启动模式：(a) 同时拉起 policy server 和 bridge 节点；(b) 仅进入交互 shell 供开发调试。
- policy server 启动命令示例应使用 PyTorch 配置，并允许通过环境变量指定 checkpoint（如 pi0_base 或微调后的本地权重目录）。

## 六、ROS2 bridge 节点要求

提供一个名为 `pi0_bridge` 的最小 ROS2 Python 包，功能：

- 订阅：相机图像话题（`sensor_msgs/Image`，用 cv_bridge 转换）和关节状态话题（`sensor_msgs/JointState`）。
- 组装 openpi-client 要求的 observation 字典（图像 + 本体状态 + 语言指令，语言指令通过 ROS2 参数传入）。
- 通过 `openpi_client.websocket_client_policy.WebsocketClientPolicy` 请求推理，得到 action chunk（π0 一次返回 50 步动作）。
- 发布：将动作块按固定频率逐步发布到 `/pi0/action` 话题（`std_msgs/Float64MultiArray` 即可），并演示 open-loop 执行策略——执行部分动作后再请求下一个 chunk，与 π0 论文的推理方式一致。
- 代码需处理好：server 未就绪时的重连、图像与关节状态的时间同步（用 message_filters 近似同步即可）。

## 七、验证清单（每项都给出具体命令并在 README 中体现）

1. `nvidia-smi` 在容器内可见 GPU。
2. 在 uv 环境中：`python -c "import torch; print(torch.__version__, torch.cuda.is_available())"` 输出 True。
3. 在 uv 环境中确认 `transformers.__version__ == 4.53.2` 且补丁文件已生效。
4. `ros2 doctor` 通过，`ros2 topic list` 正常。
5. Python 3.10 环境中 `import openpi_client` 成功。
6. policy server 能成功加载一个 π0 PyTorch checkpoint 并监听端口。
7. 用 openpi-client 发送一个 dummy observation（随机图像 + 零状态向量），能收到形状正确的 action chunk（horizon=50）。
8. bridge 节点端到端跑通：发布模拟图像与关节状态 → `/pi0/action` 上能收到动作输出。

## 八、工作方式要求

- 逐步执行：先给出整体文件结构，再逐个文件实现，每完成一个文件说明设计理由。
- 遇到 openpi 仓库文档与本 prompt 冲突时，以 openpi 仓库当前 README 为准，并向我指出差异。
- 不确定的版本号或路径，先查阅仓库源码确认，不要凭记忆猜测。
- 所有脚本必须幂等，重复构建不报错。
- 最后提供一个"常见问题排查"章节，至少覆盖：CUDA 不可见、DDS 发现失败、权重下载失败、transformers 补丁失效四种情况。

## 九、我的环境信息（请按此适配）

- 宿主机：Ubuntu 22.04，NVIDIA GPU（显存 ≥ 24GB），已安装 NVIDIA 驱动和 Docker。
- 用途：先做推理验证，后续可能做 LoRA 微调（微调仍走 openpi 官方流程，本环境只需保证推理链路完整）。
- 若我未提供的信息影响实现，列出你的假设后继续，不要停下来等待。