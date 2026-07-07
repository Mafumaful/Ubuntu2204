#!/usr/bin/env bash
set -e

USER_NAME="${USER_NAME:-ros}"
ROS_DISTRO="${ROS_DISTRO:-humble}"
WS_DIR="/home/${USER_NAME}/ws"
OPENPI_HOME="${OPENPI_HOME:-/openpi}"
OPENPI_POLICY_PORT="${OPENPI_POLICY_PORT:-8000}"
OPENPI_POLICY_CONFIG="${OPENPI_POLICY_CONFIG:-pi05_droid}"
OPENPI_SOURCE_CHECKPOINT="${OPENPI_SOURCE_CHECKPOINT:-gs://openpi-assets/checkpoints/pi05_droid}"
OPENPI_CHECKPOINT="${OPENPI_CHECKPOINT:-/home/${USER_NAME}/.cache/openpi/pytorch-checkpoints/${OPENPI_POLICY_CONFIG}}"
OPENPI_AUTO_CONVERT_PYTORCH="${OPENPI_AUTO_CONVERT_PYTORCH:-1}"

source "/opt/ros/${ROS_DISTRO}/setup.bash"

source_workspace() {
  if [ -f "${WS_DIR}/install/setup.bash" ]; then
    # shellcheck disable=SC1091
    source "${WS_DIR}/install/setup.bash"
  fi
}

build_bridge_if_requested() {
  if [ "${BUILD_WS_ON_START:-0}" = "1" ] && [ -d "${WS_DIR}/pi0_bridge" ]; then
    (
      cd "${WS_DIR}"
      colcon build --symlink-install --packages-select pi0_bridge
    )
  fi
  source_workspace
}

is_remote_path() {
  case "$1" in
    gs://*|s3://*|http://*|https://*) return 0 ;;
    *) return 1 ;;
  esac
}

is_non_empty_dir() {
  [ -d "$1" ] && [ -n "$(find "$1" -mindepth 1 -maxdepth 1 -print -quit)" ]
}

prepare_policy_checkpoint() {
  if [ "${OPENPI_AUTO_CONVERT_PYTORCH}" != "1" ]; then
    return
  fi

  if is_remote_path "${OPENPI_CHECKPOINT}"; then
    echo "OPENPI_CHECKPOINT is remote; serving it directly and skipping PyTorch conversion."
    return
  fi

  if is_non_empty_dir "${OPENPI_CHECKPOINT}"; then
    echo "Using existing PyTorch checkpoint: ${OPENPI_CHECKPOINT}"
    return
  fi

  echo "Converting ${OPENPI_SOURCE_CHECKPOINT} to PyTorch checkpoint ${OPENPI_CHECKPOINT}"
  mkdir -p "$(dirname "${OPENPI_CHECKPOINT}")"
  cd "${OPENPI_HOME}"
  uv run examples/convert_jax_model_to_pytorch.py \
    --checkpoint_dir "${OPENPI_SOURCE_CHECKPOINT}" \
    --config_name "${OPENPI_POLICY_CONFIG}" \
    --output_path "${OPENPI_CHECKPOINT}"
}

start_policy_server() {
  cd "${OPENPI_HOME}"
  prepare_policy_checkpoint
  exec uv run scripts/serve_policy.py \
    policy:checkpoint \
    --policy.config="${OPENPI_POLICY_CONFIG}" \
    --policy.dir="${OPENPI_CHECKPOINT}" \
    --port="${OPENPI_POLICY_PORT}"
}

source_workspace

case "${1:-pi0-shell}" in
  pi0-shell)
    exec "${SHELL:-/usr/bin/zsh}"
    ;;

  pi0-policy)
    shift
    start_policy_server "$@"
    ;;

  pi0-bridge)
    shift
    build_bridge_if_requested
    exec ros2 run pi0_bridge pi0_bridge_node "$@"
    ;;

  pi0-stack)
    shift
    build_bridge_if_requested
    (
      cd "${OPENPI_HOME}"
      prepare_policy_checkpoint
      uv run scripts/serve_policy.py \
        policy:checkpoint \
        --policy.config="${OPENPI_POLICY_CONFIG}" \
        --policy.dir="${OPENPI_CHECKPOINT}" \
        --port="${OPENPI_POLICY_PORT}"
    ) &
    policy_pid="$!"
    ros2 run pi0_bridge pi0_bridge_node "$@" &
    bridge_pid="$!"
    cleanup() {
      kill "${bridge_pid}" 2>/dev/null || true
      kill "${policy_pid}" 2>/dev/null || true
      wait "${bridge_pid}" 2>/dev/null || true
      wait "${policy_pid}" 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM
    wait "${bridge_pid}"
    ;;

  *)
    exec "$@"
    ;;
esac
