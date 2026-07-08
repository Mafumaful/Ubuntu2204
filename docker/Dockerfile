ARG BASE_IMAGE=ros:humble

FROM ${BASE_IMAGE} AS openpi-builder

ARG DEBIAN_FRONTEND=noninteractive
ARG http_proxy
ARG https_proxy
ARG all_proxy
ARG no_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG NO_PROXY
ARG UBUNTU_APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ubuntu
ARG ROS_APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu
ARG PYPI_MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple
ARG UV_PYTHON_INSTALL_MIRROR=
ARG HF_ENDPOINT=https://hf-mirror.com
ARG GIT_URL_REWRITE_FROM=https://github.com/
ARG GIT_URL_REWRITE_TO=
ARG OPENPI_REPO=https://github.com/Physical-Intelligence/openpi.git
ARG OPENPI_REF=main

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PIP_INDEX_URL=${PYPI_MIRROR} \
    UV_INDEX_URL=${PYPI_MIRROR} \
    UV_DEFAULT_INDEX=${PYPI_MIRROR} \
    UV_PYTHON_INSTALL_DIR=/openpi/.uv/python \
    UV_LINK_MODE=copy \
    HF_ENDPOINT=${HF_ENDPOINT} \
    GIT_LFS_SKIP_SMUDGE=1

RUN set -eux; \
    if [ -n "${GIT_URL_REWRITE_TO}" ]; then git config --system url."${GIT_URL_REWRITE_TO}".insteadOf "${GIT_URL_REWRITE_FROM}"; fi; \
    sed -i "s|http://archive.ubuntu.com/ubuntu|${UBUNTU_APT_MIRROR}|g; s|http://security.ubuntu.com/ubuntu|${UBUNTU_APT_MIRROR}|g; s|https://archive.ubuntu.com/ubuntu|${UBUNTU_APT_MIRROR}|g; s|https://security.ubuntu.com/ubuntu|${UBUNTU_APT_MIRROR}|g" /etc/apt/sources.list; \
    find /etc/apt/sources.list.d -type f -print0 | xargs -0 -r sed -i "s|http://packages.ros.org/ros2/ubuntu|${ROS_APT_MIRROR}|g; s|https://packages.ros.org/ros2/ubuntu|${ROS_APT_MIRROR}|g"; \
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' > /etc/apt/apt.conf.d/80-retries-timeouts; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      git \
      git-lfs \
      python3-pip; \
    python3 -m pip install --no-cache-dir --upgrade pip; \
    python3 -m pip install --no-cache-dir uv; \
    git lfs install --system; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /

# Clone openpi with submodules while skipping LFS payloads. Model checkpoints are
# intentionally downloaded at runtime into the mounted cache volume.
RUN git clone --recurse-submodules --branch "${OPENPI_REF}" "${OPENPI_REPO}" /openpi

WORKDIR /openpi

# openpi's .python-version asks uv to provision Python 3.11 in an isolated venv.
# The editable install is required by current upstream docs after uv sync.
RUN set -eux; \
    if [ -n "${UV_PYTHON_INSTALL_MIRROR}" ]; then export UV_PYTHON_INSTALL_MIRROR="${UV_PYTHON_INSTALL_MIRROR}"; fi; \
    GIT_LFS_SKIP_SMUDGE=1 uv sync; \
    uv pip install -e . websocket-client websockets

