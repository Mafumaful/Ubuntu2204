# ROS 2 Humble + openpi Docker Environment

这个仓库提供 ROS 2 Humble + Physical Intelligence openpi 的一体化 Docker 开发环境。ROS2 bridge 使用系统 Python 3.10；π0 policy server 使用 openpi/uv 管理的独立 Python 3.11 虚拟环境，两者的 site-packages 隔离。

## 目录

```text
.
├── compose.yaml
├── docker/
│   ├── Dockerfile
│   ├── entrypoint.sh
│   └── zshrc
├── workspace/
│   └── pi0_bridge/        # ROS2 openpi WebSocket bridge 示例
├── data/openpi-cache/     # openpi 权重缓存，挂载到 ~/.cache/openpi
└── config/
```

## 构建

```bash
cp .env.example .env
docker compose build
```

默认使用国内镜像源：

- Ubuntu apt：`https://mirrors.tuna.tsinghua.edu.cn/ubuntu`
- ROS2 apt：`https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu`
- PyPI 和 uv 包索引：`https://pypi.tuna.tsinghua.edu.cn/simple`
- Hugging Face：`https://hf-mirror.com`
- oh-my-zsh 插件：Gitee 镜像，失败时回退 GitHub

openpi 本身暂无可靠的官方国内 Git 镜像，默认仍从 GitHub 克隆。可在 `.env` 中覆盖 `OPENPI_REPO`，或者用 `GIT_URL_REWRITE_TO` 把所有 `https://github.com/` 访问重写到你的内网镜像或稳定 GitHub 加速地址。

可选网络变量：

```bash
UV_PYTHON_INSTALL_MIRROR=
HF_ENDPOINT=https://hf-mirror.com
GIT_URL_REWRITE_FROM=https://github.com/
GIT_URL_REWRITE_TO=
```

`UV_PYTHON_INSTALL_MIRROR` 用于 uv 下载 Python 3.11。如果你有 python-build-standalone 的内网镜像，可以填这个变量；默认留空，避免写死不稳定的公共 GitHub 代理。

如果 `git clone` openpi 卡住，可以在同一个终端先启用宿主机代理再构建：

```bash
proxyon
docker compose build
```

`proxyon` 会导出 `http_proxy`、`https_proxy`、`all_proxy` 等变量；Compose 会把它们作为 build args 传给 Docker build。构建阶段也配置了 `host.docker.internal:host-gateway`，所以 `http://host.docker.internal:17891` 这类代理地址在 build 容器里可解析。详情可以参考 @./scripts。

也可以手动写入 `.env`：

```bash
http_proxy=http://host.docker.internal:17891
https_proxy=http://host.docker.internal:17891
all_proxy=socks5://host.docker.internal:17891
HTTP_PROXY=http://host.docker.internal:17891
HTTPS_PROXY=http://host.docker.internal:17891
ALL_PROXY=socks5://host.docker.internal:17891
```

## 启动模式

进入交互 shell：

```bash
docker compose run --rm ros2 pi0-shell
```

只启动 policy server：

```bash
docker compose run --rm ros2 pi0-policy
```

同时启动 policy server 和 ROS2 bridge：

```bash
docker compose run --rm ros2 pi0-stack
```

`compose.yaml` 和 `docker-compose.yml` 已启用 `network_mode: host`、`gpus: all`、`shm_size: 8gb` 和 openpi cache volume。host network 下不配置 `ports` 映射。

默认启动 GPU：

```bash
docker compose up -d
```

如果需要临时无 GPU 启动，注释掉 compose 文件里的 `gpus: all` 这一行再启动。

## openpi 配置

核心环境变量：

```bash
OPENPI_POLICY_CONFIG=pi05_droid
OPENPI_SOURCE_CHECKPOINT=gs://openpi-assets/checkpoints/pi05_droid
OPENPI_CHECKPOINT=/home/ros/.cache/openpi/pytorch-checkpoints/pi05_droid
OPENPI_AUTO_CONVERT_PYTORCH=1
OPENPI_POLICY_PORT=8000
ROS_DOMAIN_ID=0
BUILD_WS_ON_START=1
```

当前 openpi README 的 PyTorch 说明要求：

```bash
cd /openpi
uv sync
uv pip install -e .
cp -r ./src/openpi/models_pytorch/transformers_replace/* \
  .venv/lib/python3.11/site-packages/transformers/
```

