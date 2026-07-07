FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USER_NAME=ros
ARG USER_UID=1000
ARG USER_GID=1000
ARG ROS_DISTRO=humble
ARG ROS_APT_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu
ARG ROS_KEY_URL=https://mirrors.tuna.tsinghua.edu.cn/rosdistro/ros.key
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
    SHELL=/usr/bin/zsh

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    locales \
    sudo \
    tzdata \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -sSL ${ROS_KEY_URL} \
      -o /etc/apt/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/ros-archive-keyring.gpg] ${ROS_APT_MIRROR} $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
      > /etc/apt/sources.list.d/ros2.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-${ROS_DISTRO}-desktop \
    ros-${ROS_DISTRO}-navigation2 \
    ros-${ROS_DISTRO}-nav2-bringup \
    ros-${ROS_DISTRO}-nav2-msgs \
    ros-${ROS_DISTRO}-action-msgs \
    ros-${ROS_DISTRO}-common-interfaces \
    ros-${ROS_DISTRO}-diagnostic-msgs \
    ros-${ROS_DISTRO}-geometry-msgs \
    ros-${ROS_DISTRO}-nav-msgs \
    ros-${ROS_DISTRO}-sensor-msgs \
    ros-${ROS_DISTRO}-shape-msgs \
    ros-${ROS_DISTRO}-std-msgs \
    ros-${ROS_DISTRO}-std-srvs \
    ros-${ROS_DISTRO}-tf2-msgs \
    ros-${ROS_DISTRO}-trajectory-msgs \
    ros-${ROS_DISTRO}-unique-identifier-msgs \
    ros-${ROS_DISTRO}-visualization-msgs \
    ros-${ROS_DISTRO}-behaviortree-cpp-v3 \
    ros-${ROS_DISTRO}-py-trees-ros \
    ros-${ROS_DISTRO}-py-trees-ros-interfaces \
    python3-argcomplete \
    python3-colcon-common-extensions \
    python3-pip \
    python3-rosdep \
    python3-vcstool \
    build-essential \
    cmake \
    git \
    less \
    nano \
    net-tools \
    openssh-client \
    ripgrep \
    tmux \
    tree \
    vim \
    wget \
    zsh \
    && rosdep init \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid ${USER_GID} ${USER_NAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /usr/bin/zsh ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} \
    && chmod 0440 /etc/sudoers.d/${USER_NAME}

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
CMD ["zsh"]
