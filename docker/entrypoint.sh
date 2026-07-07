#!/usr/bin/env bash
set -e

source "/opt/ros/${ROS_DISTRO:-humble}/setup.bash"

if [ -f "/home/${USER_NAME:-ros}/ws/install/setup.bash" ]; then
  source "/home/${USER_NAME:-ros}/ws/install/setup.bash"
fi

exec "$@"