# Current upstream PyTorch instructions require transformers==4.53.2 plus local
# replacement files. These files patch AdaRMS, precision handling, and KV-cache
# behavior used by openpi's PyTorch policy implementation. UV_LINK_MODE=copy keeps
# the patched files local to /openpi/.venv instead of mutating uv's package cache.
RUN test "$(/openpi/.venv/bin/python -c 'import transformers; print(transformers.__version__)')" = "4.53.2" \
    && cp -r ./src/openpi/models_pytorch/transformers_replace/* .venv/lib/python3.11/site-packages/transformers/

FROM ${BASE_IMAGE} AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG http_proxy
ARG https_proxy
ARG all_proxy
ARG no_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG ALL_PROXY
ARG NO_PROXY
ARG USER_NAME=ros
ARG USER_UID=1000
ARG USER_GID=1000
ARG ROS_DISTRO=humble
ARG UBUNTU_APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ubuntu
ARG ROS_APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu
ARG PYPI_MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple
ARG UV_PYTHON_INSTALL_MIRROR=
ARG HF_ENDPOINT=https://hf-mirror.com
ARG GIT_URL_REWRITE_FROM=https://github.com/
ARG GIT_URL_REWRITE_TO=
ARG OH_MY_ZSH_REPO=https://gitee.com/mirrors/oh-my-zsh.git
ARG ZSH_AUTOSUGGESTIONS_REPO=https://gitee.com/mirrors/zsh-autosuggestions.git
ARG ZSH_SYNTAX_HIGHLIGHTING_REPO=https://gitee.com/mirrors/zsh-syntax-highlighting.git
ARG OH_MY_ZSH_FALLBACK_REPO=https://github.com/ohmyzsh/ohmyzsh.git
ARG ZSH_AUTOSUGGESTIONS_FALLBACK_REPO=https://github.com/zsh-users/zsh-autosuggestions.git
ARG ZSH_SYNTAX_HIGHLIGHTING_FALLBACK_REPO=https://github.com/zsh-users/zsh-syntax-highlighting.git

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    ROS_DISTRO=${ROS_DISTRO} \
    USER_NAME=${USER_NAME} \
    SHELL=/usr/bin/zsh \
    OPENPI_HOME=/openpi \
    OPENPI_DATA_HOME=/home/${USER_NAME}/.cache/openpi \
    PIP_INDEX_URL=${PYPI_MIRROR} \
    UV_INDEX_URL=${PYPI_MIRROR} \
    UV_DEFAULT_INDEX=${PYPI_MIRROR} \
    UV_PYTHON_INSTALL_DIR=/openpi/.uv/python \
    UV_LINK_MODE=copy \
    HF_ENDPOINT=${HF_ENDPOINT} \
    GIT_LFS_SKIP_SMUDGE=1

RUN set -eux; \
    if [ -n "${GIT_URL_REWRITE_TO}" ]; then git config --system url."${GIT_URL_REWRITE_TO}".insteadOf "${GIT_URL_REWRITE_FROM}"; fi; \
    sed -i "s|http://archive.ubuntu.com/ubuntu|${UBUNTU_APT_MIRROR}|g; s|http://security.ubuntu.com/ubuntu|${UBUNTU_APT_MIRROR}|g; s|https://archive.ubuntu.com/ubuntu|${UBUNTU_APT_MIRROR}|g; s|https://security.ubuntu.com/ubuntu|${UBUNTU_APT_MIRROR}|g" /etc/apt/sources.list; \
    find /etc/apt/sources.list.d -type f -print0 | xargs -0 -r sed -i "s|http://packages.ros.org/ros2/ubuntu|${ROS_APT_MIRROR}|g; s|https://packages.ros.org/ros2/ubuntu|${ROS_APT_MIRROR}|g"; \
    printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' > /etc/apt/apt.conf.d/80-retries-timeouts; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash-completion \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      git \
      git-lfs \
      gnupg \
      less \
      locales \
      nano \
      net-tools \
      openssh-client \
      python3-argcomplete \
      python3-colcon-common-extensions \
      python3-pip \
      python3-rosdep \
      python3-vcstool \
      ripgrep \
      ros-${ROS_DISTRO}-action-msgs \
      ros-${ROS_DISTRO}-behaviortree-cpp-v3 \
      ros-${ROS_DISTRO}-common-interfaces \
      ros-${ROS_DISTRO}-cv-bridge \
      ros-${ROS_DISTRO}-demo-nodes-cpp \
      ros-${ROS_DISTRO}-demo-nodes-py \
      ros-${ROS_DISTRO}-diagnostic-msgs \
      ros-${ROS_DISTRO}-geometry-msgs \
      ros-${ROS_DISTRO}-image-transport \
      ros-${ROS_DISTRO}-message-filters \
      ros-${ROS_DISTRO}-nav-msgs \
      ros-${ROS_DISTRO}-nav2-bringup \
      ros-${ROS_DISTRO}-nav2-msgs \
      ros-${ROS_DISTRO}-navigation2 \
      ros-${ROS_DISTRO}-py-trees-ros \
      ros-${ROS_DISTRO}-py-trees-ros-interfaces \
      ros-${ROS_DISTRO}-sensor-msgs \
      ros-${ROS_DISTRO}-shape-msgs \
      ros-${ROS_DISTRO}-std-msgs \
      ros-${ROS_DISTRO}-std-srvs \
      ros-${ROS_DISTRO}-tf2-msgs \
      ros-${ROS_DISTRO}-trajectory-msgs \
      ros-${ROS_DISTRO}-unique-identifier-msgs \
      ros-${ROS_DISTRO}-visualization-msgs \
      sudo \
      tmux \
      tree \
      tzdata \
      vim \
      wget \
      zsh; \
    locale-gen en_US en_US.UTF-8; \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8; \
    git lfs install --system; \
    rosdep init || true; \
    rm -rf /var/lib/apt/lists/*

COPY --from=openpi-builder /openpi /openpi

RUN set -eux; \
    python3 -m pip install --no-cache-dir --upgrade pip; \
    python3 -m pip install --no-cache-dir uv; \
    python3 -m pip install --no-cache-dir -e /openpi/packages/openpi-client websocket-client websockets; \
    mkdir -p /etc/pip; \
    printf '[global]\nindex-url = %s\ntrusted-host = pypi.tuna.tsinghua.edu.cn\n' "${PYPI_MIRROR}" > /etc/pip.conf

RUN groupadd --gid ${USER_GID} ${USER_NAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /usr/bin/zsh ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} \
    && chmod 0440 /etc/sudoers.d/${USER_NAME} \
    && mkdir -p /home/${USER_NAME}/ws /home/${USER_NAME}/.cache/openpi \
    && chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME} /openpi

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

RUN set -eux; \
    clone_with_fallback() { \
      primary_repo="$1"; \
      fallback_repo="$2"; \
      destination="$3"; \
      timeout 120 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=30 clone --depth=1 "${primary_repo}" "${destination}" \
        || { rm -rf "${destination}"; timeout 120 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=30 clone --depth=1 "${fallback_repo}" "${destination}"; }; \
    }; \
    clone_with_fallback "${OH_MY_ZSH_REPO}" "${OH_MY_ZSH_FALLBACK_REPO}" "/home/${USER_NAME}/.oh-my-zsh" \
      || echo "WARNING: oh-my-zsh clone failed; continuing with plain zsh."; \
    if [ -d "/home/${USER_NAME}/.oh-my-zsh/custom/plugins" ]; then \
      clone_with_fallback "${ZSH_AUTOSUGGESTIONS_REPO}" "${ZSH_AUTOSUGGESTIONS_FALLBACK_REPO}" "/home/${USER_NAME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" \
        || echo "WARNING: zsh-autosuggestions clone failed; continuing without it."; \
      clone_with_fallback "${ZSH_SYNTAX_HIGHLIGHTING_REPO}" "${ZSH_SYNTAX_HIGHLIGHTING_FALLBACK_REPO}" "/home/${USER_NAME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" \
        || echo "WARNING: zsh-syntax-highlighting clone failed; continuing without it."; \
    fi; \
    timeout 180 rosdep update --rosdistro ${ROS_DISTRO} \
      || echo "WARNING: rosdep update failed during image build; run it inside the container when network is available."

COPY --chown=${USER_NAME}:${USER_NAME} docker/zshrc /home/${USER_NAME}/.zshrc
COPY docker/entrypoint.sh /ros_entrypoint.sh

USER root
RUN chmod +x /ros_entrypoint.sh

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}/ws

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["pi0-shell"]
