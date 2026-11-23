#!/bin/sh
# Python GPU 应用只在现有 glibc SDK 内运行，不激活到 musl 登录环境。
set -eu

if [ "$(id -u)" = 0 ]; then
  echo "Run as the desktop user; install cuda-sdk/Flatpak prerequisites separately." >&2
  exit 1
fi
command -v cuda-sdk >/dev/null 2>&1 || {
  echo "Missing the managed cuda-sdk launcher." >&2
  exit 1
}

state=${CUDA_PYTHON_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/gentoo-gpu}
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
case "$state" in
  /*) ;;
  *) echo "CUDA_PYTHON_HOME must be an absolute path." >&2; exit 2 ;;
esac
umask 077
mkdir -p "$state"
cd "$state"

if [ "${1:-}" = --check ]; then
  shift
  check_source=$(mktemp "$state/.cuda-check.XXXXXXXX.py")
  trap 'rm -f -- "$check_source"' 0
  trap 'exit 1' HUP INT TERM
  cp "$script_dir/check-cuda-python.py" "$check_source"
  set -- --run "$check_source" "$@"
fi

case "${1:-}" in
  --setup)
    # 不锁死历史版本；升级前先用 --dry-run 审阅官方二进制依赖图。
    shift
    cuda-sdk python3 -m venv .venv
    CUDA_SDK_NETWORK=1 cuda-sdk env \
      HTTP_PROXY="${HTTP_PROXY:-${http_proxy:-}}" \
      HTTPS_PROXY="${HTTPS_PROXY:-${https_proxy:-}}" \
      NO_PROXY="${NO_PROXY:-${no_proxy:-}}" \
      .venv/bin/python -m pip install \
      --only-binary=:all: --index-url https://download.pytorch.org/whl/cu130 "$@" torch numpy
    ;;
  --run)
    shift
    test -x .venv/bin/python || {
      echo "Run --setup first, using the same SDK Python minor version." >&2
      exit 1
    }
    # cuda-sdk 在前面添加核心 NVCC 的 lib64；PyTorch 使用自己声明的 CUDA 库。
    # 仅移除该目录，保留 Flatpak 的 NVIDIA 驱动与其他运行库搜索路径。
    # Variables in this command expand inside the SDK, not in the host shell.
    # shellcheck disable=SC2016
    # Keep this shell alive so --check can remove its private temporary source.
    cuda-sdk sh -c '
      toolkit_lib="$CUDA_HOME/lib64"
      case "$LD_LIBRARY_PATH" in
        "$toolkit_lib":*) LD_LIBRARY_PATH=${LD_LIBRARY_PATH#*:} ;;
        "$toolkit_lib") LD_LIBRARY_PATH= ;;
        *) echo "Unexpected SDK library search order; inspect before running." >&2; exit 1 ;;
      esac
      export LD_LIBRARY_PATH
      exec .venv/bin/python "$@"
    ' cuda-python "$@"
    ;;
  *)
    echo "Usage: cuda-python.sh --setup [pip options] | --check [--seconds 0..600] | --run [python arguments]" >&2
    echo "Set CUDA_SDK_NETWORK=1 only when a Python application needs network access." >&2
    exit 2
    ;;
esac
