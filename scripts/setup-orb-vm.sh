#!/usr/bin/env bash
# One-time bootstrap for the OrbStack native_sim VM.
# Run from macOS: bash scripts/setup-orb-vm.sh
set -euo pipefail

MACHINE="ubuntu-zephyr-native-sim"
ZEPHYR_WORKSPACE="/Users/kamilkrezolek/zephyr-workspace"

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
