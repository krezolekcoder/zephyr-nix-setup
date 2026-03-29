#!/usr/bin/env bash
# One-time bootstrap for the OrbStack native_sim VM.
# Run from macOS: bash scripts/setup-orb-vm.sh
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "error: This script is macOS-only (OrbStack is not available on Linux)." >&2
  echo "On Linux, native_sim runs directly — no VM setup needed." >&2
  exit 1
fi

MACHINE="${ZEPHYR_ORB_MACHINE:-ubuntu-zephyr-native-sim}"
# Default: $HOME/zephyr-workspace. Override by setting ZEPHYR_WORKSPACE before running.
ZEPHYR_WORKSPACE="${ZEPHYR_WORKSPACE:-$HOME/zephyr-workspace}"

echo "==> Bootstrapping $MACHINE for Zephyr native_sim..."

run() {
  orb run -m "$MACHINE" "$@"
}

echo "==> Installing system packages..."
run sudo apt-get update -qq
run sudo apt-get install -y --no-install-recommends \
  cmake ninja-build make gcc g++ python3-pip python3-venv python3-full

echo "==> Creating Python venv and installing Zephyr tools..."
run bash -c "
  python3 -m venv \$HOME/.venv/zephyr && \
  \$HOME/.venv/zephyr/bin/pip install --quiet \
    west pyelftools pyyaml packaging colorama
"

echo "==> Writing shell environment..."
run bash -c "cat >> \$HOME/.profile << 'EOF'

# Zephyr native_sim setup (added by setup-orb-vm.sh)
export ZEPHYR_BASE=${ZEPHYR_WORKSPACE}/zephyr
source \$HOME/.venv/zephyr/bin/activate
EOF"

echo ""
echo "Done. VM is ready."
echo "Test it: orb run -m $MACHINE bash -lc 'west --version'"