Dockerfile 已执行这些步骤，并验证 `transformers==4.53.2`。运行时默认不会把模型权重打进镜像，而是在首次启动 policy server 时把 `OPENPI_SOURCE_CHECKPOINT` 下载并转换到 `OPENPI_CHECKPOINT` 指向的挂载缓存目录。目录已有内容时会跳过转换。

## ROS2 Bridge

包名：`pi0_bridge`

节点：

- `pi0_bridge_node`：订阅 `/camera/color/image_raw` 和 `/joint_states`，调用 openpi WebSocket policy，发布 `/pi0/action`。
- `pi0_mock_sensors`：发布随机图像和零关节状态，用于端到端验证。

常用参数：

```bash
ros2 run pi0_bridge pi0_bridge_node --ros-args \
  -p policy_host:=127.0.0.1 \
  -p policy_port:=8000 \
  -p language_instruction:="pick up the object" \
  -p observation_profile:=droid
```

`observation_profile` 支持 `droid`、`libero`、`generic`。实际机器人接入时，应按所用 openpi config 需要的 observation key 调整节点代码或参数。

## 验证清单

进入容器：

```bash
docker compose run --rm ros2 pi0-shell
```

1. GPU 可见：

```bash
nvidia-smi
```

2. openpi uv 环境中 PyTorch CUDA 可见：

```bash
cd /openpi
uv run python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
```

3. transformers 版本和补丁目录可见：

```bash
cd /openpi
uv run python -c "import transformers; print(transformers.__version__, transformers.__file__)"
test -f /openpi/.venv/lib/python3.11/site-packages/transformers/models/gemma/modeling_gemma.py
```

4. ROS2 基础功能：

```bash
ros2 doctor
ros2 topic list
```

5. 系统 Python 3.10 可导入 openpi-client 和 websocket：

```bash
python3 -c "import openpi_client, websocket; print('ok')"
```

6. policy server 监听端口：

```bash
docker compose run --rm ros2 pi0-policy
```

另开终端：

```bash
ss -ltnp | grep 8000
```

7. dummy observation 调用：

```bash
python3 - <<'PY'
import numpy as np
from openpi_client import websocket_client_policy

policy = websocket_client_policy.WebsocketClientPolicy(host="127.0.0.1", port=8000)
obs = {
    "observation/exterior_image_1_left": np.zeros((224, 224, 3), dtype=np.uint8),
    "observation/wrist_image_left": np.zeros((224, 224, 3), dtype=np.uint8),
    "observation/joint_position": np.zeros((7,), dtype=np.float32),
    "observation/gripper_position": np.zeros((1,), dtype=np.float32),
    "prompt": "pick up the object",
}
result = policy.infer(obs)
actions = result["actions"] if isinstance(result, dict) and "actions" in result else result
print(np.asarray(actions).shape)
PY
```

8. bridge 端到端：

```bash
docker compose run --rm ros2 pi0-stack
```

另开终端：

```bash
docker compose exec ros2 zsh
ros2 run pi0_bridge pi0_mock_sensors
```

再开一个终端：

```bash
docker compose exec ros2 zsh
ros2 topic echo /pi0/action --once
```

## 常见问题

CUDA 不可见：确认宿主机有 NVIDIA 驱动和 nvidia-container-toolkit，执行 `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi`。

DDS 发现失败：确认容器和宿主机使用相同 `ROS_DOMAIN_ID`，并保留 `network_mode: host`。多网卡环境可显式配置 CycloneDDS/FastDDS 网卡。

权重下载失败：确认网络能访问 `gs://openpi-assets`。也可以在宿主机提前下载或转换 checkpoint，放到 `data/openpi-cache`，然后设置 `OPENPI_CHECKPOINT=/home/ros/.cache/openpi/...`。如果你已经准备好 PyTorch checkpoint，可以设置 `OPENPI_AUTO_CONVERT_PYTORCH=0`。

transformers 补丁失效：在容器内执行 `cd /openpi && uv run python -c "import transformers; print(transformers.__version__, transformers.__file__)"`，确认版本是 `4.53.2`，并重新执行 Dockerfile 中的 `cp -r src/openpi/models_pytorch/transformers_replace/* .../transformers/`。
